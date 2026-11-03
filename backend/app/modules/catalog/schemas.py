"""Pydantic request and response schemas for Catalog (Categories & Products)."""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict, Field, field_validator

T = TypeVar("T")


# -----------------------------------------------------------------------------
# Common Pagination Envelope
# -----------------------------------------------------------------------------
class PaginatedResponse(BaseModel, Generic[T]):
    """Standard pagination wrapper for list results."""

    items: list[T]
    total: int
    page: int
    limit: int
    pages: int


# -----------------------------------------------------------------------------
# Category Schemas
# -----------------------------------------------------------------------------
class CategoryCreate(BaseModel):
    """Payload to create a new product category."""

    name: str = Field(..., min_length=1, max_length=255, description="Category display name")
    parent_id: uuid.UUID | None = Field(default=None, description="Parent category for hierarchy")
    is_active: bool = Field(default=True, description="Active status")

    @field_validator("name")
    @classmethod
    def sanitize_name(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Category name cannot be empty or whitespace only")
        return cleaned


class CategoryUpdate(BaseModel):
    """Payload to update an existing category."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    parent_id: uuid.UUID | None = Field(default=None)
    is_active: bool | None = Field(default=None)

    @field_validator("name")
    @classmethod
    def sanitize_name(cls, v: str | None) -> str | None:
        if v is not None:
            cleaned = v.strip()
            if not cleaned:
                raise ValueError("Category name cannot be empty or whitespace only")
            return cleaned
        return None


class CategoryOut(BaseModel):
    """Serialized category response."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    parent_id: uuid.UUID | None
    name: str
    is_active: bool


# -----------------------------------------------------------------------------
# Product Variant Schemas
# -----------------------------------------------------------------------------
class ProductVariantOut(BaseModel):
    """Serialized product variant containing barcode, pricing, and specs."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_id: uuid.UUID
    business_id: uuid.UUID
    name: str
    barcode: str | None
    attributes_json: dict
    selling_price: Decimal
    cost_price: Decimal
    track_stock: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime


# -----------------------------------------------------------------------------
# Product Schemas
# -----------------------------------------------------------------------------
class ProductCreate(BaseModel):
    """Payload to create a product and its primary sellable variant."""

    sku: str = Field(..., min_length=1, max_length=100, description="Stock Keeping Unit")
    name: str = Field(..., min_length=1, max_length=255, description="Product title")
    category_id: uuid.UUID | None = Field(default=None)
    brand_id: uuid.UUID | None = Field(default=None)
    product_type: str = Field(
        default="STANDARD",
        description="Product type: STANDARD, SERIALIZED_IMEI, or SERVICE",
    )
    selling_price: Decimal = Field(..., ge=0, description="Retail price in BDT")
    cost_price: Decimal = Field(default=Decimal("0.0000"), ge=0, description="Wholesale cost")
    barcode: str | None = Field(default=None, max_length=100, description="Scannable barcode")
    track_stock: bool = Field(default=True, description="Whether to decrement inventory on sale")
    is_active: bool = Field(default=True)
    attributes_json: dict = Field(default_factory=dict, description="Custom variant attributes")

    @field_validator("sku")
    @classmethod
    def sanitize_sku(cls, v: str) -> str:
        cleaned = v.strip().upper()
        if not cleaned:
            raise ValueError("SKU cannot be empty")
        return cleaned

    @field_validator("barcode")
    @classmethod
    def sanitize_barcode(cls, v: str | None) -> str | None:
        if v is not None:
            cleaned = v.strip()
            return cleaned if cleaned else None
        return None

    @field_validator("product_type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        allowed = {"STANDARD", "SERIALIZED_IMEI", "SERVICE"}
        upper = v.strip().upper()
        if upper not in allowed:
            raise ValueError(f"product_type must be one of {allowed}")
        return upper


class ProductUpdate(BaseModel):
    """Payload to update a product and its primary variant."""

    sku: str | None = Field(default=None, min_length=1, max_length=100)
    name: str | None = Field(default=None, min_length=1, max_length=255)
    category_id: uuid.UUID | None = Field(default=None)
    brand_id: uuid.UUID | None = Field(default=None)
    product_type: str | None = Field(default=None)
    selling_price: Decimal | None = Field(default=None, ge=0)
    cost_price: Decimal | None = Field(default=None, ge=0)
    barcode: str | None = Field(default=None, max_length=100)
    track_stock: bool | None = Field(default=None)
    is_active: bool | None = Field(default=None)
    attributes_json: dict | None = Field(default=None)

    @field_validator("sku")
    @classmethod
    def sanitize_sku(cls, v: str | None) -> str | None:
        if v is not None:
            cleaned = v.strip().upper()
            if not cleaned:
                raise ValueError("SKU cannot be empty")
            return cleaned
        return None

    @field_validator("barcode")
    @classmethod
    def sanitize_barcode(cls, v: str | None) -> str | None:
        if v is not None:
            cleaned = v.strip()
            return cleaned if cleaned else None
        return None


class ProductOut(BaseModel):
    """Serialized product response with primary variant details."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    sku: str
    name: str
    category_id: uuid.UUID | None
    brand_id: uuid.UUID | None
    product_type: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    category_name: str | None = None
    brand_name: str | None = None
    primary_variant: ProductVariantOut | None = None
    variants: list[ProductVariantOut] = []
