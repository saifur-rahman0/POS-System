"""Repository for Sales returns, refunds, and return items."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.returns.models import Return, ReturnItem


class ReturnsRepository:
    """Database interactions for sales returns and refund ledgers."""

    async def get_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        return_id: uuid.UUID,
    ) -> Return | None:
        """Fetch return header with items loaded."""
        stmt = (
            select(Return)
            .options(selectinload(Return.items))
            .where(
                Return.business_id == business_id,
                Return.id == return_id,
            )
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def list_by_sale_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        sale_id: uuid.UUID,
    ) -> list[Return]:
        """Fetch all return records associated with an original sale."""
        stmt = (
            select(Return)
            .options(selectinload(Return.items))
            .where(
                Return.business_id == business_id,
                Return.original_sale_id == sale_id,
            )
            .order_by(Return.created_at.desc())
        )
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_returned_quantities(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        sale_id: uuid.UUID,
    ) -> dict[uuid.UUID, Decimal]:
        """Calculates total quantity returned so far for each sale_item_id of a sale."""
        stmt = (
            select(
                ReturnItem.original_sale_item_id,
                func.sum(ReturnItem.quantity).label("total_returned"),
            )
            .join(Return, ReturnItem.return_id == Return.id)
            .where(
                Return.business_id == business_id,
                Return.original_sale_id == sale_id,
                Return.status == "COMPLETED",
            )
            .group_by(ReturnItem.original_sale_item_id)
        )
        result = await session.execute(stmt)
        return {row[0]: Decimal(str(row[1])) for row in result.all()}

    async def generate_return_number(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch: Branch,
        now: datetime | None = None,
    ) -> str:
        """Generates the next sequential gapless return number for the branch.

        Format: RET-{YYYYMMDD}-{BRANCH_CODE}-{SEQ:04d}
        Example: RET-20261103-MAIN-0001
        """
        current_date = now or datetime.now(UTC)
        date_str = current_date.strftime("%Y%m%d")
        branch_code = (branch.code or "MAIN").strip().upper()
        prefix = f"RET-{date_str}-{branch_code}-"

        stmt = (
            select(Return.return_no)
            .where(
                Return.business_id == business_id,
                Return.branch_id == branch.id,
                Return.return_no.like(f"{prefix}%"),
            )
            .order_by(Return.return_no.desc())
            .limit(1)
        )
        result = await session.execute(stmt)
        last_return = result.scalars().first()

        next_seq = 1
        if last_return and last_return.startswith(prefix):
            suffix = last_return[len(prefix) :]
            try:
                next_seq = int(suffix) + 1
            except ValueError:
                next_seq = 1

        return f"{prefix}{next_seq:04d}"

    async def create(
        self,
        session: AsyncSession,
        return_obj: Return,
        items: list[ReturnItem],
    ) -> Return:
        """Persist return header and items."""
        session.add(return_obj)
        for item in items:
            item.return_id = return_obj.id
            session.add(item)
        return return_obj

