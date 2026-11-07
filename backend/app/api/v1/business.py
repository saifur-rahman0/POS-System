"""Business tenant settings and profile API endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.business.schemas import BusinessOut, BusinessUpdate
from app.modules.business.service import BranchService
from app.shared.auth import CurrentUser, get_current_user, require_permission

router = APIRouter(prefix="/business", tags=["Business & Store Profile"])
branch_service = BranchService()


@router.get(
    "",
    response_model=BusinessOut,
    summary="Get tenant business profile and settings",
)
async def get_business_profile(
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(get_current_user),
) -> BusinessOut:
    """Fetch profile settings for the authenticated business tenant."""
    return await branch_service.get_business(session=db, business_id=user.business_id)


@router.patch(
    "",
    response_model=BusinessOut,
    summary="Update business profile settings",
)
async def update_business_profile(
    payload: BusinessUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> BusinessOut:
    """Update tenant business name, legal name, currency, or timezone."""
    return await branch_service.update_business(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )
