"""Physical inventory adjustments and stock movement audit endpoints."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.inventory.schemas import (
    PaginatedStockMovements,
    StockAdjustmentCreate,
    StockAdjustmentOut,
)
from app.modules.inventory.service import InventoryService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/inventory", tags=["Inventory & Adjustments"])
inventory_service = InventoryService()


@router.get(
    "/balances",
    summary="Get all variant stock balances in a branch",
)
async def list_stock_balances(
    branch_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[dict]:
    """Fetch current stock balances on hand across all tracked variants."""
    return await inventory_service.list_balances(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
    )


@router.get(
    "/balances/{product_variant_id}",
    summary="Get stock balance for a product variant",
)
async def get_stock_balance(
    product_variant_id: uuid.UUID,
    branch_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> dict:
    """Fetch real-time physical stock quantity for a single variant."""
    qty = await inventory_service.get_balance(
        session=db,
        business_id=user.business_id,
        product_variant_id=product_variant_id,
        branch_id=branch_id,
    )
    return {
        "product_variant_id": str(product_variant_id),
        "branch_id": str(branch_id) if branch_id else None,
        "quantity_on_hand": float(qty),
    }


@router.post(
    "/adjustments",
    response_model=StockAdjustmentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Record manual stock adjustment (up or down)",
)
async def adjust_stock(
    payload: StockAdjustmentCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> StockAdjustmentOut:
    """Adjusts physical stock quantity on hand and records immutable stock movement."""
    return await inventory_service.adjust_stock(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        payload=payload,
    )


@router.get(
    "/movements",
    response_model=PaginatedStockMovements,
    summary="List stock movement audit trail",
)
async def list_stock_movements(
    branch_id: uuid.UUID | None = Query(default=None),
    product_variant_id: uuid.UUID | None = Query(default=None),
    movement_type: str | None = Query(default=None),
    start_date: datetime | None = Query(default=None),
    end_date: datetime | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> PaginatedStockMovements:
    """Fetch paginated stock movement ledger entries."""
    return await inventory_service.list_movements(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        product_variant_id=product_variant_id,
        movement_type=movement_type,
        start_date=start_date,
        end_date=end_date,
        page=page,
        page_size=page_size,
    )
