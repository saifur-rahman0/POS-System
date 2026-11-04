"""Business service orchestrating Register Shift sessions, cash reconciliation, and Z-Reports."""

import uuid
from datetime import UTC, datetime
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.business.models import Branch, Business
from app.modules.expenses.models import CashTransaction
from app.modules.returns.models import Return
from app.modules.sales.models import PaymentTender, Sale
from app.modules.shifts.models import RegisterShift
from app.modules.shifts.repository import ShiftRepository
from app.modules.shifts.schemas import (
    CashReconciliation,
    CashTransactionOut,
    PaginatedShifts,
    SalesPerformanceSummary,
    ShiftCashInOutRequest,
    ShiftCloseRequest,
    ShiftOpenRequest,
    ShiftOut,
    ShiftSummaryTotals,
    TenderBreakdown,
    ZReportOut,
)
from app.shared.exceptions import AppException


def _to_naive_utc(dt: datetime | None) -> datetime | None:
    """Converts a datetime to timezone-naive UTC for database compatibility."""
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(UTC).replace(tzinfo=None)
    return dt


class ShiftService:
    """Manages cash drawer sessions, daily cashier reconciliation, and Z-Reports."""

    def __init__(self) -> None:
        self.repo = ShiftRepository()

    async def open_shift(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: ShiftOpenRequest,
    ) -> ShiftOut:
        """Opens a new cashier register shift after ensuring no open shift already exists."""
        # 1. Check for existing open shift for this user
        existing = await self.repo.get_open_shift(session, business_id, user_id)
        if existing:
            raise AppException(
                message=f"Cashier already has an active open shift (ID: {existing.id})",
                code="SHIFT_ALREADY_OPEN",
                status_code=409,
                details={"existing_shift_id": str(existing.id), "opened_at": existing.opened_at.isoformat()},
            )

        # 2. Resolve branch
        branch_id = payload.branch_id
        if not branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id, Branch.is_active.is_(True)).limit(1)
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                raise AppException("No active branch found for shift", code="BRANCH_NOT_FOUND", status_code=404)
            branch_id = default_branch.id

        opening_cash = payload.opening_cash.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)

        # 3. Create register shift
        shift = RegisterShift(
            id=uuid.uuid4(),
            business_id=business_id,
            branch_id=branch_id,
            user_id=user_id,
            device_id=payload.device_id,
            status="OPEN",
            opening_cash=opening_cash,
            opening_notes=payload.notes,
            denominations_json={},
        )
        await self.repo.create(session, shift)

        # 4. Log cash transaction for opening float if > 0
        if opening_cash > Decimal("0.0000"):
            float_tx = CashTransaction(
                id=uuid.uuid4(),
                business_id=business_id,
                branch_id=branch_id,
                account_id="MAIN_CASH_DRAWER",
                direction="IN",
                amount=opening_cash,
                reference_type="FLOAT_IN",
                reference_id=shift.id,
                note=f"Opening cash float: {payload.notes}" if payload.notes else "Opening cash float",
                created_by=user_id,
            )
            session.add(float_tx)

        await session.commit()
        await session.refresh(shift, ["branch", "user"])

        totals = await self._calculate_shift_totals(session, shift)
        return self._map_shift_out(shift, totals)

    async def get_current_shift(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> ShiftOut | None:
        """Returns the active open shift for the user along with live drawer totals."""
        shift = await self.repo.get_open_shift(session, business_id, user_id, branch_id=branch_id)
        if not shift:
            return None

        totals = await self._calculate_shift_totals(session, shift)
        return self._map_shift_out(shift, totals)

    async def record_cash_in(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        shift_id: uuid.UUID,
        payload: ShiftCashInOutRequest,
    ) -> CashTransactionOut:
        """Records manual cash deposit or float top-up into the drawer."""
        shift = await self.repo.get_by_id(session, business_id, shift_id)
        if not shift:
            raise AppException("Shift session not found", code="SHIFT_NOT_FOUND", status_code=404)
        if shift.status != "OPEN":
            raise AppException("Cannot add cash to a closed shift", code="SHIFT_CLOSED", status_code=400)

        amount = payload.amount.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        tx = CashTransaction(
            id=uuid.uuid4(),
            business_id=business_id,
            branch_id=shift.branch_id,
            account_id="MAIN_CASH_DRAWER",
            direction="IN",
            amount=amount,
            reference_type="SHIFT_CASH_IN",
            reference_id=shift.id,
            note=f"{payload.reason}: {payload.notes}" if payload.notes else payload.reason,
            created_by=user_id,
        )
        session.add(tx)
        await session.commit()
        await session.refresh(tx)
        return CashTransactionOut.model_validate(tx)

    async def record_cash_out(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        shift_id: uuid.UUID,
        payload: ShiftCashInOutRequest,
    ) -> CashTransactionOut:
        """Records manual cash withdrawal, petty expense, or bank drop from the drawer."""
        shift = await self.repo.get_by_id(session, business_id, shift_id)
        if not shift:
            raise AppException("Shift session not found", code="SHIFT_NOT_FOUND", status_code=404)
        if shift.status != "OPEN":
            raise AppException("Cannot withdraw cash from a closed shift", code="SHIFT_CLOSED", status_code=400)

        amount = payload.amount.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)

        # Ensure drawer has sufficient expected funds
        totals = await self._calculate_shift_totals(session, shift)
        if amount > totals.expected_cash:
            raise AppException(
                f"Cash withdrawal of {amount} exceeds expected cash on hand ({totals.expected_cash})",
                code="INSUFFICIENT_DRAWER_CASH",
                status_code=409,
                details={"expected_cash": str(totals.expected_cash), "requested_withdrawal": str(amount)},
            )

        tx = CashTransaction(
            id=uuid.uuid4(),
            business_id=business_id,
            branch_id=shift.branch_id,
            account_id="MAIN_CASH_DRAWER",
            direction="OUT",
            amount=amount,
            reference_type="SHIFT_CASH_OUT",
            reference_id=shift.id,
            note=f"{payload.reason}: {payload.notes}" if payload.notes else payload.reason,
            created_by=user_id,
        )
        session.add(tx)
        await session.commit()
        await session.refresh(tx)
        return CashTransactionOut.model_validate(tx)

    async def close_shift(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        shift_id: uuid.UUID,
        payload: ShiftCloseRequest,
    ) -> ShiftOut:
        """Closes an active register shift and reconciles counted cash against expected drawer cash."""
        shift = await self.repo.get_by_id(session, business_id, shift_id, for_update=True)
        if not shift:
            raise AppException("Shift session not found", code="SHIFT_NOT_FOUND", status_code=404)
        if shift.status != "OPEN":
            raise AppException("Shift is already closed", code="SHIFT_ALREADY_CLOSED", status_code=400)

        # Calculate authoritative expected cash
        totals = await self._calculate_shift_totals(session, shift)
        counted = payload.closing_cash_counted.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        expected = totals.expected_cash
        difference = (counted - expected).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)

        now = datetime.now(UTC).replace(tzinfo=None)
        shift.status = "CLOSED"
        shift.closed_at = now
        shift.closing_cash_counted = counted
        shift.closing_cash_expected = expected
        shift.cash_difference = difference
        shift.closing_notes = payload.notes
        shift.denominations_json = payload.denominations

        await session.commit()
        await session.refresh(shift, ["branch", "user"])

        # Recompute totals with closed values
        final_totals = await self._calculate_shift_totals(session, shift)
        return self._map_shift_out(shift, final_totals)

    async def generate_z_report(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        shift_id: uuid.UUID,
    ) -> ZReportOut:
        """Generates comprehensive daily Z-Report data structure for a shift."""
        shift = await self.repo.get_by_id(session, business_id, shift_id)
        if not shift:
            raise AppException("Shift not found", code="SHIFT_NOT_FOUND", status_code=404)

        # Fetch Business details
        biz_stmt = select(Business).where(Business.id == business_id)
        biz_res = await session.execute(biz_stmt)
        business = biz_res.scalars().first()
        business_name = business.name if business else "Retail POS"

        branch_name = shift.branch.name if shift.branch else "Main Branch"
        cashier_username = shift.user.username if shift.user else "Cashier"
        cashier_full_name = getattr(shift.user, "full_name", None)

        # Time range
        start_time = _to_naive_utc(shift.opened_at) or datetime.now(UTC).replace(tzinfo=None)
        end_time = _to_naive_utc(shift.closed_at) or datetime.now(UTC).replace(tzinfo=None)
        duration_minutes = max(0, int((end_time - start_time).total_seconds() / 60))

        # 1. Tender breakdown & totals
        tenders_stmt = (
            select(
                PaymentTender.method,
                func.count(PaymentTender.id).label("tender_count"),
                func.sum(PaymentTender.amount).label("total_amount"),
            )
            .join(Sale, Sale.id == PaymentTender.sale_id)
            .where(
                Sale.business_id == business_id,
                Sale.branch_id == shift.branch_id,
                Sale.cashier_id == shift.user_id,
                PaymentTender.received_at >= start_time,
                PaymentTender.received_at <= end_time,
                PaymentTender.status == "CONFIRMED",
            )
            .group_by(PaymentTender.method)
        )
        tenders_res = await session.execute(tenders_stmt)
        tenders_rows = tenders_res.all()

        tenders_map = {
            r.method: TenderBreakdown(
                method=r.method,
                count=int(r.tender_count or 0),
                total_amount=Decimal(str(r.total_amount or "0.0000")),
            )
            for r in tenders_rows
        }

        # Include standard methods even if 0
        standard_methods = ["CASH", "CARD", "BKASH", "NAGAD", "ROCKET", "DUE"]
        all_tenders: list[TenderBreakdown] = []
        for m in standard_methods:
            if m in tenders_map:
                all_tenders.append(tenders_map[m])
            else:
                all_tenders.append(TenderBreakdown(method=m, count=0, total_amount=Decimal("0.0000")))

        # 2. Sales Summary
        sales_stmt = select(Sale).where(
            Sale.business_id == business_id,
            Sale.branch_id == shift.branch_id,
            Sale.cashier_id == shift.user_id,
            Sale.created_at >= start_time,
            Sale.created_at <= end_time,
        )
        sales_res = await session.execute(sales_stmt)
        sales_list = sales_res.scalars().all()

        total_tx = len(sales_list)
        completed_count = sum(1 for s in sales_list if s.status == "COMPLETED")
        voided_count = sum(1 for s in sales_list if s.status == "VOID")

        active_sales = [s for s in sales_list if s.status != "VOID"]
        gross_sales = sum((s.subtotal for s in active_sales), Decimal("0.0000"))
        discounts = sum((s.discount_total for s in active_sales), Decimal("0.0000"))
        net_sales = sum((s.grand_total for s in active_sales), Decimal("0.0000"))
        tax_total = sum((s.tax_total for s in active_sales), Decimal("0.0000"))

        # 3. Returns Summary
        returns_stmt = select(Return).where(
            Return.business_id == business_id,
            Return.branch_id == shift.branch_id,
            Return.created_by == shift.user_id,
            Return.created_at >= start_time,
            Return.created_at <= end_time,
            Return.status == "COMPLETED",
        )
        returns_res = await session.execute(returns_stmt)
        returns_list = returns_res.scalars().all()
        returns_count = len(returns_list)
        returns_total = sum((r.refund_total for r in returns_list), Decimal("0.0000"))

        # 4. Cash Drawer Reconciliation
        shift_totals = await self._calculate_shift_totals(session, shift)

        diff = shift.cash_difference
        if shift.status == "CLOSED":
            if diff == Decimal("0.0000"):
                variance_status = "BALANCED"
            elif diff and diff < Decimal("0.0000"):
                variance_status = "SHORTAGE"
            else:
                variance_status = "OVERAGE"
        else:
            variance_status = "PENDING_CLOSE"

        reconciliation = CashReconciliation(
            opening_float=shift.opening_cash,
            cash_sales=shift_totals.cash_sales,
            cash_in=shift_totals.cash_in,
            cash_refunds=shift_totals.cash_refunds,
            cash_out=shift_totals.cash_out,
            expected_in_drawer=shift_totals.expected_cash,
            actual_counted=shift.closing_cash_counted,
            difference=diff,
            variance_status=variance_status,
        )

        sales_summary = SalesPerformanceSummary(
            gross_sales=gross_sales,
            discount_total=discounts,
            net_sales=net_sales,
            tax_total=tax_total,
            total_transactions=total_tx,
            completed_sales=completed_count,
            voided_sales=voided_count,
            returns_count=returns_count,
            returns_total=returns_total,
        )

        return ZReportOut(
            shift_id=shift.id,
            business_name=business_name,
            branch_name=branch_name,
            cashier_username=cashier_username,
            cashier_full_name=cashier_full_name,
            status=shift.status,
            opened_at=shift.opened_at,
            closed_at=shift.closed_at,
            duration_minutes=duration_minutes,
            cash_reconciliation=reconciliation,
            tenders_breakdown=all_tenders,
            sales_summary=sales_summary,
            generated_at=datetime.now(UTC),
        )

    async def list_shifts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        user_id: uuid.UUID | None = None,
        status: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedShifts:
        """Fetch paginated shifts."""
        start_date = _to_naive_utc(start_date)
        end_date = _to_naive_utc(end_date)
        total = await self.repo.count_shifts(
            session, business_id, branch_id, user_id, status, start_date, end_date
        )
        shifts = await self.repo.list_shifts(
            session, business_id, branch_id, user_id, status, start_date, end_date, page, page_size
        )

        items_out: list[ShiftOut] = []
        for s in shifts:
            totals = await self._calculate_shift_totals(session, s)
            items_out.append(self._map_shift_out(s, totals))

        total_pages = (total + page_size - 1) // page_size if total > 0 else 1
        return PaginatedShifts(
            items=items_out,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        )

    # -------------------------------------------------------------------------
    # Internal Helpers
    # -------------------------------------------------------------------------
    async def _calculate_shift_totals(
        self,
        session: AsyncSession,
        shift: RegisterShift,
    ) -> ShiftSummaryTotals:
        """Computes authoritative cash totals, cash-in, cash-out, and expected drawer balance."""
        start_time = _to_naive_utc(shift.opened_at) or datetime.now(UTC).replace(tzinfo=None)
        end_time = _to_naive_utc(shift.closed_at) or datetime.now(UTC).replace(tzinfo=None)

        # 1. Cash sales tendered during shift
        cash_sales_stmt = (
            select(func.sum(PaymentTender.amount))
            .join(Sale, Sale.id == PaymentTender.sale_id)
            .where(
                Sale.business_id == shift.business_id,
                Sale.branch_id == shift.branch_id,
                Sale.cashier_id == shift.user_id,
                PaymentTender.received_at >= start_time,
                PaymentTender.received_at <= end_time,
                PaymentTender.method == "CASH",
                PaymentTender.status == "CONFIRMED",
            )
        )
        cash_sales_res = await session.execute(cash_sales_stmt)
        cash_sales = Decimal(str(cash_sales_res.scalar_one_or_none() or "0.0000"))

        # 2. Cash In during shift (excluding initial float which is in opening_cash)
        cash_in_stmt = select(func.sum(CashTransaction.amount)).where(
            CashTransaction.business_id == shift.business_id,
            CashTransaction.branch_id == shift.branch_id,
            CashTransaction.created_at >= start_time,
            CashTransaction.created_at <= end_time,
            CashTransaction.direction == "IN",
            CashTransaction.reference_type != "FLOAT_IN",
        )
        cash_in_res = await session.execute(cash_in_stmt)
        cash_in = Decimal(str(cash_in_res.scalar_one_or_none() or "0.0000"))

        # 3. Cash Out during shift (withdrawals, drops, petty expenses, supplier disbursements)
        cash_out_stmt = select(func.sum(CashTransaction.amount)).where(
            CashTransaction.business_id == shift.business_id,
            CashTransaction.branch_id == shift.branch_id,
            CashTransaction.created_at >= start_time,
            CashTransaction.created_at <= end_time,
            CashTransaction.direction == "OUT",
        )
        cash_out_res = await session.execute(cash_out_stmt)
        cash_out = Decimal(str(cash_out_res.scalar_one_or_none() or "0.0000"))

        # 4. Customer returns / refund total during shift
        returns_stmt = select(func.sum(Return.refund_total)).where(
            Return.business_id == shift.business_id,
            Return.branch_id == shift.branch_id,
            Return.created_by == shift.user_id,
            Return.created_at >= start_time,
            Return.created_at <= end_time,
            Return.status == "COMPLETED",
        )
        returns_res = await session.execute(returns_stmt)
        cash_refunds = Decimal(str(returns_res.scalar_one_or_none() or "0.0000"))

        # Expected cash formula:
        # Expected = Opening Float + Cash Sales + Cash In - Cash Out - Cash Refunds
        expected = shift.opening_cash + cash_sales + cash_in - cash_out - cash_refunds
        expected = max(Decimal("0.0000"), expected.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP))

        diff = shift.cash_difference
        if diff is None and shift.closing_cash_counted is not None:
            diff = shift.closing_cash_counted - expected

        return ShiftSummaryTotals(
            opening_cash=shift.opening_cash,
            cash_sales=cash_sales,
            cash_in=cash_in,
            cash_refunds=cash_refunds,
            cash_out=cash_out,
            expected_cash=expected,
            actual_cash_counted=shift.closing_cash_counted,
            cash_difference=diff,
        )

    def _map_shift_out(
        self,
        shift: RegisterShift,
        totals: ShiftSummaryTotals | None = None,
    ) -> ShiftOut:
        """Converts ORM RegisterShift to Pydantic ShiftOut schema."""
        branch_name = shift.branch.name if shift.branch else None
        cashier_name = shift.user.username if shift.user else None

        return ShiftOut(
            id=shift.id,
            business_id=shift.business_id,
            branch_id=shift.branch_id,
            branch_name=branch_name,
            user_id=shift.user_id,
            cashier_name=cashier_name,
            device_id=shift.device_id,
            status=shift.status,
            opened_at=shift.opened_at,
            closed_at=shift.closed_at,
            opening_cash=shift.opening_cash,
            closing_cash_counted=shift.closing_cash_counted,
            closing_cash_expected=shift.closing_cash_expected,
            cash_difference=shift.cash_difference,
            opening_notes=shift.opening_notes,
            closing_notes=shift.closing_notes,
            denominations=shift.denominations_json or {},
            totals=totals,
            created_at=shift.created_at,
        )
