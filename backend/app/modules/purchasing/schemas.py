"""Pydantic schemas for Suppliers, Purchase Orders, and Receiving."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class SupplierCreate(BaseModel):
    """Schema for registering a vendor/supplier."""

    name: str = Field(
        ..., min_length=2, max_length=255, description="Supplier company or trade name"
    )
    contact_person: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=50)
    email: str | None = Field(default=None, max_length=255)
    address: str | None = Field(default=None)


class SupplierUpdate(BaseModel):
    """Schema for updating supplier details."""

    name: str | None = Field(default=None, min_length=2, max_length=255)
    contact_person: str | None = Field(default=None, max_length=255)
    phone: str | None = Field(default=None, max_length=50)
    email: str | None = Field(default=None, max_length=255)
    address: str | None = Field(default=None)
    is_active: bool | None = Field(default=None)


class SupplierOut(BaseModel):
    """Supplier response schema with operational metrics."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    name: str
    contact_person: str | None
    phone: str | None
    email: str | None
    address: str | None
    is_active: bool
    total_purchases_count: int = 0
    total_purchases_amount: Decimal = Decimal("0.0000")
    unpaid_balance: Decimal = Decimal("0.0000")
    created_at: datetime


class PaginatedSuppliers(BaseModel):
    """Paginated collection of suppliers."""

    items: list[SupplierOut]
    total: int
    page: int
    page_size: int
    total_pages: int


class PurchaseItemCreate(BaseModel):
    """Line item in a purchase order."""

    product_variant_id: uuid.UUID
    quantity: Decimal = Field(..., gt=0, description="Quantity ordered (must be > 0)")
    unit_cost: Decimal = Field(..., ge=0, description="Purchase cost price per unit")


class PurchaseItemOut(BaseModel):
    """Purchase line item response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str | None = None
    variant_name: str | None = None
    sku: str | None = None
    quantity: Decimal
    unit_cost: Decimal
    line_total: Decimal


class PurchasePaymentCreate(BaseModel):
    """Record payment against a supplier invoice."""

    amount: Decimal = Field(..., gt=0, description="Payment amount (must be > 0)")
    method: str = Field(default="CASH", description="CASH, BANK, BKASH, NAGAD, CHEQUE")
    reference: str | None = Field(default=None, max_length=100)


class PurchasePaymentOut(BaseModel):
    """Purchase payment record."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    purchase_id: uuid.UUID
    business_id: uuid.UUID
    amount: Decimal
    method: str
    reference: str | None
    paid_at: datetime


class PurchaseCreate(BaseModel):
    """Create purchase order / vendor invoice."""

    supplier_id: uuid.UUID
    branch_id: uuid.UUID | None = Field(
        default=None, description="Branch to receive stock; defaults to primary"
    )
    reference_no: str | None = Field(
        default=None, max_length=100, description="Invoice/Bill # or auto-generated"
    )
    items: list[PurchaseItemCreate] = Field(
        ..., min_length=1, description="List of items to purchase"
    )
    discount: Decimal = Field(default=Decimal("0.0000"), ge=0, description="Invoice level discount")
    notes: str | None = Field(default=None)


class PurchaseOut(BaseModel):
    """Authoritative purchase order header response."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    supplier_id: uuid.UUID
    supplier_name: str | None = None
    reference_no: str
    status: str  # ORDERED, RECEIVED, CANCELLED
    subtotal: Decimal
    discount: Decimal
    total: Decimal
    paid_total: Decimal
    due_balance: Decimal = Decimal("0.0000")
    notes: str | None
    created_by: uuid.UUID
    created_at: datetime
    items: list[PurchaseItemOut] = []
    payments: list[PurchasePaymentOut] = []


class PaginatedPurchases(BaseModel):
    """Paginated collection of purchase orders."""

    items: list[PurchaseOut]
    total: int
    page: int
    page_size: int
    total_pages: int
