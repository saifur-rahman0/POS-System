"""Business and Branch management service."""

import uuid
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.business.models import Branch, Business
from app.modules.business.schemas import BranchCreate, BranchDetailOut, BranchOut, BranchUpdate
from app.modules.inventory.models import StockBalance
from app.modules.shifts.models import RegisterShift
from app.shared.exceptions import AppException


class BranchService:
    """Handles multi-store branch locations, configurations, and inventory rollups."""

    async def list_branches(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        is_active: bool | None = None,
    ) -> list[BranchOut]:
        """List all branches belonging to the tenant."""
        stmt = select(Branch).where(Branch.business_id == business_id)
        if is_active is not None:
            stmt = stmt.where(Branch.is_active == is_active)
        stmt = stmt.order_by(Branch.created_at.asc())

        res = await session.execute(stmt)
        return [BranchOut.model_validate(b) for b in res.scalars().all()]

    async def get_branch(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
    ) -> BranchOut:
        """Fetch single branch profile."""
        stmt = select(Branch).where(
            Branch.id == branch_id,
            Branch.business_id == business_id,
        )
        res = await session.execute(stmt)
        branch = res.scalars().first()
        if not branch:
            raise AppException(
                message="Branch not found",
                code="BRANCH_NOT_FOUND",
                status_code=404,
            )
        return BranchOut.model_validate(branch)

    async def get_branch_detail(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
    ) -> BranchDetailOut:
        """Fetch detailed branch profile with stock KPIs and shift status."""
        stmt = select(Branch).where(
            Branch.id == branch_id,
            Branch.business_id == business_id,
        )
        res = await session.execute(stmt)
        branch = res.scalars().first()
        if not branch:
            raise AppException(
                message="Branch not found",
                code="BRANCH_NOT_FOUND",
                status_code=404,
            )

        # Inventory aggregations
        stock_stmt = select(
            func.count(StockBalance.product_variant_id),
            func.coalesce(func.sum(StockBalance.quantity_on_hand), Decimal("0.0000")),
        ).where(
            StockBalance.business_id == business_id,
            StockBalance.branch_id == branch_id,
            StockBalance.quantity_on_hand > 0,
        )
        stock_res = await session.execute(stock_stmt)
        stock_count, total_qty = stock_res.first() or (0, Decimal("0.0000"))

        # Check for open register shifts
        shift_stmt = select(func.count(RegisterShift.id)).where(
            RegisterShift.business_id == business_id,
            RegisterShift.branch_id == branch_id,
            RegisterShift.status == "OPEN",
        )
        shift_count = (await session.execute(shift_stmt)).scalar() or 0

        return BranchDetailOut(
            id=branch.id,
            business_id=branch.business_id,
            name=branch.name,
            code=branch.code,
            address=branch.address,
            phone=branch.phone,
            is_active=branch.is_active,
            created_at=branch.created_at,
            updated_at=branch.updated_at,
            total_variants_in_stock=stock_count,
            total_stock_quantity=Decimal(str(total_qty)),
            has_active_shift=shift_count > 0,
        )

    async def create_branch(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: BranchCreate,
    ) -> BranchOut:
        """Create a new branch for the business."""
        # Verify business exists
        biz = await session.get(Business, business_id)
        if not biz:
            raise AppException(
                message="Business tenant not found",
                code="BUSINESS_NOT_FOUND",
                status_code=404,
            )

        # Check duplicate name
        name_stmt = select(Branch).where(
            Branch.business_id == business_id,
            func.lower(Branch.name) == payload.name.lower(),
        )
        if (await session.execute(name_stmt)).scalars().first():
            raise AppException(
                message=f"Branch with name '{payload.name}' already exists",
                code="DUPLICATE_BRANCH_NAME",
                status_code=409,
            )

        # Generate or check code
        code = payload.code
        if code:
            code_stmt = select(Branch).where(
                Branch.business_id == business_id,
                Branch.code == code,
            )
            if (await session.execute(code_stmt)).scalars().first():
                raise AppException(
                    message=f"Branch with code '{code}' already exists",
                    code="DUPLICATE_BRANCH_CODE",
                    status_code=409,
                )
        else:
            # Auto-generate next branch code
            count_stmt = select(func.count(Branch.id)).where(Branch.business_id == business_id)
            total = (await session.execute(count_stmt)).scalar() or 0
            code = f"BR-{(total + 1):02d}"

        branch = Branch(
            business_id=business_id,
            name=payload.name,
            code=code,
            address=payload.address,
            phone=payload.phone,
            is_active=payload.is_active,
        )
        session.add(branch)
        await session.commit()
        await session.refresh(branch)
        return BranchOut.model_validate(branch)

    async def update_branch(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        payload: BranchUpdate,
    ) -> BranchOut:
        """Update branch details."""
        stmt = select(Branch).where(
            Branch.id == branch_id,
            Branch.business_id == business_id,
        )
        res = await session.execute(stmt)
        branch = res.scalars().first()
        if not branch:
            raise AppException(
                message="Branch not found",
                code="BRANCH_NOT_FOUND",
                status_code=404,
            )

        if payload.name is not None and payload.name.lower() != branch.name.lower():
            dup_stmt = select(Branch).where(
                Branch.business_id == business_id,
                Branch.id != branch_id,
                func.lower(Branch.name) == payload.name.lower(),
            )
            if (await session.execute(dup_stmt)).scalars().first():
                raise AppException(
                    message=f"Branch with name '{payload.name}' already exists",
                    code="DUPLICATE_BRANCH_NAME",
                    status_code=409,
                )
            branch.name = payload.name

        if payload.code is not None and payload.code != branch.code:
            dup_code = select(Branch).where(
                Branch.business_id == business_id,
                Branch.id != branch_id,
                Branch.code == payload.code,
            )
            if (await session.execute(dup_code)).scalars().first():
                raise AppException(
                    message=f"Branch with code '{payload.code}' already exists",
                    code="DUPLICATE_BRANCH_CODE",
                    status_code=409,
                )
            branch.code = payload.code

        if payload.address is not None:
            branch.address = payload.address
        if payload.phone is not None:
            branch.phone = payload.phone
        if payload.is_active is not None:
            branch.is_active = payload.is_active

        await session.commit()
        await session.refresh(branch)
        return BranchOut.model_validate(branch)
