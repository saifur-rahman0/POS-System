"""Pydantic schemas for POS checkout, sale receipts, and payment tenders."""

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, field_validator


class PaymentMethodEnum(StrEnum):
    """Allowed tender payment methods."""

    CASH = "CASH"
    CARD = "CARD"
    BKASH = "BKASH"
    NAGAD = "NAGAD"
    ROCKET = "ROCKET"
    DUE = "DUE"


class CheckoutItem(BaseModel):
    """Line item in a checkout cart."""

    product_variant_id: uuid.UUID
    quantity: Decimal = Field(..., gt=0, description="Quantity to purchase (must be > 0)")
    unit_price: Decimal | None = Field(
        default=None,
        ge=0,
        description="Override unit price; defaults to catalog selling price if omitted",
    )
    discount: Decimal = Field(
        default=Decimal("0.0000"),
        ge=0,
        description="Line-item discount amount in BDT",
    )
    imei_device_id: uuid.UUID | None = Field(
        default=None,
        description="Specific serialized IMEI device ID if applicable",
    )


class PaymentTenderCreate(BaseModel):
    """Payment allocation tender specification."""

    method: str = Field(..., description="CASH, CARD, BKASH, NAGAD, ROCKET, or DUE")
    amount: Decimal = Field(..., gt=0, description="Amount tendered (must be > 0)")
    reference: str | None = Field(default=None, max_length=100, description="Transaction ID/ref")

    @field_validator("method")
    @classmethod
    def validate_method(cls, v: str) -> str:
        upper = v.strip().upper()
        allowed = {m.value for m in PaymentMethodEnum}
        if upper not in allowed:
            raise ValueError(f"Payment method must be one of {allowed}")
        return upper


class CheckoutRequest(BaseModel):
    """Comprehensive POS checkout payload."""

    idempotency_key: str = Field(
        ...,
        min_length=1,
        max_length=255,
        description="Client-generated unique UUID to prevent double submissions",
    )
    branch_id: uuid.UUID | None = Field(
        default=None,
        description="Store branch ID; defaults to user branch or main store if omitted",
    )
    customer_id: uuid.UUID | None = Field(
        default=None,
        description="Registered customer ID; required if due_total > 0",
    )
    items: list[CheckoutItem] = Field(
        ...,
        min_length=1,
        description="List of cart items (at least 1 required)",
    )
    cart_discount: Decimal = Field(
        default=Decimal("0.0000"),
        ge=0,
        description="Overall cart/order discount in BDT",
    )
    tax_rate: Decimal = Field(
        default=Decimal("0.0000"),
        ge=0,
        description="Tax percentage applied to net total (e.g. 5.0 for 5%)",
    )
    payments: list[PaymentTenderCreate] = Field(
        ...,
        min_length=1,
        description="List of payment tenders covering the sale",
    )
    notes: str | None = Field(default=None, max_length=500, description="Receipt notes")


class PaymentTenderOut(BaseModel):
    """Serialized payment tender allocation."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    method: str
    amount: Decimal
    reference: str | None
    status: str
    received_at: datetime


class SaleItemOut(BaseModel):
    """Serialized sale line item."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str
    sku: str
    barcode: str | None
    quantity: Decimal
    unit_price: Decimal
    unit_cost_snapshot: Decimal
    discount: Decimal
    line_total: Decimal
    imei_device_id: uuid.UUID | None = None


class SaleFinancials(BaseModel):
    """Financial breakdown of a checkout transaction."""

    subtotal: Decimal
    discount_total: Decimal
    tax_total: Decimal
    grand_total: Decimal
    paid_total: Decimal
    due_total: Decimal
    change_amount: Decimal


class SaleOut(BaseModel):
    """Complete serialized sales receipt response."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    receipt_no: str
    status: str
    cashier_id: uuid.UUID
    customer_id: uuid.UUID | None
    customer_name: str | None = None
    financials: SaleFinancials
    items: list[SaleItemOut]
    payments: list[PaymentTenderOut]
    notes: str | None
    idempotency_key: str
    created_at: datetime


class SaleSummaryOut(BaseModel):
    """Condensed sale record for lists, tables, and paginated searches."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    receipt_no: str
    status: str
    cashier_id: uuid.UUID
    customer_id: uuid.UUID | None
    customer_name: str | None = None
    subtotal: Decimal
    discount_total: Decimal
    tax_total: Decimal
    grand_total: Decimal
    paid_total: Decimal
    due_total: Decimal
    items_count: int
    created_at: datetime


class PaginatedSales(BaseModel):
    """Paginated collection of sales."""

    items: list[SaleSummaryOut]
    total: int
    page: int
    page_size: int
    total_pages: int


class VoidSaleRequest(BaseModel):
    """Payload to void a completed sale and reverse inventory/payment status."""

    reason: str = Field(..., min_length=2, max_length=500, description="Audit reason for voiding")

