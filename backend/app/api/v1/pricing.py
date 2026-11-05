"""API endpoints for Track 12 Advanced Product and Pricing."""

import uuid

from fastapi import APIRouter, Depends, Query, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.pricing.schemas import (
    BranchPriceOverrideCreate,
    BranchPriceOverrideOut,
    BulkImportResult,
    CustomerGroupCreate,
    CustomerGroupMemberAdd,
    CustomerGroupMemberOut,
    CustomerGroupOut,
    CustomerGroupUpdate,
    PriceListCreate,
    PriceListItemCreate,
    PriceListItemOut,
    PriceListItemUpdate,
    PriceListOut,
    PriceResolveIn,
    PriceResolveOut,
    ProductBundleCreate,
    ProductBundleItemCreate,
    ProductBundleItemOut,
    ProductBundleOut,
    PromotionCreate,
    PromotionOut,
    PromotionValidateIn,
    PromotionValidateOut,
)
from app.modules.pricing.service import PricingService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/pricing", tags=["Pricing & Products"])
pricing_service = PricingService()


# -----------------------------------------------------------------------------
# Customer Groups
# -----------------------------------------------------------------------------
@router.get(
    "/customer-groups",
    response_model=list[CustomerGroupOut],
    summary="List customer groups",
)
async def list_customer_groups(
    is_active: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:read")),
) -> list[CustomerGroupOut]:
    return await pricing_service.list_customer_groups(
        session=db,
        business_id=user.business_id,
        is_active=is_active,
    )


