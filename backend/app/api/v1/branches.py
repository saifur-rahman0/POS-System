"""Branch and store location endpoints."""

import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.business.schemas import BranchCreate, BranchDetailOut, BranchOut, BranchUpdate
from app.modules.business.service import BranchService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/branches", tags=["Branches & Multi-Store"])
branch_service = BranchService()


@router.get(
    "",
    response_model=list[BranchOut],
    summary="List store branches",
)
async def list_branches(
    is_active: bool | None = Query(default=None, description="Filter by active status"),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[BranchOut]:
    """Retrieve all store branch locations for current business."""
    return await branch_service.list_branches(
        session=db,
        business_id=user.business_id,
        is_active=is_active,
    )


@router.post(
    "",
    response_model=BranchOut,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new store branch",
)
async def create_branch(
    payload: BranchCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> BranchOut:
    """Create a new store branch with unique code and name."""
    return await branch_service.create_branch(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


@router.get(
    "/{branch_id}",
    response_model=BranchDetailOut,
    summary="Get branch detail and metrics",
)
async def get_branch(
    branch_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> BranchDetailOut:
    """Fetch branch detail including inventory on hand and active shift status."""
    return await branch_service.get_branch_detail(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
    )


@router.put(
    "/{branch_id}",
    response_model=BranchOut,
    summary="Update branch profile",
)
async def update_branch(
    branch_id: uuid.UUID,
    payload: BranchUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> BranchOut:
    """Update branch name, code, contact information, or status."""
    return await branch_service.update_branch(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
        payload=payload,
    )
