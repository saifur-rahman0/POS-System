"""Database interactions for Sales headers, items, payment tenders, and receipts."""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.sales.models import PaymentTender, Sale, SaleItem


class SalesRepository:
    """Repository handling sales persistence and sequential receipt generation."""

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

