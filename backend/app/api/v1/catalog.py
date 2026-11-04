"""API endpoints for Product Categories and Products catalog management."""

import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.catalog.schemas import (
    CategoryCreate,
    CategoryOut,
    CategoryUpdate,
    PaginatedResponse,
    ProductCreate,
    ProductOut,
    ProductUpdate,
)
from app.modules.catalog.service import CatalogService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(tags=["Catalog"])
catalog_service = CatalogService()


# -----------------------------------------------------------------------------
# Categories
# -----------------------------------------------------------------------------
@router.get(
    "/categories",
    response_model=list[CategoryOut],
    summary="List product categories",
)
async def list_categories(
    is_active: bool | None = Query(default=None, description="Filter by active status"),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[CategoryOut]:
    """Retrieve all product categories within the tenant business scope."""
    return await catalog_service.list_categories(
        session=db,
        business_id=user.business_id,
        is_active=is_active,
    )


@router.post(
    "/categories",
    response_model=CategoryOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create product category",
)
async def create_category(
    payload: CategoryCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> CategoryOut:
    """Create a new product category."""
    return await catalog_service.create_category(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


@router.put(
    "/categories/{category_id}",
    response_model=CategoryOut,
    summary="Update product category",
)
async def update_category(
    category_id: uuid.UUID,
    payload: CategoryUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> CategoryOut:
    """Update name, hierarchy, or active status of a category."""
    return await catalog_service.update_category(
        session=db,
        business_id=user.business_id,
        category_id=category_id,
        payload=payload,
    )


# -----------------------------------------------------------------------------
# Products
# -----------------------------------------------------------------------------
@router.get(
    "/products",
    response_model=PaginatedResponse[ProductOut],
    summary="List products with search and pagination",
)
async def list_products(
    search: str | None = Query(
        default=None,
        description="Search substring in product name, SKU, or variant barcode",
    ),
    category_id: uuid.UUID | None = Query(default=None, description="Filter by category ID"),
    is_active: bool | None = Query(default=None, description="Filter by active/archived status"),
    page: int = Query(default=1, ge=1, description="Page number"),
    limit: int = Query(default=20, ge=1, le=100, description="Items per page"),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> PaginatedResponse[ProductOut]:
    """Search and paginate products in tenant catalog."""
    return await catalog_service.list_products(
        session=db,
        business_id=user.business_id,
        search=search,
        category_id=category_id,
        is_active=is_active,
        page=page,
        limit=limit,
    )


@router.post(
    "/products",
    response_model=ProductOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create product",
)
async def create_product(
    payload: ProductCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> ProductOut:
    """Create a new product with its default sellable variant."""
    return await catalog_service.create_product(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


@router.get(
    "/products/barcode/{barcode}",
    response_model=ProductOut,
    summary="Lookup product by barcode",
)
async def get_product_by_barcode(
    barcode: str,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> ProductOut:
    """Instant lookup by barcode for POS scanner hardware."""
    return await catalog_service.get_product_by_barcode(
        session=db,
        business_id=user.business_id,
        barcode=barcode,
    )


@router.get(
    "/products/{product_id}",
    response_model=ProductOut,
    summary="Get product details",
)
async def get_product(
    product_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> ProductOut:
    """Retrieve full product details including variants."""
    return await catalog_service.get_product(
        session=db,
        business_id=user.business_id,
        product_id=product_id,
    )


@router.put(
    "/products/{product_id}",
    response_model=ProductOut,
    summary="Update product",
)
async def update_product(
    product_id: uuid.UUID,
    payload: ProductUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> ProductOut:
    """Update product information, pricing, barcode, or active status."""
    return await catalog_service.update_product(
        session=db,
        business_id=user.business_id,
        product_id=product_id,
        payload=payload,
    )
