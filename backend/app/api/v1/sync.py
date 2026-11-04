"""Offline POS terminal delta sync protocol endpoints."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.modules.business.models import Branch
from app.modules.business.schemas import BranchOut
from app.modules.catalog.models import Category, Product
from app.modules.catalog.schemas import CategoryOut, ProductOut
from app.modules.catalog.service import CatalogService
from app.modules.customers.schemas import CustomerOut
from app.modules.inventory.models import StockBalance
from app.modules.sales.models import Customer
from app.modules.sales.schemas import CheckoutRequest
from app.modules.sales.service import CheckoutService
from app.shared.auth import CurrentUser, require_permission
from app.shared.exceptions import AppException

router = APIRouter(prefix="/sync", tags=["Offline Terminal Sync & Deltas"])
catalog_service = CatalogService()
checkout_service = CheckoutService()


class BranchStockDelta(BaseModel):
    """Incremental stock balance snapshot."""

    product_variant_id: uuid.UUID
    branch_id: uuid.UUID
    quantity_on_hand: Decimal
    updated_at: datetime


class SyncPullResponse(BaseModel):
    """Payload containing all modified entities since last client sync."""

    server_time: datetime
    branches: list[BranchOut] = []
    categories: list[CategoryOut] = []
    products: list[ProductOut] = []
    customers: list[CustomerOut] = []
    stock_balances: list[BranchStockDelta] = []


class PushItemResult(BaseModel):
    """Status of an offline sale upload."""

    idempotency_key: str
    receipt_no: str | None = None
    status: str  # SUCCESS, REPLAY, FAILED
    error_message: str | None = None


class SyncPushRequest(BaseModel):
    """Batch payload of transactions recorded while offline."""

    sales: list[CheckoutRequest] = Field(..., description="Batch of offline sales")


class SyncPushResponse(BaseModel):
    """Summary of batch offline transaction reconciliation."""

    server_time: datetime
    results: list[PushItemResult] = []
    total_successful: int = 0
    total_failed: int = 0


@router.get(
    "/pull",
    response_model=SyncPullResponse,
    summary="Pull incremental deltas for offline client synchronization",
)
async def pull_sync_deltas(
    since: datetime | None = Query(
        default=None, description="ISO timestamp of last successful sync"
    ),
    branch_id: uuid.UUID | None = Query(default=None, description="Current terminal branch"),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> SyncPullResponse:
    """Delivers delta catalog, customer, and stock data to local POS registers."""
    now_utc = datetime.now(UTC)

    # Branches
    b_stmt = select(Branch).where(
        Branch.business_id == user.business_id, Branch.is_active.is_(True)
    )
    branches = [BranchOut.model_validate(b) for b in (await db.execute(b_stmt)).scalars().all()]

    # Categories
    cat_stmt = select(Category).where(Category.business_id == user.business_id)
    categories = [
        CategoryOut.model_validate(c) for c in (await db.execute(cat_stmt)).scalars().all()
    ]

    # Products with variants
    prod_stmt = (
        select(Product)
        .options(
            selectinload(Product.variants),
            selectinload(Product.category),
            selectinload(Product.brand),
        )
        .where(Product.business_id == user.business_id)
    )
    if since:
        prod_stmt = prod_stmt.where(Product.updated_at >= since)
    prods_raw = (await db.execute(prod_stmt)).scalars().all()
    products = [catalog_service._map_product_out(p) for p in prods_raw]

    # Customers
    cust_stmt = select(Customer).where(Customer.business_id == user.business_id)
    if since:
        cust_stmt = cust_stmt.where(Customer.created_at >= since)
    customers = [
        CustomerOut.model_validate(c) for c in (await db.execute(cust_stmt)).scalars().all()
    ]

    # Stock Balances
    stock_deltas: list[BranchStockDelta] = []
    if branch_id:
        sb_stmt = select(StockBalance).where(
            StockBalance.business_id == user.business_id,
            StockBalance.branch_id == branch_id,
        )
        if since:
            sb_stmt = sb_stmt.where(StockBalance.updated_at >= since)
        sb_raw = (await db.execute(sb_stmt)).scalars().all()
        stock_deltas = [
            BranchStockDelta(
                product_variant_id=sb.product_variant_id,
                branch_id=sb.branch_id,
                quantity_on_hand=sb.quantity_on_hand,
                updated_at=sb.updated_at,
            )
            for sb in sb_raw
        ]

    return SyncPullResponse(
        server_time=now_utc,
        branches=branches,
        categories=categories,
        products=products,
        customers=customers,
        stock_balances=stock_deltas,
    )


@router.post(
    "/push",
    response_model=SyncPushResponse,
    status_code=status.HTTP_200_OK,
    summary="Batch upload offline sales transactions",
)
async def push_offline_transactions(
    payload: SyncPushRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> SyncPushResponse:
    """Atomic batch reconciliation of offline POS transactions with deduplication."""
    results: list[PushItemResult] = []
    success_count = 0
    fail_count = 0

    for sale_req in payload.sales:
        key = sale_req.idempotency_key or "NO_KEY"
        try:
            sale_out, is_replay = await checkout_service.checkout(
                session=db,
                business_id=user.business_id,
                cashier_id=user.user_id,
                payload=sale_req,
            )
            status_str = "REPLAY" if is_replay else "SUCCESS"
            results.append(
                PushItemResult(
                    idempotency_key=key,
                    receipt_no=sale_out.receipt_no,
                    status=status_str,
                )
            )
            success_count += 1
        except AppException as ae:
            results.append(
                PushItemResult(
                    idempotency_key=key,
                    status="FAILED",
                    error_message=f"[{ae.code}] {ae.message}",
                )
            )
            fail_count += 1
        except Exception as e:
            results.append(
                PushItemResult(
                    idempotency_key=key,
                    status="FAILED",
                    error_message=str(e),
                )
            )
            fail_count += 1

    return SyncPushResponse(
        server_time=datetime.now(UTC),
        results=results,
        total_successful=success_count,
        total_failed=fail_count,
    )
