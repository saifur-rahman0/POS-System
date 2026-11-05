"""Database repository for pricing, customer groups, bundles, and promotions."""

import uuid
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.catalog.models import Product, ProductVariant
from app.modules.pricing.models import (
    BranchPriceOverride,
    CustomerGroup,
    CustomerGroupMember,
    PriceList,
    PriceListItem,
    ProductBundle,
    ProductBundleItem,
    Promotion,
    PromotionUsage,
)
from app.modules.sales.models import Customer


class PricingRepository:
    """Async database operations for pricing models."""

    # -------------------------------------------------------------------------
    # Customer Groups
    # -------------------------------------------------------------------------
    async def list_customer_groups(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[CustomerGroup]:
        stmt = select(CustomerGroup).where(CustomerGroup.business_id == business_id)
        if is_active is not None:
            stmt = stmt.where(CustomerGroup.is_active == is_active)
        stmt = stmt.order_by(CustomerGroup.name.asc())
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_customer_group_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        group_id: uuid.UUID,
    ) -> CustomerGroup | None:
        stmt = (
            select(CustomerGroup)
            .where(
                CustomerGroup.business_id == business_id,
                CustomerGroup.id == group_id,
            )
            .options(selectinload(CustomerGroup.members))
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_customer_group_by_name(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        name: str,
    ) -> CustomerGroup | None:
        stmt = select(CustomerGroup).where(
            CustomerGroup.business_id == business_id,
            func.lower(CustomerGroup.name) == name.strip().lower(),
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def count_group_members(
        self,
        session: AsyncSession,
        group_id: uuid.UUID,
    ) -> int:
        stmt = select(func.count(CustomerGroupMember.id)).where(
            CustomerGroupMember.customer_group_id == group_id
        )
        result = await session.execute(stmt)
        return result.scalar_one() or 0

    async def create_customer_group(
        self,
        session: AsyncSession,
        group: CustomerGroup,
    ) -> CustomerGroup:
        session.add(group)
        await session.flush()
        await session.refresh(group)
        return group

    async def add_group_member(
        self,
        session: AsyncSession,
        member: CustomerGroupMember,
    ) -> CustomerGroupMember:
        session.add(member)
        await session.flush()
        await session.refresh(member)
        return member

    async def remove_group_member(
        self,
        session: AsyncSession,
        group_id: uuid.UUID,
        customer_id: uuid.UUID,
    ) -> bool:
        stmt = select(CustomerGroupMember).where(
            CustomerGroupMember.customer_group_id == group_id,
            CustomerGroupMember.customer_id == customer_id,
        )
        res = await session.execute(stmt)
        member = res.scalar_one_or_none()
        if not member:
            return False
        await session.delete(member)
        await session.flush()
        return True

    async def get_customer_primary_group(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
    ) -> CustomerGroup | None:
        stmt = (
            select(CustomerGroup)
            .join(Customer, Customer.primary_group_id == CustomerGroup.id)
            .where(
                Customer.id == customer_id,
                Customer.business_id == business_id,
                CustomerGroup.is_active == True,  # noqa: E712
            )
        )
        result = await session.execute(stmt)
        group = result.scalar_one_or_none()
        if group:
            return group

        # Fallback to any active membership in customer_group_members
        stmt_member = (
            select(CustomerGroup)
            .join(CustomerGroupMember, CustomerGroupMember.customer_group_id == CustomerGroup.id)
            .where(
                CustomerGroupMember.customer_id == customer_id,
                CustomerGroup.business_id == business_id,
                CustomerGroup.is_active == True,  # noqa: E712
            )
            .limit(1)
        )
        res_member = await session.execute(stmt_member)
        return res_member.scalar_one_or_none()

    # -------------------------------------------------------------------------
    # Price Lists
    # -------------------------------------------------------------------------
    async def list_price_lists(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[PriceList]:
        stmt = select(PriceList).where(PriceList.business_id == business_id)
        if is_active is not None:
            stmt = stmt.where(PriceList.is_active == is_active)
        stmt = stmt.order_by(PriceList.is_default.desc(), PriceList.name.asc())
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_price_list_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        price_list_id: uuid.UUID,
    ) -> PriceList | None:
        stmt = (
            select(PriceList)
            .where(
                PriceList.business_id == business_id,
                PriceList.id == price_list_id,
            )
            .options(selectinload(PriceList.items))
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_default_price_list(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
    ) -> PriceList | None:
        stmt = select(PriceList).where(
            PriceList.business_id == business_id,
            PriceList.is_default == True,  # noqa: E712
            PriceList.is_active == True,  # noqa: E712
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_price_list_for_group(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_group_id: uuid.UUID,
    ) -> PriceList | None:
        stmt = (
            select(PriceList)
            .where(
                PriceList.business_id == business_id,
                PriceList.customer_group_id == customer_group_id,
                PriceList.is_active == True,  # noqa: E712
            )
            .order_by(PriceList.is_default.desc(), PriceList.created_at.desc())
            .limit(1)
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def clear_default_price_list(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        exclude_id: uuid.UUID | None = None,
    ) -> None:
        stmt = select(PriceList).where(
            PriceList.business_id == business_id,
            PriceList.is_default == True,  # noqa: E712
        )
        if exclude_id:
            stmt = stmt.where(PriceList.id != exclude_id)
        result = await session.execute(stmt)
        for pl in result.scalars().all():
            pl.is_default = False

    async def create_price_list(
        self,
        session: AsyncSession,
        price_list: PriceList,
    ) -> PriceList:
        session.add(price_list)
        await session.flush()
        await session.refresh(price_list)
        return price_list

    # -------------------------------------------------------------------------
    # Price List Items
    # -------------------------------------------------------------------------
    async def list_price_list_items(
        self,
        session: AsyncSession,
        price_list_id: uuid.UUID,
    ) -> list[PriceListItem]:
        stmt = (
            select(PriceListItem)
            .where(PriceListItem.price_list_id == price_list_id)
            .order_by(PriceListItem.product_variant_id, PriceListItem.min_quantity.asc())
        )
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_price_list_item_by_id(
        self,
        session: AsyncSession,
        item_id: uuid.UUID,
    ) -> PriceListItem | None:
        stmt = select(PriceListItem).where(PriceListItem.id == item_id)
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_price_list_item_by_variant_minqty(
        self,
        session: AsyncSession,
        price_list_id: uuid.UUID,
        variant_id: uuid.UUID,
        min_qty: Decimal,
    ) -> PriceListItem | None:
        stmt = select(PriceListItem).where(
            PriceListItem.price_list_id == price_list_id,
            PriceListItem.product_variant_id == variant_id,
            PriceListItem.min_quantity == min_qty,
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_price_list_item(
        self,
        session: AsyncSession,
        item: PriceListItem,
    ) -> PriceListItem:
        session.add(item)
        await session.flush()
        await session.refresh(item)
        return item

    async def delete_price_list_item(
        self,
        session: AsyncSession,
        item: PriceListItem,
    ) -> None:
        await session.delete(item)
        await session.flush()

    # -------------------------------------------------------------------------
    # Branch Price Overrides
    # -------------------------------------------------------------------------
    async def list_branch_overrides(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> list[BranchPriceOverride]:
        stmt = select(BranchPriceOverride).where(BranchPriceOverride.business_id == business_id)
        if branch_id is not None:
            stmt = stmt.where(BranchPriceOverride.branch_id == branch_id)
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_branch_override(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        variant_id: uuid.UUID,
    ) -> BranchPriceOverride | None:
        stmt = select(BranchPriceOverride).where(
            BranchPriceOverride.business_id == business_id,
            BranchPriceOverride.branch_id == branch_id,
            BranchPriceOverride.product_variant_id == variant_id,
            BranchPriceOverride.is_active == True,  # noqa: E712
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_branch_override_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        override_id: uuid.UUID,
    ) -> BranchPriceOverride | None:
        stmt = select(BranchPriceOverride).where(
            BranchPriceOverride.business_id == business_id,
            BranchPriceOverride.id == override_id,
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def upsert_branch_override(
        self,
        session: AsyncSession,
        override: BranchPriceOverride,
    ) -> BranchPriceOverride:
        existing = await self.get_branch_override(
            session=session,
            business_id=override.business_id,
            branch_id=override.branch_id,
            variant_id=override.product_variant_id,
        )
        if existing:
            existing.selling_price = override.selling_price
            existing.is_active = override.is_active
            await session.flush()
            await session.refresh(existing)
            return existing

        session.add(override)
        await session.flush()
        await session.refresh(override)
        return override

    async def delete_branch_override(
        self,
        session: AsyncSession,
        override: BranchPriceOverride,
    ) -> None:
        await session.delete(override)
        await session.flush()

    # -------------------------------------------------------------------------
    # Product Bundles & Kits
    # -------------------------------------------------------------------------
    async def list_bundles(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[ProductBundle]:
        stmt = (
            select(ProductBundle)
            .where(ProductBundle.business_id == business_id)
            .options(selectinload(ProductBundle.items))
        )
        if is_active is not None:
            stmt = stmt.where(ProductBundle.is_active == is_active)
        stmt = stmt.order_by(ProductBundle.name.asc())
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_bundle_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        bundle_id: uuid.UUID,
    ) -> ProductBundle | None:
        stmt = (
            select(ProductBundle)
            .where(
                ProductBundle.business_id == business_id,
                ProductBundle.id == bundle_id,
            )
            .options(selectinload(ProductBundle.items))
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_bundle_by_product_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        product_id: uuid.UUID,
    ) -> ProductBundle | None:
        stmt = (
            select(ProductBundle)
            .where(
                ProductBundle.business_id == business_id,
                ProductBundle.product_id == product_id,
            )
            .options(selectinload(ProductBundle.items))
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_bundle(
        self,
        session: AsyncSession,
        bundle: ProductBundle,
    ) -> ProductBundle:
        session.add(bundle)
        await session.flush()
        await session.refresh(bundle)
        return bundle

    async def add_bundle_item(
        self,
        session: AsyncSession,
        item: ProductBundleItem,
    ) -> ProductBundleItem:
        session.add(item)
        await session.flush()
        await session.refresh(item)
        return item

    async def delete_bundle_item(
        self,
        session: AsyncSession,
        item: ProductBundleItem,
    ) -> None:
        await session.delete(item)
        await session.flush()

    # -------------------------------------------------------------------------
    # Promotions & Coupons
    # -------------------------------------------------------------------------
    async def list_promotions(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[Promotion]:
        stmt = select(Promotion).where(Promotion.business_id == business_id)
        if is_active is not None:
            stmt = stmt.where(Promotion.is_active == is_active)
        stmt = stmt.order_by(Promotion.created_at.desc())
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_promotion_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        promo_id: uuid.UUID,
    ) -> Promotion | None:
        stmt = select(Promotion).where(
            Promotion.business_id == business_id,
            Promotion.id == promo_id,
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_promotion_by_code(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        code: str,
        for_update: bool = False,
    ) -> Promotion | None:
        stmt = select(Promotion).where(
            Promotion.business_id == business_id,
            func.lower(Promotion.code) == code.strip().lower(),
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_promotion(
        self,
        session: AsyncSession,
        promo: Promotion,
    ) -> Promotion:
        session.add(promo)
        await session.flush()
        await session.refresh(promo)
        return promo

    async def record_promotion_usage(
        self,
        session: AsyncSession,
        usage: PromotionUsage,
    ) -> PromotionUsage:
        session.add(usage)
        await session.flush()
        await session.refresh(usage)
        return usage

    async def list_promotion_usages(
        self,
        session: AsyncSession,
        promo_id: uuid.UUID,
    ) -> list[PromotionUsage]:
        stmt = (
            select(PromotionUsage)
            .where(PromotionUsage.promotion_id == promo_id)
            .order_by(PromotionUsage.used_at.desc())
        )
        result = await session.execute(stmt)
        return list(result.scalars().all())

    # -------------------------------------------------------------------------
    # Variant & Product Details Helpers
    # -------------------------------------------------------------------------
    async def get_variant_with_product(
        self,
        session: AsyncSession,
        variant_id: uuid.UUID,
    ) -> tuple[ProductVariant | None, Product | None]:
        stmt = (
            select(ProductVariant, Product)
            .join(Product, Product.id == ProductVariant.product_id)
            .where(ProductVariant.id == variant_id)
        )
        res = await session.execute(stmt)
        row = res.first()
        if not row:
            return None, None
        return row[0], row[1]
