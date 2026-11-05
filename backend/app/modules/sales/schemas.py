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
    discount_type: str = Field(
        default="FIXED",
        description="Discount type: FIXED (BDT amount) or PERCENTAGE (e.g. 10.0 for 10%)",
    )
    discount_reason: str | None = Field(
        default=None,
        max_length=100,
        description="Reason or code for item-level discount",
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
    delivery_charge: Decimal = Field(
        default=Decimal("0.0000"),
        ge=0,
        description="Delivery / shipping fee in BDT",
    )
    sale_type: str = Field(
        default="RETAIL",
        description="Sale classification: RETAIL, EXCHANGE, DELIVERY, SALES_ORDER",
    )
    manager_approved_by: uuid.UUID | None = Field(
        default=None,
        description="Manager user ID who authorized high discount or price override",
    )
    exchange_return_id: uuid.UUID | None = Field(
        default=None,
        description="Linked return order ID if checkout is part of an exchange",
    )
    held_cart_id: uuid.UUID | None = Field(
        default=None,
        description="Held cart ID to purge upon successful checkout completion",
    )
    promotion_code: str | None = Field(
        default=None,
        max_length=50,
        description="Optional coupon / promotional code applied",
    )
    price_list_id: uuid.UUID | None = Field(
        default=None,
        description="Applied price list tier ID",
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
    discount_type: str = "FIXED"
    discount_reason: str | None = None
    line_total: Decimal
    imei_device_id: uuid.UUID | None = None


class SaleFinancials(BaseModel):
    """Financial breakdown of a checkout transaction."""

    subtotal: Decimal
    discount_total: Decimal
    tax_total: Decimal
    delivery_charge: Decimal = Decimal("0.0000")
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
    sale_type: str = "RETAIL"
    manager_approved_by: uuid.UUID | None = None
    exchange_return_id: uuid.UUID | None = None
    promotion_id: uuid.UUID | None = None
    promotion_code: str | None = None
    promotion_discount: Decimal = Decimal("0.0000")
    price_list_id: uuid.UUID | None = None
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
    sale_type: str = "RETAIL"
    cashier_id: uuid.UUID
    customer_id: uuid.UUID | None
    customer_name: str | None = None
    subtotal: Decimal
    discount_total: Decimal
    tax_total: Decimal
    delivery_charge: Decimal = Decimal("0.0000")
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


class HeldCartCreate(BaseModel):
    """Payload to park an active cart."""

    branch_id: uuid.UUID | None = Field(default=None)
    customer_id: uuid.UUID | None = Field(default=None)
    customer_name: str | None = Field(default=None, max_length=255)
    label: str | None = Field(default=None, max_length=100)
    items: list[dict] = Field(..., min_length=1, description="List of raw cart items")
    cart_discount: Decimal = Field(default=Decimal("0.0000"), ge=0)
    tax_rate: Decimal = Field(default=Decimal("0.0000"), ge=0)
    delivery_charge: Decimal = Field(default=Decimal("0.0000"), ge=0)
    notes: str | None = Field(default=None, max_length=500)


class HeldCartOut(BaseModel):
    """Serialized held cart record."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    cashier_id: uuid.UUID
    customer_id: uuid.UUID | None
    customer_name: str | None
    label: str | None
    cart_items_json: list[dict] | dict
    cart_discount: Decimal
    tax_rate: Decimal
    delivery_charge: Decimal
    notes: str | None
    created_at: datetime
    updated_at: datetime


class QuotationItemCreate(BaseModel):
    """Line item for creating a quotation."""

    product_variant_id: uuid.UUID
    quantity: Decimal = Field(..., gt=0)
    unit_price: Decimal = Field(..., ge=0)
    discount: Decimal = Field(default=Decimal("0.0000"), ge=0)


class QuotationCreate(BaseModel):
    """Payload to issue a pro-forma price quotation."""

    branch_id: uuid.UUID | None = Field(default=None)
    customer_id: uuid.UUID | None = Field(default=None)
    customer_name: str | None = Field(default=None, max_length=255)
    items: list[QuotationItemCreate] = Field(..., min_length=1)
    cart_discount: Decimal = Field(default=Decimal("0.0000"), ge=0)
    tax_rate: Decimal = Field(default=Decimal("0.0000"), ge=0)
    delivery_charge: Decimal = Field(default=Decimal("0.0000"), ge=0)
    valid_until: datetime | None = Field(default=None)
    notes: str | None = Field(default=None, max_length=500)


class QuotationItemOut(BaseModel):
    """Serialized line item in a quotation."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str = "Item"
    sku: str = ""
    quantity: Decimal
    unit_price: Decimal
    discount: Decimal
    line_total: Decimal


class QuotationOut(BaseModel):
    """Serialized quotation document."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    quotation_no: str
    customer_id: uuid.UUID | None
    customer_name: str | None
    status: str
    subtotal: Decimal
    discount_total: Decimal
    tax_total: Decimal
    delivery_charge: Decimal
    grand_total: Decimal
    valid_until: datetime | None
    notes: str | None
    created_by: uuid.UUID
    created_at: datetime
    converted_sale_id: uuid.UUID | None
    items: list[QuotationItemOut] = []


class QuotationConvertRequest(BaseModel):
    """Request payload to convert an approved quotation directly to an active sale."""

    idempotency_key: str = Field(..., min_length=1, max_length=255)
    payments: list[PaymentTenderCreate] = Field(..., min_length=1)
    notes: str | None = Field(default=None, max_length=500)


class ExchangeItemReturn(BaseModel):
    """Return item specification in an exchange transaction."""

    original_sale_item_id: uuid.UUID
    quantity: Decimal = Field(..., gt=0)
    refund_amount: Decimal | None = Field(default=None, ge=0)
    reason: str | None = Field(default=None, max_length=255)


class ExchangeRequest(BaseModel):
    """Atomic product exchange payload (return + new sale)."""

    idempotency_key: str = Field(..., min_length=1, max_length=255)
    branch_id: uuid.UUID | None = Field(default=None)
    original_sale_id: uuid.UUID
    return_items: list[ExchangeItemReturn] = Field(..., min_length=1)
    new_items: list[CheckoutItem] = Field(..., min_length=1)
    cart_discount: Decimal = Field(default=Decimal("0.0000"), ge=0)
    tax_rate: Decimal = Field(default=Decimal("0.0000"), ge=0)
    delivery_charge: Decimal = Field(default=Decimal("0.0000"), ge=0)
    payments: list[PaymentTenderCreate] = Field(default_factory=list)
    manager_approved_by: uuid.UUID | None = Field(default=None)
    notes: str | None = Field(default=None, max_length=500)


class ExchangeOut(BaseModel):
    """Result of an atomic exchange operation."""

    return_order_id: uuid.UUID
    return_no: str
    return_total: Decimal
    new_sale: SaleOut
    net_difference: Decimal  # positive if customer owed & paid extra, negative if customer got refund


class ManagerOverrideRequest(BaseModel):
    """Manager credential or PIN authorization request."""

    pin: str = Field(..., min_length=4, max_length=64, description="Manager PIN or password")
    username: str | None = Field(default=None, max_length=100)
    action: str = Field(..., description="Action code, e.g. HIGH_DISCOUNT, FLOOR_PRICE, SALE_VOID")
    reason: str = Field(..., min_length=2, max_length=255)


class ManagerOverrideOut(BaseModel):
    """Response authorizing a manager override."""

    approved: bool
    manager_id: uuid.UUID
    manager_name: str
    token: str

