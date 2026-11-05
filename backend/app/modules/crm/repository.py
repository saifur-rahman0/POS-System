"""Repository layer for Loyalty, Membership Tiers, Gift Cards, Credit Notes, and CRM."""

import uuid
from datetime import datetime, timedelta
from decimal import Decimal

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.crm.gift_card_service import GiftCardService
from app.modules.crm.models import (
    CreditNote,
    GiftCard,
    GiftCardTransaction,
    LoyaltySettings,
    LoyaltyTransaction,
    MembershipTier,
    PromotionalCampaign,
)
from app.modules.crm.rfm_engine import CustomerSalesData
from app.modules.crm.schemas import (
    LoyaltySettingsUpdate,
    MembershipTierCreate,
    MembershipTierUpdate,
    PromotionalCampaignCreate,
    PromotionalCampaignUpdate,
)
from app.modules.sales.models import Customer, Sale


class CrmRepository:
    """Database persistence and query operations for CRM domain."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # -----------------------------------------------------------------------
    # Loyalty Settings
    # -----------------------------------------------------------------------
    async def get_or_create_settings(self, business_id: uuid.UUID) -> LoyaltySettings:
        stmt = select(LoyaltySettings).where(LoyaltySettings.business_id == business_id)
        result = await self.session.execute(stmt)
        settings = result.scalar_one_or_none()

        if settings is None:
            settings = LoyaltySettings(business_id=business_id)
            self.session.add(settings)
            await self.session.flush()

        return settings

    async def update_settings(
        self, business_id: uuid.UUID, data: LoyaltySettingsUpdate
    ) -> LoyaltySettings:
        settings = await self.get_or_create_settings(business_id)
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            if value is not None:
                setattr(settings, field, value)
        settings.updated_at = datetime.utcnow()
        await self.session.flush()
        return settings

    # -----------------------------------------------------------------------
    # Membership Tiers
    # -----------------------------------------------------------------------
    async def get_tiers(
        self, business_id: uuid.UUID, active_only: bool = False
    ) -> list[MembershipTier]:
        stmt = select(MembershipTier).where(MembershipTier.business_id == business_id)
        if active_only:
            stmt = stmt.where(MembershipTier.is_active == True)  # noqa: E712
        stmt = stmt.order_by(MembershipTier.sort_order.asc(), MembershipTier.min_spend.asc())
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_tier_by_id(
        self, business_id: uuid.UUID, tier_id: uuid.UUID
    ) -> MembershipTier | None:
        stmt = select(MembershipTier).where(
            MembershipTier.business_id == business_id,
            MembershipTier.id == tier_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_tier_by_code(
        self, business_id: uuid.UUID, code: str
    ) -> MembershipTier | None:
        stmt = select(MembershipTier).where(
            MembershipTier.business_id == business_id,
            func.lower(MembershipTier.code) == code.lower(),
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_tier(
        self, business_id: uuid.UUID, data: MembershipTierCreate
    ) -> MembershipTier:
        tier = MembershipTier(
            business_id=business_id,
            name=data.name,
            code=data.code.upper(),
            min_spend=data.min_spend,
            points_multiplier=data.points_multiplier,
            discount_pct=data.discount_pct,
            badge_color=data.badge_color,
            perks_description=data.perks_description,
            sort_order=data.sort_order,
            is_active=data.is_active,
        )
        self.session.add(tier)
        await self.session.flush()
        return tier

    async def update_tier(
        self, business_id: uuid.UUID, tier_id: uuid.UUID, data: MembershipTierUpdate
    ) -> MembershipTier | None:
        tier = await self.get_tier_by_id(business_id, tier_id)
        if not tier:
            return None
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            if value is not None:
                setattr(tier, field, value)
        await self.session.flush()
        return tier

    async def delete_tier(self, business_id: uuid.UUID, tier_id: uuid.UUID) -> bool:
        tier = await self.get_tier_by_id(business_id, tier_id)
        if not tier:
            return False
        # Remove tier references from customers first
        await self.session.execute(
            update(Customer)
            .where(Customer.membership_tier_id == tier_id)
            .values(membership_tier_id=None)
        )
        await self.session.delete(tier)
        await self.session.flush()
        return True

    # -----------------------------------------------------------------------
    # Loyalty Transactions & Customer Points
    # -----------------------------------------------------------------------
    async def get_customer(
        self, business_id: uuid.UUID, customer_id: uuid.UUID, for_update: bool = False
    ) -> Customer | None:
        stmt = select(Customer).where(
            Customer.business_id == business_id,
            Customer.id == customer_id,
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_customer_transactions(
        self, business_id: uuid.UUID, customer_id: uuid.UUID, limit: int = 50
    ) -> list[LoyaltyTransaction]:
        stmt = (
            select(LoyaltyTransaction)
            .where(
                LoyaltyTransaction.business_id == business_id,
                LoyaltyTransaction.customer_id == customer_id,
            )
            .order_by(LoyaltyTransaction.created_at.desc())
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def record_loyalty_transaction(
        self,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
        transaction_type: str,
        points: int,
        reason: str | None = None,
        sale_id: uuid.UUID | None = None,
    ) -> LoyaltyTransaction:
        customer = await self.get_customer(business_id, customer_id, for_update=True)
        if not customer:
            raise ValueError("Customer not found")

        new_balance = customer.loyalty_points_balance + points
        if new_balance < 0:
            raise ValueError(
                f"Customer points balance cannot be negative (current {customer.loyalty_points_balance}, delta {points})"
            )

        customer.loyalty_points_balance = new_balance

        tx = LoyaltyTransaction(
            business_id=business_id,
            customer_id=customer_id,
            sale_id=sale_id,
            transaction_type=transaction_type,
            points=points,
            points_balance_after=new_balance,
            reason=reason,
        )
        self.session.add(tx)
        await self.session.flush()
        return tx

    # -----------------------------------------------------------------------
    # Gift Cards
    # -----------------------------------------------------------------------
    async def get_gift_cards(
        self,
        business_id: uuid.UUID,
        status: str | None = None,
        search: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[GiftCard]:
        stmt = select(GiftCard).where(GiftCard.business_id == business_id)
        if status:
            stmt = stmt.where(GiftCard.status == status)
        if search:
            pattern = f"%{search.strip()}%"
            stmt = stmt.where(
                GiftCard.card_number.ilike(pattern)
                | GiftCard.recipient_name.ilike(pattern)
                | GiftCard.recipient_phone.ilike(pattern)
            )
        stmt = stmt.order_by(GiftCard.created_at.desc()).offset(offset).limit(limit)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_gift_card_by_id(
        self, business_id: uuid.UUID, card_id: uuid.UUID, for_update: bool = False
    ) -> GiftCard | None:
        stmt = select(GiftCard).where(
            GiftCard.business_id == business_id,
            GiftCard.id == card_id,
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_gift_card_by_number(
        self, business_id: uuid.UUID, card_number: str, for_update: bool = False
    ) -> GiftCard | None:
        stmt = select(GiftCard).where(
            GiftCard.business_id == business_id,
            func.lower(GiftCard.card_number) == card_number.strip().lower(),
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_gift_card(
        self,
        business_id: uuid.UUID,
        card_number: str,
        pin_hash: str,
        initial_balance: Decimal,
        purchaser_customer_id: uuid.UUID | None = None,
        recipient_name: str | None = None,
        recipient_phone: str | None = None,
        recipient_email: str | None = None,
        expires_at: datetime | None = None,
    ) -> GiftCard:
        card = GiftCard(
            business_id=business_id,
            card_number=card_number,
            pin_hash=pin_hash,
            initial_balance=initial_balance,
            current_balance=initial_balance,
            status="ACTIVE",
            purchaser_customer_id=purchaser_customer_id,
            recipient_name=recipient_name,
            recipient_phone=recipient_phone,
            recipient_email=recipient_email,
            expires_at=expires_at,
        )
        self.session.add(card)
        await self.session.flush()

        tx = GiftCardTransaction(
            business_id=business_id,
            gift_card_id=card.id,
            transaction_type="ISSUE",
            amount=initial_balance,
            balance_after=initial_balance,
            notes="Initial card issuance",
        )
        self.session.add(tx)
        await self.session.flush()
        return card

    async def record_gift_card_transaction(
        self,
        business_id: uuid.UUID,
        gift_card_id: uuid.UUID,
        transaction_type: str,
        amount: Decimal,
        reference: str | None = None,
        notes: str | None = None,
        sale_id: uuid.UUID | None = None,
    ) -> tuple[GiftCard, GiftCardTransaction]:
        card = await self.get_gift_card_by_id(business_id, gift_card_id, for_update=True)
        if not card:
            raise ValueError("Gift card not found")

        new_balance = card.current_balance + amount
        if new_balance < Decimal("0.0000"):
            raise ValueError(
                f"Insufficient gift card balance: current {card.current_balance}, charge {amount}"
            )

        card.current_balance = new_balance
        if new_balance == Decimal("0.0000") and card.status == "ACTIVE":
            card.status = "DEPLETED"
        elif new_balance > Decimal("0.0000") and card.status == "DEPLETED":
            card.status = "ACTIVE"

        tx = GiftCardTransaction(
            business_id=business_id,
            gift_card_id=card.id,
            sale_id=sale_id,
            transaction_type=transaction_type,
            amount=amount,
            balance_after=new_balance,
            reference=reference,
            notes=notes,
        )
        self.session.add(tx)
        await self.session.flush()
        return card, tx

    async def get_gift_card_transactions(
        self, business_id: uuid.UUID, gift_card_id: uuid.UUID
    ) -> list[GiftCardTransaction]:
        stmt = (
            select(GiftCardTransaction)
            .where(
                GiftCardTransaction.business_id == business_id,
                GiftCardTransaction.gift_card_id == gift_card_id,
            )
            .order_by(GiftCardTransaction.created_at.desc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    # -----------------------------------------------------------------------
    # Credit Notes
    # -----------------------------------------------------------------------
    async def get_credit_notes(
        self,
        business_id: uuid.UUID,
        customer_id: uuid.UUID | None = None,
        status: str | None = None,
        search: str | None = None,
    ) -> list[CreditNote]:
        stmt = select(CreditNote).where(CreditNote.business_id == business_id)
        if customer_id:
            stmt = stmt.where(CreditNote.customer_id == customer_id)
        if status:
            stmt = stmt.where(CreditNote.status == status)
        if search:
            stmt = stmt.where(CreditNote.note_number.ilike(f"%{search.strip()}%"))
        stmt = stmt.order_by(CreditNote.created_at.desc())
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def create_credit_note(
        self,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
        initial_amount: Decimal,
        reason: str,
        sale_return_id: uuid.UUID | None = None,
        expires_at: datetime | None = None,
    ) -> CreditNote:
        note_num = GiftCardService.generate_credit_note_number()
        note = CreditNote(
            business_id=business_id,
            customer_id=customer_id,
            sale_return_id=sale_return_id,
            note_number=note_num,
            initial_amount=initial_amount,
            remaining_balance=initial_amount,
            status="ACTIVE",
            reason=reason,
            expires_at=expires_at,
        )
        self.session.add(note)

        # Update customer store credit balance
        customer = await self.get_customer(business_id, customer_id, for_update=True)
        if customer:
            customer.store_credit_balance += initial_amount

        await self.session.flush()
        return note

    # -----------------------------------------------------------------------
    # RFM & Retention Aggregates
    # -----------------------------------------------------------------------
    async def get_customer_sales_aggregates_365d(
        self, business_id: uuid.UUID
    ) -> list[CustomerSalesData]:
        cutoff = datetime.utcnow() - timedelta(days=365)

        # Aggregate completed sales in last 365 days
        stmt = (
            select(
                Customer.id,
                Customer.name,
                Customer.phone,
                func.max(Sale.created_at).label("last_sale_date"),
                func.count(Sale.id).label("order_count"),
                func.coalesce(func.sum(Sale.grand_total), 0).label("total_spent"),
            )
            .outerjoin(
                Sale,
                (Sale.customer_id == Customer.id)
                & (Sale.status == "COMPLETED")
                & (Sale.created_at >= cutoff),
            )
            .where(Customer.business_id == business_id)
            .group_by(Customer.id, Customer.name, Customer.phone)
        )
        result = await self.session.execute(stmt)

        data: list[CustomerSalesData] = []
        for row in result.all():
            data.append(
                CustomerSalesData(
                    customer_id=str(row[0]),
                    customer_name=row[1],
                    phone=row[2],
                    last_sale_date=row[3],
                    order_count=row[4] or 0,
                    total_spent=Decimal(str(row[5] or 0)),
                )
            )
        return data

    # -----------------------------------------------------------------------
    # Promotional Campaigns
    # -----------------------------------------------------------------------
    async def get_campaigns(self, business_id: uuid.UUID) -> list[PromotionalCampaign]:
        stmt = (
            select(PromotionalCampaign)
            .where(PromotionalCampaign.business_id == business_id)
            .order_by(PromotionalCampaign.created_at.desc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_campaign_by_id(
        self, business_id: uuid.UUID, campaign_id: uuid.UUID
    ) -> PromotionalCampaign | None:
        stmt = select(PromotionalCampaign).where(
            PromotionalCampaign.business_id == business_id,
            PromotionalCampaign.id == campaign_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_campaign(
        self, business_id: uuid.UUID, data: PromotionalCampaignCreate, audience_count: int
    ) -> PromotionalCampaign:
        camp = PromotionalCampaign(
            business_id=business_id,
            title=data.title,
            target_segment=data.target_segment,
            target_group_id=data.target_group_id,
            channel=data.channel,
            message_template=data.message_template,
            promotion_id=data.promotion_id,
            audience_count=audience_count,
            status="DRAFT" if not data.scheduled_at else "SCHEDULED",
            scheduled_at=data.scheduled_at,
        )
        self.session.add(camp)
        await self.session.flush()
        return camp

    async def update_campaign(
        self,
        business_id: uuid.UUID,
        campaign_id: uuid.UUID,
        data: PromotionalCampaignUpdate,
    ) -> PromotionalCampaign | None:
        camp = await self.get_campaign_by_id(business_id, campaign_id)
        if not camp:
            return None
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            if value is not None:
                setattr(camp, field, value)
        await self.session.flush()
        return camp

    async def get_audience_customers(
        self,
        business_id: uuid.UUID,
        target_segment: str,
        target_group_id: uuid.UUID | None = None,
    ) -> list[Customer]:
        stmt = select(Customer).where(
            Customer.business_id == business_id,
            Customer.is_active == True,  # noqa: E712
        )
        if target_group_id:
            stmt = stmt.where(Customer.primary_group_id == target_group_id)
        elif target_segment != "ALL":
            stmt = stmt.where(Customer.rfm_segment == target_segment)

        stmt = stmt.order_by(Customer.name.asc())
        result = await self.session.execute(stmt)
        return list(result.scalars().all())
