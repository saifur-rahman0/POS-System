"""Operating expense records, categories, financial accounts, and transfer models."""

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    ForeignKey,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ExpenseCategory(Base):
    """Categorization for operating expenses (e.g. Utilities, Rent, Petty Cash, Salaries)."""

    __tablename__ = "expense_categories"
    __table_args__ = (
        UniqueConstraint("business_id", "code", name="uq_expense_category_biz_code"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    monthly_budget: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        default=Decimal("0.0000"),
        server_default="0.0000",
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    expenses: Mapped[list["Expense"]] = relationship(
        "Expense",
        back_populates="expense_category",
        lazy="selectin",
    )


class FinancialAccount(Base):
    """Liquid financial accounts (Store Safe, Cash Drawer, Commercial Bank, Mobile Wallet)."""

    __tablename__ = "financial_accounts"
    __table_args__ = (
        CheckConstraint(
            "account_type IN ('CASH_DRAWER', 'SAFE', 'BANK', 'MOBILE_WALLET', 'PETTY_CASH')",
            name="chk_financial_account_type",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    branch_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    account_name: Mapped[str] = mapped_column(String(100), nullable=False)
    account_type: Mapped[str] = mapped_column(String(32), nullable=False)
    account_number: Mapped[str | None] = mapped_column(String(100), nullable=True)
    bank_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    opening_balance: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        default=Decimal("0.0000"),
        server_default="0.0000",
        nullable=False,
    )
    current_balance: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        default=Decimal("0.0000"),
        server_default="0.0000",
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )


class AccountTransfer(Base):
    """Audit ledger tracking funds moved between financial accounts (e.g. Safe deposit to Bank)."""

    __tablename__ = "account_transfers"
    __table_args__ = (
        CheckConstraint("amount > 0", name="chk_transfer_amount_positive"),
        CheckConstraint("from_account_id <> to_account_id", name="chk_transfer_diff_accounts"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    from_account_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("financial_accounts.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    to_account_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("financial_accounts.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    reference_no: Mapped[str | None] = mapped_column(String(100), nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    transfer_date: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    from_account: Mapped[FinancialAccount] = relationship(
        "FinancialAccount",
        foreign_keys=[from_account_id],
        lazy="joined",
    )
    to_account: Mapped[FinancialAccount] = relationship(
        "FinancialAccount",
        foreign_keys=[to_account_id],
        lazy="joined",
    )


class RecurringExpense(Base):
    """Recurring operational charges (e.g. Monthly Rent, Internet Bill, Software Subscription)."""

    __tablename__ = "recurring_expenses"
    __table_args__ = (
        CheckConstraint("amount > 0", name="chk_recurring_amount_positive"),
        CheckConstraint(
            "frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUAL')",
            name="chk_recurring_frequency",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    branch_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    category_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("expense_categories.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    payment_account_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("financial_accounts.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    frequency: Mapped[str] = mapped_column(String(32), nullable=False)
    next_due_date: Mapped[date] = mapped_column(Date, nullable=False)
    last_generated_at: Mapped[datetime | None] = mapped_column(nullable=True)
    auto_post: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    category: Mapped[ExpenseCategory] = relationship("ExpenseCategory", lazy="joined")
    payment_account: Mapped[FinancialAccount | None] = relationship("FinancialAccount", lazy="joined")


class Expense(Base):
    """Operational store expense recording with approval hierarchy and payment accounts."""

    __tablename__ = "expenses"
    __table_args__ = (
        CheckConstraint("amount > 0", name="chk_expense_amount_positive"),
        CheckConstraint(
            "approval_status IN ('APPROVED', 'PENDING_APPROVAL', 'REJECTED')",
            name="chk_expense_approval_status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    branch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    voucher_no: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        index=True,
    )
    category: Mapped[str] = mapped_column(String(100), nullable=False)
    category_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("expense_categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    payment_account_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("financial_accounts.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    payment_method: Mapped[str] = mapped_column(
        String(32),
        default="CASH",
        server_default="CASH",
        nullable=False,
    )
    payee: Mapped[str | None] = mapped_column(String(200), nullable=True)
    receipt_reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    tax_deductible: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default="true",
        nullable=False,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    approval_status: Mapped[str] = mapped_column(
        String(32),
        default="APPROVED",
        server_default="APPROVED",
        nullable=False,
    )
    approved_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    approved_at: Mapped[datetime | None] = mapped_column(nullable=True)
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )

    # Relationships
    expense_category: Mapped[ExpenseCategory | None] = relationship(
        "ExpenseCategory",
        back_populates="expenses",
        lazy="joined",
    )
    payment_account: Mapped[FinancialAccount | None] = relationship(
        "FinancialAccount",
        lazy="joined",
    )


class CashTransaction(Base):
    """Authoritative cash drawer audit transaction (cash in/out, drops, floats)."""

    __tablename__ = "cash_transactions"
    __table_args__ = (CheckConstraint("amount > 0", name="chk_cash_txn_amount_positive"),)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    branch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    account_id: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )  # e.g., 'MAIN_CASH_DRAWER', 'PETTY_CASH'
    direction: Mapped[str] = mapped_column(String(10), nullable=False)  # IN, OUT
    amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    reference_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )  # SALE, EXPENSE, PURCHASE, CASH_DROP, FLOAT_IN, TRANSFER
    reference_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
    )
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )
