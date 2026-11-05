"""Database repository for Expense records, Categories, Financial Accounts, and Transfers."""

import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.expenses.models import (
    AccountTransfer,
    Expense,
    ExpenseCategory,
    FinancialAccount,
    RecurringExpense,
)
from app.modules.purchasing.models import Purchase


class ExpensesRepository:
    """Handles persistence, locking, sequential numbering, and reporting for expenses and accounts."""

    # -------------------------------------------------------------------------
    # Expense Categories
    # -------------------------------------------------------------------------
    async def create_category(
        self,
        session: AsyncSession,
        category: ExpenseCategory,
    ) -> ExpenseCategory:
        session.add(category)
        await session.flush()
        return category

    async def get_category(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        category_id: uuid.UUID,
    ) -> ExpenseCategory | None:
        stmt = select(ExpenseCategory).where(
            ExpenseCategory.business_id == business_id,
            ExpenseCategory.id == category_id,
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_category_by_code(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        code: str,
    ) -> ExpenseCategory | None:
        stmt = select(ExpenseCategory).where(
            ExpenseCategory.business_id == business_id,
            ExpenseCategory.code == code.strip().upper(),
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def list_categories(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[ExpenseCategory]:
        stmt = (
            select(ExpenseCategory)
            .where(ExpenseCategory.business_id == business_id)
            .order_by(ExpenseCategory.name.asc())
        )
        if is_active is not None:
            stmt = stmt.where(ExpenseCategory.is_active == is_active)
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_category_monthly_spent(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        category_id: uuid.UUID,
        year: int,
        month: int,
    ) -> Decimal:
        """Sum of approved expenses for a category in a given calendar month."""
        start_date = datetime(year, month, 1, tzinfo=UTC)
        if month == 12:
            end_date = datetime(year + 1, 1, 1, tzinfo=UTC)
        else:
            end_date = datetime(year, month + 1, 1, tzinfo=UTC)

        stmt = select(func.coalesce(func.sum(Expense.amount), Decimal("0.0000"))).where(
            Expense.business_id == business_id,
            Expense.category_id == category_id,
            Expense.approval_status == "APPROVED",
            Expense.created_at >= start_date,
            Expense.created_at < end_date,
        )
        result = await session.execute(stmt)
        return result.scalar() or Decimal("0.0000")

    # -------------------------------------------------------------------------
    # Financial Accounts
    # -------------------------------------------------------------------------
    async def create_account(
        self,
        session: AsyncSession,
        account: FinancialAccount,
    ) -> FinancialAccount:
        session.add(account)
        await session.flush()
        return account

    async def get_account(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        account_id: uuid.UUID,
        for_update: bool = False,
    ) -> FinancialAccount | None:
        stmt = select(FinancialAccount).where(
            FinancialAccount.business_id == business_id,
            FinancialAccount.id == account_id,
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_accounts_for_transfer(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        from_account_id: uuid.UUID,
        to_account_id: uuid.UUID,
    ) -> tuple[FinancialAccount | None, FinancialAccount | None]:
        """Locks both accounts in deterministic UUID order to prevent deadlocks under concurrency."""
        first_id, second_id = (
            (from_account_id, to_account_id)
            if str(from_account_id) < str(to_account_id)
            else (to_account_id, from_account_id)
        )

        acc1 = await self.get_account(session, business_id, first_id, for_update=True)
        acc2 = await self.get_account(session, business_id, second_id, for_update=True)

        if from_account_id == first_id:
            return acc1, acc2
        return acc2, acc1

    async def list_accounts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        is_active: bool | None = None,
    ) -> list[FinancialAccount]:
        stmt = (
            select(FinancialAccount)
            .where(FinancialAccount.business_id == business_id)
            .order_by(FinancialAccount.account_name.asc())
        )
        if branch_id is not None:
            # Return accounts matching branch OR global accounts with branch_id IS NULL
            stmt = stmt.where(
                (FinancialAccount.branch_id == branch_id)
                | (FinancialAccount.branch_id.is_(None))
            )
        if is_active is not None:
            stmt = stmt.where(FinancialAccount.is_active == is_active)
        result = await session.execute(stmt)
        return list(result.scalars().all())

    # -------------------------------------------------------------------------
    # Account Transfers
    # -------------------------------------------------------------------------
    async def create_transfer(
        self,
        session: AsyncSession,
        transfer: AccountTransfer,
    ) -> AccountTransfer:
        session.add(transfer)
        await session.flush()
        return transfer

    async def list_transfers(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        account_id: uuid.UUID | None = None,
        limit: int = 50,
    ) -> list[AccountTransfer]:
        stmt = (
            select(AccountTransfer)
            .options(
                selectinload(AccountTransfer.from_account),
                selectinload(AccountTransfer.to_account),
            )
            .where(AccountTransfer.business_id == business_id)
            .order_by(AccountTransfer.transfer_date.desc())
            .limit(limit)
        )
        if account_id:
            stmt = stmt.where(
                (AccountTransfer.from_account_id == account_id)
                | (AccountTransfer.to_account_id == account_id)
            )
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def generate_transfer_reference(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        now: datetime | None = None,
    ) -> str:
        """Format: TRF-YYYYMMDD-SEQ:04d (e.g. TRF-20261105-0001)."""
        current_date = now or datetime.now(UTC)
        date_str = current_date.strftime("%Y%m%d")
        prefix = f"TRF-{date_str}-"

        stmt = (
            select(AccountTransfer.reference_no)
            .where(
                AccountTransfer.business_id == business_id,
                AccountTransfer.reference_no.like(f"{prefix}%"),
            )
            .order_by(AccountTransfer.reference_no.desc())
            .limit(1)
        )
        result = await session.execute(stmt)
        latest = result.scalar_one_or_none()

        seq = 1
        if latest and latest.startswith(prefix):
            try:
                seq = int(latest[len(prefix) :]) + 1
            except ValueError:
                seq = 1
        return f"{prefix}{seq:04d}"

    # -------------------------------------------------------------------------
    # Recurring Expenses
    # -------------------------------------------------------------------------
    async def create_recurring_expense(
        self,
        session: AsyncSession,
        recurring: RecurringExpense,
    ) -> RecurringExpense:
        session.add(recurring)
        await session.flush()
        return recurring

    async def get_recurring_expense(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        recurring_id: uuid.UUID,
    ) -> RecurringExpense | None:
        stmt = (
            select(RecurringExpense)
            .options(
                selectinload(RecurringExpense.category),
                selectinload(RecurringExpense.payment_account),
            )
            .where(
                RecurringExpense.business_id == business_id,
                RecurringExpense.id == recurring_id,
            )
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def list_recurring_expenses(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        is_active: bool | None = None,
    ) -> list[RecurringExpense]:
        stmt = (
            select(RecurringExpense)
            .options(
                selectinload(RecurringExpense.category),
                selectinload(RecurringExpense.payment_account),
            )
            .where(RecurringExpense.business_id == business_id)
            .order_by(RecurringExpense.next_due_date.asc())
        )
        if branch_id:
            stmt = stmt.where(
                (RecurringExpense.branch_id == branch_id)
                | (RecurringExpense.branch_id.is_(None))
            )
        if is_active is not None:
            stmt = stmt.where(RecurringExpense.is_active == is_active)
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_due_recurring_expenses(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        as_of_date: date,
    ) -> list[RecurringExpense]:
        stmt = (
            select(RecurringExpense)
            .options(
                selectinload(RecurringExpense.category),
                selectinload(RecurringExpense.payment_account),
            )
            .where(
                RecurringExpense.business_id == business_id,
                RecurringExpense.is_active.is_(True),
                RecurringExpense.next_due_date <= as_of_date,
            )
            .order_by(RecurringExpense.next_due_date.asc())
        )
        result = await session.execute(stmt)
        return list(result.scalars().all())

    # -------------------------------------------------------------------------
    # Expense Vouchers
    # -------------------------------------------------------------------------
    async def generate_voucher_number(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch: Branch,
        now: datetime | None = None,
    ) -> str:
        """Format: EXP-YYYYMMDD-BRANCH_CODE-SEQ:04d (e.g. EXP-20261105-MAIN-0001)."""
        current_date = now or datetime.now(UTC)
        date_str = current_date.strftime("%Y%m%d")
        branch_code = (branch.code or "MAIN").strip().upper()
        prefix = f"EXP-{date_str}-{branch_code}-"

        stmt = (
            select(Expense.voucher_no)
            .where(
                Expense.business_id == business_id,
                Expense.branch_id == branch.id,
                Expense.voucher_no.like(f"{prefix}%"),
            )
            .order_by(Expense.voucher_no.desc())
            .limit(1)
        )
        result = await session.execute(stmt)
        latest = result.scalar_one_or_none()

        seq = 1
        if latest and latest.startswith(prefix):
            try:
                seq = int(latest[len(prefix) :]) + 1
            except ValueError:
                seq = 1
        return f"{prefix}{seq:04d}"

    async def create_expense(
        self,
        session: AsyncSession,
        expense: Expense,
    ) -> Expense:
        session.add(expense)
        await session.flush()
        return expense

    async def get_expense(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        expense_id: uuid.UUID,
        for_update: bool = False,
    ) -> Expense | None:
        stmt = (
            select(Expense)
            .options(
                selectinload(Expense.expense_category),
                selectinload(Expense.payment_account),
            )
            .where(
                Expense.business_id == business_id,
                Expense.id == expense_id,
            )
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await session.execute(stmt)
        return result.scalars().first()

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
        stmt = (
            select(Expense)
            .options(
                selectinload(Expense.expense_category),
                selectinload(Expense.payment_account),
            )
            .where(Expense.business_id == business_id)
        )
        if branch_id:
            stmt = stmt.where(Expense.branch_id == branch_id)
        if category_id:
            stmt = stmt.where(Expense.category_id == category_id)
        if payment_account_id:
            stmt = stmt.where(Expense.payment_account_id == payment_account_id)
        if approval_status:
            stmt = stmt.where(Expense.approval_status == approval_status.strip().upper())
        if start_date:
            stmt = stmt.where(Expense.created_at >= start_date)
        if end_date:
            stmt = stmt.where(Expense.created_at <= end_date)
        if search and search.strip():
            term = f"%{search.strip()}%"
            stmt = stmt.where(
                (Expense.voucher_no.ilike(term))
                | (Expense.payee.ilike(term))
                | (Expense.category.ilike(term))
            )

        stmt = stmt.order_by(Expense.created_at.desc())
        offset = (page - 1) * page_size
        stmt = stmt.offset(offset).limit(page_size)
        result = await session.execute(stmt)
        return list(result.scalars().all())

    # -------------------------------------------------------------------------
    # AP Aging Breakdown
    # -------------------------------------------------------------------------
    async def get_ap_aging(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        as_of_date: date,
    ) -> list[dict]:
        """Calculates Accounts Payable aging buckets from pending/partial purchases.

        Buckets:
        - 0-30 Days
        - 31-60 Days
        - 61-90 Days
        - 90+ Days
        """
        # Find all purchases with remaining payable (total - paid_total > 0)
        stmt = select(Purchase).where(
            Purchase.business_id == business_id,
            Purchase.status.in_(["ORDERED", "RECEIVED"]),
            (Purchase.total - Purchase.paid_total) > 0,
        )
        result = await session.execute(stmt)
        purchases = result.scalars().all()

        buckets: dict[str, dict[str, Decimal | int]] = {
            "0-30 Days": {"total": Decimal("0.0000"), "count": 0},
            "31-60 Days": {"total": Decimal("0.0000"), "count": 0},
            "61-90 Days": {"total": Decimal("0.0000"), "count": 0},
            "90+ Days": {"total": Decimal("0.0000"), "count": 0},
        }

        for p in purchases:
            due: Decimal = p.total - p.paid_total
            p_date = p.created_at.date() if isinstance(p.created_at, datetime) else p.created_at
            age_days = (as_of_date - p_date).days

            if age_days <= 30:
                buckets["0-30 Days"]["total"] = Decimal(buckets["0-30 Days"]["total"]) + due
                buckets["0-30 Days"]["count"] = int(buckets["0-30 Days"]["count"]) + 1
            elif age_days <= 60:
                buckets["31-60 Days"]["total"] = Decimal(buckets["31-60 Days"]["total"]) + due
                buckets["31-60 Days"]["count"] = int(buckets["31-60 Days"]["count"]) + 1
            elif age_days <= 90:
                buckets["61-90 Days"]["total"] = Decimal(buckets["61-90 Days"]["total"]) + due
                buckets["61-90 Days"]["count"] = int(buckets["61-90 Days"]["count"]) + 1
            else:
                buckets["90+ Days"]["total"] = Decimal(buckets["90+ Days"]["total"]) + due
                buckets["90+ Days"]["count"] = int(buckets["90+ Days"]["count"]) + 1

        return [
            {
                "bucket_name": k,
                "total_amount": Decimal(v["total"]),
                "count": int(v["count"]),
            }
            for k, v in buckets.items()
        ]
