"""Service for physical stock adjustments and inventory movement ledger."""

import uuid
from datetime import datetime
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.catalog.models import ProductVariant
from app.modules.inventory.models import StockBalance, StockMovement
from app.modules.inventory.repository import InventoryRepository
from app.modules.inventory.schemas import (
    PaginatedStockMovements,
    StockAdjustmentCreate,
    StockAdjustmentOut,
    StockMovementOut,
)
from app.shared.exceptions import AppException


class InventoryService:
    """Manages stock adjustments and audit history."""

    def __init__(self) -> None:
        self.repo = InventoryRepository()

    async def get_balance(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        product_variant_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> Decimal:
        """Fetch quantity on hand for a specific product variant."""
        if not branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id, Branch.is_active.is_(True)).limit(1)
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                return Decimal("0.0000")
            branch_id = default_branch.id

        bal = await self.repo.get_balance(session, business_id, branch_id, product_variant_id)
        return bal.quantity_on_hand if bal else Decimal("0.0000")

    async def list_balances(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> list[dict]:
        """Fetch all stock balances for an active branch."""
        if not branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id, Branch.is_active.is_(True)).limit(1)
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                return []
            branch_id = default_branch.id

        stmt = select(StockBalance).where(
            StockBalance.business_id == business_id,
            StockBalance.branch_id == branch_id,
        )
        res = await session.execute(stmt)
        balances = res.scalars().all()
        return [
            {
                "product_variant_id": str(b.product_variant_id),
                "branch_id": str(b.branch_id),
                "quantity_on_hand": float(b.quantity_on_hand),
            }
            for b in balances
        ]

    async def adjust_stock(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: StockAdjustmentCreate,
    ) -> StockAdjustmentOut:
        """Applies manual stock adjustment (up or down) with audit tracking."""
        # 1. Validate variant
        v_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.id == payload.product_variant_id,
                ProductVariant.is_active.is_(True),
            )
        )
        v_res = await session.execute(v_stmt)
        variant = v_res.scalars().first()
        if not variant:
            raise AppException("Product variant not found", code="VARIANT_NOT_FOUND", status_code=404)

        # 2. Resolve branch
        branch_id = payload.branch_id
        if not branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id, Branch.is_active.is_(True)).limit(1)
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                raise AppException("No active branch found", code="BRANCH_NOT_FOUND", status_code=404)
            branch_id = default_branch.id

        # 3. Lock balance row
        balance = await self.repo.get_balance(
            session, business_id, branch_id, variant.id, for_update=True
        )
        prev_qty = balance.quantity_on_hand if balance else Decimal("0.0000")

        # 4. Compute delta
        adj_type = payload.adjustment_type.upper()
        if adj_type not in ("ADJUSTMENT_UP", "ADJUSTMENT_DOWN"):
            raise AppException(
                "adjustment_type must be either ADJUSTMENT_UP or ADJUSTMENT_DOWN",
                code="INVALID_ADJUSTMENT_TYPE",
                status_code=400,
            )

        qty = payload.quantity.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        if adj_type == "ADJUSTMENT_DOWN":
            if prev_qty < qty:
                raise AppException(
                    f"Insufficient stock on hand to deduct {qty}. Current stock: {prev_qty}",
                    code="INSUFFICIENT_STOCK",
                    status_code=409,
                    details={"available": str(prev_qty), "requested_deduction": str(qty)},
                )
            delta = -qty
        else:
            delta = qty

        new_qty = prev_qty + delta

        # 5. Update or insert balance
        if balance:
            balance.quantity_on_hand = new_qty
        else:
            balance = StockBalance(
                business_id=business_id,
                branch_id=branch_id,
                product_variant_id=variant.id,
                quantity_on_hand=new_qty,
            )
            session.add(balance)

        # 6. Record movement ledger entry
        movement_id = uuid.uuid4()
        movement = StockMovement(
            id=movement_id,
            business_id=business_id,
            branch_id=branch_id,
            product_variant_id=variant.id,
            movement_type=adj_type,
            quantity_delta=delta,
            unit_cost=variant.cost_price,
            reference_type="STOCK_ADJUSTMENT",
            reference_id=movement_id,
            created_by=user_id,
        )
        session.add(movement)

        await session.commit()
        await session.refresh(movement)

        product_name = variant.product.name if variant.product else None

        return StockAdjustmentOut(
            movement_id=movement.id,
            business_id=movement.business_id,
            branch_id=movement.branch_id,
            product_variant_id=movement.product_variant_id,
            product_name=product_name,
            variant_name=variant.name,
            adjustment_type=adj_type,
            quantity_adjusted=qty,
            previous_quantity=prev_qty,
            new_quantity=new_qty,
            reason=payload.reason,
            notes=payload.notes,
            created_at=movement.created_at,
        )

    async def list_movements(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        product_variant_id: uuid.UUID | None = None,
        movement_type: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedStockMovements:
        """Fetch stock ledger audit movements with variant and product details."""
        total = await self.repo.count_movements(
            session, business_id, branch_id, product_variant_id, movement_type, start_date, end_date
        )
        movements = await self.repo.list_movements(
            session, business_id, branch_id, product_variant_id, movement_type, start_date, end_date, page, page_size
        )

        # Batch load variants
        v_ids = list({m.product_variant_id for m in movements})
        v_map: dict[uuid.UUID, ProductVariant] = {}
        if v_ids:
            v_stmt = (
                select(ProductVariant)
                .options(selectinload(ProductVariant.product))
                .where(ProductVariant.id.in_(v_ids))
            )
            v_res = await session.execute(v_stmt)
            v_map = {v.id: v for v in v_res.scalars().all()}

        items_out: list[StockMovementOut] = []
        for m in movements:
            variant = v_map.get(m.product_variant_id)
            items_out.append(
                StockMovementOut(
                    id=m.id,
                    business_id=m.business_id,
                    branch_id=m.branch_id,
                    product_variant_id=m.product_variant_id,
                    product_name=variant.product.name if variant and variant.product else None,
                    variant_name=variant.name if variant else None,
                    sku=variant.product.sku if variant and variant.product else None,
                    movement_type=m.movement_type,
                    quantity_delta=m.quantity_delta,
                    unit_cost=m.unit_cost,
                    reference_type=m.reference_type,
                    reference_id=m.reference_id,
                    created_by=m.created_by,
                    created_at=m.created_at,
                )
            )

        total_pages = (total + page_size - 1) // page_size if total > 0 else 1

        return PaginatedStockMovements(
            items=items_out,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        )
