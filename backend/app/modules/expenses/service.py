"""Domain business logic for Operating Expenses, Financial Accounts, and Liquidity Management."""

import calendar
import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from typing import Literal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.business.models import Branch
from app.modules.expenses.models import (
    AccountTransfer,
    CashTransaction,
    Expense,
    ExpenseCategory,
    FinancialAccount,
    RecurringExpense,
)
from app.modules.expenses.repository import ExpensesRepository
from app.modules.expenses.schemas import (
    AccountTransferCreate,
    APAgeingBucket,
    APAgeingReportOut,
    CashFlowReportOut,
    ExpenseCategoryCreate,
    ExpenseCategoryOut,
    ExpenseCategoryUpdate,
    ExpenseCreate,
    FinancialAccountCreate,
    FinancialAccountUpdate,
    RecurringExpenseCreate,
    RecurringExpenseUpdate,
)
from app.modules.purchasing.models import PurchasePayment
from app.modules.sales.models import PaymentTender
from app.shared.exceptions import AppException

# Operating payout threshold requiring supervisor/manager sign-off (BDT 5,000)
APPROVAL_THRESHOLD = Decimal("5000.0000")


def advance_due_date(current: date, frequency: str) -> date:
    """Calculates the subsequent due date based on recurrence frequency."""
    freq = frequency.upper()
    if freq == "DAILY":
        return current + timedelta(days=1)
    if freq == "WEEKLY":
        return current + timedelta(days=7)
    if freq == "MONTHLY":
        month = current.month + 1
        year = current.year
        if month > 12:
            month = 1
            year += 1
        max_days = calendar.monthrange(year, month)[1]
        day = min(current.day, max_days)
        return date(year, month, day)
    if freq == "QUARTERLY":
        month = current.month + 3
        year = current.year
        while month > 12:
            month -= 12
            year += 1
        max_days = calendar.monthrange(year, month)[1]
        day = min(current.day, max_days)
        return date(year, month, day)
    if freq == "ANNUAL":
        try:
            return current.replace(year=current.year + 1)
        except ValueError:
            return date(current.year + 1, 2, 28)
    return current + timedelta(days=30)


