"""Pydantic v2 schemas for expense records, categories, financial accounts, and transfers."""

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


# ============================================================================
# Expense Categories
# ============================================================================
class ExpenseCategoryBase(BaseModel):
    name: Annotated[str, Field(min_length=1, max_length=100)]
    code: Annotated[str, Field(min_length=1, max_length=50)]
    description: str | None = None
    monthly_budget: Annotated[Decimal, Field(default=Decimal("0.0000"), ge=0)]
    is_active: bool = True


class ExpenseCategoryCreate(ExpenseCategoryBase):
    pass


class ExpenseCategoryUpdate(BaseModel):
    name: Annotated[str, Field(min_length=1, max_length=100)] | None = None
    code: Annotated[str, Field(min_length=1, max_length=50)] | None = None
    description: str | None = None
    monthly_budget: Annotated[Decimal, Field(ge=0)] | None = None
    is_active: bool | None = None


class ExpenseCategoryOut(ExpenseCategoryBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    current_month_spent: Decimal = Decimal("0.0000")
    created_at: datetime


# ============================================================================
# Financial Accounts
# ============================================================================
FinancialAccountType = Literal[
    "CASH_DRAWER",
    "SAFE",
    "BANK",
    "MOBILE_WALLET",
    "PETTY_CASH",
]


class FinancialAccountBase(BaseModel):
    branch_id: uuid.UUID | None = None
    account_name: Annotated[str, Field(min_length=1, max_length=100)]
    account_type: FinancialAccountType
    account_number: Annotated[str, Field(max_length=100)] | None = None
    bank_name: Annotated[str, Field(max_length=100)] | None = None
    opening_balance: Annotated[Decimal, Field(default=Decimal("0.0000"), ge=0)]


class FinancialAccountCreate(FinancialAccountBase):
    pass


class FinancialAccountUpdate(BaseModel):
    account_name: Annotated[str, Field(min_length=1, max_length=100)] | None = None
    account_number: Annotated[str, Field(max_length=100)] | None = None
    bank_name: Annotated[str, Field(max_length=100)] | None = None
    is_active: bool | None = None


class FinancialAccountOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID | None
    account_name: str
    account_type: str
    account_number: str | None
    bank_name: str | None
    opening_balance: Decimal
    current_balance: Decimal
    is_active: bool
    created_at: datetime


# ============================================================================
# Account Transfers
# ============================================================================
class AccountTransferCreate(BaseModel):
    from_account_id: uuid.UUID
    to_account_id: uuid.UUID
    amount: Annotated[Decimal, Field(gt=0)]
    reference_no: Annotated[str, Field(max_length=100)] | None = None
    note: str | None = None


class AccountTransferOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    from_account_id: uuid.UUID
    to_account_id: uuid.UUID
    amount: Decimal
    reference_no: str | None
    note: str | None
    transfer_date: datetime
    created_by: uuid.UUID
    created_at: datetime
    from_account_name: str | None = None
    to_account_name: str | None = None


# ============================================================================
# Recurring Expenses
# ============================================================================
RecurringFrequency = Literal["DAILY", "WEEKLY", "MONTHLY", "QUARTERLY", "ANNUAL"]


class RecurringExpenseBase(BaseModel):
    branch_id: uuid.UUID | None = None
    category_id: uuid.UUID
    payment_account_id: uuid.UUID | None = None
    title: Annotated[str, Field(min_length=1, max_length=150)]
    amount: Annotated[Decimal, Field(gt=0)]
    frequency: RecurringFrequency
    next_due_date: date
    auto_post: bool = False
    is_active: bool = True


class RecurringExpenseCreate(RecurringExpenseBase):
    pass


class RecurringExpenseUpdate(BaseModel):
    category_id: uuid.UUID | None = None
    payment_account_id: uuid.UUID | None = None
    title: Annotated[str, Field(min_length=1, max_length=150)] | None = None
    amount: Annotated[Decimal, Field(gt=0)] | None = None
    frequency: RecurringFrequency | None = None
    next_due_date: date | None = None
    auto_post: bool | None = None
    is_active: bool | None = None


class RecurringExpenseOut(RecurringExpenseBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    last_generated_at: datetime | None
    created_at: datetime
    category_name: str | None = None
    payment_account_name: str | None = None


# ============================================================================
# Expense Records
# ============================================================================
ExpenseApprovalStatus = Literal["APPROVED", "PENDING_APPROVAL", "REJECTED"]


class ExpenseCreate(BaseModel):
    branch_id: uuid.UUID | None = None
    category: str | None = None
    category_id: uuid.UUID | None = None
    amount: Annotated[Decimal, Field(gt=0)]
    note: str | None = None
    payment_account_id: uuid.UUID | None = None
    payment_method: str = "CASH"
    payee: Annotated[str, Field(max_length=200)] | None = None
    receipt_reference: Annotated[str, Field(max_length=100)] | None = None
    tax_deductible: bool = True


class ExpenseApprovalRequest(BaseModel):
    action: Literal["APPROVED", "REJECTED"]
    note: str | None = None


class ExpenseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    voucher_no: str | None
    category: str
    category_id: uuid.UUID | None
    payment_account_id: uuid.UUID | None
    payment_method: str
    payee: str | None
    receipt_reference: str | None
    tax_deductible: bool
    amount: Decimal
    note: str | None
    approval_status: str
    approved_by: uuid.UUID | None
    approved_at: datetime | None
    created_by: uuid.UUID
    created_at: datetime
    category_name: str | None = None
    payment_account_name: str | None = None


# ============================================================================
# Financial Reports (Cash Flow & AP Aging)
# ============================================================================
class CashFlowReportOut(BaseModel):
    start_date: date
    end_date: date
    total_cash_in: Decimal
    total_cash_out: Decimal
    net_cash_flow: Decimal
    inflow_breakdown: dict[str, Decimal] = Field(default_factory=dict)
    outflow_breakdown: dict[str, Decimal] = Field(default_factory=dict)


class APAgeingBucket(BaseModel):
    bucket_name: str  # e.g., "0-30 Days", "31-60 Days", "61-90 Days", "90+ Days"
    total_amount: Decimal
    count: int


class APAgeingReportOut(BaseModel):
    as_of_date: date
    total_payable: Decimal
    buckets: list[APAgeingBucket] = Field(default_factory=list)

