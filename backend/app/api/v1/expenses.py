"""API router for Expense vouchers, categories, approvals, and recurring expenses."""

import uuid
from datetime import date, datetime

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.expenses.models import Expense
from app.modules.expenses.schemas import (
    ExpenseApprovalRequest,
    ExpenseCategoryCreate,
    ExpenseCategoryOut,
    ExpenseCategoryUpdate,
    ExpenseCreate,
    ExpenseOut,
    RecurringExpenseCreate,
    RecurringExpenseOut,
    RecurringExpenseUpdate,
)
from app.modules.expenses.service import ExpensesService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/expenses", tags=["Expenses & Vouchers"])
expenses_service = ExpensesService()


def _to_expense_out(exp: Expense) -> ExpenseOut:
    return ExpenseOut(
        id=exp.id,
        business_id=exp.business_id,
        branch_id=exp.branch_id,
        voucher_no=exp.voucher_no,
        category=exp.category,
        category_id=exp.category_id,
        payment_account_id=exp.payment_account_id,
        payment_method=exp.payment_method,
        payee=exp.payee,
        receipt_reference=exp.receipt_reference,
        tax_deductible=exp.tax_deductible,
        amount=exp.amount,
        note=exp.note,
        approval_status=exp.approval_status,
        approved_by=exp.approved_by,
        approved_at=exp.approved_at,
        created_by=exp.created_by,
        created_at=exp.created_at,
        category_name=exp.expense_category.name if exp.expense_category else None,
        payment_account_name=exp.payment_account.account_name if exp.payment_account else None,
    )


# ============================================================================
# Expense Categories
# ============================================================================
@router.get(
    "/categories",
    response_model=list[ExpenseCategoryOut],
    summary="List expense categories with budget tracking",
)
async def list_categories(
    is_active: bool | None = Query(None),
    current_user: CurrentUser = Depends(require_permission("expenses:read")),
    db: AsyncSession = Depends(get_db),
) -> list[ExpenseCategoryOut]:
    return await expenses_service.list_categories(
        db, current_user.business_id, is_active=is_active
    )


@router.post(
    "/categories",
    response_model=ExpenseCategoryOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create an expense category",
)
async def create_category(
    payload: ExpenseCategoryCreate,
    current_user: CurrentUser = Depends(require_permission("expenses:write")),
    db: AsyncSession = Depends(get_db),
) -> ExpenseCategoryOut:
    category = await expenses_service.create_category(
        db, current_user.business_id, payload
    )
    await db.commit()
    return category


@router.put(
    "/categories/{category_id}",
    response_model=ExpenseCategoryOut,
    summary="Update an expense category",
)
async def update_category(
    category_id: uuid.UUID,
    payload: ExpenseCategoryUpdate,
    current_user: CurrentUser = Depends(require_permission("expenses:write")),
    db: AsyncSession = Depends(get_db),
) -> ExpenseCategoryOut:
    category = await expenses_service.update_category(
        db, current_user.business_id, category_id, payload
    )
    await db.commit()
    return category


# ============================================================================
# Recurring Expenses
# ============================================================================
@router.get(
    "/recurring",
    response_model=list[RecurringExpenseOut],
    summary="List recurring expense schedules",
)
async def list_recurring_expenses(
    branch_id: uuid.UUID | None = Query(None),
    is_active: bool | None = Query(None),
    current_user: CurrentUser = Depends(require_permission("expenses:read")),
    db: AsyncSession = Depends(get_db),
) -> list[RecurringExpenseOut]:
    recs = await expenses_service.list_recurring_expenses(
        db, current_user.business_id, branch_id=branch_id, is_active=is_active
    )
    return [
        RecurringExpenseOut(
            id=r.id,
            business_id=r.business_id,
            branch_id=r.branch_id,
            category_id=r.category_id,
            payment_account_id=r.payment_account_id,
            title=r.title,
            amount=r.amount,
            frequency=r.frequency,  # type: ignore[arg-type]
            next_due_date=r.next_due_date,
            last_generated_at=r.last_generated_at,
            auto_post=r.auto_post,
            is_active=r.is_active,
            created_at=r.created_at,
            category_name=r.category.name if r.category else None,
            payment_account_name=r.payment_account.account_name if r.payment_account else None,
        )
        for r in recs
    ]


@router.post(
    "/recurring",
    response_model=RecurringExpenseOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a recurring expense schedule",
)
async def create_recurring_expense(
    payload: RecurringExpenseCreate,
    current_user: CurrentUser = Depends(require_permission("expenses:write")),
    db: AsyncSession = Depends(get_db),
) -> RecurringExpenseOut:
    rec = await expenses_service.create_recurring_expense(
        db, current_user.business_id, payload
    )
    await db.commit()
    # Reload relation fields
    rec_full = await expenses_service.repo.get_recurring_expense(
        db, current_user.business_id, rec.id
    )
    item = rec_full or rec
    return RecurringExpenseOut(
        id=item.id,
        business_id=item.business_id,
        branch_id=item.branch_id,
        category_id=item.category_id,
        payment_account_id=item.payment_account_id,
        title=item.title,
        amount=item.amount,
        frequency=item.frequency,  # type: ignore[arg-type]
        next_due_date=item.next_due_date,
        last_generated_at=item.last_generated_at,
        auto_post=item.auto_post,
        is_active=item.is_active,
        created_at=item.created_at,
        category_name=item.category.name if item.category else None,
        payment_account_name=item.payment_account.account_name if item.payment_account else None,
    )


