"""Schemas for physical inventory adjustments, stock movements, and audit ledger."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class StockAdjustmentCreate(BaseModel):
    """Payload to record a manual stock adjustment."""

    product_variant_id: uuid.UUID
    adjustment_type: str = Field(..., description="ADJUSTMENT_UP or ADJUSTMENT_DOWN")
    quantity: Decimal = Field(..., gt=0, description="Quantity to adjust (positive number)")
    reason: str = Field(
        default="STOCKTAKE_CORRECTION",
        description="DAMAGE, SPOILAGE, THEFT, STOCKTAKE_CORRECTION, INTERNAL_USE, EXPIRED, OTHER",
    )
    branch_id: uuid.UUID | None = Field(default=None, description="Branch to adjust; defaults to primary")
    notes: str | None = Field(default=None, max_length=500)


class StockAdjustmentOut(BaseModel):
    """Response detailing the stock adjustment and resulting balance."""

    model_config = ConfigDict(from_attributes=True)

    movement_id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str | None = None
    variant_name: str | None = None
    adjustment_type: str
    quantity_adjusted: Decimal
    previous_quantity: Decimal
    new_quantity: Decimal
    reason: str
    notes: str | None
    created_at: datetime


class StockMovementOut(BaseModel):
    """Immutable stock movement audit trail entry."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str | None = None
    variant_name: str | None = None
    sku: str | None = None
    movement_type: str
    quantity_delta: Decimal
    unit_cost: Decimal
    reference_type: str
    reference_id: uuid.UUID
    created_by: uuid.UUID
    created_at: datetime


class PaginatedStockMovements(BaseModel):
    """Paginated collection of stock ledger movements."""

    items: list[StockMovementOut]
    total: int
    page: int
    page_size: int
    total_pages: int
