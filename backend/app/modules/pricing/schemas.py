"""Pydantic schemas for Track 12 Advanced Product and Pricing."""

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


# -----------------------------------------------------------------------------
# Customer Groups
# -----------------------------------------------------------------------------
class CustomerGroupBase(BaseModel):
    name: str = Field(..., max_length=100)
    description: str | None = None
    is_active: bool = True


class CustomerGroupCreate(CustomerGroupBase):
    pass


class CustomerGroupUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=100)
    description: str | None = None
    is_active: bool | None = None


class CustomerGroupMemberOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    customer_group_id: uuid.UUID
    customer_id: uuid.UUID
    assigned_at: datetime


class CustomerGroupOut(CustomerGroupBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    created_at: datetime
    member_count: int = 0


class CustomerGroupMemberAdd(BaseModel):
    customer_id: uuid.UUID


# -----------------------------------------------------------------------------
# Price Lists & Items
# -----------------------------------------------------------------------------
class PriceListItemBase(BaseModel):
    product_variant_id: uuid.UUID
    min_quantity: Decimal = Field(default=Decimal("1.0000"), gt=0)
    price: Decimal = Field(..., ge=0)
    start_date: date | None = None
    end_date: date | None = None
    is_active: bool = True


class PriceListItemCreate(PriceListItemBase):
    pass


class PriceListItemUpdate(BaseModel):
    min_quantity: Decimal | None = Field(default=None, gt=0)
    price: Decimal | None = Field(default=None, ge=0)
    start_date: date | None = None
    end_date: date | None = None
    is_active: bool | None = None


class PriceListItemOut(PriceListItemBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    price_list_id: uuid.UUID
    created_at: datetime
    variant_name: str | None = None
    variant_sku: str | None = None


class PriceListItemBulkUpsert(BaseModel):
    items: list[PriceListItemCreate]


class PriceListBase(BaseModel):
    name: str = Field(..., max_length=100)
    description: str | None = None
    currency: str = Field(default="BDT", max_length=10)
    is_default: bool = False
    is_active: bool = True
    customer_group_id: uuid.UUID | None = None


class PriceListCreate(PriceListBase):
    pass


class PriceListUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=100)
    description: str | None = None
    currency: str | None = Field(default=None, max_length=10)
    is_default: bool | None = None
    is_active: bool | None = None
    customer_group_id: uuid.UUID | None = None


class PriceListOut(PriceListBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    items: list[PriceListItemOut] = []


# -----------------------------------------------------------------------------
# Branch Price Overrides
# -----------------------------------------------------------------------------
class BranchPriceOverrideBase(BaseModel):
    branch_id: uuid.UUID
    product_variant_id: uuid.UUID
    selling_price: Decimal = Field(..., ge=0)
    is_active: bool = True


class BranchPriceOverrideCreate(BranchPriceOverrideBase):
    pass


class BranchPriceOverrideOut(BranchPriceOverrideBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    variant_name: str | None = None
    variant_sku: str | None = None
    branch_name: str | None = None


# -----------------------------------------------------------------------------
# Product Bundles & Kits
# -----------------------------------------------------------------------------
class ProductBundleItemBase(BaseModel):
    component_variant_id: uuid.UUID
    quantity: Decimal = Field(..., gt=0)
    is_optional: bool = False


class ProductBundleItemCreate(ProductBundleItemBase):
    pass


class ProductBundleItemOut(ProductBundleItemBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    bundle_id: uuid.UUID
    component_name: str | None = None
    component_sku: str | None = None


class ProductBundleBase(BaseModel):
    name: str = Field(..., max_length=255)
    bundle_price: Decimal | None = Field(default=None, ge=0)
    is_kit: bool = False
    is_active: bool = True


class ProductBundleCreate(ProductBundleBase):
    product_id: uuid.UUID
    items: list[ProductBundleItemCreate] = []


class ProductBundleUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=255)
    bundle_price: Decimal | None = Field(default=None, ge=0)
    is_kit: bool | None = None
    is_active: bool | None = None


class ProductBundleOut(ProductBundleBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    product_id: uuid.UUID
    created_at: datetime
    items: list[ProductBundleItemOut] = []


# -----------------------------------------------------------------------------
# Promotions & Coupons
# -----------------------------------------------------------------------------
class PromotionBase(BaseModel):
    name: str = Field(..., max_length=255)
    code: str | None = Field(default=None, max_length=50)
    discount_type: Literal["PERCENTAGE", "FIXED_AMOUNT"]
    discount_value: Decimal = Field(..., gt=0)
    min_spend: Decimal = Field(default=Decimal("0.0000"), ge=0)
    max_discount_cap: Decimal | None = Field(default=None, ge=0)
    usage_limit: int | None = Field(default=None, gt=0)
    valid_from: date
    valid_until: date
    applies_to: Literal["ALL", "CATEGORY", "PRODUCT"] = "ALL"
    scope_ids: list[str] = Field(default_factory=list)
    is_active: bool = True


class PromotionCreate(PromotionBase):
    pass


class PromotionUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=255)
    code: str | None = Field(default=None, max_length=50)
    discount_type: Literal["PERCENTAGE", "FIXED_AMOUNT"] | None = None
    discount_value: Decimal | None = Field(default=None, gt=0)
    min_spend: Decimal | None = Field(default=None, ge=0)
    max_discount_cap: Decimal | None = Field(default=None, ge=0)
    usage_limit: int | None = Field(default=None, gt=0)
    valid_from: date | None = None
    valid_until: date | None = None
    applies_to: Literal["ALL", "CATEGORY", "PRODUCT"] | None = None
    scope_ids: list[str] | None = None
    is_active: bool | None = None


class PromotionOut(PromotionBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    times_used: int
    created_at: datetime
    updated_at: datetime


class PromotionUsageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    promotion_id: uuid.UUID
    sale_id: uuid.UUID
    discount_applied: Decimal
    used_at: datetime


class CartItemValidationIn(BaseModel):
    variant_id: uuid.UUID
    quantity: Decimal = Decimal("1.0000")
    category_id: uuid.UUID | None = None


class PromotionValidateIn(BaseModel):
    code: str
    branch_id: uuid.UUID
    customer_id: uuid.UUID | None = None
    subtotal: Decimal
    items: list[CartItemValidationIn] = []


class PromotionValidateOut(BaseModel):
    is_valid: bool
    promotion_id: uuid.UUID | None = None
    discount_type: str | None = None
    discount_value: Decimal | None = None
    calculated_discount: Decimal = Decimal("0.0000")
    message: str


# -----------------------------------------------------------------------------
# Price Resolution
# -----------------------------------------------------------------------------
class PriceResolveItemIn(BaseModel):
    variant_id: uuid.UUID
    quantity: Decimal = Decimal("1.0000")


class PriceResolveIn(BaseModel):
    branch_id: uuid.UUID
    customer_id: uuid.UUID | None = None
    items: list[PriceResolveItemIn]
    sale_date: date | None = None


class PriceResolveItemOut(BaseModel):
    variant_id: uuid.UUID
    unit_price: Decimal
    source: str  # "BRANCH_OVERRIDE" | "PRICE_LIST" | "BASE_PRICE"
    price_list_id: uuid.UUID | None = None
    price_list_name: str | None = None


class PriceResolveOut(BaseModel):
    results: list[PriceResolveItemOut]


# -----------------------------------------------------------------------------
# Bulk Import Result
# -----------------------------------------------------------------------------
class BulkImportError(BaseModel):
    row: int
    field: str | None = None
    message: str


class BulkImportResult(BaseModel):
    total_rows: int
    created_count: int
    updated_count: int
    error_count: int
    errors: list[BulkImportError] = []
