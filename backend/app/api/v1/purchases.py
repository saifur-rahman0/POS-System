"""Purchase orders, goods receiving, and supplier payments API endpoints."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.purchasing.schemas import (
    PaginatedPurchases,
    PurchaseCreate,
    PurchaseOut,
    PurchasePaymentCreate,
    PurchasePaymentOut,
)
from app.modules.purchasing.service import PurchasingService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/purchasing", tags=["Suppliers & Purchasing"])
purchasing_service = PurchasingService()


@router.get(
    "/orders",
    response_model=PaginatedPurchases,
    summary="List purchase orders with filters",
)
async def list_purchases(
    branch_id: uuid.UUID | None = Query(default=None),
    supplier_id: uuid.UUID | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    start_date: datetime | None = Query(default=None),
    end_date: datetime | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> PaginatedPurchases:
    """Fetch paginated purchase orders."""
    return await purchasing_service.list_purchases(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        supplier_id=supplier_id,
        status=status_filter,
        start_date=start_date,
        end_date=end_date,
        page=page,
        page_size=page_size,
    )


@router.post(
    "/orders",
    response_model=PurchaseOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new purchase order",
)
async def create_purchase(
    payload: PurchaseCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> PurchaseOut:
    """Creates a purchase order in ORDERED state."""
    return await purchasing_service.create_purchase(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        payload=payload,
    )


@router.get(
    "/orders/{purchase_id}",
    response_model=PurchaseOut,
    summary="Get purchase order details",
)
async def get_purchase(
    purchase_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> PurchaseOut:
    """Retrieve full purchase order with items and payments."""
    return await purchasing_service.get_purchase(
        session=db,
        business_id=user.business_id,
        purchase_id=purchase_id,
    )


@router.post(
    "/orders/{purchase_id}/receive",
    response_model=PurchaseOut,
    summary="Receive purchase order and increment stock balances",
)
async def receive_purchase(
    purchase_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> PurchaseOut:
    """Executes atomic receiving: increases stock balance, updates cost prices, logs stock movements."""
    return await purchasing_service.receive_purchase(
        session=db,
        business_id=user.business_id,
        purchase_id=purchase_id,
        user_id=user.user_id,
    )


@router.post(
    "/orders/{purchase_id}/payments",
    response_model=PurchasePaymentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Record disbursement payment towards purchase order",
)
async def add_purchase_payment(
    purchase_id: uuid.UUID,
    payload: PurchasePaymentCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> PurchasePaymentOut:
    """Records payment to supplier, deducts from cash drawer if CASH."""
    return await purchasing_service.add_purchase_payment(
        session=db,
        business_id=user.business_id,
        purchase_id=purchase_id,
        user_id=user.user_id,
        payload=payload,
    )
