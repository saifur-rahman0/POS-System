"""Inventory Transfer Service: Inter-branch shipments, stock movement audit, and cross-branch queries."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.catalog.models import Product, ProductVariant
from app.modules.identity.models import User
from app.modules.inventory.models import (
    StockBalance,
    StockMovement,
    StockTransfer,
    StockTransferItem,
)
from app.modules.inventory.transfer_schemas import (
    CrossBranchStockOut,
    StockTransferItemOut,
    StockTransferOut,
    TransferCreate,
)
from app.shared.exceptions import AppException


class StockTransferService:
    """Manages inter-branch inventory transfer workflows, atomic dispatches, and receptions."""

    def _to_naive_utc(self, dt: datetime | None) -> datetime | None:
        if dt is None:
            return None
        if dt.tzinfo is not None:
            return dt.astimezone(UTC).replace(tzinfo=None)
        return dt

    async def _generate_transfer_no(self, session: AsyncSession, business_id: uuid.UUID) -> str:
        """Generates sequential daily transfer identifier (TRF-YYYYMMDD-0001)."""
        today_str = datetime.now(UTC).strftime("%Y%m%d")
        prefix = f"TRF-{today_str}-"

        stmt = (
            select(StockTransfer.transfer_no)
            .where(
                StockTransfer.business_id == business_id,
                StockTransfer.transfer_no.like(f"{prefix}%"),
            )
            .order_by(StockTransfer.transfer_no.desc())
            .limit(1)
        )
        res = await session.execute(stmt)
        last_no = res.scalar()

        if last_no:
            try:
                seq = int(last_no.split("-")[-1]) + 1
            except ValueError:
                seq = 1
        else:
            seq = 1

        return f"{prefix}{seq:04d}"

    def _map_transfer_out(
        self,
        t: StockTransfer,
        branch_map: dict[uuid.UUID, str],
        variant_map: dict[uuid.UUID, tuple[str, str, str | None]],
    ) -> StockTransferOut:
        """Helper to serialize StockTransfer with enriched titles and lines."""
        item_outs: list[StockTransferItemOut] = []
        total_qty = Decimal("0.0000")

        for item in t.items:
            total_qty += item.quantity
            prod_name, var_name, sku = variant_map.get(
                item.product_variant_id, ("Product", "Standard", None)
            )
            item_outs.append(
                StockTransferItemOut(
                    id=item.id,
                    transfer_id=item.transfer_id,
                    product_variant_id=item.product_variant_id,
                    product_name=prod_name,
                    variant_name=var_name,
                    sku=sku,
                    quantity=item.quantity,
                    unit_cost=item.unit_cost,
                )
            )

        return StockTransferOut(
            id=t.id,
            business_id=t.business_id,
            transfer_no=t.transfer_no,
            source_branch_id=t.source_branch_id,
            source_branch_name=branch_map.get(t.source_branch_id, "Source Store"),
            destination_branch_id=t.destination_branch_id,
            destination_branch_name=branch_map.get(t.destination_branch_id, "Destination Store"),
            status=t.status,
            created_by=t.created_by,
            received_by=t.received_by,
            notes=t.notes,
            created_at=t.created_at,
            sent_at=t.sent_at,
            received_at=t.received_at,
            total_items_count=len(t.items),
            total_quantity=total_qty,
            items=item_outs,
        )

    async def _resolve_maps(
        self, session: AsyncSession, business_id: uuid.UUID
    ) -> tuple[dict[uuid.UUID, str], dict[uuid.UUID, tuple[str, str, str | None]]]:
        """Resolves branches and variant names dictionary."""
        b_stmt = select(Branch.id, Branch.name).where(Branch.business_id == business_id)
        branches = (await session.execute(b_stmt)).all()
        branch_map = {b[0]: b[1] for b in branches}

        v_stmt = (
            select(ProductVariant.id, Product.name, ProductVariant.name, Product.sku)
            .join(Product, ProductVariant.product_id == Product.id)
            .where(ProductVariant.business_id == business_id)
        )
        variants = (await session.execute(v_stmt)).all()
        variant_map: dict[uuid.UUID, tuple[str, str, str | None]] = {
            v[0]: (v[1], v[2], v[3]) for v in variants
        }

        return branch_map, variant_map

    async def list_transfers(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        source_branch_id: uuid.UUID | None = None,
        destination_branch_id: uuid.UUID | None = None,
        status: str | None = None,
    ) -> list[StockTransferOut]:
        """List historical and in-flight stock transfers."""
        stmt = (
            select(StockTransfer)
            .options(selectinload(StockTransfer.items))
            .where(StockTransfer.business_id == business_id)
        )
        if source_branch_id:
            stmt = stmt.where(StockTransfer.source_branch_id == source_branch_id)
        if destination_branch_id:
            stmt = stmt.where(StockTransfer.destination_branch_id == destination_branch_id)
        if status:
            stmt = stmt.where(StockTransfer.status == status.upper())

        stmt = stmt.order_by(StockTransfer.created_at.desc())
        res = await session.execute(stmt)
        transfers = res.scalars().all()

        branch_map, variant_map = await self._resolve_maps(session, business_id)
        return [self._map_transfer_out(t, branch_map, variant_map) for t in transfers]

    async def get_transfer(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        transfer_id: uuid.UUID,
    ) -> StockTransferOut:
        """Fetch transfer details by ID."""
        stmt = (
            select(StockTransfer)
            .options(selectinload(StockTransfer.items))
            .where(
                StockTransfer.id == transfer_id,
                StockTransfer.business_id == business_id,
            )
        )
        res = await session.execute(stmt)
        t = res.scalars().first()
        if not t:
            raise AppException(
                message="Stock transfer order not found",
                code="TRANSFER_NOT_FOUND",
                status_code=404,
            )
        branch_map, variant_map = await self._resolve_maps(session, business_id)
        return self._map_transfer_out(t, branch_map, variant_map)

    async def create_transfer(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: TransferCreate,
    ) -> StockTransferOut:
        """Creates a draft inter-branch transfer shipment."""
        if payload.source_branch_id == payload.destination_branch_id:
            raise AppException(
                message="Source and destination branches cannot be the same",
                code="INVALID_BRANCH_SELECTION",
                status_code=400,
            )

        # Verify source and destination branches
        s_branch = await session.get(Branch, payload.source_branch_id)
        d_branch = await session.get(Branch, payload.destination_branch_id)
        if not s_branch or s_branch.business_id != business_id or not s_branch.is_active:
            raise AppException(
                message="Source branch not found or inactive",
                code="SOURCE_BRANCH_INVALID",
                status_code=404,
            )
        if not d_branch or d_branch.business_id != business_id or not d_branch.is_active:
            raise AppException(
                message="Destination branch not found or inactive",
                code="DESTINATION_BRANCH_INVALID",
                status_code=404,
            )

        # Verify user exists for FK constraint
        cashier = await session.get(User, user_id)
        if not cashier:
            fallback_u = (
                (await session.execute(select(User).where(User.is_active.is_(True)).limit(1)))
                .scalars()
                .first()
            )
            if fallback_u:
                user_id = fallback_u.id

        transfer_no = await self._generate_transfer_no(session, business_id)
        transfer = StockTransfer(
            business_id=business_id,
            transfer_no=transfer_no,
            source_branch_id=payload.source_branch_id,
            destination_branch_id=payload.destination_branch_id,
            status="DRAFT",
            created_by=user_id,
            notes=payload.notes,
        )
        session.add(transfer)
        await session.flush()

        for item_in in payload.items:
            variant = await session.get(ProductVariant, item_in.product_variant_id)
            if not variant or variant.business_id != business_id:
                raise AppException(
                    message=f"Product variant {item_in.product_variant_id} not found",
                    code="VARIANT_NOT_FOUND",
                    status_code=404,
                )
            t_item = StockTransferItem(
                transfer_id=transfer.id,
                product_variant_id=item_in.product_variant_id,
                quantity=item_in.quantity,
                unit_cost=variant.cost_price,
            )
            session.add(t_item)

        await session.commit()
        return await self.get_transfer(session, business_id, transfer.id)

    async def send_transfer(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        transfer_id: uuid.UUID,
    ) -> StockTransferOut:
        """Dispatches transfer: locks source stock, validates availability, and decrements inventory."""
        stmt = (
            select(StockTransfer)
            .options(selectinload(StockTransfer.items))
            .where(
                StockTransfer.id == transfer_id,
                StockTransfer.business_id == business_id,
            )
            .with_for_update()
        )
        res = await session.execute(stmt)
        t = res.scalars().first()
        if not t:
            raise AppException(
                message="Transfer not found",
                code="TRANSFER_NOT_FOUND",
                status_code=404,
            )
        if t.status != "DRAFT":
            raise AppException(
                message=f"Cannot dispatch transfer in '{t.status}' status",
                code="INVALID_TRANSFER_STATUS",
                status_code=400,
            )

        # Validate and lock source stock balances
        for item in t.items:
            bal_stmt = (
                select(StockBalance)
                .where(
                    StockBalance.business_id == business_id,
                    StockBalance.branch_id == t.source_branch_id,
                    StockBalance.product_variant_id == item.product_variant_id,
                )
                .with_for_update()
            )
            bal_res = await session.execute(bal_stmt)
            balance = bal_res.scalars().first()
            available = balance.quantity_on_hand if balance else Decimal("0.0000")

            if available < item.quantity:
                raise AppException(
                    message=f"Insufficient source stock for item {item.product_variant_id}. Required: {item.quantity}, Available: {available}",
                    code="INSUFFICIENT_STOCK",
                    status_code=409,
                    details={
                        "product_variant_id": str(item.product_variant_id),
                        "requested": str(item.quantity),
                        "available": str(available),
                    },
                )

            # Decrement source stock
            balance.quantity_on_hand -= item.quantity  # type: ignore

            # Record ledger audit entry
            movement = StockMovement(
                business_id=business_id,
                branch_id=t.source_branch_id,
                product_variant_id=item.product_variant_id,
                movement_type="TRANSFER_OUT",
                quantity_delta=-item.quantity,
                unit_cost=item.unit_cost,
                reference_type="TRANSFER",
                reference_id=t.id,
                created_by=user_id,
            )
            session.add(movement)

        t.status = "IN_TRANSIT"
        t.sent_at = self._to_naive_utc(datetime.now(UTC))
        await session.commit()
        return await self.get_transfer(session, business_id, t.id)

    async def receive_transfer(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        transfer_id: uuid.UUID,
    ) -> StockTransferOut:
        """Receives shipment at destination branch: increments destination stock and completes transfer."""
        stmt = (
            select(StockTransfer)
            .options(selectinload(StockTransfer.items))
            .where(
                StockTransfer.id == transfer_id,
                StockTransfer.business_id == business_id,
            )
            .with_for_update()
        )
        res = await session.execute(stmt)
        t = res.scalars().first()
        if not t:
            raise AppException(
                message="Transfer not found",
                code="TRANSFER_NOT_FOUND",
                status_code=404,
            )
        if t.status != "IN_TRANSIT":
            raise AppException(
                message=f"Cannot receive transfer in '{t.status}' status (must be IN_TRANSIT)",
                code="INVALID_TRANSFER_STATUS",
                status_code=400,
            )

        # Increment destination stock balances
        for item in t.items:
            bal_stmt = (
                select(StockBalance)
                .where(
                    StockBalance.business_id == business_id,
                    StockBalance.branch_id == t.destination_branch_id,
                    StockBalance.product_variant_id == item.product_variant_id,
                )
                .with_for_update()
            )
            bal_res = await session.execute(bal_stmt)
            balance = bal_res.scalars().first()
            if not balance:
                balance = StockBalance(
                    business_id=business_id,
                    branch_id=t.destination_branch_id,
                    product_variant_id=item.product_variant_id,
                    quantity_on_hand=Decimal("0.0000"),
                )
                session.add(balance)
                await session.flush()

            balance.quantity_on_hand += item.quantity

            # Record ledger audit entry
            movement = StockMovement(
                business_id=business_id,
                branch_id=t.destination_branch_id,
                product_variant_id=item.product_variant_id,
                movement_type="TRANSFER_IN",
                quantity_delta=item.quantity,
                unit_cost=item.unit_cost,
                reference_type="TRANSFER",
                reference_id=t.id,
                created_by=user_id,
            )
            session.add(movement)

        t.status = "RECEIVED"
        t.received_by = user_id
        t.received_at = self._to_naive_utc(datetime.now(UTC))
        await session.commit()
        return await self.get_transfer(session, business_id, t.id)

    async def cancel_transfer(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        transfer_id: uuid.UUID,
    ) -> StockTransferOut:
        """Cancels a transfer. If was IN_TRANSIT, restores inventory to source branch."""
        stmt = (
            select(StockTransfer)
            .options(selectinload(StockTransfer.items))
            .where(
                StockTransfer.id == transfer_id,
                StockTransfer.business_id == business_id,
            )
            .with_for_update()
        )
        res = await session.execute(stmt)
        t = res.scalars().first()
        if not t:
            raise AppException(
                message="Transfer not found",
                code="TRANSFER_NOT_FOUND",
                status_code=404,
            )
        if t.status in ("RECEIVED", "CANCELLED"):
            raise AppException(
                message=f"Cannot cancel transfer in '{t.status}' status",
                code="CANNOT_CANCEL_TRANSFER",
                status_code=400,
            )

        if t.status == "IN_TRANSIT":
            # Restore stock on source branch
            for item in t.items:
                bal_stmt = (
                    select(StockBalance)
                    .where(
                        StockBalance.business_id == business_id,
                        StockBalance.branch_id == t.source_branch_id,
                        StockBalance.product_variant_id == item.product_variant_id,
                    )
                    .with_for_update()
                )
                bal_res = await session.execute(bal_stmt)
                balance = bal_res.scalars().first()
                if balance:
                    balance.quantity_on_hand += item.quantity

                movement = StockMovement(
                    business_id=business_id,
                    branch_id=t.source_branch_id,
                    product_variant_id=item.product_variant_id,
                    movement_type="TRANSFER_IN",
                    quantity_delta=item.quantity,
                    unit_cost=item.unit_cost,
                    reference_type="TRANSFER",
                    reference_id=t.id,
                    created_by=user_id,
                )
                session.add(movement)

        t.status = "CANCELLED"
        await session.commit()
        return await self.get_transfer(session, business_id, t.id)

    async def get_cross_branch_stock(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        product_variant_id: uuid.UUID,
    ) -> list[CrossBranchStockOut]:
        """Queries current on-hand inventory for a variant across all branches."""
        stmt = (
            select(
                Branch.id,
                Branch.name,
                Branch.code,
                Branch.is_active,
                func.coalesce(StockBalance.quantity_on_hand, Decimal("0.0000")).label("qty"),
            )
            .outerjoin(
                StockBalance,
                (StockBalance.branch_id == Branch.id)
                & (StockBalance.product_variant_id == product_variant_id),
            )
            .where(
                Branch.business_id == business_id,
                Branch.is_active.is_(True),
            )
            .order_by(Branch.name.asc())
        )
        res = await session.execute(stmt)
        rows = res.all()

        return [
            CrossBranchStockOut(
                branch_id=r[0],
                branch_name=r[1],
                branch_code=r[2],
                is_active=r[3],
                quantity_on_hand=Decimal(str(r[4])),
            )
            for r in rows
        ]
