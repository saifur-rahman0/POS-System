"""Pydantic request and response schemas for Register Shifts and Z-Reports."""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict, Field, field_validator

T = TypeVar("T")


class PaginatedResponse(BaseModel, Generic[T]):
    """Standard pagination envelope."""

    items: list[T]
    total: int
    page: int
    limit: int
    pages: int


class ShiftOpenRequest(BaseModel):
    """Payload to open a register shift session."""

    opening_cash: Decimal = Field(
        default=Decimal("0.0000"),
        ge=0,
        description="Initial cash float inside drawer",
    )
    branch_id: uuid.UUID | None = Field(
        default=None,
        description="Branch location ID; defaults to user's assigned active branch",
    )
    device_id: uuid.UUID | None = Field(
        default=None,
        description="POS Register hardware terminal identifier",
    )
    notes: str | None = Field(default=None, max_length=500)


class ShiftCloseRequest(BaseModel):
    """Payload to close an active register shift and perform cash reconciliation."""

    closing_cash_counted: Decimal = Field(
        ...,
        ge=0,
        description="Actual counted physical cash present in drawer at shift close",
    )
    notes: str | None = Field(default=None, max_length=500)
    denominations: dict[str, int] = Field(
        default_factory=dict,
        description="Optional cash notes and coins count breakdown (e.g. {'1000': 5, '500': 4})",
    )


class ShiftCashInOutRequest(BaseModel):
    """Payload for manual cash deposits or drawer disbursements."""

    amount: Decimal = Field(..., gt=0, description="Transaction monetary amount")
    reason: str = Field(..., min_length=2, max_length=100, description="Audit reason for movement")
    notes: str | None = Field(default=None, max_length=500)

    @field_validator("reason")
    @classmethod
    def sanitize_reason(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Reason cannot be blank")
        return cleaned


class CashTransactionOut(BaseModel):
    """Cash movement ledger entry."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    direction: str  # IN, OUT
    amount: Decimal
    reference_type: str
    reference_id: uuid.UUID
    note: str | None
    created_by: uuid.UUID
    created_at: datetime


class ShiftSummaryTotals(BaseModel):
    """Real-time financial summary calculated for a shift."""

    opening_cash: Decimal
    cash_sales: Decimal
    cash_in: Decimal
    cash_refunds: Decimal
    cash_out: Decimal
    expected_cash: Decimal
    actual_cash_counted: Decimal | None = None
    cash_difference: Decimal | None = None
    sales_count: int = 0
    returns_count: int = 0


class ShiftOut(BaseModel):
    """Serialized register shift session details."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    branch_name: str | None = None
    user_id: uuid.UUID
    cashier_name: str | None = None
    device_id: uuid.UUID | None = None
    status: str  # OPEN, CLOSED
    opened_at: datetime
    closed_at: datetime | None = None
    opening_cash: Decimal
    closing_cash_counted: Decimal | None = None
    closing_cash_expected: Decimal | None = None
    cash_difference: Decimal | None = None
    opening_notes: str | None = None
    closing_notes: str | None = None
    denominations: dict[str, int] = Field(default_factory=dict)
    totals: ShiftSummaryTotals | None = None
    created_at: datetime


class PaginatedShifts(BaseModel):
    """Paginated collection of register shifts."""

    items: list[ShiftOut]
    total: int
    page: int
    page_size: int
    total_pages: int


class TenderBreakdown(BaseModel):
    """Tender aggregation by payment method."""

    method: str
    count: int
    total_amount: Decimal


class CashReconciliation(BaseModel):
    """Cash drawer reconciliation section of Z-Report."""

    opening_float: Decimal
    cash_sales: Decimal
    cash_in: Decimal
    cash_refunds: Decimal
    cash_out: Decimal
    expected_in_drawer: Decimal
    actual_counted: Decimal | None
    difference: Decimal | None
    variance_status: str  # BALANCED, SHORTAGE, OVERAGE, PENDING_CLOSE


class SalesPerformanceSummary(BaseModel):
    """Sales performance metrics for Z-Report."""

    gross_sales: Decimal
    discount_total: Decimal
    net_sales: Decimal
    tax_total: Decimal
    total_transactions: int
    completed_sales: int
    voided_sales: int
    returns_count: int
    returns_total: Decimal


class ZReportOut(BaseModel):
    """Comprehensive, authoritative daily Z-Report data structure."""

    shift_id: uuid.UUID
    business_name: str
    branch_name: str
    cashier_username: str
    cashier_full_name: str | None = None
    status: str  # OPEN (X-Report preview), CLOSED (Finalized Z-Report)
    opened_at: datetime
    closed_at: datetime | None
    duration_minutes: int
    cash_reconciliation: CashReconciliation
    tenders_breakdown: list[TenderBreakdown]
    sales_summary: SalesPerformanceSummary
    generated_at: datetime

