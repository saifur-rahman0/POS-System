"""Database interactions for Sales headers, items, payment tenders, and receipts."""

import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.sales.models import (
    HeldCart,
    PaymentTender,
    Quotation,
    QuotationItem,
    Sale,
    SaleItem,
)


class SalesRepository:
    """Repository handling sales persistence, filtering, and sequential receipt generation."""

    async def list_sales(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        cashier_id: uuid.UUID | None = None,
        status: str | None = None,
        search: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> list[Sale]:
        """Fetch paginated sales ordered by created_at DESC matching multiple filter criteria."""
        stmt = (
            select(Sale)
            .options(
                selectinload(Sale.items),
                selectinload(Sale.payments),
            )
            .where(Sale.business_id == business_id)
        )
        if branch_id:
            stmt = stmt.where(Sale.branch_id == branch_id)
        if start_date:
            stmt = stmt.where(Sale.created_at >= start_date)
        if end_date:
            stmt = stmt.where(Sale.created_at <= end_date)
        if cashier_id:
            stmt = stmt.where(Sale.cashier_id == cashier_id)
        if status:
            stmt = stmt.where(Sale.status == status.strip().upper())
        if search and search.strip():
            stmt = stmt.where(Sale.receipt_no.ilike(f"%{search.strip()}%"))

        stmt = stmt.order_by(Sale.created_at.desc())
        offset = (page - 1) * page_size
        stmt = stmt.offset(offset).limit(page_size)

        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def count_sales(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        cashier_id: uuid.UUID | None = None,
        status: str | None = None,
        search: str | None = None,
    ) -> int:
        """Count total sales matching filter criteria."""
        stmt = select(func.count(Sale.id)).where(Sale.business_id == business_id)
        if branch_id:
            stmt = stmt.where(Sale.branch_id == branch_id)
        if start_date:
            stmt = stmt.where(Sale.created_at >= start_date)
        if end_date:
            stmt = stmt.where(Sale.created_at <= end_date)
        if cashier_id:
            stmt = stmt.where(Sale.cashier_id == cashier_id)
        if status:
            stmt = stmt.where(Sale.status == status.strip().upper())
        if search and search.strip():
            stmt = stmt.where(Sale.receipt_no.ilike(f"%{search.strip()}%"))

        result = await session.execute(stmt)
        return int(result.scalar_one() or 0)

    async def get_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        sale_id: uuid.UUID,
    ) -> Sale | None:
        """Fetch sale by primary key with items and payment tenders loaded."""
        stmt = (
            select(Sale)
            .options(
                selectinload(Sale.items),
                selectinload(Sale.payments),
            )
            .where(
                Sale.business_id == business_id,
                Sale.id == sale_id,
            )
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_by_idempotency_key(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        idempotency_key: str,
    ) -> Sale | None:
        """Fetch existing sale matching an idempotency key."""
        stmt = (
            select(Sale)
            .options(
                selectinload(Sale.items),
                selectinload(Sale.payments),
            )
            .where(
                Sale.business_id == business_id,
                Sale.idempotency_key == idempotency_key,
            )
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_by_receipt_no(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        receipt_no: str,
    ) -> Sale | None:
        """Fetch sale by receipt number."""
        stmt = (
            select(Sale)
            .options(
                selectinload(Sale.items),
                selectinload(Sale.payments),
            )
            .where(
                Sale.business_id == business_id,
                Sale.receipt_no == receipt_no,
            )
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def generate_receipt_number(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch: Branch,
        now: datetime | None = None,
    ) -> str:
        """Generates the next sequential gapless receipt number for the branch.

        Format: REC-{YYYYMMDD}-{BRANCH_CODE}-{SEQ:04d}
        Example: REC-20261103-MAIN-0001
        """
        current_date = now or datetime.now(UTC)
        date_str = current_date.strftime("%Y%m%d")
        branch_code = (branch.code or "MAIN").strip().upper()
        prefix = f"REC-{date_str}-{branch_code}-"

        stmt = (
            select(Sale.receipt_no)
            .where(
                Sale.business_id == business_id,
                Sale.branch_id == branch.id,
                Sale.receipt_no.like(f"{prefix}%"),
            )
            .order_by(Sale.receipt_no.desc())
            .limit(1)
        )
        result = await session.execute(stmt)
        last_receipt = result.scalars().first()

        next_seq = 1
        if last_receipt and last_receipt.startswith(prefix):
            suffix = last_receipt[len(prefix) :]
            try:
                next_seq = int(suffix) + 1
            except ValueError:
                next_seq = 1

        return f"{prefix}{next_seq:04d}"

    async def create(
        self,
        session: AsyncSession,
        sale: Sale,
        items: list[SaleItem],
        payments: list[PaymentTender],
    ) -> Sale:
        """Persist sale header, items, and tenders."""
        session.add(sale)
        for item in items:
            item.sale_id = sale.id
            session.add(item)
        for payment in payments:
            payment.sale_id = sale.id
            session.add(payment)
        return sale

    async def create_held_cart(
        self,
        session: AsyncSession,
        held_cart: HeldCart,
    ) -> HeldCart:
        """Persist a parked cart."""
        session.add(held_cart)
        await session.flush()
        return held_cart

    async def list_held_carts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> list[HeldCart]:
        """List active held carts for a business and optional branch ordered newest first."""
        stmt = select(HeldCart).where(HeldCart.business_id == business_id)
        if branch_id:
            stmt = stmt.where(HeldCart.branch_id == branch_id)
        stmt = stmt.order_by(HeldCart.created_at.desc())
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_held_cart(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        held_cart_id: uuid.UUID,
    ) -> HeldCart | None:
        """Fetch a single held cart by ID."""
        stmt = select(HeldCart).where(
            HeldCart.business_id == business_id,
            HeldCart.id == held_cart_id,
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def delete_held_cart(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        held_cart_id: uuid.UUID,
    ) -> bool:
        """Delete a held cart from database."""
        held = await self.get_held_cart(session, business_id, held_cart_id)
        if held:
            await session.delete(held)
            return True
        return False

    async def generate_quotation_number(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch: Branch,
        now: datetime | None = None,
    ) -> str:
        """Generates consecutive sequential quotation number.

        Format: QT-{YYYYMMDD}-{BRANCH_CODE}-{SEQ:04d}
        Example: QT-20261105-MAIN-0001
        """
        current_date = now or datetime.now(UTC)
        date_str = current_date.strftime("%Y%m%d")
        branch_code = (branch.code or "MAIN").strip().upper()
        prefix = f"QT-{date_str}-{branch_code}-"

        stmt = (
            select(Quotation.quotation_no)
            .where(
                Quotation.business_id == business_id,
                Quotation.branch_id == branch.id,
                Quotation.quotation_no.like(f"{prefix}%"),
            )
            .order_by(Quotation.quotation_no.desc())
            .limit(1)
        )
        result = await session.execute(stmt)
        last_quotation = result.scalars().first()

        next_seq = 1
        if last_quotation and last_quotation.startswith(prefix):
            suffix = last_quotation[len(prefix) :]
            try:
                next_seq = int(suffix) + 1
            except ValueError:
                next_seq = 1

        return f"{prefix}{next_seq:04d}"

    async def create_quotation(
        self,
        session: AsyncSession,
        quotation: Quotation,
        items: list[QuotationItem],
    ) -> Quotation:
        """Persist quotation header and line items."""
        session.add(quotation)
        for item in items:
            item.quotation_id = quotation.id
            session.add(item)
        await session.flush()
        return quotation

    async def list_quotations(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        status: str | None = None,
        search: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> list[Quotation]:
        """Fetch quotations matching filters ordered by created_at DESC."""
        stmt = (
            select(Quotation)
            .options(selectinload(Quotation.items))
            .where(Quotation.business_id == business_id)
        )
        if branch_id:
            stmt = stmt.where(Quotation.branch_id == branch_id)
        if status:
            stmt = stmt.where(Quotation.status == status.strip().upper())
        if search and search.strip():
            stmt = stmt.where(
                (Quotation.quotation_no.ilike(f"%{search.strip()}%"))
                | (Quotation.customer_name.ilike(f"%{search.strip()}%"))
            )
        stmt = stmt.order_by(Quotation.created_at.desc())
        offset = (page - 1) * page_size
        stmt = stmt.offset(offset).limit(page_size)

        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_quotation(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        quotation_id: uuid.UUID,
    ) -> Quotation | None:
        """Fetch quotation with items loaded."""
        stmt = (
            select(Quotation)
            .options(selectinload(Quotation.items))
            .where(
                Quotation.business_id == business_id,
                Quotation.id == quotation_id,
            )
        )
        result = await session.execute(stmt)
        return result.scalars().first()

