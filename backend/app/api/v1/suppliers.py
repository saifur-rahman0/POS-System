"""Supplier and vendor management API endpoints."""

import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.purchasing.schemas import (
    PaginatedSuppliers,
    SupplierCreate,
    SupplierOut,
    SupplierUpdate,
)
from app.modules.purchasing.service import PurchasingService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/suppliers", tags=["Suppliers & Purchasing"])
purchasing_service = PurchasingService()


@router.get(
    "",
    response_model=PaginatedSuppliers,
    summary="List and search vendors/suppliers",
)
async def list_suppliers(
    search: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> PaginatedSuppliers:
    """Fetch paginated suppliers for the tenant."""
    return await purchasing_service.list_suppliers(
        session=db,
        business_id=user.business_id,
        search=search,
        is_active=is_active,
        page=page,
        page_size=page_size,
    )


@router.post(
    "",
    response_model=SupplierOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new vendor/supplier",
)
async def create_supplier(
    payload: SupplierCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> SupplierOut:
    """Register a new supplier with unique name enforcement."""
    return await purchasing_service.create_supplier(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


@router.get(
    "/{supplier_id}",
    response_model=SupplierOut,
    summary="Get supplier details with purchase balance",
)
async def get_supplier(
    supplier_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> SupplierOut:
    """Retrieve single vendor profile."""
    return await purchasing_service.get_supplier(
        session=db,
        business_id=user.business_id,
        supplier_id=supplier_id,
    )


@router.put(
    "/{supplier_id}",
    response_model=SupplierOut,
    summary="Update supplier details",
)
async def update_supplier(
    supplier_id: uuid.UUID,
    payload: SupplierUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> SupplierOut:
    """Update supplier contact details and active status."""
    return await purchasing_service.update_supplier(
        session=db,
        business_id=user.business_id,
        supplier_id=supplier_id,
        payload=payload,
    )

