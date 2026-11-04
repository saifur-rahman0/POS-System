"""Database repository for customer profiles, credit queries, and due ledgers."""

import uuid
from decimal import Decimal

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.sales.models import Customer, PaymentTender, Sale


class CustomersRepository:
    """Persistence operations and financial aggregations for retail customers."""

    async def get_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
        for_update: bool = False,
    ) -> Customer | None:
        """Fetch customer by ID within business tenant scope."""
        stmt = select(Customer).where(
            Customer.business_id == business_id,
            Customer.id == customer_id,
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_by_phone(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        phone: str,
    ) -> Customer | None:
        """Find existing customer by phone number within the business."""
        stmt = select(Customer).where(
            Customer.business_id == business_id,
            Customer.phone == phone.strip(),
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def list_customers(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        search: str | None = None,
        is_active: bool | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> list[Customer]:
        """Fetch paginated customer records matching search criteria."""
        stmt = select(Customer).where(Customer.business_id == business_id)

        if is_active is not None:
            stmt = stmt.where(Customer.is_active == is_active)

        if search and search.strip():
            term = f"%{search.strip()}%"
            stmt = stmt.where(
                or_(
                    Customer.name.ilike(term),
                    Customer.phone.ilike(term),
                    Customer.email.ilike(term),
                )
            )

        stmt = stmt.order_by(Customer.created_at.desc())
        offset = (page - 1) * page_size
        stmt = stmt.offset(offset).limit(page_size)

        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def count_customers(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        search: str | None = None,
        is_active: bool | None = None,
    ) -> int:
        """Count total customers matching filter criteria."""
        stmt = select(func.count(Customer.id)).where(Customer.business_id == business_id)

        if is_active is not None:
            stmt = stmt.where(Customer.is_active == is_active)

        if search and search.strip():
            term = f"%{search.strip()}%"
            stmt = stmt.where(
                or_(
                    Customer.name.ilike(term),
                    Customer.phone.ilike(term),
                    Customer.email.ilike(term),
                )
            )

        result = await session.execute(stmt)
        return int(result.scalar_one() or 0)

    async def get_customer_financial_metrics(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
    ) -> tuple[Decimal, int, Decimal]:
        """Calculates (due_balance, total_sales_count, total_spent) for a single customer."""
        stmt = select(
            func.coalesce(func.sum(Sale.due_total), 0).label("due_balance"),
            func.count(Sale.id).label("total_sales_count"),
            func.coalesce(func.sum(Sale.paid_total), 0).label("total_spent"),
        ).where(
            Sale.business_id == business_id,
            Sale.customer_id == customer_id,
            Sale.status != "VOIDED",
        )
        result = await session.execute(stmt)
        row = result.one()
        return (
            Decimal(str(row[0])),
            int(row[1] or 0),
            Decimal(str(row[2])),
        )

    async def get_batch_financial_metrics(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_ids: list[uuid.UUID],
    ) -> dict[uuid.UUID, tuple[Decimal, int, Decimal]]:
        """Batch aggregates financial metrics for multiple customers to prevent N+1 queries."""
        if not customer_ids:
            return {}

        stmt = (
            select(
                Sale.customer_id,
                func.coalesce(func.sum(Sale.due_total), 0).label("due_balance"),
                func.count(Sale.id).label("total_sales_count"),
                func.coalesce(func.sum(Sale.paid_total), 0).label("total_spent"),
            )
            .where(
                Sale.business_id == business_id,
                Sale.customer_id.in_(customer_ids),
                Sale.status != "VOIDED",
            )
            .group_by(Sale.customer_id)
        )
        result = await session.execute(stmt)
        metrics: dict[uuid.UUID, tuple[Decimal, int, Decimal]] = {}
        for row in result.all():
            if row[0]:
                metrics[row[0]] = (
                    Decimal(str(row[1])),
                    int(row[2] or 0),
                    Decimal(str(row[3])),
                )
        return metrics

    async def get_total_business_outstanding_dues(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
    ) -> Decimal:
        """Returns total unpaid customer dues across the entire business."""
        stmt = select(func.coalesce(func.sum(Sale.due_total), 0)).where(
            Sale.business_id == business_id,
            Sale.status != "VOIDED",
            Sale.due_total > 0,
        )
        result = await session.execute(stmt)
        return Decimal(str(result.scalar_one() or 0))

    async def get_unpaid_sales_for_update(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
        specific_sale_id: uuid.UUID | None = None,
    ) -> list[Sale]:
        """Fetches customer sales with outstanding due_total > 0 locked with FOR UPDATE."""
        stmt = (
            select(Sale)
            .where(
                Sale.business_id == business_id,
                Sale.customer_id == customer_id,
                Sale.status != "VOIDED",
                Sale.due_total > 0,
            )
            .order_by(Sale.created_at.asc())  # FIFO
            .with_for_update()
        )
        if specific_sale_id:
            stmt = stmt.where(Sale.id == specific_sale_id)

        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_customer_sales_and_tenders_for_ledger(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        customer_id: uuid.UUID,
    ) -> list[tuple[Sale, list[PaymentTender]]]:
        """Fetches sales and payment tenders for ledger statement generation."""
        from sqlalchemy.orm import selectinload

        stmt = (
            select(Sale)
            .options(selectinload(Sale.payments))
            .where(
                Sale.business_id == business_id,
                Sale.customer_id == customer_id,
                Sale.status != "VOIDED",
            )
            .order_by(Sale.created_at.asc())
        )
        result = await session.execute(stmt)
        sales = result.scalars().all()
        return [(s, list(s.payments)) for s in sales]

    async def create(self, session: AsyncSession, customer: Customer) -> Customer:
        """Persist new customer profile."""
        session.add(customer)
        return customer
