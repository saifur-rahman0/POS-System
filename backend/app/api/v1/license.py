"""Offline Cryptographic Licensing API endpoints."""

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.licensing.schemas import (
    LicenseActivationRequest,
    LicenseGenerateRequest,
    LicenseGenerateResponse,
    LicenseStatusOut,
)
from app.modules.licensing.service import LicensingService
from app.shared.auth import CurrentUser, get_current_user, require_permission

router = APIRouter(prefix="/license", tags=["Offline Licensing & Hardware Entitlements"])
licensing_service = LicensingService()


@router.get(
    "/status",
    response_model=LicenseStatusOut,
    summary="Get offline license status, entitlements, and remaining days",
)
async def get_license_status(
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(get_current_user),
) -> LicenseStatusOut:
    """Returns local license validity, active plan, device limits, and feature entitlements."""
    return await licensing_service.get_license_status(
        session=db,
        business_id=user.business_id,
    )


@router.post(
    "/activate",
    response_model=LicenseStatusOut,
    status_code=status.HTTP_200_OK,
    summary="Activate offline cryptographic license token",
)
async def activate_license(
    payload: LicenseActivationRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> LicenseStatusOut:
    """Verifies cryptographic signature offline and applies license entitlements without internet access."""
    return await licensing_service.activate_license(
        session=db,
        business_id=user.business_id,
        license_token=payload.license_token,
    )


@router.post(
    "/generate",
    response_model=LicenseGenerateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Generate a signed offline license certificate (Admin/Vendor Utility)",
)
async def generate_license(
    payload: LicenseGenerateRequest,
    user: CurrentUser = Depends(require_permission("admin")),
) -> LicenseGenerateResponse:
    """Issues an asymmetric cryptographic token for customer distribution."""
    return licensing_service.generate_signed_token(payload)

