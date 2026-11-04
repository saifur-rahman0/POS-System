"""Cashier Register Shift Sessions, Drawer Balancing & Z-Report Endpoints."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.shifts.schemas import (
    CashTransactionOut,
    PaginatedShifts,
    ShiftCashInOutRequest,
    ShiftCloseRequest,
    ShiftOpenRequest,
    ShiftOut,
    ZReportOut,
)
from app.modules.shifts.service import ShiftService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/shifts", tags=["Cash Drawer & Register Shifts"])
shift_service = ShiftService()


@router.post(
    "/open",
    response_model=ShiftOut,
    status_code=status.HTTP_201_CREATED,
    summary="Open a cashier register shift with starting float",
)
async def open_shift(
    payload: ShiftOpenRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> ShiftOut:
    """Opens a new register shift session and records initial float."""
    return await shift_service.open_shift(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        payload=payload,
    )


@router.get(
    "/current",
    response_model=ShiftOut | None,
    summary="Get current active open shift for logged-in cashier",
)
async def get_current_shift(
    branch_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> ShiftOut | None:
    """Fetch current active open shift session with live drawer totals."""
    return await shift_service.get_current_shift(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        branch_id=branch_id,
    )


@router.post(
    "/{id}/cash-in",
    response_model=CashTransactionOut,
    status_code=status.HTTP_201_CREATED,
    summary="Record cash deposit or float top-up into drawer",
)
async def record_cash_in(
    id: uuid.UUID,
    payload: ShiftCashInOutRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> CashTransactionOut:
    """Injects cash into the active drawer session."""
    return await shift_service.record_cash_in(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        shift_id=id,
        payload=payload,
    )


@router.post(
    "/{id}/cash-out",
    response_model=CashTransactionOut,
    status_code=status.HTTP_201_CREATED,
    summary="Record cash withdrawal, petty expense, or bank drop from drawer",
)
async def record_cash_out(
    id: uuid.UUID,
    payload: ShiftCashInOutRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> CashTransactionOut:
    """Withdraws cash from the active drawer session."""
    return await shift_service.record_cash_out(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        shift_id=id,
        payload=payload,
    )


@router.post(
    "/{id}/close",
    response_model=ShiftOut,
    summary="Close register shift and reconcile drawer cash",
)
async def close_shift(
    id: uuid.UUID,
    payload: ShiftCloseRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:create")),
) -> ShiftOut:
    """Closes an active shift, records physical cash counted, and computes discrepancy."""
    return await shift_service.close_shift(
        session=db,
        business_id=user.business_id,
        user_id=user.user_id,
        shift_id=id,
        payload=payload,
    )


@router.get(
    "/{id}/z-report",
    response_model=ZReportOut,
    summary="Generate comprehensive daily Z-Report for a shift",
)
async def get_z_report(
    id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("reports:read")),
) -> ZReportOut:
    """Generates financial reconciliation, sales summary, and tender breakdown."""
    return await shift_service.generate_z_report(
        session=db,
        business_id=user.business_id,
        shift_id=id,
    )


@router.get(
    "",
    response_model=PaginatedShifts,
    summary="List paginated shift history",
)
async def list_shifts(
    branch_id: uuid.UUID | None = Query(default=None),
    user_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    start_date: datetime | None = Query(default=None),
    end_date: datetime | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("reports:read")),
) -> PaginatedShifts:
    """Query past cashier shift sessions and audit logs."""
    return await shift_service.list_shifts(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        user_id=user_id,
        status=status,
        start_date=start_date,
        end_date=end_date,
        page=page,
        page_size=page_size,
    )

