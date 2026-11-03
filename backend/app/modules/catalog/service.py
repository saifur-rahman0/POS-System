"""Catalog domain business logic, validation, duplicate handling, and orchestration."""

import math
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.catalog.models import Category, Product, ProductVariant
from app.modules.catalog.repository import CategoryRepository, ProductRepository
from app.modules.catalog.schemas import (
    CategoryCreate,
    CategoryOut,
    CategoryUpdate,
    PaginatedResponse,
    ProductCreate,
    ProductOut,
    ProductUpdate,
    ProductVariantOut,
)
from app.shared.exceptions import AppException


class CatalogService:
    """Service handling catalog business transactions and invariants."""

    def __init__(
        self,
        category_repo: CategoryRepository | None = None,
        product_repo: ProductRepository | None = None,
    ):
        self.category_repo = category_repo or CategoryRepository()
        self.product_repo = product_repo or ProductRepository()

    # -------------------------------------------------------------------------
    # Category Operations
    # -------------------------------------------------------------------------
    async def create_category(
        self, session: AsyncSession, business_id: uuid.UUID, payload: CategoryCreate
    ) -> CategoryOut:
        if payload.parent_id:
            parent = await self.category_repo.get_by_id(session, business_id, payload.parent_id)
            if not parent:
                raise AppException(
                    message="Parent category not found",
                    code="PARENT_CATEGORY_NOT_FOUND",
                    status_code=404,
                )

        existing = await self.category_repo.get_by_name(
            session, business_id, payload.name, payload.parent_id
        )
        if existing:
            raise AppException(
                message=f"Category with name '{payload.name}' already exists",
                code="DUPLICATE_CATEGORY",
                status_code=409,
                details={"name": payload.name},
            )

        category = Category(
            business_id=business_id,
            name=payload.name,
            parent_id=payload.parent_id,
            is_active=payload.is_active,
        )
        created = await self.category_repo.create(session, category)
        await session.commit()
        await session.refresh(created)
        return CategoryOut.model_validate(created)

    async def update_category(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        category_id: uuid.UUID,
        payload: CategoryUpdate,
    ) -> CategoryOut:
        category = await self.category_repo.get_by_id(session, business_id, category_id)
        if not category:
            raise AppException(
                message="Category not found",
                code="CATEGORY_NOT_FOUND",
                status_code=404,
            )

        if payload.parent_id is not None:
            if payload.parent_id == category_id:
                raise AppException(
                    message="A category cannot be its own parent",
                    code="INVALID_PARENT_CATEGORY",
                    status_code=400,
                )
            parent = await self.category_repo.get_by_id(session, business_id, payload.parent_id)
            if not parent:
                raise AppException(
                    message="Parent category not found",
                    code="PARENT_CATEGORY_NOT_FOUND",
                    status_code=404,
                )

        name_to_check = payload.name if payload.name is not None else category.name
        parent_to_check = payload.parent_id if payload.parent_id is not None else category.parent_id

        if name_to_check != category.name or parent_to_check != category.parent_id:
            duplicate = await self.category_repo.get_by_name(
                session, business_id, name_to_check, parent_to_check
            )
            if duplicate and duplicate.id != category.id:
                raise AppException(
                    message=f"Category with name '{name_to_check}' already exists",
                    code="DUPLICATE_CATEGORY",
                    status_code=409,
                    details={"name": name_to_check},
                )

        if payload.name is not None:
            category.name = payload.name
        if payload.parent_id is not None:
            category.parent_id = payload.parent_id
        if payload.is_active is not None:
            category.is_active = payload.is_active

        await session.commit()
        await session.refresh(category)
        return CategoryOut.model_validate(category)

    async def list_categories(
        self, session: AsyncSession, business_id: uuid.UUID, is_active: bool | None = None
    ) -> list[CategoryOut]:
        categories = await self.category_repo.list_all(session, business_id, is_active=is_active)
        return [CategoryOut.model_validate(c) for c in categories]

    # -------------------------------------------------------------------------
    # Product Operations
    # -------------------------------------------------------------------------
    def _map_product_out(self, p: Product) -> ProductOut:
        """Helper to convert Product model to ProductOut with variant and label details."""
        variants_out = [ProductVariantOut.model_validate(v) for v in p.variants]
        primary = variants_out[0] if variants_out else None

        return ProductOut(
            id=p.id,
            business_id=p.business_id,
            sku=p.sku,
            name=p.name,
            category_id=p.category_id,
            brand_id=p.brand_id,
            product_type=p.product_type,
            is_active=p.is_active,
            created_at=p.created_at,
            updated_at=p.updated_at,
            category_name=p.category.name if p.category else None,
            brand_name=p.brand.name if p.brand else None,
            primary_variant=primary,
            variants=variants_out,
        )

    async def create_product(
        self, session: AsyncSession, business_id: uuid.UUID, payload: ProductCreate
    ) -> ProductOut:
        # Check duplicate SKU
        existing_sku = await self.product_repo.get_by_sku(session, business_id, payload.sku)
        if existing_sku:
            raise AppException(
                message=f"Product with SKU '{payload.sku}' already exists",
                code="DUPLICATE_SKU",
                status_code=409,
                details={"sku": payload.sku},
            )

        # Check duplicate barcode if provided
        if payload.barcode:
            existing_barcode = await self.product_repo.get_variant_by_barcode(
                session, business_id, payload.barcode
            )
            if existing_barcode:
                raise AppException(
                    message=f"Product variant with barcode '{payload.barcode}' already exists",
                    code="DUPLICATE_BARCODE",
                    status_code=409,
                    details={"barcode": payload.barcode},
                )

        # Validate category belongs to this business
        if payload.category_id:
            category = await self.category_repo.get_by_id(session, business_id, payload.category_id)
            if not category:
                raise AppException(
                    message="Category not found",
                    code="CATEGORY_NOT_FOUND",
                    status_code=404,
                )

        product = Product(
            business_id=business_id,
            sku=payload.sku,
            name=payload.name,
            category_id=payload.category_id,
            brand_id=payload.brand_id,
            product_type=payload.product_type,
            is_active=payload.is_active,
        )

        default_variant = ProductVariant(
            business_id=business_id,
            name="Standard",
            barcode=payload.barcode,
            selling_price=payload.selling_price,
            cost_price=payload.cost_price,
            track_stock=payload.track_stock,
            is_active=payload.is_active,
            attributes_json=payload.attributes_json,
        )

        created = await self.product_repo.create(session, product, default_variant)
        await session.commit()
        return self._map_product_out(created)

    async def get_product(
        self, session: AsyncSession, business_id: uuid.UUID, product_id: uuid.UUID
    ) -> ProductOut:
        product = await self.product_repo.get_by_id(session, business_id, product_id)
        if not product:
            raise AppException(
                message="Product not found",
                code="PRODUCT_NOT_FOUND",
                status_code=404,
            )
        return self._map_product_out(product)

    async def get_product_by_barcode(
        self, session: AsyncSession, business_id: uuid.UUID, barcode: str
    ) -> ProductOut:
        clean_code = barcode.strip()
        product = await self.product_repo.get_by_barcode(session, business_id, clean_code)
        if not product:
            raise AppException(
                message=f"No product found for barcode '{clean_code}'",
                code="BARCODE_NOT_FOUND",
                status_code=404,
                details={"barcode": clean_code},
            )
        return self._map_product_out(product)

    async def list_products(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        search: str | None = None,
        category_id: uuid.UUID | None = None,
        is_active: bool | None = None,
        page: int = 1,
        limit: int = 20,
    ) -> PaginatedResponse[ProductOut]:
        items, total = await self.product_repo.list_paginated(
            session=session,
            business_id=business_id,
            search=search,
            category_id=category_id,
            is_active=is_active,
            page=page,
            limit=limit,
        )
        pages = math.ceil(total / limit) if total > 0 else 1
        serialized = [self._map_product_out(p) for p in items]
        return PaginatedResponse(
            items=serialized,
            total=total,
            page=page,
            limit=limit,
            pages=pages,
        )

    async def update_product(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        product_id: uuid.UUID,
        payload: ProductUpdate,
    ) -> ProductOut:
        product = await self.product_repo.get_by_id(session, business_id, product_id)
        if not product:
            raise AppException(
                message="Product not found",
                code="PRODUCT_NOT_FOUND",
                status_code=404,
            )

        # SKU uniqueness
        if payload.sku is not None and payload.sku != product.sku:
            existing_sku = await self.product_repo.get_by_sku(session, business_id, payload.sku)
            if existing_sku and existing_sku.id != product.id:
                raise AppException(
                    message=f"Product with SKU '{payload.sku}' already exists",
                    code="DUPLICATE_SKU",
                    status_code=409,
                    details={"sku": payload.sku},
                )
            product.sku = payload.sku

        # Barcode uniqueness
        primary_variant = product.variants[0] if product.variants else None
        if payload.barcode is not None:
            existing_bar = await self.product_repo.get_variant_by_barcode(
                session, business_id, payload.barcode
            )
            if existing_bar and existing_bar.product_id != product.id:
                raise AppException(
                    message=f"Product variant with barcode '{payload.barcode}' already exists",
                    code="DUPLICATE_BARCODE",
                    status_code=409,
                    details={"barcode": payload.barcode},
                )
            if primary_variant:
                primary_variant.barcode = payload.barcode

        # Category check
        if payload.category_id is not None:
            cat = await self.category_repo.get_by_id(session, business_id, payload.category_id)
            if not cat:
                raise AppException(
                    message="Category not found",
                    code="CATEGORY_NOT_FOUND",
                    status_code=404,
                )
            product.category_id = payload.category_id

        if payload.name is not None:
            product.name = payload.name
        if payload.brand_id is not None:
            product.brand_id = payload.brand_id
        if payload.product_type is not None:
            product.product_type = payload.product_type
        if payload.is_active is not None:
            product.is_active = payload.is_active
            if primary_variant:
                primary_variant.is_active = payload.is_active

        # Variant updates
        if primary_variant:
            if payload.selling_price is not None:
                primary_variant.selling_price = payload.selling_price
            if payload.cost_price is not None:
                primary_variant.cost_price = payload.cost_price
            if payload.track_stock is not None:
                primary_variant.track_stock = payload.track_stock
            if payload.attributes_json is not None:
                primary_variant.attributes_json = payload.attributes_json

        await session.commit()
        await session.refresh(product, ["variants", "category", "brand"])
        return self._map_product_out(product)
