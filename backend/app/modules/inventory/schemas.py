"""Schemas for physical inventory adjustments, stock movements, and audit ledger."""

import uuid
from datetime import date, datetime
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
    branch_id: uuid.UUID | None = Field(
        default=None, description="Branch to adjust; defaults to primary"
    )
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
    batch_id: uuid.UUID | None = None
    created_by: uuid.UUID
    created_at: datetime


class PaginatedStockMovements(BaseModel):
    """Paginated collection of stock ledger movements."""

    items: list[StockMovementOut]
    total: int
    page: int
    page_size: int
    total_pages: int


# ==============================================================================
# 1. INVENTORY BATCH & EXPIRY SCHEMAS
# ==============================================================================


class InventoryBatchCreate(BaseModel):
    """Inward creation payload for an inventory batch / lot."""

    branch_id: uuid.UUID | None = None
    product_variant_id: uuid.UUID
    batch_number: str = Field(..., min_length=1, max_length=100)
    manufacturing_date: date | None = None
    expiry_date: date | None = None
    quantity_received: Decimal = Field(..., gt=0)
    cost_price: Decimal = Field(default=Decimal("0.0000"), ge=0)
    supplier_id: uuid.UUID | None = None


class InventoryBatchOut(BaseModel):
    """Details of a stock batch."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str | None = None
    variant_name: str | None = None
    sku: str | None = None
    batch_number: str
    manufacturing_date: date | None = None
    expiry_date: date | None = None
    quantity_received: Decimal
    quantity_on_hand: Decimal
    cost_price: Decimal
    supplier_id: uuid.UUID | None = None
    supplier_name: str | None = None
    is_active: bool
    days_to_expiry: int | None = None
    expiry_status: str | None = None  # EXPIRED, EXPIRING_7_DAYS, EXPIRING_30_DAYS, EXPIRING_60_DAYS, GOOD
    created_at: datetime


class ExpiryAlertOut(BaseModel):
    """Actionable alert item for expiring or expired inventory lots."""

    model_config = ConfigDict(from_attributes=True)

    batch_id: uuid.UUID
    batch_number: str
    product_variant_id: uuid.UUID
    product_name: str
    variant_name: str
    branch_id: uuid.UUID
    branch_name: str | None = None
    quantity_on_hand: Decimal
    expiry_date: date
    days_remaining: int
    urgency: str  # CRITICAL_EXPIRED, HIGH_7_DAYS, MEDIUM_30_DAYS, LOW_60_DAYS


# ==============================================================================
# 2. DAMAGED STOCK & WRITE-OFF SCHEMAS
# ==============================================================================


class DamagedStockCreate(BaseModel):
    """Write-off voucher creation for damaged, expired, or spoiled stock."""

    branch_id: uuid.UUID | None = None
    product_variant_id: uuid.UUID
    batch_id: uuid.UUID | None = None
    quantity: Decimal = Field(..., gt=0)
    unit_cost: Decimal | None = Field(default=None, ge=0)
    reason: str = Field(
        ...,
        description="EXPIRED, BROKEN, TRANSIT_DAMAGE, WATER_DAMAGE, THEFT, OTHER",
    )
    disposal_method: str = Field(
        ...,
        description="DESTROYED, RETURNED_TO_VENDOR, SOLD_AT_DISCOUNT, WRITTEN_OFF",
    )
    notes: str | None = None


class DamagedStockOut(BaseModel):
    """Damaged stock write-off record."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str | None = None
    variant_name: str | None = None
    batch_id: uuid.UUID | None = None
    batch_number: str | None = None
    voucher_no: str
    quantity: Decimal
    unit_cost: Decimal
    total_loss: Decimal
    reason: str
    disposal_method: str
    notes: str | None = None
    reported_by: uuid.UUID
    reporter_name: str | None = None
    created_at: datetime


# ==============================================================================
# 3. STOCK RESERVATION SCHEMAS
# ==============================================================================


class StockReservationCreate(BaseModel):
    """Creation payload to hold stock for quotations, layaways, or sales orders."""

    branch_id: uuid.UUID | None = None
    product_variant_id: uuid.UUID
    batch_id: uuid.UUID | None = None
    quantity: Decimal = Field(..., gt=0)
    reference_type: str = Field(
        ...,
        description="QUOTATION, LAYAWAY, SALES_ORDER",
    )
    reference_id: uuid.UUID
    duration_hours: int = Field(default=24, ge=1, le=720)


