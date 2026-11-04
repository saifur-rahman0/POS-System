"""Schemas for inter-branch inventory transfers and cross-branch stock queries."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class TransferItemCreate(BaseModel):
    """Line item requested in a stock transfer."""

    product_variant_id: uuid.UUID
    quantity: Decimal = Field(..., gt=Decimal("0.0000"), description="Quantity to transfer")


class TransferCreate(BaseModel):
    """Payload to initiate an inter-branch stock transfer."""

    source_branch_id: uuid.UUID = Field(..., description="Branch dispatching the inventory")
    destination_branch_id: uuid.UUID = Field(..., description="Branch receiving the inventory")
    items: list[TransferItemCreate] = Field(
        ..., min_length=1, description="Variants and quantities to transfer"
    )
    notes: str | None = Field(default=None, description="Optional dispatch instructions or notes")

    @field_validator("destination_branch_id")
    @classmethod
    def validate_distinct_branches(cls, v: uuid.UUID, info) -> uuid.UUID:
        source_id = info.data.get("source_branch_id")
        if source_id and v == source_id:
            raise ValueError("Destination branch must be different from source branch")
        return v


class StockTransferItemOut(BaseModel):
    """Line item details inside a stock transfer."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    transfer_id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str | None = None
    variant_name: str | None = None
    sku: str | None = None
    quantity: Decimal
    unit_cost: Decimal


class StockTransferOut(BaseModel):
    """Public representation of an inter-branch stock shipment."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    transfer_no: str
    source_branch_id: uuid.UUID
    source_branch_name: str | None = None
    destination_branch_id: uuid.UUID
    destination_branch_name: str | None = None
    status: str  # DRAFT, IN_TRANSIT, RECEIVED, CANCELLED
    created_by: uuid.UUID
    received_by: uuid.UUID | None = None
    notes: str | None = None
    created_at: datetime
    sent_at: datetime | None = None
    received_at: datetime | None = None
    total_items_count: int = 0
    total_quantity: Decimal = Decimal("0.0000")
    items: list[StockTransferItemOut] = []


class CrossBranchStockOut(BaseModel):
    """Current stock level for a product variant at a specific branch."""

    branch_id: uuid.UUID
    branch_name: str
    branch_code: str | None = None
    quantity_on_hand: Decimal
    is_active: bool
