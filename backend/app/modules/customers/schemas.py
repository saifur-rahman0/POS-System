"""Schemas for customer management, store credit, and due collection."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class CustomerBase(BaseModel):
    """Base customer fields."""

    name: str = Field(..., min_length=1, max_length=255, description="Full customer name")
    phone: str | None = Field(default=None, max_length=50, description="Contact phone number")
    email: str | None = Field(default=None, max_length=255, description="Contact email address")
    address: str | None = Field(default=None, max_length=500, description="Postal address")
    credit_limit: Decimal = Field(
        default=Decimal("0.0000"),
        ge=0,
        description="Maximum permissible outstanding due credit in BDT",
    )
    is_active: bool = Field(default=True, description="Active status")

    @field_validator("phone")
    @classmethod
    def clean_phone(cls, v: str | None) -> str | None:
        if v is None:
            return None
        stripped = v.strip()
        return stripped if stripped else None


class CustomerCreate(CustomerBase):
    """Payload to create a new store customer."""

    pass


class CustomerUpdate(BaseModel):
    """Payload to modify an existing customer profile."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    phone: str | None = Field(default=None, max_length=50)
    email: str | None = Field(default=None, max_length=255)
    address: str | None = Field(default=None, max_length=500)
    credit_limit: Decimal | None = Field(default=None, ge=0)
    is_active: bool | None = Field(default=None)

    @field_validator("phone")
    @classmethod
    def clean_phone(cls, v: str | None) -> str | None:
        if v is None:
            return None
        stripped = v.strip()
        return stripped if stripped else None


class CustomerOut(CustomerBase):
    """Serialized customer profile with real-time financial balances."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    due_balance: Decimal = Decimal("0.0000")
    available_credit: Decimal = Decimal("0.0000")
    total_sales_count: int = 0
    total_spent: Decimal = Decimal("0.0000")
    created_at: datetime


class PaginatedCustomers(BaseModel):
    """Paginated collection of customers."""

    items: list[CustomerOut]
    total: int
    page: int
    page_size: int
    total_pages: int
    total_outstanding_dues: Decimal = Decimal("0.0000")


class CustomerDuePaymentRequest(BaseModel):
    """Payload to collect repayment against customer's outstanding balance."""

    amount: Decimal = Field(..., gt=0, description="Repayment amount tendered (must be > 0)")
    payment_method: str = Field(
        default="CASH",
        description="Tender method: CASH, CARD, BKASH, NAGAD, ROCKET",
    )
    sale_id: uuid.UUID | None = Field(
        default=None,
        description="Optional specific sale receipt to allocate payment to; if omitted, FIFO applies",
    )
    reference: str | None = Field(default=None, max_length=100, description="Transaction ID/ref")
    notes: str | None = Field(default=None, max_length=500, description="Payment receipt notes")

    @field_validator("payment_method")
    @classmethod
    def validate_method(cls, v: str) -> str:
        upper = v.strip().upper()
        allowed = {"CASH", "CARD", "BKASH", "NAGAD", "ROCKET"}
        if upper not in allowed:
            raise ValueError(f"Payment method must be one of {allowed}")
        return upper


class AllocatedSalePayment(BaseModel):
    """Details of a single sale receipt that received a portion of the due repayment."""

    sale_id: uuid.UUID
    receipt_no: str
    allocated_amount: Decimal
    remaining_sale_due: Decimal


class CustomerDuePaymentOut(BaseModel):
    """Receipt summary of a successfully collected customer due repayment."""

    customer_id: uuid.UUID
    customer_name: str
    amount_paid: Decimal
    previous_due: Decimal
    remaining_due: Decimal
    payment_method: str
    reference: str | None
    allocated_sales: list[AllocatedSalePayment]
    created_at: datetime


class CustomerLedgerEntry(BaseModel):
    """Chronological ledger entry for customer credit statements."""

    date: datetime
    entry_type: str  # SALE_DUE, REPAYMENT
    receipt_no: str
    description: str
    debit: Decimal = Decimal("0.0000")  # increases due
    credit: Decimal = Decimal("0.0000")  # decreases due
    balance: Decimal = Decimal("0.0000")

