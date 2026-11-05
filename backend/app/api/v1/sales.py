"""POS Sales, Returns, and Checkout API endpoints."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Header, Query, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.modules.catalog.models import ProductVariant
from app.modules.returns.schemas import (
    ReturnCreateRequest,
    ReturnItemOut,
    ReturnOut,
    SaleReturnableItem,
)
from app.modules.returns.service import ReturnsService
from app.modules.sales.schemas import (
    CheckoutRequest,
    ExchangeOut,
    ExchangeRequest,
    HeldCartCreate,
    HeldCartOut,
    ManagerOverrideOut,
    ManagerOverrideRequest,
    PaginatedSales,
    QuotationConvertRequest,
    QuotationCreate,
    QuotationOut,
    SaleOut,
    VoidSaleRequest,
)
from app.modules.sales.service import CheckoutService
from app.shared.auth import CurrentUser, require_permission
from app.shared.exceptions import AppException

router = APIRouter(prefix="/sales", tags=["Sales & Checkout"])
checkout_service = CheckoutService()
returns_service = ReturnsService()


@router.get(
    "",
    response_model=PaginatedSales,
    summary="List sales with filters and pagination",
)
async def list_sales(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    start_date: datetime | None = Query(default=None),
    end_date: datetime | None = Query(default=None),
    cashier_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    search: str | None = Query(default=None),
    branch_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> PaginatedSales:
    """Fetch paginated sales for the business."""
    return await checkout_service.list_sales(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        start_date=start_date,
        end_date=end_date,
        cashier_id=cashier_id,
        status=status,
        search=search,
        page=page,
        page_size=page_size,
    )


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


# -----------------------------------------------------------------------------
# HELD CARTS (PARKED BASKETS)
# -----------------------------------------------------------------------------
@router.post(
    "/held-carts",
    response_model=HeldCartOut,
    status_code=status.HTTP_201_CREATED,
    summary="Park / hold an active shopping cart",
)
async def create_held_cart(
    payload: HeldCartCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> HeldCartOut:
    """Stores a temporary cart for later resumption."""
    branch_id = payload.branch_id
    if not branch_id:
        from app.modules.business.models import Branch

        b_res = await db.execute(
            select(Branch.id)
            .where(Branch.business_id == user.business_id, Branch.is_active.is_(True))
            .limit(1)
        )
        branch_id = b_res.scalars().first()
        if not branch_id:
            raise AppException("Active branch not found", code="BRANCH_NOT_FOUND", status_code=404)

    return await checkout_service.create_held_cart(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        cashier_id=user.user_id,
        payload=payload,
    )


@router.get(
    "/held-carts",
    response_model=list[HeldCartOut],
    summary="List active held carts",
)
async def list_held_carts(
    branch_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> list[HeldCartOut]:
    """Retrieve all held carts for the current business."""
    return await checkout_service.list_held_carts(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
    )


@router.get(
    "/held-carts/{held_cart_id}",
    response_model=HeldCartOut,
    summary="Get held cart by ID",
)
async def get_held_cart(
    held_cart_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> HeldCartOut:
    """Retrieve a single held cart for resumption."""
    return await checkout_service.get_held_cart(
        session=db,
        business_id=user.business_id,
        held_cart_id=held_cart_id,
    )


@router.delete(
    "/held-carts/{held_cart_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete / discard a held cart",
)
async def delete_held_cart(
    held_cart_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> None:
    """Purge a held cart without checkout."""
    await checkout_service.delete_held_cart(
        session=db,
        business_id=user.business_id,
        held_cart_id=held_cart_id,
    )


# -----------------------------------------------------------------------------
# QUOTATIONS / PRO-FORMA INVOICES
# -----------------------------------------------------------------------------
@router.post(
    "/quotations",
    response_model=QuotationOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a pro-forma price quotation",
)
async def create_quotation(
    payload: QuotationCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> QuotationOut:
    """Generates a quotation without deducting stock."""
    branch_id = payload.branch_id
    if not branch_id:
        from app.modules.business.models import Branch

        b_res = await db.execute(
            select(Branch.id)
            .where(Branch.business_id == user.business_id, Branch.is_active.is_(True))
            .limit(1)
        )
        branch_id = b_res.scalars().first()
        if not branch_id:
            raise AppException("Active branch not found", code="BRANCH_NOT_FOUND", status_code=404)

    return await checkout_service.create_quotation(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        user_id=user.user_id,
        payload=payload,
    )


@router.get(
    "/quotations",
    response_model=list[QuotationOut],
    summary="List price quotations",
)
async def list_quotations(
    branch_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    search: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> list[QuotationOut]:
    """List quotations matching search and status criteria."""
    return await checkout_service.list_quotations(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        status=status,
        search=search,
        page=page,
        page_size=page_size,
    )


@router.get(
    "/quotations/{quotation_id}",
    response_model=QuotationOut,
    summary="Get quotation details",
)
async def get_quotation(
    quotation_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> QuotationOut:
    """Retrieve quotation and line items."""
    return await checkout_service.get_quotation(
        session=db,
        business_id=user.business_id,
        quotation_id=quotation_id,
    )


@router.post(
    "/quotations/{quotation_id}/convert",
    response_model=SaleOut,
    summary="Convert quotation into a completed sale",
)
async def convert_quotation(
    quotation_id: uuid.UUID,
    payload: QuotationConvertRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> SaleOut:
    """Executes atomic checkout conversion from an approved quotation."""
    return await checkout_service.convert_quotation_to_sale(
        session=db,
        business_id=user.business_id,
        cashier_id=user.user_id,
        quotation_id=quotation_id,
        payload=payload,
    )


# -----------------------------------------------------------------------------
# PRODUCT EXCHANGES & MANAGER OVERRIDES
# -----------------------------------------------------------------------------
@router.post(
    "/exchange",
    response_model=ExchangeOut,
    status_code=status.HTTP_201_CREATED,
    summary="Atomic product exchange (return + new sale)",
)
async def exchange_products(
    payload: ExchangeRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> ExchangeOut:
    """Processes product return and replacement checkout in a single atomic transaction."""
    branch_id = payload.branch_id
    if not branch_id:
        from app.modules.business.models import Branch

        b_res = await db.execute(
            select(Branch.id)
            .where(Branch.business_id == user.business_id, Branch.is_active.is_(True))
            .limit(1)
        )
        branch_id = b_res.scalars().first()
        if not branch_id:
            raise AppException("Active branch not found", code="BRANCH_NOT_FOUND", status_code=404)

    return await checkout_service.exchange(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        cashier_id=user.user_id,
        payload=payload,
    )


@router.post(
    "/manager-override",
    response_model=ManagerOverrideOut,
    summary="Supervisor authorization for price override, high discount, or void",
)
async def verify_manager_override(
    payload: ManagerOverrideRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> ManagerOverrideOut:
    """Validates manager PIN and credentials for privileged operations."""
    return await checkout_service.verify_manager_override(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


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
        raise AppException("Sale not found", code="SALE_NOT_FOUND", status_code=404)

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
        raise AppException("Sale not found", code="SALE_NOT_FOUND", status_code=404)

    variant_ids = [item.product_variant_id for item in sale.items]
    var_stmt = (
        select(ProductVariant)
        .options(selectinload(ProductVariant.product))
        .where(ProductVariant.id.in_(variant_ids))
    )
    var_res = await db.execute(var_stmt)
    v_map = {v.id: v for v in var_res.scalars().all()}

    return checkout_service._map_sale_out(sale, v_map)


@router.post(
    "/{sale_id}/returns",
    response_model=ReturnOut,
    status_code=status.HTTP_201_CREATED,
    summary="Process customer return / refund for a sale",
)
async def create_sale_return(
    sale_id: uuid.UUID,
    payload: ReturnCreateRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> ReturnOut:
    """Process partial or full customer return with stock restoration."""
    return await returns_service.create_return(
        session=db,
        business_id=user.business_id,
        cashier_id=user.user_id,
        sale_id=sale_id,
        payload=payload,
    )


@router.get(
    "/{sale_id}/returns",
    response_model=list[ReturnOut],
    summary="Get return records for a sale",
)
async def get_sale_returns(
    sale_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> list[ReturnOut]:
    """Retrieve return history for a specific sale."""
    returns = await returns_service.returns_repo.list_by_sale_id(db, user.business_id, sale_id)
    all_variant_ids = [item.product_variant_id for ret in returns for item in ret.items]
    variant_map = {}
    if all_variant_ids:
        v_res = await db.execute(
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_(all_variant_ids))
        )
        variant_map = {v.id: v for v in v_res.scalars().all()}

    output = []
    for ret in returns:
        items_out = []
        for ri in ret.items:
            variant = variant_map.get(ri.product_variant_id)
            items_out.append(
                ReturnItemOut(
                    id=ri.id,
                    return_id=ri.return_id,
                    original_sale_item_id=ri.original_sale_item_id,
                    product_variant_id=ri.product_variant_id,
                    product_name=variant.product.name
                    if variant and variant.product
                    else "Unknown Product",
                    sku=variant.product.sku if variant and variant.product else "UNKNOWN",
                    quantity=ri.quantity,
                    refund_amount=ri.refund_amount,
                    restock_status=ri.restock_status,
                )
            )
        output.append(
            ReturnOut(
                id=ret.id,
                business_id=ret.business_id,
                branch_id=ret.branch_id,
                original_sale_id=ret.original_sale_id,
                return_no=ret.return_no,
                status=ret.status,
                refund_total=ret.refund_total,
                reason=ret.reason,
                created_by=ret.created_by,
                created_at=ret.created_at,
                items=items_out,
            )
        )
    return output


@router.get(
    "/{sale_id}/returnable-items",
    response_model=list[SaleReturnableItem],
    summary="Get remaining returnable quantities for a sale",
)
async def get_sale_returnable_items(
    sale_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> list[SaleReturnableItem]:
    """Inspect remaining returnable quantities for each item on a sale."""
    return await returns_service.get_returnable_items(db, user.business_id, sale_id)


@router.post(
    "/{sale_id}/void",
    response_model=SaleOut,
    summary="Void a sale and reverse inventory",
)
async def void_sale(
    sale_id: uuid.UUID,
    payload: VoidSaleRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:write")),
) -> SaleOut:
    """Void an existing completed sale, reversing stock and marking tenders voided."""
    return await returns_service.void_sale(
        session=db,
        business_id=user.business_id,
        cashier_id=user.user_id,
        sale_id=sale_id,
        payload=payload,
    )
