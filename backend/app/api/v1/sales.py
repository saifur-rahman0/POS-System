"""POS Sales and Checkout API endpoints."""

import uuid

from fastapi import APIRouter, Depends, Header, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.sales.schemas import CheckoutRequest, SaleOut
from app.modules.sales.service import CheckoutService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/sales", tags=["Sales & Checkout"])
checkout_service = CheckoutService()


@router.post(
    "/checkout",
    response_model=SaleOut,
    status_code=status.HTTP_201_CREATED,
    summary="Process POS checkout transaction",
)
async def checkout(
    payload: CheckoutRequest,
    response: Response,
    x_idempotency_key: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> SaleOut:
    """Executes atomic checkout, inventory deduction, and payment allocation.

    If re-submitted with the same idempotency key and payload, returns the existing sale
    with HTTP 200 and header 'X-Idempotent-Replay: true' without double deducting stock.
    """
    if x_idempotency_key and not payload.idempotency_key:
        payload.idempotency_key = x_idempotency_key

    sale_out, is_replay = await checkout_service.checkout(
        session=db,
        business_id=user.business_id,
        cashier_id=user.user_id,
        payload=payload,
    )

    if is_replay:
        response.status_code = status.HTTP_200_OK
        response.headers["X-Idempotent-Replay"] = "true"

    return sale_out


@router.get(
    "/{sale_id}",
    response_model=SaleOut,
    summary="Get sale by ID",
)
async def get_sale(
    sale_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> SaleOut:
    """Fetch completed sale and receipt details by UUID."""
    sale = await checkout_service.sales_repo.get_by_id(db, user.business_id, sale_id)
    if not sale:
        from app.shared.exceptions import AppException

        raise AppException("Sale not found", code="SALE_NOT_FOUND", status_code=404)

    # Load variant products
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload

    from app.modules.catalog.models import ProductVariant

    variant_ids = [item.product_variant_id for item in sale.items]
    var_stmt = (
        select(ProductVariant)
        .options(selectinload(ProductVariant.product))
        .where(ProductVariant.id.in_(variant_ids))
    )
    var_res = await db.execute(var_stmt)
    v_map = {v.id: v for v in var_res.scalars().all()}

    return checkout_service._map_sale_out(sale, v_map)


@router.get(
    "/receipt/{receipt_no}",
    response_model=SaleOut,
    summary="Get sale by receipt number",
)
async def get_sale_by_receipt(
    receipt_no: str,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> SaleOut:
    """Fetch completed sale and receipt details by receipt number."""
    sale = await checkout_service.sales_repo.get_by_receipt_no(db, user.business_id, receipt_no)
    if not sale:
        from app.shared.exceptions import AppException

        raise AppException("Sale not found", code="SALE_NOT_FOUND", status_code=404)

    from sqlalchemy import select
    from sqlalchemy.orm import selectinload

    from app.modules.catalog.models import ProductVariant

    variant_ids = [item.product_variant_id for item in sale.items]
    var_stmt = (
        select(ProductVariant)
        .options(selectinload(ProductVariant.product))
        .where(ProductVariant.id.in_(variant_ids))
    )
    var_res = await db.execute(var_stmt)
    v_map = {v.id: v for v in var_res.scalars().all()}

    return checkout_service._map_sale_out(sale, v_map)