@router.post(
    "/customer-groups",
    response_model=CustomerGroupOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create customer group",
)
async def create_customer_group(
    payload: CustomerGroupCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> CustomerGroupOut:
    return await pricing_service.create_customer_group(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


@router.put(
    "/customer-groups/{group_id}",
    response_model=CustomerGroupOut,
    summary="Update customer group",
)
async def update_customer_group(
    group_id: uuid.UUID,
    payload: CustomerGroupUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> CustomerGroupOut:
    return await pricing_service.update_customer_group(
        session=db,
        business_id=user.business_id,
        group_id=group_id,
        payload=payload,
    )


@router.post(
    "/customer-groups/{group_id}/members",
    response_model=CustomerGroupMemberOut,
    status_code=status.HTTP_201_CREATED,
    summary="Assign customer to group",
)
async def add_customer_to_group(
    group_id: uuid.UUID,
    payload: CustomerGroupMemberAdd,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> CustomerGroupMemberOut:
    return await pricing_service.add_customer_to_group(
        session=db,
        business_id=user.business_id,
        group_id=group_id,
        customer_id=payload.customer_id,
    )


@router.delete(
    "/customer-groups/{group_id}/members/{customer_id}",
    summary="Remove customer from group",
)
async def remove_customer_from_group(
    group_id: uuid.UUID,
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> dict[str, str]:
    return await pricing_service.remove_customer_from_group(
        session=db,
        business_id=user.business_id,
        group_id=group_id,
        customer_id=customer_id,
    )


# -----------------------------------------------------------------------------
# Price Lists & Items
# -----------------------------------------------------------------------------
@router.get(
    "/price-lists",
    response_model=list[PriceListOut],
    summary="List all price lists",
)
async def list_price_lists(
    is_active: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:read")),
) -> list[PriceListOut]:
    return await pricing_service.list_price_lists(
        session=db,
        business_id=user.business_id,
        is_active=is_active,
    )


@router.post(
    "/price-lists",
    response_model=PriceListOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new price list",
)
async def create_price_list(
    payload: PriceListCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> PriceListOut:
    return await pricing_service.create_price_list(
        session=db,
        business_id=user.business_id,
        name=payload.name,
        description=payload.description,
        currency=payload.currency,
        is_default=payload.is_default,
        is_active=payload.is_active,
        customer_group_id=payload.customer_group_id,
    )


@router.get(
    "/price-lists/{price_list_id}",
    response_model=PriceListOut,
    summary="Get price list details with items",
)
async def get_price_list(
    price_list_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:read")),
) -> PriceListOut:
    return await pricing_service.get_price_list(
        session=db,
        business_id=user.business_id,
        price_list_id=price_list_id,
    )


@router.post(
    "/price-lists/{price_list_id}/items",
    response_model=PriceListItemOut,
    status_code=status.HTTP_201_CREATED,
    summary="Add or update item in price list",
)
async def add_or_update_price_list_item(
    price_list_id: uuid.UUID,
    payload: PriceListItemCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> PriceListItemOut:
    return await pricing_service.add_or_update_price_list_item(
        session=db,
        business_id=user.business_id,
        price_list_id=price_list_id,
        payload=payload,
    )


@router.put(
    "/price-lists/{price_list_id}/items/{item_id}",
    response_model=PriceListItemOut,
    summary="Update price list item",
)
async def update_price_list_item(
    price_list_id: uuid.UUID,
    item_id: uuid.UUID,
    payload: PriceListItemUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> PriceListItemOut:
    return await pricing_service.update_price_list_item(
        session=db,
        business_id=user.business_id,
        price_list_id=price_list_id,
        item_id=item_id,
        payload=payload,
    )


@router.delete(
    "/price-lists/{price_list_id}/items/{item_id}",
    summary="Delete price list item",
)
async def delete_price_list_item(
    price_list_id: uuid.UUID,
    item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> dict[str, str]:
    return await pricing_service.delete_price_list_item(
        session=db,
        business_id=user.business_id,
        price_list_id=price_list_id,
        item_id=item_id,
    )


# -----------------------------------------------------------------------------
# Branch Price Overrides
# -----------------------------------------------------------------------------
@router.get(
    "/branch-overrides",
    response_model=list[BranchPriceOverrideOut],
    summary="List branch price overrides",
)
async def list_branch_overrides(
    branch_id: uuid.UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:read")),
) -> list[BranchPriceOverrideOut]:
    return await pricing_service.list_branch_overrides(
        session=db,
        business_id=user.business_id,
        branch_id=branch_id,
    )


@router.post(
    "/branch-overrides",
    response_model=BranchPriceOverrideOut,
    summary="Create or update branch price override",
)
async def upsert_branch_override(
    payload: BranchPriceOverrideCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> BranchPriceOverrideOut:
    return await pricing_service.upsert_branch_override(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


@router.delete(
    "/branch-overrides/{override_id}",
    summary="Delete branch price override",
)
async def delete_branch_override(
    override_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> dict[str, str]:
    return await pricing_service.delete_branch_override(
        session=db,
        business_id=user.business_id,
        override_id=override_id,
    )


# -----------------------------------------------------------------------------
# Dynamic Price Resolution
# -----------------------------------------------------------------------------
@router.post(
    "/resolve",
    response_model=PriceResolveOut,
    summary="Resolve effective price for items given branch and customer context",
)
async def resolve_prices(
    payload: PriceResolveIn,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:read")),
) -> PriceResolveOut:
    return await pricing_service.resolve_prices(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


# -----------------------------------------------------------------------------
# Product Bundles & Kits
# -----------------------------------------------------------------------------
@router.get(
    "/bundles",
    response_model=list[ProductBundleOut],
    summary="List product bundles and kits",
)
async def list_bundles(
    is_active: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> list[ProductBundleOut]:
    return await pricing_service.list_bundles(
        session=db,
        business_id=user.business_id,
        is_active=is_active,
    )


@router.post(
    "/bundles",
    response_model=ProductBundleOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create product bundle or kit",
)
async def create_bundle(
    payload: ProductBundleCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> ProductBundleOut:
    return await pricing_service.create_bundle(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


@router.post(
    "/bundles/{bundle_id}/components",
    response_model=ProductBundleItemOut,
    status_code=status.HTTP_201_CREATED,
    summary="Add component to bundle",
)
async def add_bundle_component(
    bundle_id: uuid.UUID,
    payload: ProductBundleItemCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> ProductBundleItemOut:
    return await pricing_service.add_bundle_component(
        session=db,
        business_id=user.business_id,
        bundle_id=bundle_id,
        payload=payload,
    )


@router.delete(
    "/bundles/{bundle_id}/components/{component_item_id}",
    summary="Remove component from bundle",
)
async def delete_bundle_component(
    bundle_id: uuid.UUID,
    component_item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> dict[str, str]:
    return await pricing_service.delete_bundle_component(
        session=db,
        business_id=user.business_id,
        bundle_id=bundle_id,
        component_item_id=component_item_id,
    )


# -----------------------------------------------------------------------------
# Promotions & Coupons
# -----------------------------------------------------------------------------
@router.get(
    "/promotions",
    response_model=list[PromotionOut],
    summary="List promotions and coupons",
)
async def list_promotions(
    is_active: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:read")),
) -> list[PromotionOut]:
    return await pricing_service.list_promotions(
        session=db,
        business_id=user.business_id,
        is_active=is_active,
    )


@router.post(
    "/promotions",
    response_model=PromotionOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create promotion or coupon code",
)
async def create_promotion(
    payload: PromotionCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("pricing:write")),
) -> PromotionOut:
    return await pricing_service.create_promotion(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


@router.post(
    "/promotions/validate",
    response_model=PromotionValidateOut,
    summary="Validate coupon code and compute discount",
)
async def validate_promotion(
    payload: PromotionValidateIn,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("sales:write")),
) -> PromotionValidateOut:
    return await pricing_service.validate_promotion(
        session=db,
        business_id=user.business_id,
        payload=payload,
    )


# -----------------------------------------------------------------------------
# Bulk Import
# -----------------------------------------------------------------------------
@router.post(
    "/bulk-import",
    response_model=BulkImportResult,
    summary="Bulk import products, variants and prices via CSV",
)
async def bulk_import(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("catalog:write")),
) -> BulkImportResult:
    content = await request.body()
    return await pricing_service.process_bulk_import(
        session=db,
        business_id=user.business_id,
        file_content=content,
    )


@router.get(
    "/bulk-import/template",
    summary="Download sample CSV template for bulk import",
)
async def download_import_template(
    user: CurrentUser = Depends(require_permission("catalog:read")),
) -> Response:
    template_csv = pricing_service.generate_csv_template()
    return Response(
        content=template_csv,
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="product_pricing_template.csv"'},
    )
