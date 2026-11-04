"""SQLAlchemy repository for RegisterShift entities and shift history."""

import uuid
from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.shifts.models import RegisterShift


class ShiftRepository:
    """Database interactions for RegisterShift sessions."""

    def _base_query(self, business_id: uuid.UUID) -> Select[RegisterShift]:
        return (
            select(RegisterShift)
            .where(RegisterShift.business_id == business_id)
            .options(
                selectinload(RegisterShift.branch),
                selectinload(RegisterShift.user),
            )
        )

    async def get_by_id(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        shift_id: uuid.UUID,
        for_update: bool = False,
    ) -> RegisterShift | None:
        """Fetch shift by ID within business scope."""
        stmt = self._base_query(business_id).where(RegisterShift.id == shift_id)
        if for_update:
            stmt = stmt.with_for_update()
        res = await session.execute(stmt)
        return res.scalars().first()

    async def get_open_shift(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        for_update: bool = False,
    ) -> RegisterShift | None:
        """Fetch currently open shift for a specific user, optionally constrained to branch."""
        stmt = (
            self._base_query(business_id)
            .where(
                RegisterShift.user_id == user_id,
                RegisterShift.status == "OPEN",
            )
            .order_by(RegisterShift.opened_at.desc())
        )
        if branch_id:
            stmt = stmt.where(RegisterShift.branch_id == branch_id)
        if for_update:
            stmt = stmt.with_for_update()
        res = await session.execute(stmt)
        return res.scalars().first()

    async def create(
        self,
        session: AsyncSession,
        shift: RegisterShift,
    ) -> RegisterShift:
        """Persist a new register shift session."""
        session.add(shift)
        await session.flush()
        return shift

    async def list_shifts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        user_id: uuid.UUID | None = None,
        status: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> Sequence[RegisterShift]:
        """Fetch paginated shift history."""
        stmt = self._base_query(business_id)
        if branch_id:
            stmt = stmt.where(RegisterShift.branch_id == branch_id)
        if user_id:
            stmt = stmt.where(RegisterShift.user_id == user_id)
        if status:
            stmt = stmt.where(RegisterShift.status == status.upper())
        if start_date:
            stmt = stmt.where(RegisterShift.opened_at >= start_date)
        if end_date:
            stmt = stmt.where(RegisterShift.opened_at <= end_date)

        offset = (page - 1) * page_size
        stmt = stmt.order_by(RegisterShift.opened_at.desc()).offset(offset).limit(page_size)
        res = await session.execute(stmt)
        return res.scalars().all()

    async def count_shifts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        user_id: uuid.UUID | None = None,
        status: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
    ) -> int:
        """Count matching register shifts."""
        stmt = select(func.count(RegisterShift.id)).where(RegisterShift.business_id == business_id)
        if branch_id:
            stmt = stmt.where(RegisterShift.branch_id == branch_id)
        if user_id:
            stmt = stmt.where(RegisterShift.user_id == user_id)
        if status:
            stmt = stmt.where(RegisterShift.status == status.upper())
        if start_date:
            stmt = stmt.where(RegisterShift.opened_at >= start_date)
        if end_date:
            stmt = stmt.where(RegisterShift.opened_at <= end_date)

        res = await session.execute(stmt)
        return res.scalar_one() or 0
