"""Inter-branch stock transfer and cross-branch visibility API router."""

import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.inventory.transfer_schemas import (
    CrossBranchStockOut,
    StockTransferOut,
    TransferCreate,
)
from app.modules.inventory.transfer_service import StockTransferService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/transfers", tags=["Multi-Store & Stock Transfers"])
transfer_service = StockTransferService()


@router.get(
    "",
    response_model=list[StockTransferOut],
    summary="List inter-branch stock transfers",
)
async def list_transfers(
    source_branch_id: uuid.UUID | None = Query(default=None),
    destination_branch_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("inventory:read")),
) -> list[StockTransferOut]:
    """List transfers across branches with status filter."""
    return await transfer_service.list_transfers(
        session=db,
        business_id=user.business_id,
        source_branch_id=source_branch_id,
        destination_branch_id=destination_branch_id,
        status=status,
    )


@router.post(
    "",
    response_model=StockTransferOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new draft stock transfer order",
)
async def create_transfer(
    payload: TransferCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("inventory:write")),
) -> StockTransferOut:
    """Create draft stock transfer between two distinct branches."""
    return await transfer_service.create_transfer(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        payload=payload,
    )


@router.get(
    "/cross-branch-stock/{product_variant_id}",
    response_model=list[CrossBranchStockOut],
    summary="Check stock levels across all branches for a variant",
)
async def get_cross_branch_stock(
    product_variant_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[CrossBranchStockOut]:
    """Allows cashiers and managers to inspect availability at other store locations."""
    return await transfer_service.get_cross_branch_stock(
        session=db,
        business_id=user.business_id,
        product_variant_id=product_variant_id,
    )


@router.get(
    "/{transfer_id}",
    response_model=StockTransferOut,
    summary="Get stock transfer shipment detail",
)
async def get_transfer(
    transfer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("inventory:read")),
) -> StockTransferOut:
    """Fetch transfer line items and audit timeline."""
    return await transfer_service.get_transfer(
        session=db,
        business_id=user.business_id,
        transfer_id=transfer_id,
    )


@router.post(
    "/{transfer_id}/send",
    response_model=StockTransferOut,
    summary="Dispatch / send transfer shipment",
)
async def send_transfer(
    transfer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("inventory:write")),
) -> StockTransferOut:
    """Locks source inventory, checks availability, decrements stock, and moves status to IN_TRANSIT."""
    return await transfer_service.send_transfer(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        transfer_id=transfer_id,
    )


@router.post(
    "/{transfer_id}/receive",
    response_model=StockTransferOut,
    summary="Receive stock transfer at destination branch",
)
async def receive_transfer(
    transfer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("inventory:write")),
) -> StockTransferOut:
    """Increments stock on destination branch and sets status to RECEIVED."""
    return await transfer_service.receive_transfer(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        transfer_id=transfer_id,
    )


@router.post(
    "/{transfer_id}/cancel",
    response_model=StockTransferOut,
    summary="Cancel stock transfer shipment",
)
async def cancel_transfer(
    transfer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("inventory:write")),
) -> StockTransferOut:
    """Cancels draft transfer or restores source inventory if already IN_TRANSIT."""
    return await transfer_service.cancel_transfer(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        transfer_id=transfer_id,
    )
