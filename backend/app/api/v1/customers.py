"""Customer CRM and Due Collection API endpoints."""

import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.customers.schemas import (
    CustomerCreate,
    CustomerDuePaymentOut,
    CustomerDuePaymentRequest,
    CustomerLedgerEntry,
    CustomerOut,
    CustomerUpdate,
    PaginatedCustomers,
)
from app.modules.customers.service import CustomersService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/customers", tags=["Customers & Due Ledger"])
customers_service = CustomersService()


@router.get(
    "",
    response_model=PaginatedCustomers,
    summary="List customers with filters and financial summaries",
)
async def list_customers(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    search: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> PaginatedCustomers:
    """Fetch paginated customers with due balances and total spent metrics."""
    return await customers_service.list_customers(
        session=db,
        business_id=user.business_id,
        search=search,
        is_active=is_active,
        page=page,
        page_size=page_size,
    )


@router.post(
    "",
    response_model=CustomerOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new customer profile",
)
async def create_customer(
    payload: CustomerCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> CustomerOut:
    """Register a new customer with optional credit limit."""
    return await customers_service.create_customer(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


@router.get(
    "/{customer_id}",
    response_model=CustomerOut,
    summary="Get customer profile and real-time dues",
)
async def get_customer(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> CustomerOut:
    """Retrieve customer details and active due balances."""
    return await customers_service.get_customer(
        session=db,
        business_id=user.business_id,
        customer_id=customer_id,
    )


@router.put(
    "/{customer_id}",
    response_model=CustomerOut,
    summary="Update customer profile or credit limit",
)
async def update_customer(
    customer_id: uuid.UUID,
    payload: CustomerUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:write")),
) -> CustomerOut:
    """Update customer contact info, address, or credit limit."""
    return await customers_service.update_customer(
        session=db,
        business_id=user.business_id,
        customer_id=customer_id,
        payload=payload,
    )


@router.post(
    "/{customer_id}/payments",
    response_model=CustomerDuePaymentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Collect due debt repayment from customer",
)
async def collect_due_payment(
    customer_id: uuid.UUID,
    payload: CustomerDuePaymentRequest,
    branch_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> CustomerDuePaymentOut:
    """Collects debt repayment and updates unpaid sale receipts atomically."""
    # Find cashier branch if not explicitly provided
    from sqlalchemy import select

    from app.modules.business.models import Branch

    active_branch_id = branch_id
    if not active_branch_id:
        b_res = await db.execute(
            select(Branch.id).where(Branch.business_id == user.business_id).limit(1)
        )
        active_branch_id = b_res.scalars().first()
        if not active_branch_id:
            from app.shared.exceptions import AppException

            raise AppException(
                "No active store branch found", code="BRANCH_NOT_FOUND", status_code=404
            )

    return await customers_service.collect_due_payment(
        session=db,
        business_id=user.business_id,
        branch_id=active_branch_id,
        cashier_id=user.user_id,
        customer_id=customer_id,
        payload=payload,
    )


@router.get(
    "/{customer_id}/ledger",
    response_model=list[CustomerLedgerEntry],
    summary="Get customer store credit and due ledger statement",
)
async def get_customer_ledger(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:read")),
) -> list[CustomerLedgerEntry]:
    """Retrieve chronological debit/credit transaction statement for a customer."""
    return await customers_service.get_customer_ledger(
        session=db,
        business_id=user.business_id,
        customer_id=customer_id,
    )
