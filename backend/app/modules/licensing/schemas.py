"""Schemas for Offline Cryptographic Licensing."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class LicenseActivationRequest(BaseModel):
    """Payload to activate an offline cryptographic license."""

    license_token: str = Field(..., description="Base64 encoded signed license certificate token")


class LicenseStatusOut(BaseModel):
    """Current offline license state and entitlement limits."""

    business_id: uuid.UUID
    license_key_id: str
    status: str  # ACTIVE, EXPIRING_SOON, EXPIRED, TRIAL
    plan_name: str
    device_limit: int
    features: list[str] = []
    days_remaining: int | None = None
    is_perpetual: bool = False
    activated_at: datetime | None = None
    expires_at: datetime | None = None
    message: str


class LicenseGenerateRequest(BaseModel):
    """Payload to generate a signed license (for vendor/licensing authority)."""

    business_id: uuid.UUID
    plan_name: str = "PRO"
    device_limit: int = 5
    days_valid: int | None = 365  # None for perpetual lifetime
    features: list[str] = [
        "MULTI_STORE",
        "ESC_POS_PRINTING",
        "BARCODE_SCANNER",
        "REPORTS_ANALYTICS",
        "DATA_BACKUP",
    ]


class LicenseGenerateResponse(BaseModel):
    """Signed license certificate ready for offline client activation."""

    license_key_id: str
    license_token: str
    plan_name: str
    device_limit: int
    expires_at: datetime | None = None

