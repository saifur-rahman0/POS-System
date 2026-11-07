"""Schemas for Business and Branch domain."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class BranchCreate(BaseModel):
    """Payload to create a new branch or store location."""

    name: str = Field(..., min_length=1, max_length=255, description="Branch name")
    code: str | None = Field(
        default=None, max_length=50, description="Unique store code (e.g. DHK-01)"
    )
    address: str | None = Field(default=None, description="Physical location address")
    phone: str | None = Field(default=None, max_length=50, description="Branch phone number")
    is_active: bool = Field(default=True, description="Whether the branch is currently active")

    @field_validator("name")
    @classmethod
    def sanitize_name(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Branch name cannot be empty")
        return cleaned

    @field_validator("code")
    @classmethod
    def sanitize_code(cls, v: str | None) -> str | None:
        if v is not None:
            cleaned = v.strip().upper()
            return cleaned if cleaned else None
        return None


class BranchUpdate(BaseModel):
    """Payload to update an existing branch location."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    code: str | None = Field(default=None, max_length=50)
    address: str | None = Field(default=None)
    phone: str | None = Field(default=None, max_length=50)
    is_active: bool | None = Field(default=None)

    @field_validator("name")
    @classmethod
    def sanitize_name(cls, v: str | None) -> str | None:
        if v is not None:
            cleaned = v.strip()
            if not cleaned:
                raise ValueError("Branch name cannot be empty")
            return cleaned
        return None

    @field_validator("code")
    @classmethod
    def sanitize_code(cls, v: str | None) -> str | None:
        if v is not None:
            cleaned = v.strip().upper()
            return cleaned if cleaned else None
        return None


class BranchOut(BaseModel):
    """Public representation of a branch store."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    name: str
    code: str | None = None
    address: str | None = None
    phone: str | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime


class BranchDetailOut(BranchOut):
    """Detailed branch info with inventory and operational KPIs."""

    total_variants_in_stock: int = 0
    total_stock_quantity: Decimal = Decimal("0.0000")
    has_active_shift: bool = False


class BusinessOut(BaseModel):
    """Authoritative tenant business info."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    legal_name: str | None = None
    timezone: str
    currency: str
    is_active: bool
    created_at: datetime
    updated_at: datetime


class BusinessUpdate(BaseModel):
    """Payload to update tenant business info."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    legal_name: str | None = Field(default=None, max_length=255)
    timezone: str | None = Field(default=None, max_length=64)
    currency: str | None = Field(default=None, max_length=10)

