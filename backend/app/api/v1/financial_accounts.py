"""API router for Financial Accounts, Inter-Account Transfers, and Cash Flow / AP Aging Reports."""

import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.expenses.models import AccountTransfer
from app.modules.expenses.schemas import (
    AccountTransferCreate,
    AccountTransferOut,
    APAgeingReportOut,
    CashFlowReportOut,
    FinancialAccountCreate,
    FinancialAccountOut,
    FinancialAccountUpdate,
)
from app.modules.expenses.service import ExpensesService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/financial-accounts", tags=["Financial Accounts & Cash Flow"])
expenses_service = ExpensesService()


def _to_transfer_out(t: AccountTransfer) -> AccountTransferOut:
    return AccountTransferOut(
        id=t.id,
        business_id=t.business_id,
        from_account_id=t.from_account_id,
        to_account_id=t.to_account_id,
        amount=t.amount,
        reference_no=t.reference_no,
        note=t.note,
        transfer_date=t.transfer_date,
        created_by=t.created_by,
        created_at=t.created_at,
        from_account_name=t.from_account.account_name if t.from_account else None,
        to_account_name=t.to_account.account_name if t.to_account else None,
    )


# ============================================================================
# Liquid Accounts
# ============================================================================
@router.get(
    "",
    response_model=list[FinancialAccountOut],
    summary="List financial liquidity accounts (Safe, Cash Drawer, Bank, Mobile Wallet)",
)
async def list_financial_accounts(
    branch_id: uuid.UUID | None = Query(None),
    is_active: bool | None = Query(None),
    current_user: CurrentUser = Depends(require_permission("financial:read")),
    db: AsyncSession = Depends(get_db),
) -> list[FinancialAccountOut]:
    accounts = await expenses_service.list_accounts(
        db, current_user.business_id, branch_id=branch_id, is_active=is_active
    )
    return [FinancialAccountOut.model_validate(acc) for acc in accounts]


@router.post(
    "",
    response_model=FinancialAccountOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new financial account",
)
async def create_financial_account(
    payload: FinancialAccountCreate,
    current_user: CurrentUser = Depends(require_permission("financial:write")),
    db: AsyncSession = Depends(get_db),
) -> FinancialAccountOut:
    acc = await expenses_service.create_account(
        db, current_user.business_id, payload
    )
    await db.commit()
    return FinancialAccountOut.model_validate(acc)


@router.put(
    "/{account_id}",
    response_model=FinancialAccountOut,
    summary="Update financial account details",
)
async def update_financial_account(
    account_id: uuid.UUID,
    payload: FinancialAccountUpdate,
    current_user: CurrentUser = Depends(require_permission("financial:write")),
    db: AsyncSession = Depends(get_db),
) -> FinancialAccountOut:
    acc = await expenses_service.update_account(
        db, current_user.business_id, account_id, payload
    )
    await db.commit()
    return FinancialAccountOut.model_validate(acc)


# ============================================================================
# Inter-Account Transfers
# ============================================================================
@router.post(
    "/transfers",
    response_model=AccountTransferOut,
    status_code=status.HTTP_201_CREATED,
    summary="Execute inter-account fund transfer with atomic locking",
)
async def transfer_funds(
    payload: AccountTransferCreate,
    current_user: CurrentUser = Depends(require_permission("financial:write")),
    db: AsyncSession = Depends(get_db),
) -> AccountTransferOut:
    transfer = await expenses_service.transfer_funds(
        db, current_user.business_id, current_user.user_id, payload
    )
    await db.commit()
    return _to_transfer_out(transfer)


@router.get(
    "/transfers",
    response_model=list[AccountTransferOut],
    summary="List inter-account transfer audit logs",
)
async def list_transfers(
    account_id: uuid.UUID | None = Query(None),
    limit: int = Query(default=50, ge=1, le=200),
    current_user: CurrentUser = Depends(require_permission("financial:read")),
    db: AsyncSession = Depends(get_db),
) -> list[AccountTransferOut]:
    transfers = await expenses_service.list_transfers(
        db, current_user.business_id, account_id=account_id, limit=limit
    )
    return [_to_transfer_out(t) for t in transfers]


# ============================================================================
# Financial Reports
# ============================================================================
@router.get(
    "/reports/cash-flow",
    response_model=CashFlowReportOut,
    summary="Generate cash flow statement (inflows vs outflows)",
)
async def get_cash_flow_report(
    start_date: date | None = Query(None),
    end_date: date | None = Query(None),
    branch_id: uuid.UUID | None = Query(None),
    current_user: CurrentUser = Depends(require_permission("financial:read")),
    db: AsyncSession = Depends(get_db),
) -> CashFlowReportOut:
    today = date.today()
    effective_start = start_date or (today - timedelta(days=30))
    effective_end = end_date or today
    return await expenses_service.get_cash_flow_statement(
        db,
        business_id=current_user.business_id,
        start_date=effective_start,
        end_date=effective_end,
        branch_id=branch_id,
    )


@router.get(
    "/reports/ap-aging",
    response_model=APAgeingReportOut,
    summary="Generate Accounts Payable aging report",
)
async def get_ap_aging_report(
    as_of_date: date | None = Query(None),
    current_user: CurrentUser = Depends(require_permission("financial:read")),
    db: AsyncSession = Depends(get_db),
) -> APAgeingReportOut:
    return await expenses_service.get_ap_aging_report(
        db,
        business_id=current_user.business_id,
        as_of_date=as_of_date,
    )

