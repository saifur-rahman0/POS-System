"""Physical inventory adjustments, batches, damaged write-offs, reservations, counts, and valuation endpoints."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.inventory.schemas import (
    AvailableStockOut,
    DamagedStockCreate,
    DamagedStockOut,
    ExpiryAlertOut,
    InventoryBatchCreate,
    InventoryBatchOut,
    InventoryValuationReportOut,
    PaginatedStockMovements,
    ReorderSuggestionOut,
    StockAdjustmentCreate,
    StockAdjustmentOut,
    StockCountCreate,
    StockCountOut,
    StockCountScanRequest,
    StockReservationCreate,
    StockReservationOut,
    VariantThresholdUpdate,
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


# ==============================================================================
# 1. BATCH TRACKING & EXPIRY ALERTS
# ==============================================================================


@router.post(
    "/batches",
    response_model=InventoryBatchOut,
    status_code=status.HTTP_201_CREATED,
    summary="Inward record an inventory batch / lot",
)
async def create_batch(
    payload: InventoryBatchCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> InventoryBatchOut:
    """Create new inventory lot/batch and increment stock balance."""
    return await inventory_service.create_batch(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        payload=payload,
    )


@router.get(
    "/batches",
    response_model=list[InventoryBatchOut],
    summary="List inventory batches with expiry status",
)
async def list_batches(
    branch_id: uuid.UUID | None = Query(default=None),
    product_variant_id: uuid.UUID | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[InventoryBatchOut]:
    """Retrieve all inventory batches filtered by branch or product variant."""
    return await inventory_service.list_batches(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        product_variant_id=product_variant_id,
        is_active=is_active,
    )


@router.get(
    "/batches/alerts",
    response_model=list[ExpiryAlertOut],
    summary="Get expiring or expired batch alerts",
)
async def get_expiry_alerts(
    branch_id: uuid.UUID | None = Query(default=None),
    days_threshold: int = Query(default=60, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[ExpiryAlertOut]:
    """Fetch actionable expiry alerts (Expired, <7d, <30d, <60d)."""
    return await inventory_service.get_expiry_alerts(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        days_threshold=days_threshold,
    )


# ==============================================================================
# 2. DAMAGED STOCK & WRITE-OFFS
# ==============================================================================


@router.post(
    "/damaged",
    response_model=DamagedStockOut,
    status_code=status.HTTP_201_CREATED,
    summary="Record damaged, expired, or spoiled stock write-off",
)
async def record_damaged_stock(
    payload: DamagedStockCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> DamagedStockOut:
    """Write-off damaged stock with batch FEFO deduction and movement logging."""
    return await inventory_service.record_damaged_stock(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        payload=payload,
    )


@router.get(
    "/damaged",
    response_model=list[DamagedStockOut],
    summary="List damaged stock write-off vouchers",
)
async def list_damaged_records(
    branch_id: uuid.UUID | None = Query(default=None),
    start_date: datetime | None = Query(default=None),
    end_date: datetime | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[DamagedStockOut]:
    """Retrieve historical damaged stock write-off records."""
    return await inventory_service.list_damaged_records(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        start_date=start_date,
        end_date=end_date,
    )


# ==============================================================================
# 3. STOCK RESERVATIONS
# ==============================================================================


@router.get(
    "/available/{product_variant_id}",
    response_model=AvailableStockOut,
    summary="Get unreserved available stock for a variant",
)
async def get_available_stock(
    product_variant_id: uuid.UUID,
    branch_id: uuid.UUID = Query(...),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> AvailableStockOut:
    """Calculate available stock: on hand minus active reservations."""
    return await inventory_service.get_available_stock(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        product_variant_id=product_variant_id,
    )


@router.post(
    "/reservations",
    response_model=StockReservationOut,
    status_code=status.HTTP_201_CREATED,
    summary="Hold stock allocation for quotation, layaway, or order",
)
async def create_reservation(
    payload: StockReservationCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> StockReservationOut:
    """Reserve inventory ensuring zero overselling."""
    return await inventory_service.create_reservation(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        payload=payload,
    )


@router.post(
    "/reservations/{reservation_id}/release",
    response_model=StockReservationOut,
    summary="Release or fulfill a stock reservation",
)
async def release_reservation(
    reservation_id: uuid.UUID,
    status_action: str = Query(default="RELEASED", description="RELEASED or FULFILLED"),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> StockReservationOut:
    """Release active hold back to available stock."""
    return await inventory_service.release_reservation(
        session=db,
        business_id=user.business_id,
        reservation_id=reservation_id,
        status=status_action,
    )


@router.get(
    "/reservations",
    response_model=list[StockReservationOut],
    summary="List stock reservations",
)
async def list_reservations(
    branch_id: uuid.UUID | None = Query(default=None),
    product_variant_id: uuid.UUID | None = Query(default=None),
    status_val: str | None = Query(default=None, alias="status"),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[StockReservationOut]:
    """Retrieve stock allocations and holds."""
    return await inventory_service.list_reservations(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        product_variant_id=product_variant_id,
        status=status_val,
    )


# ==============================================================================
# 4. PHYSICAL STOCK COUNTS (AUDITS)
# ==============================================================================


@router.post(
    "/counts",
    response_model=StockCountOut,
    status_code=status.HTTP_201_CREATED,
    summary="Initiate a physical stock count session",
)
async def create_stock_count(
    payload: StockCountCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> StockCountOut:
    """Create new stock audit session (DRAFT)."""
    return await inventory_service.create_stock_count(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        payload=payload,
    )


@router.get(
    "/counts",
    response_model=list[StockCountOut],
    summary="List stock count audit sessions",
)
async def list_stock_counts(
    branch_id: uuid.UUID | None = Query(default=None),
    status_val: str | None = Query(default=None, alias="status"),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[StockCountOut]:
    """List physical count sessions."""
    return await inventory_service.list_stock_counts(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        status=status_val,
    )


@router.get(
    "/counts/{count_id}",
    response_model=StockCountOut,
    summary="Get stock count session details with variance",
)
async def get_stock_count(
    count_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> StockCountOut:
    """Retrieve full audit lines, expected vs counted quantities, and discrepancies."""
    return await inventory_service.get_stock_count(
        session=db,
        business_id=user.business_id,
        count_id=count_id,
    )


@router.post(
    "/counts/{count_id}/scan",
    response_model=StockCountOut,
    summary="Barcode scan increment during live stock count",
)
async def scan_stock_count_item(
    count_id: uuid.UUID,
    payload: StockCountScanRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> StockCountOut:
    """Fast barcode scanner tallying within an active count session."""
    return await inventory_service.scan_stock_count_item(
        session=db,
        business_id=user.business_id,
        count_id=count_id,
        payload=payload,
    )


@router.post(
    "/counts/{count_id}/complete",
    response_model=StockCountOut,
    summary="Finalize stock count and post variance adjustments",
)
async def complete_stock_count(
    count_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> StockCountOut:
    """Finalize count: automatically posts ADJUSTMENT_UP and ADJUSTMENT_DOWN movements."""
    return await inventory_service.complete_stock_count(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        count_id=count_id,
    )


# ==============================================================================
# 5. REORDER ENGINE & THRESHOLDS
# ==============================================================================


@router.get(
    "/reorder/suggestions",
    response_model=list[ReorderSuggestionOut],
    summary="Get automated replenishment suggestions",
)
async def get_reorder_suggestions(
    branch_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[ReorderSuggestionOut]:
    """Calculate purchase reorder suggestions based on min stock and active reservations."""
    return await inventory_service.get_reorder_suggestions(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
    )


@router.patch(
    "/variants/{variant_id}/thresholds",
    summary="Update variant stock thresholds and batch tracking",
)
async def update_variant_thresholds(
    variant_id: uuid.UUID,
    payload: VariantThresholdUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> dict:
    """Configure min stock level, reorder quantity, and batch tracking flag."""
    v = await inventory_service.update_variant_thresholds(
        session=db,
        business_id=user.business_id,
        variant_id=variant_id,
        payload=payload,
    )
    return {
        "variant_id": str(v.id),
        "min_stock_level": float(v.min_stock_level),
        "reorder_quantity": float(v.reorder_quantity),
        "has_batch_tracking": v.has_batch_tracking,
    }


# ==============================================================================
# 6. INVENTORY VALUATION
# ==============================================================================


@router.get(
    "/valuation",
    response_model=InventoryValuationReportOut,
    summary="Multi-tier inventory valuation report",
)
async def get_inventory_valuation(
    branch_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> InventoryValuationReportOut:
    """Calculate inventory valuation across FIFO (batches), WAC, and Retail."""
    return await inventory_service.get_inventory_valuation(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
    )

