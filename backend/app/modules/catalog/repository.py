"""SQLAlchemy repositories for Category, Product, and ProductVariant."""

import uuid
from collections.abc import Sequence

from sqlalchemy import Select, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.catalog.models import Category, Product, ProductVariant


class CategoryRepository:
    """Async repository for Category entities."""

    async def get_by_id(
        self, session: AsyncSession, business_id: uuid.UUID, category_id: uuid.UUID
    ) -> Category | None:
        stmt = select(Category).where(
            Category.business_id == business_id,
            Category.id == category_id,
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_name(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        name: str,
        parent_id: uuid.UUID | None = None,
    ) -> Category | None:
        stmt = select(Category).where(
            Category.business_id == business_id,
            func.lower(Category.name) == func.lower(name),
            Category.parent_id == parent_id,
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_all(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> Sequence[Category]:
        stmt = (
            select(Category)
            .where(Category.business_id == business_id)
            .order_by(Category.name.asc())
        )
        if is_active is not None:
            stmt = stmt.where(Category.is_active == is_active)

        result = await session.execute(stmt)
        return result.scalars().all()

    async def create(self, session: AsyncSession, category: Category) -> Category:
        session.add(category)
        await session.flush()
        return category


class ProductRepository:
    """Async repository for Product and ProductVariant entities."""

    def _base_query(self, business_id: uuid.UUID) -> Select[Product]:
        return (
            select(Product)
            .where(Product.business_id == business_id)
            .options(
                selectinload(Product.variants),
                selectinload(Product.category),
                selectinload(Product.brand),
            )
        )

    async def get_by_id(
        self, session: AsyncSession, business_id: uuid.UUID, product_id: uuid.UUID
    ) -> Product | None:
        stmt = self._base_query(business_id).where(Product.id == product_id)
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_sku(
        self, session: AsyncSession, business_id: uuid.UUID, sku: str
    ) -> Product | None:
        stmt = self._base_query(business_id).where(func.upper(Product.sku) == func.upper(sku))
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_variant_by_barcode(
        self, session: AsyncSession, business_id: uuid.UUID, barcode: str
    ) -> ProductVariant | None:
        stmt = select(ProductVariant).where(
            ProductVariant.business_id == business_id,
            ProductVariant.barcode == barcode,
        )
        result = await session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_barcode(
        self, session: AsyncSession, business_id: uuid.UUID, barcode: str
    ) -> Product | None:
        variant_stmt = select(ProductVariant.product_id).where(
            ProductVariant.business_id == business_id,
            ProductVariant.barcode == barcode,
        )
        var_res = await session.execute(variant_stmt)
        product_id = var_res.scalar_one_or_none()
        if not product_id:
            return None
        return await self.get_by_id(session, business_id, product_id)

    async def list_paginated(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        search: str | None = None,
        category_id: uuid.UUID | None = None,
        is_active: bool | None = None,
        page: int = 1,
        limit: int = 20,
    ) -> tuple[Sequence[Product], int]:
        query = select(Product).where(Product.business_id == business_id)

        if category_id is not None:
            query = query.where(Product.category_id == category_id)

        if is_active is not None:
            query = query.where(Product.is_active == is_active)

        if search and search.strip():
            term = f"%{search.strip()}%"
            # Match on name, sku, or barcode of attached variants
            variant_match = (
                select(ProductVariant.product_id)
                .where(
                    ProductVariant.business_id == business_id,
                    ProductVariant.barcode.ilike(term),
                )
                .scalar_subquery()
            )
            query = query.where(
                or_(
                    Product.name.ilike(term),
                    Product.sku.ilike(term),
                    Product.id.in_(variant_match),
                )
            )

        # Count total matching rows
        count_stmt = select(func.count()).select_from(query.subquery())
        total_result = await session.execute(count_stmt)
        total = total_result.scalar_one()

        # Paginate
        offset = (page - 1) * limit
        paginated_query = (
            query.options(
                selectinload(Product.variants),
                selectinload(Product.category),
                selectinload(Product.brand),
            )
            .order_by(Product.name.asc(), Product.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        res = await session.execute(paginated_query)
        items = res.scalars().all()
        return items, total

    async def create(
        self, session: AsyncSession, product: Product, default_variant: ProductVariant
    ) -> Product:
        session.add(product)
        await session.flush()
        default_variant.product_id = product.id
        session.add(default_variant)
        await session.flush()
        await session.refresh(product, ["variants", "category", "brand"])
        return product
