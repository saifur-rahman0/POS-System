"""Service layer orchestrating Loyalty, Membership Tiers, Gift Cards, Credit Notes, and CRM."""

import csv
import io
import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.crm.gift_card_service import GiftCardService
from app.modules.crm.loyalty_engine import LoyaltyEngine
from app.modules.crm.models import (
    CreditNote,
    GiftCard,
    LoyaltySettings,
    MembershipTier,
    PromotionalCampaign,
)
from app.modules.crm.repository import CrmRepository
from app.modules.crm.rfm_engine import RfmEngine, ScoredCustomer
from app.modules.crm.schemas import (
    AudiencePreviewOut,
    CustomerLoyaltySummaryOut,
    GiftCardCreate,
    GiftCardTransactionOut,
    GiftCardVerifyOut,
    LoyaltySettingsUpdate,
    LoyaltyTransactionOut,
    MembershipTierCreate,
    MembershipTierUpdate,
    PointsRedemptionPreviewOut,
    PromotionalCampaignCreate,
    PromotionalCampaignUpdate,
    RetentionKpisOut,
    RfmSegmentSummaryOut,
)


class CrmService:
    """Master business facade coordinating all CRM and loyalty subsystems."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repo = CrmRepository(session)

    # -----------------------------------------------------------------------
    # Loyalty Settings
    # -----------------------------------------------------------------------
    async def get_settings(self, business_id: uuid.UUID) -> LoyaltySettings:
        return await self.repo.get_or_create_settings(business_id)

    async def update_settings(
        self, business_id: uuid.UUID, data: LoyaltySettingsUpdate
    ) -> LoyaltySettings:
        return await self.repo.update_settings(business_id, data)

    # -----------------------------------------------------------------------
    # Membership Tiers
    # -----------------------------------------------------------------------
    async def get_tiers(
        self, business_id: uuid.UUID, active_only: bool = False
    ) -> list[MembershipTier]:
        return await self.repo.get_tiers(business_id, active_only=active_only)

    async def create_tier(
        self, business_id: uuid.UUID, data: MembershipTierCreate
    ) -> MembershipTier:
        existing = await self.repo.get_tier_by_code(business_id, data.code)
        if existing:
            raise ValueError(f"Tier with code '{data.code}' already exists")
        return await self.repo.create_tier(business_id, data)

    async def update_tier(
        self, business_id: uuid.UUID, tier_id: uuid.UUID, data: MembershipTierUpdate
    ) -> MembershipTier:
        tier = await self.repo.update_tier(business_id, tier_id, data)
        if not tier:
            raise ValueError("Membership tier not found")
        return tier

    async def delete_tier(self, business_id: uuid.UUID, tier_id: uuid.UUID) -> bool:
        deleted = await self.repo.delete_tier(business_id, tier_id)
        if not deleted:
            raise ValueError("Membership tier not found")
        return True

    # -----------------------------------------------------------------------
    # Customer Loyalty Summary & Point Actions
    # -----------------------------------------------------------------------
    async def get_customer_loyalty_summary(
        self, business_id: uuid.UUID, customer_id: uuid.UUID
    ) -> CustomerLoyaltySummaryOut:
        customer = await self.repo.get_customer(business_id, customer_id)
        if not customer:
            raise ValueError("Customer not found")

        tier: MembershipTier | None = None
        if customer.membership_tier_id:
            tier = await self.repo.get_tier_by_id(business_id, customer.membership_tier_id)

        txs = await self.repo.get_customer_transactions(business_id, customer_id, limit=20)
        recent_tx_models = [LoyaltyTransactionOut.model_validate(t) for t in txs]

        return CustomerLoyaltySummaryOut(
            customer_id=customer.id,
            customer_name=customer.name,
            phone=customer.phone,
            loyalty_points_balance=customer.loyalty_points_balance,
            membership_tier_id=tier.id if tier else None,
            membership_tier_name=tier.name if tier else None,
            points_multiplier=tier.points_multiplier if tier else Decimal("1.00"),
            tier_discount_pct=tier.discount_pct if tier else Decimal("0.00"),
            badge_color=tier.badge_color if tier else "#64748B",
            lifetime_spend=customer.lifetime_spend,
            store_credit_balance=customer.store_credit_balance,
            recent_transactions=recent_tx_models,
        )

    async def adjust_customer_points(
        self, business_id: uuid.UUID, customer_id: uuid.UUID, points: int, reason: str
    ) -> LoyaltyTransactionOut:
        tx_type = "BONUS" if points > 0 else "ADJUSTMENT"
        tx = await self.repo.record_loyalty_transaction(
            business_id=business_id,
            customer_id=customer_id,
            transaction_type=tx_type,
            points=points,
            reason=reason,
        )
        return LoyaltyTransactionOut.model_validate(tx)

    async def preview_points_redemption(
        self,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
        points_to_redeem: int,
        cart_subtotal: Decimal,
    ) -> PointsRedemptionPreviewOut:
        settings = await self.repo.get_or_create_settings(business_id)
        customer = await self.repo.get_customer(business_id, customer_id)
        if not customer:
            return PointsRedemptionPreviewOut(
                points_to_redeem=points_to_redeem,
                discount_amount=Decimal("0.0000"),
                points_balance_remaining=0,
                is_valid=False,
                error_message="Customer not found",
            )

        try:
            discount = LoyaltyEngine.validate_and_calculate_redemption(
                customer_points=customer.loyalty_points_balance,
                points_to_redeem=points_to_redeem,
                cart_subtotal=cart_subtotal,
                is_enabled=settings.is_enabled,
                min_redeem_points=settings.min_redeem_points,
                redeem_rate=settings.redeem_rate,
                max_cart_discount_pct=settings.max_cart_discount_pct,
            )
            return PointsRedemptionPreviewOut(
                points_to_redeem=points_to_redeem,
                discount_amount=discount,
                points_balance_remaining=customer.loyalty_points_balance - points_to_redeem,
                is_valid=True,
            )
        except ValueError as err:
            return PointsRedemptionPreviewOut(
                points_to_redeem=points_to_redeem,
                discount_amount=Decimal("0.0000"),
                points_balance_remaining=customer.loyalty_points_balance,
                is_valid=False,
                error_message=str(err),
            )

    # -----------------------------------------------------------------------
    # Gift Cards
    # -----------------------------------------------------------------------
    async def get_gift_cards(
        self,
        business_id: uuid.UUID,
        status: str | None = None,
        search: str | None = None,
    ) -> list[GiftCard]:
        return await self.repo.get_gift_cards(business_id, status=status, search=search)

    async def issue_gift_card(
        self, business_id: uuid.UUID, data: GiftCardCreate
    ) -> GiftCard:
        card_number = data.card_number or GiftCardService.generate_card_number()
        pin_hash = GiftCardService.hash_pin(data.pin)

        return await self.repo.create_gift_card(
            business_id=business_id,
            card_number=card_number,
            pin_hash=pin_hash,
            initial_balance=data.initial_balance,
            purchaser_customer_id=data.purchaser_customer_id,
            recipient_name=data.recipient_name,
            recipient_phone=data.recipient_phone,
            recipient_email=data.recipient_email,
            expires_at=data.expires_at,
        )

    async def verify_gift_card(
        self, business_id: uuid.UUID, card_number: str, pin: str
    ) -> GiftCardVerifyOut:
        card = await self.repo.get_gift_card_by_number(business_id, card_number)
        if not card:
            return GiftCardVerifyOut(
                is_valid=False,
                message="Gift card number not found",
            )

        if not GiftCardService.verify_pin(card.pin_hash, pin):
            return GiftCardVerifyOut(
                is_valid=False,
                card_number=card.card_number,
                message="Invalid PIN entered",
            )

        if card.status != "ACTIVE":
            return GiftCardVerifyOut(
                is_valid=False,
                card_id=card.id,
                card_number=card.card_number,
                current_balance=card.current_balance,
                status=card.status,
                message=f"Gift card is {card.status}",
            )

        if card.expires_at and card.expires_at < datetime.utcnow():
            return GiftCardVerifyOut(
                is_valid=False,
                card_id=card.id,
                card_number=card.card_number,
                current_balance=card.current_balance,
                status="EXPIRED",
                message="Gift card has expired",
            )

        return GiftCardVerifyOut(
            is_valid=True,
            card_id=card.id,
            card_number=card.card_number,
            current_balance=card.current_balance,
            status=card.status,
            message="Gift card is active and verified",
        )

    async def reload_gift_card(
        self,
        business_id: uuid.UUID,
        card_id: uuid.UUID,
        amount: Decimal,
        reference: str | None = None,
        notes: str | None = None,
    ) -> GiftCardTransactionOut:
        card, tx = await self.repo.record_gift_card_transaction(
            business_id=business_id,
            gift_card_id=card_id,
            transaction_type="RELOAD",
            amount=amount,
            reference=reference,
            notes=notes or "Card balance reload",
        )
        return GiftCardTransactionOut.model_validate(tx)

    async def toggle_gift_card_status(
        self, business_id: uuid.UUID, card_id: uuid.UUID, new_status: str
    ) -> GiftCard:
        card = await self.repo.get_gift_card_by_id(business_id, card_id, for_update=True)
        if not card:
            raise ValueError("Gift card not found")
        card.status = new_status
        await self.session.flush()
        return card

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
        return await self.repo.get_credit_notes(
            business_id, customer_id=customer_id, status=status, search=search
        )

    async def create_credit_note(
        self,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
        initial_amount: Decimal,
        reason: str,
        sale_return_id: uuid.UUID | None = None,
        expires_at: datetime | None = None,
    ) -> CreditNote:
        return await self.repo.create_credit_note(
            business_id=business_id,
            customer_id=customer_id,
            initial_amount=initial_amount,
            reason=reason,
            sale_return_id=sale_return_id,
            expires_at=expires_at,
        )

    # -----------------------------------------------------------------------
    # RFM & Retention Analytics
    # -----------------------------------------------------------------------
    async def get_rfm_analytics(self, business_id: uuid.UUID) -> RetentionKpisOut:
        customer_data = await self.repo.get_customer_sales_aggregates_365d(business_id)
        scored: list[ScoredCustomer] = RfmEngine.score_customers(customer_data)

        # Update rfm_segment on customer records
        for item in scored:
            customer = await self.repo.get_customer(business_id, uuid.UUID(item.customer_id))
            if customer and customer.rfm_segment != item.segment:
                customer.rfm_segment = item.segment

        await self.session.flush()

        # Compute Segment Breakdown
        segment_groups: dict[str, list[ScoredCustomer]] = {}
        for s in scored:
            segment_groups.setdefault(s.segment, []).append(s)

        total_customers = len(scored) or 1
        summaries: list[RfmSegmentSummaryOut] = []
        for seg_name, members in segment_groups.items():
            tot_monetary = sum((m.monetary_spent for m in members), Decimal("0.0000"))
            avg_recency = sum(m.recency_days for m in members) / len(members)
            summaries.append(
                RfmSegmentSummaryOut(
                    segment=seg_name,
                    count=len(members),
                    percentage=round((len(members) / total_customers) * 100, 2),
                    total_monetary=tot_monetary,
                    avg_recency_days=round(avg_recency, 1),
                )
            )

        # Retention KPIs
        active_customers = [s for s in scored if s.recency_days <= 90]
        repeat_customers = [s for s in scored if s.frequency_orders > 1]
        churned_90d = [s for s in scored if s.frequency_orders > 0 and s.recency_days > 90]

        repeat_rate = (len(repeat_customers) / total_customers) * 100 if scored else 0.0
        churn_rate = (len(churned_90d) / total_customers) * 100 if scored else 0.0

        total_revenue = sum((s.monetary_spent for s in scored), Decimal("0.0000"))
        avg_clv = (total_revenue / Decimal(str(len(scored)))) if scored else Decimal("0.0000")

        at_risk_members = segment_groups.get("AT_RISK", [])
        revenue_at_risk = sum((m.monetary_spent for m in at_risk_members), Decimal("0.0000"))

        return RetentionKpisOut(
            total_active_customers=len(active_customers),
            repeat_purchase_rate=round(repeat_rate, 2),
            churn_rate_90d=round(churn_rate, 2),
            avg_clv=avg_clv.quantize(Decimal("0.01")),
            revenue_at_risk=revenue_at_risk.quantize(Decimal("0.01")),
            segments=summaries,
        )

    # -----------------------------------------------------------------------
    # Promotional Campaigns
    # -----------------------------------------------------------------------
    async def get_campaigns(self, business_id: uuid.UUID) -> list[PromotionalCampaign]:
        return await self.repo.get_campaigns(business_id)

    async def create_campaign(
        self, business_id: uuid.UUID, data: PromotionalCampaignCreate
    ) -> PromotionalCampaign:
        audience = await self.repo.get_audience_customers(
            business_id,
            target_segment=data.target_segment,
            target_group_id=data.target_group_id,
        )
        return await self.repo.create_campaign(business_id, data, audience_count=len(audience))

    async def update_campaign(
        self,
        business_id: uuid.UUID,
        campaign_id: uuid.UUID,
        data: PromotionalCampaignUpdate,
    ) -> PromotionalCampaign:
        camp = await self.repo.update_campaign(business_id, campaign_id, data)
        if not camp:
            raise ValueError("Promotional campaign not found")
        return camp

    async def preview_campaign_audience(
        self, business_id: uuid.UUID, campaign_id: uuid.UUID
    ) -> AudiencePreviewOut:
        camp = await self.repo.get_campaign_by_id(business_id, campaign_id)
        if not camp:
            raise ValueError("Campaign not found")

        customers = await self.repo.get_audience_customers(
            business_id,
            target_segment=camp.target_segment,
            target_group_id=camp.target_group_id,
        )

        samples = [
            {
                "id": str(c.id),
                "name": c.name,
                "phone": c.phone,
                "email": c.email,
                "rfm_segment": c.rfm_segment,
                "loyalty_points": c.loyalty_points_balance,
            }
            for c in customers[:10]
        ]

        return AudiencePreviewOut(
            total_recipients=len(customers),
            sample_recipients=samples,
        )

    async def export_campaign_recipients_csv(
        self, business_id: uuid.UUID, campaign_id: uuid.UUID
    ) -> str:
        camp = await self.repo.get_campaign_by_id(business_id, campaign_id)
        if not camp:
            raise ValueError("Campaign not found")

        customers = await self.repo.get_audience_customers(
            business_id,
            target_segment=camp.target_segment,
            target_group_id=camp.target_group_id,
        )

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["Customer Name", "Phone", "Email", "RFM Segment", "Loyalty Points", "Store Credit"])

        for c in customers:
            writer.writerow([
                c.name,
                c.phone or "",
                c.email or "",
                c.rfm_segment or "",
                c.loyalty_points_balance,
                f"{c.store_credit_balance:.2f}",
            ])

        return output.getvalue()