class ExpensesService:
    """Domain service orchestrating expense authorizations, account ledgers, and reporting."""

    def __init__(self, repo: ExpensesRepository | None = None) -> None:
        self.repo = repo or ExpensesRepository()

    # =========================================================================
    # Expense Categories
    # =========================================================================
    async def create_category(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: ExpenseCategoryCreate,
    ) -> ExpenseCategoryOut:
        clean_code = payload.code.strip().upper()
        existing = await self.repo.get_category_by_code(session, business_id, clean_code)
        if existing:
            raise AppException(
                message=f"Category code '{clean_code}' already exists for this business",
                code="CATEGORY_CODE_EXISTS",
                status_code=400,
            )

        category = ExpenseCategory(
            business_id=business_id,
            name=payload.name.strip(),
            code=clean_code,
            description=payload.description.strip() if payload.description else None,
            monthly_budget=payload.monthly_budget,
            is_active=payload.is_active,
        )
        saved = await self.repo.create_category(session, category)
        return ExpenseCategoryOut.model_validate(saved)

    async def list_categories(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[ExpenseCategoryOut]:
        categories = await self.repo.list_categories(session, business_id, is_active=is_active)
        now = datetime.now(UTC)
        results: list[ExpenseCategoryOut] = []
        for cat in categories:
            spent = await self.repo.get_category_monthly_spent(
                session, business_id, cat.id, now.year, now.month
            )
            out = ExpenseCategoryOut.model_validate(cat)
            out.current_month_spent = spent
            results.append(out)
        return results

    async def update_category(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        category_id: uuid.UUID,
        payload: ExpenseCategoryUpdate,
    ) -> ExpenseCategoryOut:
        cat = await self.repo.get_category(session, business_id, category_id)
        if not cat:
            raise AppException("Expense category not found", code="CATEGORY_NOT_FOUND", status_code=404)

        if payload.name is not None:
            cat.name = payload.name.strip()
        if payload.code is not None:
            new_code = payload.code.strip().upper()
            if new_code != cat.code:
                existing = await self.repo.get_category_by_code(session, business_id, new_code)
                if existing:
                    raise AppException("Category code already in use", code="CATEGORY_CODE_EXISTS", status_code=400)
                cat.code = new_code
        if payload.description is not None:
            cat.description = payload.description.strip() if payload.description else None
        if payload.monthly_budget is not None:
            cat.monthly_budget = payload.monthly_budget
        if payload.is_active is not None:
            cat.is_active = payload.is_active

        await session.flush()
        now = datetime.now(UTC)
        spent = await self.repo.get_category_monthly_spent(session, business_id, cat.id, now.year, now.month)
        out = ExpenseCategoryOut.model_validate(cat)
        out.current_month_spent = spent
        return out

    # =========================================================================
    # Financial Accounts
    # =========================================================================
    async def create_account(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: FinancialAccountCreate,
    ) -> FinancialAccount:
        if payload.branch_id:
            branch = await session.get(Branch, payload.branch_id)
            if not branch or branch.business_id != business_id:
                raise AppException("Branch not found", code="BRANCH_NOT_FOUND", status_code=404)

        account = FinancialAccount(
            business_id=business_id,
            branch_id=payload.branch_id,
            account_name=payload.account_name.strip(),
            account_type=payload.account_type,
            account_number=payload.account_number.strip() if payload.account_number else None,
            bank_name=payload.bank_name.strip() if payload.bank_name else None,
            opening_balance=payload.opening_balance,
            current_balance=payload.opening_balance,
        )
        return await self.repo.create_account(session, account)

    async def list_accounts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        is_active: bool | None = None,
    ) -> list[FinancialAccount]:
        return await self.repo.list_accounts(
            session, business_id, branch_id=branch_id, is_active=is_active
        )

    async def update_account(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        account_id: uuid.UUID,
        payload: FinancialAccountUpdate,
    ) -> FinancialAccount:
        acc = await self.repo.get_account(session, business_id, account_id)
        if not acc:
            raise AppException("Financial account not found", code="ACCOUNT_NOT_FOUND", status_code=404)

        if payload.account_name is not None:
            acc.account_name = payload.account_name.strip()
        if payload.account_number is not None:
            acc.account_number = payload.account_number.strip() if payload.account_number else None
        if payload.bank_name is not None:
            acc.bank_name = payload.bank_name.strip() if payload.bank_name else None
        if payload.is_active is not None:
            acc.is_active = payload.is_active

        await session.flush()
        return acc

    # =========================================================================
    # Account Transfers (Inter-Account Balance Movements)
    # =========================================================================
    async def transfer_funds(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: AccountTransferCreate,
    ) -> AccountTransfer:
        if payload.from_account_id == payload.to_account_id:
            raise AppException(
                "Source and destination accounts must be different",
                code="INVALID_TRANSFER_ACCOUNTS",
                status_code=400,
            )

        if payload.amount <= Decimal("0.0000"):
            raise AppException("Transfer amount must be positive", code="INVALID_AMOUNT", status_code=400)

        # Lock both accounts in deterministic order to prevent deadlock
        from_acc, to_acc = await self.repo.get_accounts_for_transfer(
            session, business_id, payload.from_account_id, payload.to_account_id
        )

        if not from_acc or not from_acc.is_active:
            raise AppException("Source account is missing or inactive", code="SOURCE_ACCOUNT_INVALID", status_code=400)
        if not to_acc or not to_acc.is_active:
            raise AppException("Destination account is missing or inactive", code="DEST_ACCOUNT_INVALID", status_code=400)

        # Non-negative liquidity check
        if from_acc.current_balance < payload.amount:
            raise AppException(
                f"Insufficient funds in source account '{from_acc.account_name}' "
                f"(Balance: ৳{from_acc.current_balance:.2f}, Required: ৳{payload.amount:.2f})",
                code="INSUFFICIENT_FUNDS",
                status_code=400,
            )

        # Atomic balance mutation
        from_acc.current_balance -= payload.amount
        to_acc.current_balance += payload.amount

        # Reference number
        ref_no = payload.reference_no
        if not ref_no or not ref_no.strip():
            ref_no = await self.repo.generate_transfer_reference(session, business_id)

        transfer = AccountTransfer(
            business_id=business_id,
            from_account_id=from_acc.id,
            to_account_id=to_acc.id,
            amount=payload.amount,
            reference_no=ref_no,
            note=payload.note.strip() if payload.note else None,
            created_by=user_id,
        )
        saved_transfer = await self.repo.create_transfer(session, transfer)

        # If cash drawer/petty cash involved, log CashTransactions
        if from_acc.account_type in ("CASH_DRAWER", "PETTY_CASH") and from_acc.branch_id:
            session.add(
                CashTransaction(
                    business_id=business_id,
                    branch_id=from_acc.branch_id,
                    account_id=from_acc.account_name,
                    direction="OUT",
                    amount=payload.amount,
                    reference_type="TRANSFER",
                    reference_id=saved_transfer.id,
                    note=f"Transfer to {to_acc.account_name} ({ref_no})",
                    created_by=user_id,
                )
            )

        if to_acc.account_type in ("CASH_DRAWER", "PETTY_CASH") and to_acc.branch_id:
            session.add(
                CashTransaction(
                    business_id=business_id,
                    branch_id=to_acc.branch_id,
                    account_id=to_acc.account_name,
                    direction="IN",
                    amount=payload.amount,
                    reference_type="TRANSFER",
                    reference_id=saved_transfer.id,
                    note=f"Transfer from {from_acc.account_name} ({ref_no})",
                    created_by=user_id,
                )
            )

        await session.flush()
        return saved_transfer

    async def list_transfers(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        account_id: uuid.UUID | None = None,
        limit: int = 50,
    ) -> list[AccountTransfer]:
        return await self.repo.list_transfers(session, business_id, account_id=account_id, limit=limit)

    # =========================================================================
    # Recurring Expenses
    # =========================================================================
    async def create_recurring_expense(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: RecurringExpenseCreate,
    ) -> RecurringExpense:
        # Validate category
        cat = await self.repo.get_category(session, business_id, payload.category_id)
        if not cat or not cat.is_active:
            raise AppException("Active expense category required", code="INVALID_CATEGORY", status_code=400)

        # Validate account if provided
        if payload.payment_account_id:
            acc = await self.repo.get_account(session, business_id, payload.payment_account_id)
            if not acc or not acc.is_active:
                raise AppException("Active payment account required", code="INVALID_ACCOUNT", status_code=400)

        recurring = RecurringExpense(
            business_id=business_id,
            branch_id=payload.branch_id,
            category_id=payload.category_id,
            payment_account_id=payload.payment_account_id,
            title=payload.title.strip(),
            amount=payload.amount,
            frequency=payload.frequency,
            next_due_date=payload.next_due_date,
            auto_post=payload.auto_post,
            is_active=payload.is_active,
        )
        return await self.repo.create_recurring_expense(session, recurring)

    async def list_recurring_expenses(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        is_active: bool | None = None,
    ) -> list[RecurringExpense]:
        return await self.repo.list_recurring_expenses(session, business_id, branch_id=branch_id, is_active=is_active)

    async def update_recurring_expense(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        recurring_id: uuid.UUID,
        payload: RecurringExpenseUpdate,
    ) -> RecurringExpense:
        rec = await self.repo.get_recurring_expense(session, business_id, recurring_id)
        if not rec:
            raise AppException("Recurring expense not found", code="RECURRING_NOT_FOUND", status_code=404)

        if payload.category_id is not None:
            cat = await self.repo.get_category(session, business_id, payload.category_id)
            if not cat or not cat.is_active:
                raise AppException("Active expense category required", code="INVALID_CATEGORY", status_code=400)
            rec.category_id = payload.category_id

        if payload.payment_account_id is not None:
            acc = await self.repo.get_account(session, business_id, payload.payment_account_id)
            if not acc or not acc.is_active:
                raise AppException("Active payment account required", code="INVALID_ACCOUNT", status_code=400)
            rec.payment_account_id = payload.payment_account_id

        if payload.title is not None:
            rec.title = payload.title.strip()
        if payload.amount is not None:
            rec.amount = payload.amount
        if payload.frequency is not None:
            rec.frequency = payload.frequency
        if payload.next_due_date is not None:
            rec.next_due_date = payload.next_due_date
        if payload.auto_post is not None:
            rec.auto_post = payload.auto_post
        if payload.is_active is not None:
            rec.is_active = payload.is_active

        await session.flush()
        return rec

    async def process_due_recurring_expenses(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        as_of_date: date | None = None,
    ) -> list[Expense]:
        target_date = as_of_date or datetime.now(UTC).date()
        due_list = await self.repo.get_due_recurring_expenses(session, business_id, target_date)
        generated_expenses: list[Expense] = []

        for rec in due_list:
            if not rec.auto_post:
                continue

            # Resolve branch
            branch_id = rec.branch_id
            if not branch_id:
                # Find default branch of business
                b_stmt = select(Branch).where(Branch.business_id == business_id).order_by(Branch.created_at.asc())
                b_res = await session.execute(b_stmt)
                def_branch = b_res.scalars().first()
                if def_branch:
                    branch_id = def_branch.id
                else:
                    continue

            # Create the expense voucher
            expense_payload = ExpenseCreate(
                branch_id=branch_id,
                category=rec.category.name if rec.category else "Recurring",
                category_id=rec.category_id,
                amount=rec.amount,
                note=f"Auto-generated recurring expense: {rec.title}",
                payment_account_id=rec.payment_account_id,
                payment_method="TRANSFER" if rec.payment_account_id else "CASH",
                tax_deductible=True,
            )
            created_exp = await self.create_expense(session, business_id, branch_id, user_id, expense_payload)
            generated_expenses.append(created_exp)

            # Advance next_due_date and record last_generated_at
            rec.last_generated_at = datetime.now(UTC)
            rec.next_due_date = advance_due_date(rec.next_due_date, rec.frequency)

        await session.flush()
        return generated_expenses

    # =========================================================================
    # Operating Expense Vouchers & Approval Workflow
    # =========================================================================
    async def create_expense(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None,
        user_id: uuid.UUID,
        payload: ExpenseCreate,
    ) -> Expense:
        if payload.amount <= Decimal("0.0000"):
            raise AppException("Expense amount must be positive", code="INVALID_AMOUNT", status_code=400)

        # Resolve branch
        effective_branch_id = payload.branch_id or branch_id
        if not effective_branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id).order_by(Branch.created_at.asc())
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                raise AppException("No active branch found", code="BRANCH_NOT_FOUND", status_code=404)
            effective_branch_id = default_branch.id

        branch = await session.get(Branch, effective_branch_id)
        if not branch or branch.business_id != business_id:
            raise AppException("Branch not found", code="BRANCH_NOT_FOUND", status_code=404)

        # Resolve category
        category_name = payload.category
        if payload.category_id:
            cat = await self.repo.get_category(session, business_id, payload.category_id)
            if not cat:
                raise AppException("Category not found", code="CATEGORY_NOT_FOUND", status_code=404)
            category_name = cat.name
        elif not category_name or not category_name.strip():
            category_name = "General Expense"

        # Check approval threshold (> BDT 5,000)
        is_pending = payload.amount > APPROVAL_THRESHOLD
        status = "PENDING_APPROVAL" if is_pending else "APPROVED"
        approved_by = None if is_pending else user_id
        approved_at = None if is_pending else datetime.now(UTC)

        # Check & deduct from financial account if immediately approved
        payment_acc: FinancialAccount | None = None
        if payload.payment_account_id:
            payment_acc = await self.repo.get_account(
                session, business_id, payload.payment_account_id, for_update=True
            )
            if not payment_acc or not payment_acc.is_active:
                raise AppException("Payment account is missing or inactive", code="INVALID_ACCOUNT", status_code=400)

            if status == "APPROVED":
                if payment_acc.current_balance < payload.amount:
                    raise AppException(
                        f"Insufficient funds in account '{payment_acc.account_name}' "
                        f"(Balance: ৳{payment_acc.current_balance:.2f}, Amount: ৳{payload.amount:.2f})",
                        code="INSUFFICIENT_FUNDS",
                        status_code=400,
                    )
                payment_acc.current_balance -= payload.amount

        # Generate sequential voucher number
        voucher_no = await self.repo.generate_voucher_number(session, business_id, branch)

        expense = Expense(
            business_id=business_id,
            branch_id=effective_branch_id,
            voucher_no=voucher_no,
            category=category_name.strip(),
            category_id=payload.category_id,
            payment_account_id=payload.payment_account_id,
            payment_method=payload.payment_method.strip().upper(),
            payee=payload.payee.strip() if payload.payee else None,
            receipt_reference=payload.receipt_reference.strip() if payload.receipt_reference else None,
            tax_deductible=payload.tax_deductible,
            amount=payload.amount,
            note=payload.note.strip() if payload.note else None,
            approval_status=status,
            approved_by=approved_by,
            approved_at=approved_at,
            created_by=user_id,
        )
        saved_expense = await self.repo.create_expense(session, expense)

        # If immediately approved and paid via cash drawer/petty cash, record CashTransaction
        if status == "APPROVED" and payment_acc and payment_acc.account_type in ("CASH_DRAWER", "PETTY_CASH"):
            session.add(
                CashTransaction(
                    business_id=business_id,
                    branch_id=effective_branch_id,
                    account_id=payment_acc.account_name,
                    direction="OUT",
                    amount=payload.amount,
                    reference_type="EXPENSE",
                    reference_id=saved_expense.id,
                    note=f"Expense Voucher {voucher_no}: {category_name}",
                    created_by=user_id,
                )
            )

        await session.flush()
        return saved_expense

    async def approve_or_reject_expense(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        expense_id: uuid.UUID,
        approver_id: uuid.UUID,
        action: Literal["APPROVED", "REJECTED"],
        note: str | None = None,
    ) -> Expense:
        expense = await self.repo.get_expense(session, business_id, expense_id, for_update=True)
        if not expense:
            raise AppException("Expense voucher not found", code="EXPENSE_NOT_FOUND", status_code=404)

        if expense.approval_status != "PENDING_APPROVAL":
            raise AppException(
                f"Expense cannot be processed because current status is '{expense.approval_status}'",
                code="INVALID_EXPENSE_STATUS",
                status_code=400,
            )

        now = datetime.now(UTC)
        if action == "APPROVED":
            # If payment account is configured, check and deduct now
            if expense.payment_account_id:
                acc = await self.repo.get_account(
                    session, business_id, expense.payment_account_id, for_update=True
                )
                if not acc or not acc.is_active:
                    raise AppException("Payment account is inactive or missing", code="INVALID_ACCOUNT", status_code=400)
                if acc.current_balance < expense.amount:
                    raise AppException(
                        f"Cannot approve: insufficient funds in account '{acc.account_name}' "
                        f"(Balance: ৳{acc.current_balance:.2f}, Required: ৳{expense.amount:.2f})",
                        code="INSUFFICIENT_FUNDS",
                        status_code=400,
                    )
                acc.current_balance -= expense.amount

                if acc.account_type in ("CASH_DRAWER", "PETTY_CASH"):
                    session.add(
                        CashTransaction(
                            business_id=business_id,
                            branch_id=expense.branch_id,
                            account_id=acc.account_name,
                            direction="OUT",
                            amount=expense.amount,
                            reference_type="EXPENSE",
                            reference_id=expense.id,
                            note=f"Expense Voucher {expense.voucher_no} Approved: {expense.category}",
                            created_by=approver_id,
                        )
                    )

            expense.approval_status = "APPROVED"
            expense.approved_by = approver_id
            expense.approved_at = now
        else:
            expense.approval_status = "REJECTED"
            expense.approved_by = approver_id
            expense.approved_at = now

        if note and note.strip():
            existing_note = expense.note or ""
            expense.note = f"{existing_note}\n[Review Note]: {note.strip()}".strip()

        await session.flush()
        return expense

    async def list_expenses(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        category_id: uuid.UUID | None = None,
        payment_account_id: uuid.UUID | None = None,
        approval_status: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        search: str | None = None,
        page: int = 1,
        page_size: int = 50,
    ) -> list[Expense]:
        return await self.repo.list_expenses(
            session,
            business_id=business_id,
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

    # =========================================================================
    # Financial Reports (Cash Flow Statement & AP Aging)
    # =========================================================================
    async def get_cash_flow_statement(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        start_date: date,
        end_date: date,
        branch_id: uuid.UUID | None = None,
    ) -> CashFlowReportOut:
        start_dt = datetime.combine(start_date, datetime.min.time(), tzinfo=UTC)
        end_dt = datetime.combine(end_date, datetime.max.time(), tzinfo=UTC)

        # Inflows from Confirmed Sales PaymentTenders
        sales_inflow_stmt = (
            select(
                PaymentTender.method,
                func.coalesce(func.sum(PaymentTender.amount), Decimal("0.0000")),
            )
            .where(
                PaymentTender.business_id == business_id,
                PaymentTender.status == "CONFIRMED",
                PaymentTender.received_at >= start_dt,
                PaymentTender.received_at <= end_dt,
            )
            .group_by(PaymentTender.method)
        )
        sales_res = await session.execute(sales_inflow_stmt)
        inflows: dict[str, Decimal] = {}
        total_inflow = Decimal("0.0000")
        for method, amt in sales_res.all():
            inflows[f"Sales: {method}"] = amt
            total_inflow += amt

        # Outflows: Approved Expenses
        exp_outflow_stmt = (
            select(
                Expense.category,
                func.coalesce(func.sum(Expense.amount), Decimal("0.0000")),
            )
            .where(
                Expense.business_id == business_id,
                Expense.approval_status == "APPROVED",
                Expense.created_at >= start_dt,
                Expense.created_at <= end_dt,
            )
            .group_by(Expense.category)
        )
        if branch_id:
            exp_outflow_stmt = exp_outflow_stmt.where(Expense.branch_id == branch_id)
        exp_res = await session.execute(exp_outflow_stmt)
        outflows: dict[str, Decimal] = {}
        total_outflow = Decimal("0.0000")
        for cat, amt in exp_res.all():
            outflows[f"Expense: {cat}"] = amt
            total_outflow += amt

        # Outflows: Purchase Payments
        po_outflow_stmt = (
            select(
                PurchasePayment.method,
                func.coalesce(func.sum(PurchasePayment.amount), Decimal("0.0000")),
            )
            .where(
                PurchasePayment.business_id == business_id,
                PurchasePayment.paid_at >= start_dt,
                PurchasePayment.paid_at <= end_dt,
            )
            .group_by(PurchasePayment.method)
        )
        po_res = await session.execute(po_outflow_stmt)
        for method, amt in po_res.all():
            outflows[f"Supplier Payment: {method}"] = amt
            total_outflow += amt

        net_cash = total_inflow - total_outflow

        return CashFlowReportOut(
            start_date=start_date,
            end_date=end_date,
            total_cash_in=total_inflow,
            total_cash_out=total_outflow,
            net_cash_flow=net_cash,
            inflow_breakdown=inflows,
            outflow_breakdown=outflows,
        )

    async def get_ap_aging_report(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        as_of_date: date | None = None,
    ) -> APAgeingReportOut:
        target_date = as_of_date or datetime.now(UTC).date()
        raw_buckets = await self.repo.get_ap_aging(session, business_id, target_date)
        total_payable = sum((b["total_amount"] for b in raw_buckets), Decimal("0.0000"))
        return APAgeingReportOut(
            as_of_date=target_date,
            total_payable=total_payable,
            buckets=[APAgeingBucket(**b) for b in raw_buckets],
        )
