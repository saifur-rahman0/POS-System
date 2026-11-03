"""Schemas for customer sales returns, refunds, and restocked items."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class ReturnItemCreate(BaseModel):
    """Specification of an individual sale line item to be returned."""

    original_sale_item_id: uuid.UUID
    quantity: Decimal = Field(..., gt=0, description="Quantity to return (must be > 0)")
    refund_amount: Decimal | None = Field(
        default=None,
        ge=0,
        description="Optional custom refund amount; defaults to pro-rata item total",
    )
    restock: bool = Field(
        default=True,
        description="Whether to restock item into branch inventory (SALE_RETURN ledger)",
    )
    restock_status: str = Field(
        default="RESTOCKED",
        description="RESTOCKED, DEFECTIVE, or SCRAPPED",
    )


class ReturnCreateRequest(BaseModel):
    """Payload to initiate a partial or full customer sales return."""

    items: list[ReturnItemCreate] = Field(
        ...,
        min_length=1,
        description="Line items being returned (at least 1 required)",
    )
    reason: str | None = Field(default=None, max_length=500, description="Return explanation")
    refund_method: str = Field(
        default="CASH",
        description="Payment method used to refund the customer (CASH, CARD, STORE_CREDIT)",
    )


class ReturnItemOut(BaseModel):
    """Serialized return line item."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    return_id: uuid.UUID
    original_sale_item_id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str | None = None
    sku: str | None = None
    quantity: Decimal
    refund_amount: Decimal
    restock_status: str


class ReturnOut(BaseModel):
    """Complete return receipt response."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    original_sale_id: uuid.UUID
    return_no: str
    status: str
    refund_total: Decimal
    reason: str | None
    created_by: uuid.UUID
    created_at: datetime
    items: list[ReturnItemOut]


class SaleReturnableItem(BaseModel):
    """Inspection helper indicating remaining returnable quantity for a sale line item."""

    model_config = ConfigDict(from_attributes=True)

    sale_item_id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str
    sku: str
    quantity_sold: Decimal
    quantity_returned: Decimal
    quantity_returnable: Decimal
    unit_price: Decimal
    line_total: Decimal
