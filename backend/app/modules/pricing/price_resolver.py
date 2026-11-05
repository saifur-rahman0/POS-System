"""Stateless dynamic price resolution engine for Retail POS."""

import uuid
from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.catalog.models import ProductVariant
from app.modules.pricing.models import (
    BranchPriceOverride,
    PriceList,
    PriceListItem,
)
from app.modules.pricing.repository import PricingRepository


@dataclass
class PriceContext:
    """Evaluation context for determining variant selling price."""

    business_id: uuid.UUID
    branch_id: uuid.UUID
    customer_id: uuid.UUID | None
    quantity: Decimal
    sale_date: date


@dataclass
class ResolvedPrice:
    """Resolved price item and its source hierarchy."""

    unit_price: Decimal
    source: str  # "BRANCH_OVERRIDE" | "PRICE_LIST" | "BASE_PRICE"
    price_list_id: uuid.UUID | None = None
    price_list_name: str | None = None


class PriceResolver:
    """Layered price determination engine adhering to Priority Chain:

    1. Branch Override
    2. Customer Group Price List / Default Price List (Quantity Break & Schedules)
    3. Variant Base Price
    """

    def __init__(self, repo: PricingRepository | None = None) -> None:
        self.repo = repo or PricingRepository()

    async def resolve(
        self,
        session: AsyncSession,
        variant_id: uuid.UUID,
        context: PriceContext,
    ) -> ResolvedPrice:
        """Resolve the effective unit price for a given variant in context."""
        # ---------------------------------------------------------------------
        # Priority 1: Branch Price Override
        # ---------------------------------------------------------------------
        override_stmt = select(BranchPriceOverride).where(
            BranchPriceOverride.business_id == context.business_id,
            BranchPriceOverride.branch_id == context.branch_id,
            BranchPriceOverride.product_variant_id == variant_id,
            BranchPriceOverride.is_active == True,  # noqa: E712
        )
        override_res = await session.execute(override_stmt)
        override = override_res.scalar_one_or_none()
        if override:
            return ResolvedPrice(
                unit_price=override.selling_price,
                source="BRANCH_OVERRIDE",
            )

        # ---------------------------------------------------------------------
        # Priority 2: Price List Item (Customer Group or Default)
        # ---------------------------------------------------------------------
        target_price_list: PriceList | None = None

        if context.customer_id:
            cust_group = await self.repo.get_customer_primary_group(
                session=session,
                business_id=context.business_id,
                customer_id=context.customer_id,
            )
            if cust_group:
                target_price_list = await self.repo.get_price_list_for_group(
                    session=session,
                    business_id=context.business_id,
                    customer_group_id=cust_group.id,
                )

        if not target_price_list:
            target_price_list = await self.repo.get_default_price_list(
                session=session,
                business_id=context.business_id,
            )

        if target_price_list:
            item_stmt = (
                select(PriceListItem)
                .where(
                    PriceListItem.price_list_id == target_price_list.id,
                    PriceListItem.product_variant_id == variant_id,
                    PriceListItem.is_active == True,  # noqa: E712
                    PriceListItem.min_quantity <= context.quantity,
                )
                .order_by(PriceListItem.min_quantity.desc())
            )
            items_res = await session.execute(item_stmt)
            candidate_items = items_res.scalars().all()

            for item in candidate_items:
                # Check schedule dates
                if item.start_date and item.start_date > context.sale_date:
                    continue
                if item.end_date and item.end_date < context.sale_date:
                    continue

                return ResolvedPrice(
                    unit_price=item.price,
                    source="PRICE_LIST",
                    price_list_id=target_price_list.id,
                    price_list_name=target_price_list.name,
                )

        # ---------------------------------------------------------------------
        # Priority 3: Base Variant Price Fallback
        # ---------------------------------------------------------------------
        variant_stmt = select(ProductVariant).where(
            ProductVariant.id == variant_id,
            ProductVariant.business_id == context.business_id,
        )
        variant_res = await session.execute(variant_stmt)
        variant = variant_res.scalar_one_or_none()

        if variant:
            return ResolvedPrice(
                unit_price=variant.selling_price,
                source="BASE_PRICE",
            )

        return ResolvedPrice(
            unit_price=Decimal("0.0000"),
            source="BASE_PRICE",
        )

