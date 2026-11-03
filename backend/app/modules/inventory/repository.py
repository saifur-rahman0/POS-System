"""Repository for inventory balances and stock movement ledger."""

import uuid
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.inventory.models import StockBalance, StockMovement


class InventoryRepository:
    """Database interactions for physical inventory stock balances and ledger."""

    async def get_balance(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        product_variant_id: uuid.UUID,
        for_update: bool = False,
    ) -> StockBalance | None:
        """Fetch stock balance for a single variant in a branch, optionally acquiring a row lock."""
        stmt = select(StockBalance).where(
            StockBalance.business_id == business_id,
            StockBalance.branch_id == branch_id,
            StockBalance.product_variant_id == product_variant_id,
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_balances_for_update(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        variant_ids: list[uuid.UUID],
    ) -> dict[uuid.UUID, StockBalance]:
        """Fetch multiple variant stock balances ordered lexicographically with pessimistic row locks."""
        if not variant_ids:
            return {}

        # Sort variant IDs to prevent database deadlocks across concurrent checkouts
        sorted_ids = sorted(variant_ids)

        stmt = (
            select(StockBalance)
            .where(
                StockBalance.business_id == business_id,
                StockBalance.branch_id == branch_id,
                StockBalance.product_variant_id.in_(sorted_ids),
            )
            .with_for_update()
        )
        result = await session.execute(stmt)
        balances = result.scalars().all()
        return {b.product_variant_id: b for b in balances}

    async def set_balance(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        product_variant_id: uuid.UUID,
        quantity: Decimal,
    ) -> StockBalance:
        """Create or update stock balance quantity on hand."""
        balance = await self.get_balance(
            session, business_id, branch_id, product_variant_id, for_update=True
        )
        if balance:
            balance.quantity_on_hand = quantity
        else:
            balance = StockBalance(
                business_id=business_id,
                branch_id=branch_id,
                product_variant_id=product_variant_id,
                quantity_on_hand=quantity,
            )
            session.add(balance)
        return balance

    async def record_movement(
        self,
        session: AsyncSession,
        movement: StockMovement,
    ) -> StockMovement:
        """Append an immutable audit entry to stock movements ledger."""
        session.add(movement)
        return movement

