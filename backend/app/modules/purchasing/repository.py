"""Repository for Suppliers, Purchase Orders, Items, and Disbursements."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.purchasing.models import Purchase, PurchaseItem, Supplier


class PurchasingRepository:
    """Database interactions for supply chain, vendors, and purchasing."""

    # -------------------------------------------------------------------------
    # Suppliers
    # -------------------------------------------------------------------------

    async def get_supplier_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        supplier_id: uuid.UUID,
    ) -> Supplier | None:
        """Fetch supplier by primary key within business tenant."""
        stmt = select(Supplier).where(
            Supplier.business_id == business_id,
            Supplier.id == supplier_id,
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_supplier_by_name(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        name: str,
    ) -> Supplier | None:
        """Fetch supplier by exact name match within tenant."""
        stmt = select(Supplier).where(
            Supplier.business_id == business_id,
            func.lower(Supplier.name) == name.strip().lower(),
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def list_suppliers(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        search: str | None = None,
        is_active: bool | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> list[Supplier]:
        """Query paginated suppliers with optional search filter."""
        stmt = select(Supplier).where(Supplier.business_id == business_id)

        if is_active is not None:
            stmt = stmt.where(Supplier.is_active == is_active)

        if search and search.strip():
            token = f"%{search.strip().lower()}%"
            stmt = stmt.where(
                func.lower(Supplier.name).like(token)
                | func.lower(Supplier.phone).like(token)
                | func.lower(Supplier.contact_person).like(token)
            )

        stmt = stmt.order_by(Supplier.name.asc())
        stmt = stmt.offset((page - 1) * page_size).limit(page_size)

        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def count_suppliers(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        search: str | None = None,
        is_active: bool | None = None,
    ) -> int:
        """Count suppliers matching filters."""
        stmt = select(func.count(Supplier.id)).where(Supplier.business_id == business_id)

        if is_active is not None:
            stmt = stmt.where(Supplier.is_active == is_active)

        if search and search.strip():
            token = f"%{search.strip().lower()}%"
            stmt = stmt.where(
                func.lower(Supplier.name).like(token)
                | func.lower(Supplier.phone).like(token)
                | func.lower(Supplier.contact_person).like(token)
            )

        result = await session.execute(stmt)
        return result.scalar_one()

    async def get_supplier_financial_metrics(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        supplier_id: uuid.UUID,
    ) -> tuple[int, Decimal, Decimal]:
        """Returns (total_purchases_count, total_purchases_amount, unpaid_balance)."""
        stmt = select(
            func.count(Purchase.id),
            func.coalesce(func.sum(Purchase.total), 0),
            func.coalesce(func.sum(Purchase.total - Purchase.paid_total), 0),
        ).where(
            Purchase.business_id == business_id,
            Purchase.supplier_id == supplier_id,
            Purchase.status != "CANCELLED",
        )
        res = await session.execute(stmt)
        row = res.one()
        return (row[0], Decimal(str(row[1])), Decimal(str(row[2])))

    # -------------------------------------------------------------------------
    # Purchases
    # -------------------------------------------------------------------------

    async def generate_reference_no(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
    ) -> str:
        """Generates sequential PO reference number (e.g. PO-YYYYMMDD-0001)."""
        today_str = datetime.now(UTC).strftime("%Y%m%d")
        prefix = f"PO-{today_str}-"

        stmt = (
            select(Purchase.reference_no)
            .where(
                Purchase.business_id == business_id,
                Purchase.reference_no.like(f"{prefix}%"),
            )
            .order_by(Purchase.reference_no.desc())
            .limit(1)
        )
        res = await session.execute(stmt)
        last_ref = res.scalars().first()

        if last_ref:
            try:
                seq = int(last_ref.split("-")[-1]) + 1
            except ValueError:
                seq = 1
        else:
            seq = 1

        return f"{prefix}{seq:04d}"

    async def get_purchase_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        purchase_id: uuid.UUID,
        for_update: bool = False,
    ) -> Purchase | None:
        """Fetch purchase order with eager loaded line items and payments."""
        stmt = (
            select(Purchase)
            .options(
                selectinload(Purchase.items),
                selectinload(Purchase.payments),
            )
            .where(
                Purchase.business_id == business_id,
                Purchase.id == purchase_id,
            )
        )
        if for_update:
            stmt = stmt.with_for_update()

        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_purchase_by_reference_no(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        reference_no: str,
    ) -> Purchase | None:
        """Fetch purchase by exact reference number."""
        stmt = select(Purchase).where(
            Purchase.business_id == business_id,
            Purchase.reference_no == reference_no.strip(),
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def list_purchases(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        supplier_id: uuid.UUID | None = None,
        status: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> list[Purchase]:
        """Fetch filtered and paginated purchases."""
        stmt = (
            select(Purchase)
            .options(
                selectinload(Purchase.items),
                selectinload(Purchase.payments),
            )
            .where(Purchase.business_id == business_id)
        )

        if branch_id:
            stmt = stmt.where(Purchase.branch_id == branch_id)
        if supplier_id:
            stmt = stmt.where(Purchase.supplier_id == supplier_id)
        if status:
            stmt = stmt.where(Purchase.status == status)
        if start_date:
            stmt = stmt.where(Purchase.created_at >= start_date)
        if end_date:
            stmt = stmt.where(Purchase.created_at <= end_date)

        stmt = stmt.order_by(Purchase.created_at.desc())
        stmt = stmt.offset((page - 1) * page_size).limit(page_size)

        res = await session.execute(stmt)
        return list(res.scalars().all())

    async def count_purchases(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        supplier_id: uuid.UUID | None = None,
        status: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
    ) -> int:
        """Count filtered purchases."""
        stmt = select(func.count(Purchase.id)).where(Purchase.business_id == business_id)

        if branch_id:
            stmt = stmt.where(Purchase.branch_id == branch_id)
        if supplier_id:
            stmt = stmt.where(Purchase.supplier_id == supplier_id)
        if status:
            stmt = stmt.where(Purchase.status == status)
        if start_date:
            stmt = stmt.where(Purchase.created_at >= start_date)
        if end_date:
            stmt = stmt.where(Purchase.created_at <= end_date)

        res = await session.execute(stmt)
        return res.scalar_one()

    async def create_purchase(
        self,
        session: AsyncSession,
        purchase: Purchase,
        items: list[PurchaseItem],
    ) -> Purchase:
        """Persists a new purchase order with its line items."""
        session.add(purchase)
        for item in items:
            session.add(item)
        await session.flush()
        return purchase