@router.put(
    "/recurring/{recurring_id}",
    response_model=RecurringExpenseOut,
    summary="Update a recurring expense schedule",
)
async def update_recurring_expense(
    recurring_id: uuid.UUID,
    payload: RecurringExpenseUpdate,
    current_user: CurrentUser = Depends(require_permission("expenses:write")),
    db: AsyncSession = Depends(get_db),
) -> RecurringExpenseOut:
    rec = await expenses_service.update_recurring_expense(
        db, current_user.business_id, recurring_id, payload
    )
    await db.commit()
    rec_full = await expenses_service.repo.get_recurring_expense(
        db, current_user.business_id, rec.id
    )
    item = rec_full or rec
    return RecurringExpenseOut(
        id=item.id,
        business_id=item.business_id,
        branch_id=item.branch_id,
        category_id=item.category_id,
        payment_account_id=item.payment_account_id,
        title=item.title,
        amount=item.amount,
        frequency=item.frequency,  # type: ignore[arg-type]
        next_due_date=item.next_due_date,
        last_generated_at=item.last_generated_at,
        auto_post=item.auto_post,
        is_active=item.is_active,
        created_at=item.created_at,
        category_name=item.category.name if item.category else None,
        payment_account_name=item.payment_account.account_name if item.payment_account else None,
    )


@router.post(
    "/recurring/process",
    response_model=list[ExpenseOut],
    summary="Process and generate vouchers for due recurring expenses",
)
async def process_recurring_expenses(
    as_of_date: date | None = Query(None),
    current_user: CurrentUser = Depends(require_permission("expenses:write")),
    db: AsyncSession = Depends(get_db),
) -> list[ExpenseOut]:
    created_list = await expenses_service.process_due_recurring_expenses(
        db, current_user.business_id, current_user.user_id, as_of_date=as_of_date
    )
    await db.commit()
    return [_to_expense_out(exp) for exp in created_list]


# ============================================================================
# Expense Vouchers
# ============================================================================
@router.get(
    "",
    response_model=list[ExpenseOut],
    summary="List expense vouchers with optional filters",
)
async def list_expenses(
    branch_id: uuid.UUID | None = Query(None),
    category_id: uuid.UUID | None = Query(None),
    payment_account_id: uuid.UUID | None = Query(None),
    approval_status: str | None = Query(None),
    start_date: datetime | None = Query(None),
    end_date: datetime | None = Query(None),
    search: str | None = Query(None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=100),
    current_user: CurrentUser = Depends(require_permission("expenses:read")),
    db: AsyncSession = Depends(get_db),
) -> list[ExpenseOut]:
    expenses = await expenses_service.list_expenses(
        db,
        business_id=current_user.business_id,
        branch_id=branch_id,
        category_id=category_id,
        payment_account_id=payment_account_id,
        approval_status=approval_status,
        start_date=start_date,
        end_date=end_date,
        search=search,
        page=page,
        page_size=page_size,
    )
    return [_to_expense_out(e) for e in expenses]


@router.post(
    "",
    response_model=ExpenseOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create an expense voucher (held for approval if > ৳5,000)",
)
async def create_expense(
    payload: ExpenseCreate,
    current_user: CurrentUser = Depends(require_permission("expenses:create")),
    db: AsyncSession = Depends(get_db),
) -> ExpenseOut:
    expense = await expenses_service.create_expense(
        db,
        business_id=current_user.business_id,
        branch_id=payload.branch_id,
        user_id=current_user.user_id,
        payload=payload,
    )
    await db.commit()
    # Refresh relations
    reloaded = await expenses_service.repo.get_expense(
        db, current_user.business_id, expense.id
    )
    return _to_expense_out(reloaded or expense)


@router.post(
    "/{expense_id}/approve",
    response_model=ExpenseOut,
    summary="Approve or reject a pending expense voucher",
)
async def approve_expense(
    expense_id: uuid.UUID,
    payload: ExpenseApprovalRequest,
    current_user: CurrentUser = Depends(require_permission("expenses:approve")),
    db: AsyncSession = Depends(get_db),
) -> ExpenseOut:
    expense = await expenses_service.approve_or_reject_expense(
        db,
        business_id=current_user.business_id,
        expense_id=expense_id,
        approver_id=current_user.user_id,
        action=payload.action,
        note=payload.note,
    )
    await db.commit()
    reloaded = await expenses_service.repo.get_expense(
        db, current_user.business_id, expense.id
    )
    return _to_expense_out(reloaded or expense)

