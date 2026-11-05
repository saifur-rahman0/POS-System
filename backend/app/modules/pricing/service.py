"""Business service orchestrating customer groups, price lists, promotions, and bundles."""

import uuid
from datetime import date
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.pricing.bulk_import import BulkImportProcessor
from app.modules.pricing.models import (
    BranchPriceOverride,
    CustomerGroup,
    CustomerGroupMember,
    PriceList,
    PriceListItem,
    ProductBundle,
    ProductBundleItem,
    Promotion,
    PromotionUsage,
)
from app.modules.pricing.price_resolver import PriceContext, PriceResolver
from app.modules.pricing.repository import PricingRepository
from app.modules.pricing.schemas import (
    BranchPriceOverrideCreate,
    BranchPriceOverrideOut,
    BulkImportResult,
    CustomerGroupCreate,
    CustomerGroupMemberOut,
    CustomerGroupOut,
    CustomerGroupUpdate,
    PriceListItemCreate,
    PriceListItemOut,
    PriceListItemUpdate,
    PriceListOut,
    PriceResolveIn,
    PriceResolveItemOut,
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
from app.modules.sales.models import Customer


class PricingService:
    """Service layer managing Track 12 pricing entities."""

    def __init__(
        self,
        repo: PricingRepository | None = None,
        resolver: PriceResolver | None = None,
        bulk_importer: BulkImportProcessor | None = None,
    ) -> None:
        self.repo = repo or PricingRepository()
        self.resolver = resolver or PriceResolver(self.repo)
        self.bulk_importer = bulk_importer or BulkImportProcessor()

    # -------------------------------------------------------------------------
    # Customer Groups
    # -------------------------------------------------------------------------
    async def list_customer_groups(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[CustomerGroupOut]:
        groups = await self.repo.list_customer_groups(session, business_id, is_active)
        out: list[CustomerGroupOut] = []
        for g in groups:
            count = await self.repo.count_group_members(session, g.id)
            out.append(
                CustomerGroupOut(
                    id=g.id,
                    business_id=g.business_id,
                    name=g.name,
                    description=g.description,
                    is_active=g.is_active,
                    created_at=g.created_at,
                    member_count=count,
                )
            )
        return out

    async def create_customer_group(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: CustomerGroupCreate,
    ) -> CustomerGroupOut:
        existing = await self.repo.get_customer_group_by_name(session, business_id, payload.name)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Customer group '{payload.name}' already exists",
            )

        group = CustomerGroup(
            business_id=business_id,
            name=payload.name,
            description=payload.description,
            is_active=payload.is_active,
        )
        created = await self.repo.create_customer_group(session, group)
        return CustomerGroupOut(
            id=created.id,
            business_id=created.business_id,
            name=created.name,
            description=created.description,
            is_active=created.is_active,
            created_at=created.created_at,
            member_count=0,
        )

    async def update_customer_group(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        group_id: uuid.UUID,
        payload: CustomerGroupUpdate,
    ) -> CustomerGroupOut:
        group = await self.repo.get_customer_group_by_id(session, business_id, group_id)
        if not group:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer group not found")

        if payload.name and payload.name.lower() != group.name.lower():
            conflict = await self.repo.get_customer_group_by_name(session, business_id, payload.name)
            if conflict and conflict.id != group_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Customer group '{payload.name}' already exists",
                )
            group.name = payload.name

        if payload.description is not None:
            group.description = payload.description
        if payload.is_active is not None:
            group.is_active = payload.is_active

        await session.flush()
        count = await self.repo.count_group_members(session, group.id)
        return CustomerGroupOut(
            id=group.id,
            business_id=group.business_id,
            name=group.name,
            description=group.description,
            is_active=group.is_active,
            created_at=group.created_at,
            member_count=count,
        )

    async def add_customer_to_group(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        group_id: uuid.UUID,
        customer_id: uuid.UUID,
    ) -> CustomerGroupMemberOut:
        group = await self.repo.get_customer_group_by_id(session, business_id, group_id)
        if not group:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer group not found")

        cust_stmt = select(Customer).where(Customer.id == customer_id, Customer.business_id == business_id)
        cust_res = await session.execute(cust_stmt)
        customer = cust_res.scalar_one_or_none()
        if not customer:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found")

        # Set as primary group if not set
        if not customer.primary_group_id:
            customer.primary_group_id = group_id

        member = CustomerGroupMember(
            customer_group_id=group_id,
            customer_id=customer_id,
        )
        created = await self.repo.add_group_member(session, member)
        return CustomerGroupMemberOut.model_validate(created)

    async def remove_customer_from_group(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        group_id: uuid.UUID,
        customer_id: uuid.UUID,
    ) -> dict[str, str]:
        removed = await self.repo.remove_group_member(session, group_id, customer_id)
        if not removed:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer group membership not found")

        cust_stmt = select(Customer).where(Customer.id == customer_id, Customer.business_id == business_id)
        cust_res = await session.execute(cust_stmt)
        customer = cust_res.scalar_one_or_none()
        if customer and customer.primary_group_id == group_id:
            customer.primary_group_id = None
            await session.flush()

        return {"message": "Customer removed from group successfully"}

    # -------------------------------------------------------------------------
    # Price Lists & Items
    # -------------------------------------------------------------------------
    async def list_price_lists(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[PriceListOut]:
        lists = await self.repo.list_price_lists(session, business_id, is_active)
        out: list[PriceListOut] = []
        for pl in lists:
            items = await self.repo.list_price_list_items(session, pl.id)
            items_out: list[PriceListItemOut] = []
            for item in items:
                variant, _ = await self.repo.get_variant_with_product(session, item.product_variant_id)
                items_out.append(
                    PriceListItemOut(
                        id=item.id,
                        price_list_id=item.price_list_id,
                        product_variant_id=item.product_variant_id,
                        min_quantity=item.min_quantity,
                        price=item.price,
                        start_date=item.start_date,
                        end_date=item.end_date,
                        is_active=item.is_active,
                        created_at=item.created_at,
                        variant_name=variant.name if variant else None,
                        variant_sku=variant.barcode if variant else None,
                    )
                )
            out.append(
                PriceListOut(
                    id=pl.id,
                    business_id=pl.business_id,
                    name=pl.name,
                    description=pl.description,
                    currency=pl.currency,
                    is_default=pl.is_default,
                    is_active=pl.is_active,
                    customer_group_id=pl.customer_group_id,
                    created_at=pl.created_at,
                    updated_at=pl.updated_at,
                    items=items_out,
                )
            )
        return out

    async def create_price_list(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        name: str,
        description: str | None = None,
        currency: str = "BDT",
        is_default: bool = False,
        is_active: bool = True,
        customer_group_id: uuid.UUID | None = None,
    ) -> PriceListOut:
        if is_default:
            await self.repo.clear_default_price_list(session, business_id)

        pl = PriceList(
            business_id=business_id,
            name=name,
            description=description,
            currency=currency,
            is_default=is_default,
            is_active=is_active,
            customer_group_id=customer_group_id,
        )
        created = await self.repo.create_price_list(session, pl)
        return PriceListOut(
            id=created.id,
            business_id=created.business_id,
            name=created.name,
            description=created.description,
            currency=created.currency,
            is_default=created.is_default,
            is_active=created.is_active,
            customer_group_id=created.customer_group_id,
            created_at=created.created_at,
            updated_at=created.updated_at,
            items=[],
        )

    async def get_price_list(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        price_list_id: uuid.UUID,
    ) -> PriceListOut:
        pl = await self.repo.get_price_list_by_id(session, business_id, price_list_id)
        if not pl:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Price list not found")

        items = await self.repo.list_price_list_items(session, pl.id)
        items_out: list[PriceListItemOut] = []
        for item in items:
            variant, _ = await self.repo.get_variant_with_product(session, item.product_variant_id)
            items_out.append(
                PriceListItemOut(
                    id=item.id,
                    price_list_id=item.price_list_id,
                    product_variant_id=item.product_variant_id,
                    min_quantity=item.min_quantity,
                    price=item.price,
                    start_date=item.start_date,
                    end_date=item.end_date,
                    is_active=item.is_active,
                    created_at=item.created_at,
                    variant_name=variant.name if variant else None,
                    variant_sku=variant.barcode if variant else None,
                )
            )
        return PriceListOut(
            id=pl.id,
            business_id=pl.business_id,
            name=pl.name,
            description=pl.description,
            currency=pl.currency,
            is_default=pl.is_default,
            is_active=pl.is_active,
            customer_group_id=pl.customer_group_id,
            created_at=pl.created_at,
            updated_at=pl.updated_at,
            items=items_out,
        )

    async def add_or_update_price_list_item(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        price_list_id: uuid.UUID,
        payload: PriceListItemCreate,
    ) -> PriceListItemOut:
        pl = await self.repo.get_price_list_by_id(session, business_id, price_list_id)
        if not pl:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Price list not found")

        existing = await self.repo.get_price_list_item_by_variant_minqty(
            session, price_list_id, payload.product_variant_id, payload.min_quantity
        )
        if existing:
            existing.price = payload.price
            existing.start_date = payload.start_date
            existing.end_date = payload.end_date
            existing.is_active = payload.is_active
            await session.flush()
            item = existing
        else:
            item = PriceListItem(
                price_list_id=price_list_id,
                product_variant_id=payload.product_variant_id,
                min_quantity=payload.min_quantity,
                price=payload.price,
                start_date=payload.start_date,
                end_date=payload.end_date,
                is_active=payload.is_active,
            )
            item = await self.repo.create_price_list_item(session, item)

        variant, _ = await self.repo.get_variant_with_product(session, item.product_variant_id)
        return PriceListItemOut(
            id=item.id,
            price_list_id=item.price_list_id,
            product_variant_id=item.product_variant_id,
            min_quantity=item.min_quantity,
            price=item.price,
            start_date=item.start_date,
            end_date=item.end_date,
            is_active=item.is_active,
            created_at=item.created_at,
            variant_name=variant.name if variant else None,
            variant_sku=variant.barcode if variant else None,
        )

    async def update_price_list_item(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        price_list_id: uuid.UUID,
        item_id: uuid.UUID,
        payload: PriceListItemUpdate,
    ) -> PriceListItemOut:
        pl = await self.repo.get_price_list_by_id(session, business_id, price_list_id)
        if not pl:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Price list not found")

        item = await self.repo.get_price_list_item_by_id(session, item_id)
        if not item or item.price_list_id != price_list_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Price list item not found")

        if payload.min_quantity is not None:
            item.min_quantity = payload.min_quantity
        if payload.price is not None:
            item.price = payload.price
        if payload.start_date is not None:
            item.start_date = payload.start_date
        if payload.end_date is not None:
            item.end_date = payload.end_date
        if payload.is_active is not None:
            item.is_active = payload.is_active

        await session.flush()
        variant, _ = await self.repo.get_variant_with_product(session, item.product_variant_id)
        return PriceListItemOut(
            id=item.id,
            price_list_id=item.price_list_id,
            product_variant_id=item.product_variant_id,
            min_quantity=item.min_quantity,
            price=item.price,
            start_date=item.start_date,
            end_date=item.end_date,
            is_active=item.is_active,
            created_at=item.created_at,
            variant_name=variant.name if variant else None,
            variant_sku=variant.barcode if variant else None,
        )

    async def delete_price_list_item(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        price_list_id: uuid.UUID,
        item_id: uuid.UUID,
    ) -> dict[str, str]:
        pl = await self.repo.get_price_list_by_id(session, business_id, price_list_id)
        if not pl:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Price list not found")

        item = await self.repo.get_price_list_item_by_id(session, item_id)
        if not item or item.price_list_id != price_list_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Price list item not found")

        await self.repo.delete_price_list_item(session, item)
        return {"message": "Price list item removed successfully"}

    # -------------------------------------------------------------------------
    # Branch Price Overrides
    # -------------------------------------------------------------------------
    async def list_branch_overrides(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> list[BranchPriceOverrideOut]:
        overrides = await self.repo.list_branch_overrides(session, business_id, branch_id)
        out: list[BranchPriceOverrideOut] = []
        for ov in overrides:
            variant, _ = await self.repo.get_variant_with_product(session, ov.product_variant_id)
            out.append(
                BranchPriceOverrideOut(
                    id=ov.id,
                    business_id=ov.business_id,
                    branch_id=ov.branch_id,
                    product_variant_id=ov.product_variant_id,
                    selling_price=ov.selling_price,
                    is_active=ov.is_active,
                    created_at=ov.created_at,
                    updated_at=ov.updated_at,
                    variant_name=variant.name if variant else None,
                    variant_sku=variant.barcode if variant else None,
                )
            )
        return out

    async def upsert_branch_override(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: BranchPriceOverrideCreate,
    ) -> BranchPriceOverrideOut:
        override = BranchPriceOverride(
            business_id=business_id,
            branch_id=payload.branch_id,
            product_variant_id=payload.product_variant_id,
            selling_price=payload.selling_price,
            is_active=payload.is_active,
        )
        saved = await self.repo.upsert_branch_override(session, override)
        variant, _ = await self.repo.get_variant_with_product(session, saved.product_variant_id)
        return BranchPriceOverrideOut(
            id=saved.id,
            business_id=saved.business_id,
            branch_id=saved.branch_id,
            product_variant_id=saved.product_variant_id,
            selling_price=saved.selling_price,
            is_active=saved.is_active,
            created_at=saved.created_at,
            updated_at=saved.updated_at,
            variant_name=variant.name if variant else None,
            variant_sku=variant.barcode if variant else None,
        )

    async def delete_branch_override(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        override_id: uuid.UUID,
    ) -> dict[str, str]:
        override = await self.repo.get_branch_override_by_id(session, business_id, override_id)
        if not override:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Branch override not found")
        await self.repo.delete_branch_override(session, override)
        return {"message": "Branch override deleted successfully"}

    # -------------------------------------------------------------------------
    # Price Resolution
    # -------------------------------------------------------------------------
    async def resolve_prices(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: PriceResolveIn,
    ) -> PriceResolveOut:
        eval_date = payload.sale_date or date.today()
        results: list[PriceResolveItemOut] = []

        for item in payload.items:
            ctx = PriceContext(
                business_id=business_id,
                branch_id=payload.branch_id,
                customer_id=payload.customer_id,
                quantity=item.quantity,
                sale_date=eval_date,
            )
            resolved = await self.resolver.resolve(session, item.variant_id, ctx)
            results.append(
                PriceResolveItemOut(
                    variant_id=item.variant_id,
                    unit_price=resolved.unit_price,
                    source=resolved.source,
                    price_list_id=resolved.price_list_id,
                    price_list_name=resolved.price_list_name,
                )
            )

        return PriceResolveOut(results=results)

    # -------------------------------------------------------------------------
    # Product Bundles & Kits
    # -------------------------------------------------------------------------
    async def list_bundles(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[ProductBundleOut]:
        bundles = await self.repo.list_bundles(session, business_id, is_active)
        out: list[ProductBundleOut] = []
        for b in bundles:
            items_out: list[ProductBundleItemOut] = []
            for itm in b.items:
                variant, _ = await self.repo.get_variant_with_product(session, itm.component_variant_id)
                items_out.append(
                    ProductBundleItemOut(
                        id=itm.id,
                        bundle_id=itm.bundle_id,
                        component_variant_id=itm.component_variant_id,
                        quantity=itm.quantity,
                        is_optional=itm.is_optional,
                        component_name=variant.name if variant else None,
                        component_sku=variant.barcode if variant else None,
                    )
                )
            out.append(
                ProductBundleOut(
                    id=b.id,
                    business_id=b.business_id,
                    product_id=b.product_id,
                    name=b.name,
                    bundle_price=b.bundle_price,
                    is_kit=b.is_kit,
                    is_active=b.is_active,
                    created_at=b.created_at,
                    items=items_out,
                )
            )
        return out

    async def create_bundle(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: ProductBundleCreate,
    ) -> ProductBundleOut:
        bundle = ProductBundle(
            business_id=business_id,
            product_id=payload.product_id,
            name=payload.name,
            bundle_price=payload.bundle_price,
            is_kit=payload.is_kit,
            is_active=payload.is_active,
        )
        created = await self.repo.create_bundle(session, bundle)

        items_out: list[ProductBundleItemOut] = []
        for itm in payload.items:
            bundle_item = ProductBundleItem(
                bundle_id=created.id,
                component_variant_id=itm.component_variant_id,
                quantity=itm.quantity,
                is_optional=itm.is_optional,
            )
            saved_item = await self.repo.add_bundle_item(session, bundle_item)
            variant, _ = await self.repo.get_variant_with_product(session, saved_item.component_variant_id)
            items_out.append(
                ProductBundleItemOut(
                    id=saved_item.id,
                    bundle_id=saved_item.bundle_id,
                    component_variant_id=saved_item.component_variant_id,
                    quantity=saved_item.quantity,
                    is_optional=saved_item.is_optional,
                    component_name=variant.name if variant else None,
                    component_sku=variant.barcode if variant else None,
                )
            )

        return ProductBundleOut(
            id=created.id,
            business_id=created.business_id,
            product_id=created.product_id,
            name=created.name,
            bundle_price=created.bundle_price,
            is_kit=created.is_kit,
            is_active=created.is_active,
            created_at=created.created_at,
            items=items_out,
        )

    async def add_bundle_component(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        bundle_id: uuid.UUID,
        payload: ProductBundleItemCreate,
    ) -> ProductBundleItemOut:
        bundle = await self.repo.get_bundle_by_id(session, business_id, bundle_id)
        if not bundle:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bundle not found")

        item = ProductBundleItem(
            bundle_id=bundle_id,
            component_variant_id=payload.component_variant_id,
            quantity=payload.quantity,
            is_optional=payload.is_optional,
        )
        saved = await self.repo.add_bundle_item(session, item)
        variant, _ = await self.repo.get_variant_with_product(session, saved.component_variant_id)
        return ProductBundleItemOut(
            id=saved.id,
            bundle_id=saved.bundle_id,
            component_variant_id=saved.component_variant_id,
            quantity=saved.quantity,
            is_optional=saved.is_optional,
            component_name=variant.name if variant else None,
            component_sku=variant.barcode if variant else None,
        )

    async def delete_bundle_component(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        bundle_id: uuid.UUID,
        component_item_id: uuid.UUID,
    ) -> dict[str, str]:
        bundle = await self.repo.get_bundle_by_id(session, business_id, bundle_id)
        if not bundle:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bundle not found")

        item_stmt = select(ProductBundleItem).where(
            ProductBundleItem.id == component_item_id,
            ProductBundleItem.bundle_id == bundle_id,
        )
        res = await session.execute(item_stmt)
        item = res.scalar_one_or_none()
        if not item:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Component item not found in bundle")

        await self.repo.delete_bundle_item(session, item)
        return {"message": "Bundle component removed successfully"}

    # -------------------------------------------------------------------------
    # Promotions & Coupons
    # -------------------------------------------------------------------------
    async def list_promotions(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[PromotionOut]:
        promos = await self.repo.list_promotions(session, business_id, is_active)
        return [PromotionOut.model_validate(p) for p in promos]

    async def create_promotion(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: PromotionCreate,
    ) -> PromotionOut:
        if payload.code:
            existing = await self.repo.get_promotion_by_code(session, business_id, payload.code)
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Promotion with code '{payload.code}' already exists",
                )

        if payload.valid_until < payload.valid_from:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Promotion valid_until cannot be earlier than valid_from",
            )

        promo = Promotion(
            business_id=business_id,
            name=payload.name,
            code=payload.code,
            discount_type=payload.discount_type,
            discount_value=payload.discount_value,
            min_spend=payload.min_spend,
            max_discount_cap=payload.max_discount_cap,
            usage_limit=payload.usage_limit,
            valid_from=payload.valid_from,
            valid_until=payload.valid_until,
            applies_to=payload.applies_to,
            scope_ids=payload.scope_ids,
            is_active=payload.is_active,
        )
        created = await self.repo.create_promotion(session, promo)
        return PromotionOut.model_validate(created)

    async def validate_promotion(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: PromotionValidateIn,
    ) -> PromotionValidateOut:
        promo = await self.repo.get_promotion_by_code(session, business_id, payload.code)
        if not promo or not promo.is_active:
            return PromotionValidateOut(
                is_valid=False,
                message=f"Coupon code '{payload.code}' is invalid or inactive",
            )

        today = date.today()
        if today < promo.valid_from:
            return PromotionValidateOut(
                is_valid=False,
                message=f"Coupon code '{payload.code}' is not active yet",
            )
        if today > promo.valid_until:
            return PromotionValidateOut(
                is_valid=False,
                message=f"Coupon code '{payload.code}' has expired",
            )

        if promo.usage_limit is not None and promo.times_used >= promo.usage_limit:
            return PromotionValidateOut(
                is_valid=False,
                message=f"Coupon code '{payload.code}' usage limit has been reached",
            )

        if payload.subtotal < promo.min_spend:
            return PromotionValidateOut(
                is_valid=False,
                message=f"Minimum spend of ৳{promo.min_spend:,.2f} required for this coupon",
            )

        # Calculate discount
        if promo.discount_type == "PERCENTAGE":
            raw_discount = (payload.subtotal * (promo.discount_value / Decimal("100.0000"))).quantize(
                Decimal("0.0001")
            )
            if promo.max_discount_cap is not None:
                calculated_discount = min(raw_discount, promo.max_discount_cap)
            else:
                calculated_discount = raw_discount
        else:
            calculated_discount = min(promo.discount_value, payload.subtotal)

        return PromotionValidateOut(
            is_valid=True,
            promotion_id=promo.id,
            discount_type=promo.discount_type,
            discount_value=promo.discount_value,
            calculated_discount=calculated_discount,
            message="Promotion applied successfully",
        )

    async def record_promotion_usage(
        self,
        session: AsyncSession,
        promotion_id: uuid.UUID,
        sale_id: uuid.UUID,
        discount_applied: Decimal,
    ) -> None:
        promo_stmt = (
            select(Promotion)
            .where(Promotion.id == promotion_id)
            .with_for_update()
        )
        res = await session.execute(promo_stmt)
        promo = res.scalar_one_or_none()
        if promo:
            promo.times_used += 1

        usage = PromotionUsage(
            promotion_id=promotion_id,
            sale_id=sale_id,
            discount_applied=discount_applied,
        )
        await self.repo.record_promotion_usage(session, usage)

    # -------------------------------------------------------------------------
    # Bulk CSV / Excel Import
    # -------------------------------------------------------------------------
    async def process_bulk_import(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        file_content: bytes,
    ) -> BulkImportResult:
        return await self.bulk_importer.process_csv(session, business_id, file_content)

    def generate_csv_template(self) -> str:
        return (
            "product_sku,product_name,variant_name,barcode,cost_price,selling_price,track_stock,category_name\n"
            "SKU-DEMO-01,Wireless Mouse,Black,123456789012,350.00,550.00,true,Accessories\n"
            "SKU-DEMO-02,Mechanical Keyboard,RGB Blue Switch,123456789013,1800.00,2500.00,true,Accessories\n"
        )