class StockReservationOut(BaseModel):
    """Stock reservation allocation record."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str | None = None
    variant_name: str | None = None
    batch_id: uuid.UUID | None = None
    quantity: Decimal
    reference_type: str
    reference_id: uuid.UUID
    status: str  # ACTIVE, FULFILLED, RELEASED, EXPIRED
    reserved_until: datetime
    created_by: uuid.UUID
    created_at: datetime


class AvailableStockOut(BaseModel):
    """Stock availability check taking into account active reservations."""

    product_variant_id: uuid.UUID
    branch_id: uuid.UUID
    quantity_on_hand: Decimal
    quantity_reserved: Decimal
    available_quantity: Decimal


# ==============================================================================
# 4. PHYSICAL STOCK COUNT (AUDIT) SCHEMAS
# ==============================================================================


class StockCountLineCreate(BaseModel):
    """Individual line item for a physical stock audit."""

    product_variant_id: uuid.UUID
    counted_qty: Decimal = Field(..., ge=0)
    discrepancy_reason: str | None = None


class StockCountCreate(BaseModel):
    """Session initiation payload for physical inventory count."""

    branch_id: uuid.UUID | None = None
    notes: str | None = None
    lines: list[StockCountLineCreate] = []


class StockCountScanRequest(BaseModel):
    """Barcode scan increment request within a live count session."""

    barcode: str
    increment_qty: Decimal = Field(default=Decimal("1.0000"), gt=0)


class StockCountLineOut(BaseModel):
    """Line item with variance analysis."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    stock_count_id: uuid.UUID
    product_variant_id: uuid.UUID
    product_name: str | None = None
    variant_name: str | None = None
    barcode: str | None = None
    expected_qty: Decimal
    counted_qty: Decimal
    variance: Decimal
    discrepancy_reason: str | None = None


class StockCountOut(BaseModel):
    """Stock count session with lines and progress."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    branch_id: uuid.UUID
    branch_name: str | None = None
    status: str  # DRAFT, IN_PROGRESS, COMPLETED, CANCELLED
    notes: str | None = None
    created_by: uuid.UUID
    approved_by: uuid.UUID | None = None
    created_at: datetime
    completed_at: datetime | None = None
    lines: list[StockCountLineOut] = []


# ==============================================================================
# 5. REORDER SUGGESTIONS & THRESHOLDS SCHEMAS
# ==============================================================================


class ReorderSuggestionOut(BaseModel):
    """Replenishment suggestion item."""

    product_variant_id: uuid.UUID
    product_name: str
    variant_name: str
    sku: str | None = None
    barcode: str | None = None
    branch_id: uuid.UUID
    branch_name: str | None = None
    quantity_on_hand: Decimal
    active_reservations: Decimal
    available_quantity: Decimal
    min_stock_level: Decimal
    suggested_reorder_qty: Decimal
    estimated_unit_cost: Decimal
    estimated_total_cost: Decimal
    primary_supplier_id: uuid.UUID | None = None
    primary_supplier_name: str | None = None


class VariantThresholdUpdate(BaseModel):
    """Update inventory thresholds on a variant."""

    min_stock_level: Decimal = Field(..., ge=0)
    reorder_quantity: Decimal = Field(..., ge=0)
    has_batch_tracking: bool | None = None


# ==============================================================================
# 6. INVENTORY VALUATION SCHEMAS
# ==============================================================================


class CategoryValuationOut(BaseModel):
    """Valuation aggregation per category."""

    category_id: uuid.UUID | None = None
    category_name: str
    item_count: int
    total_units: Decimal
    fifo_valuation: Decimal
    wac_valuation: Decimal
    retail_valuation: Decimal


class InventoryValuationReportOut(BaseModel):
    """Multi-method inventory valuation summary report."""

    business_id: uuid.UUID
    branch_id: uuid.UUID | None = None
    branch_name: str | None = None
    as_of_date: datetime
    total_variants: int
    total_quantity_on_hand: Decimal
    total_fifo_valuation: Decimal
    total_wac_valuation: Decimal
    total_retail_valuation: Decimal
    categories: list[CategoryValuationOut]

