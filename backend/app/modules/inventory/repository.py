"""Repository for inventory balances, stock movements, batches, counts, and reservations."""

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.catalog.models import Product, ProductVariant
from app.modules.inventory.models import (
    DamagedStockRecord,
    InventoryBatch,
    StockBalance,
    StockCount,
    StockMovement,
    StockReservation,
)


class InventoryRepository:
    """Database interactions for physical inventory stock balances and ledger."""

    async def get_balance(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        product_variant_id: uuid.UUID,
        for_update: bool = False,
    ) -> StockBalance | None:
        """Fetch stock balance for a single variant in a branch, optionally acquiring a row lock."""
        stmt = select(StockBalance).where(
            StockBalance.business_id == business_id,
            StockBalance.branch_id == branch_id,
            StockBalance.product_variant_id == product_variant_id,
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_balances_for_update(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        variant_ids: list[uuid.UUID],
    ) -> dict[uuid.UUID, StockBalance]:
        """Fetch multiple variant stock balances ordered lexicographically with pessimistic row locks."""
        if not variant_ids:
            return {}

        # Sort variant IDs to prevent database deadlocks across concurrent checkouts
        sorted_ids = sorted(variant_ids)

        stmt = (
            select(StockBalance)
            .where(
                StockBalance.business_id == business_id,
                StockBalance.branch_id == branch_id,
                StockBalance.product_variant_id.in_(sorted_ids),
            )
            .with_for_update()
        )
        result = await session.execute(stmt)
        balances = result.scalars().all()
        return {b.product_variant_id: b for b in balances}

    async def set_balance(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        product_variant_id: uuid.UUID,
        quantity: Decimal,
    ) -> StockBalance:
        """Create or update stock balance quantity on hand."""
        balance = await self.get_balance(
            session, business_id, branch_id, product_variant_id, for_update=True
        )
        if balance:
            balance.quantity_on_hand = quantity
        else:
            balance = StockBalance(
                business_id=business_id,
                branch_id=branch_id,
                product_variant_id=product_variant_id,
                quantity_on_hand=quantity,
            )
            session.add(balance)
        return balance

    async def record_movement(
        self,
        session: AsyncSession,
        movement: StockMovement,
    ) -> StockMovement:
        """Append an immutable audit entry to stock movements ledger."""
        session.add(movement)
        return movement

    async def list_movements(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        product_variant_id: uuid.UUID | None = None,
        movement_type: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> list[StockMovement]:
        """Fetch filtered and paginated stock movement audit trail."""
        stmt = select(StockMovement).where(StockMovement.business_id == business_id)

        if branch_id:
            stmt = stmt.where(StockMovement.branch_id == branch_id)
        if product_variant_id:
            stmt = stmt.where(StockMovement.product_variant_id == product_variant_id)
        if movement_type:
            stmt = stmt.where(StockMovement.movement_type == movement_type)
        if start_date:
            stmt = stmt.where(StockMovement.created_at >= start_date)
        if end_date:
            stmt = stmt.where(StockMovement.created_at <= end_date)

        stmt = stmt.order_by(StockMovement.created_at.desc())
        stmt = stmt.offset((page - 1) * page_size).limit(page_size)

        res = await session.execute(stmt)
        return list(res.scalars().all())

    async def count_movements(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        product_variant_id: uuid.UUID | None = None,
        movement_type: str | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
    ) -> int:
        """Count filtered stock movements."""
        stmt = select(func.count(StockMovement.id)).where(StockMovement.business_id == business_id)

        if branch_id:
            stmt = stmt.where(StockMovement.branch_id == branch_id)
        if product_variant_id:
            stmt = stmt.where(StockMovement.product_variant_id == product_variant_id)
        if movement_type:
            stmt = stmt.where(StockMovement.movement_type == movement_type)
        if start_date:
            stmt = stmt.where(StockMovement.created_at >= start_date)
        if end_date:
            stmt = stmt.where(StockMovement.created_at <= end_date)

        res = await session.execute(stmt)
        return res.scalar_one()

    # -------------------------------------------------------------------------
    # Inventory Batches & FEFO Picking
    # -------------------------------------------------------------------------
    async def create_batch(
        self,
        session: AsyncSession,
        batch: InventoryBatch,
    ) -> InventoryBatch:
        """Inward record a new inventory batch."""
        session.add(batch)
        await session.flush()
        return batch

    async def get_batch(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        batch_id: uuid.UUID,
        for_update: bool = False,
    ) -> InventoryBatch | None:
        """Fetch a specific batch with optional row locking."""
        stmt = select(InventoryBatch).where(
            InventoryBatch.business_id == business_id,
            InventoryBatch.id == batch_id,
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await session.execute(stmt)
        return result.scalars().first()

    async def get_batch_by_number(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        product_variant_id: uuid.UUID,
        batch_number: str,
    ) -> InventoryBatch | None:
        """Find batch by its unique composite identifier."""
        stmt = select(InventoryBatch).where(
            InventoryBatch.business_id == business_id,
            InventoryBatch.branch_id == branch_id,
            InventoryBatch.product_variant_id == product_variant_id,
            InventoryBatch.batch_number == batch_number,
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def list_batches(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        product_variant_id: uuid.UUID | None = None,
        is_active: bool | None = None,
    ) -> list[InventoryBatch]:
        """List inventory batches with filters."""
        stmt = select(InventoryBatch).where(InventoryBatch.business_id == business_id)
        if branch_id:
            stmt = stmt.where(InventoryBatch.branch_id == branch_id)
        if product_variant_id:
            stmt = stmt.where(InventoryBatch.product_variant_id == product_variant_id)
        if is_active is not None:
            stmt = stmt.where(InventoryBatch.is_active == is_active)

        stmt = stmt.order_by(
            InventoryBatch.expiry_date.asc().nullslast(),
            InventoryBatch.created_at.asc(),
        )
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_batches_fefo(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        product_variant_id: uuid.UUID,
        for_update: bool = True,
    ) -> list[InventoryBatch]:
        """Fetch active batches with stock ordered by FEFO (First-Expired, First-Out)."""
        stmt = (
            select(InventoryBatch)
            .where(
                InventoryBatch.business_id == business_id,
                InventoryBatch.branch_id == branch_id,
                InventoryBatch.product_variant_id == product_variant_id,
                InventoryBatch.is_active.is_(True),
                InventoryBatch.quantity_on_hand > 0,
            )
            .order_by(
                InventoryBatch.expiry_date.asc().nullslast(),
                InventoryBatch.created_at.asc(),
            )
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def get_expiring_batches(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        days_threshold: int = 60,
    ) -> list[InventoryBatch]:
        """Fetch batches expiring within days_threshold or already expired."""
        cutoff_date = datetime.now(UTC).date() + timedelta(days=days_threshold)
        stmt = select(InventoryBatch).where(
            InventoryBatch.business_id == business_id,
            InventoryBatch.is_active.is_(True),
            InventoryBatch.quantity_on_hand > 0,
            InventoryBatch.expiry_date.is_not(None),
            InventoryBatch.expiry_date <= cutoff_date,
        )
        if branch_id:
            stmt = stmt.where(InventoryBatch.branch_id == branch_id)

        stmt = stmt.order_by(InventoryBatch.expiry_date.asc())
        result = await session.execute(stmt)
        return list(result.scalars().all())

    # -------------------------------------------------------------------------
    # Damaged Stock Records
    # -------------------------------------------------------------------------
    async def get_next_damaged_voucher_no(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        now: datetime | None = None,
    ) -> str:
        """Generate sequential voucher number formatted as DAM-YYYYMMDD-XXXX."""
        current_date = now or datetime.now(UTC)
        date_str = current_date.strftime("%Y%m%d")
        prefix = f"DAM-{date_str}-"

        stmt = (
            select(DamagedStockRecord.voucher_no)
            .where(
                DamagedStockRecord.business_id == business_id,
                DamagedStockRecord.voucher_no.like(f"{prefix}%"),
            )
            .order_by(DamagedStockRecord.voucher_no.desc())
            .limit(1)
        )
        result = await session.execute(stmt)
        latest = result.scalar_one_or_none()

        seq = 1
        if latest and latest.startswith(prefix):
            try:
                seq = int(latest[len(prefix) :]) + 1
            except ValueError:
                seq = 1
        return f"{prefix}{seq:04d}"

    async def create_damaged_record(
        self,
        session: AsyncSession,
        record: DamagedStockRecord,
    ) -> DamagedStockRecord:
        """Persist damaged stock write-off record."""
        session.add(record)
        await session.flush()
        return record

    async def list_damaged_records(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
    ) -> list[DamagedStockRecord]:
        """Fetch damaged stock records with filters."""
        stmt = select(DamagedStockRecord).where(DamagedStockRecord.business_id == business_id)
        if branch_id:
            stmt = stmt.where(DamagedStockRecord.branch_id == branch_id)
        if start_date:
            stmt = stmt.where(DamagedStockRecord.created_at >= start_date)
        if end_date:
            stmt = stmt.where(DamagedStockRecord.created_at <= end_date)

        stmt = stmt.order_by(DamagedStockRecord.created_at.desc())
        result = await session.execute(stmt)
        return list(result.scalars().all())

    # -------------------------------------------------------------------------
    # Stock Reservations
    # -------------------------------------------------------------------------
    async def get_active_reservations_qty(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        product_variant_id: uuid.UUID,
    ) -> Decimal:
        """Sum quantities of active, unexpired reservations for a variant."""
        now = datetime.now(UTC)
        stmt = select(func.coalesce(func.sum(StockReservation.quantity), Decimal("0.0000"))).where(
            StockReservation.business_id == business_id,
            StockReservation.branch_id == branch_id,
            StockReservation.product_variant_id == product_variant_id,
            StockReservation.status == "ACTIVE",
            StockReservation.reserved_until > now,
        )
        result = await session.execute(stmt)
        return Decimal(result.scalar_one())

    async def create_reservation(
        self,
        session: AsyncSession,
        reservation: StockReservation,
    ) -> StockReservation:
        """Persist a stock reservation."""
        session.add(reservation)
        await session.flush()
        return reservation

    async def get_reservation(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        reservation_id: uuid.UUID,
        for_update: bool = False,
    ) -> StockReservation | None:
        """Fetch reservation by ID."""
        stmt = select(StockReservation).where(
            StockReservation.business_id == business_id,
            StockReservation.id == reservation_id,
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await session.execute(stmt)
        return result.scalars().first()

    async def list_reservations(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        product_variant_id: uuid.UUID | None = None,
        status: str | None = None,
    ) -> list[StockReservation]:
        """List stock reservations."""
        stmt = select(StockReservation).where(StockReservation.business_id == business_id)
        if branch_id:
            stmt = stmt.where(StockReservation.branch_id == branch_id)
        if product_variant_id:
            stmt = stmt.where(StockReservation.product_variant_id == product_variant_id)
        if status:
            stmt = stmt.where(StockReservation.status == status)

        stmt = stmt.order_by(StockReservation.created_at.desc())
        result = await session.execute(stmt)
        return list(result.scalars().all())

    # -------------------------------------------------------------------------
    # Physical Stock Counts (Audits)
    # -------------------------------------------------------------------------
    async def create_stock_count(
        self,
        session: AsyncSession,
        count: StockCount,
    ) -> StockCount:
        """Initiate physical count session."""
        session.add(count)
        await session.flush()
        return count

    async def get_stock_count(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        count_id: uuid.UUID,
    ) -> StockCount | None:
        """Fetch stock count session with lines."""
        stmt = (
            select(StockCount)
            .options(selectinload(StockCount.lines))
            .where(
                StockCount.business_id == business_id,
                StockCount.id == count_id,
            )
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    async def list_stock_counts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        status: str | None = None,
    ) -> list[StockCount]:
        """List stock count audit sessions."""
        stmt = (
            select(StockCount)
            .options(selectinload(StockCount.lines))
            .where(StockCount.business_id == business_id)
        )
        if branch_id:
            stmt = stmt.where(StockCount.branch_id == branch_id)
        if status:
            stmt = stmt.where(StockCount.status == status)

        stmt = stmt.order_by(StockCount.created_at.desc())
        result = await session.execute(stmt)
        return list(result.scalars().all())

    async def find_variant_by_barcode(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        barcode: str,
    ) -> ProductVariant | None:
        """Lookup variant by barcode for fast scanning."""
        stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.barcode == barcode,
                ProductVariant.is_active.is_(True),
            )
        )
        result = await session.execute(stmt)
        return result.scalars().first()

    # -------------------------------------------------------------------------
    # Reorder Queries
    # -------------------------------------------------------------------------
    async def list_reorder_variants(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
    ) -> list[tuple[ProductVariant, StockBalance | None, Decimal]]:
        """Fetch variants configured with min_stock_level > 0 alongside balances and active reservations."""
        now = datetime.now(UTC)

        # 1. Fetch all active variants with min_stock_level > 0
        v_stmt = (
            select(ProductVariant)
            .options(
                selectinload(ProductVariant.product).selectinload(Product.category),
                selectinload(ProductVariant.product).selectinload(Product.brand),
            )
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.is_active.is_(True),
                ProductVariant.track_stock.is_(True),
                ProductVariant.min_stock_level > 0,
            )
        )
        v_result = await session.execute(v_stmt)
        variants = list(v_result.scalars().all())

        if not variants:
            return []

        v_ids = [v.id for v in variants]

        # 2. Fetch balances
        b_stmt = select(StockBalance).where(
            StockBalance.business_id == business_id,
            StockBalance.branch_id == branch_id,
            StockBalance.product_variant_id.in_(v_ids),
        )
        b_res = await session.execute(b_stmt)
        bal_map = {b.product_variant_id: b for b in b_res.scalars().all()}

        # 3. Fetch active reservations sum
        r_stmt = (
            select(
                StockReservation.product_variant_id,
                func.coalesce(func.sum(StockReservation.quantity), Decimal("0.0000")),
            )
            .where(
                StockReservation.business_id == business_id,
                StockReservation.branch_id == branch_id,
                StockReservation.product_variant_id.in_(v_ids),
                StockReservation.status == "ACTIVE",
                StockReservation.reserved_until > now,
            )
            .group_by(StockReservation.product_variant_id)
        )
        r_res = await session.execute(r_stmt)
        res_map = {row[0]: Decimal(row[1]) for row in r_res.all()}

        out: list[tuple[ProductVariant, StockBalance | None, Decimal]] = []
        for v in variants:
            balance = bal_map.get(v.id)
            reservations = res_map.get(v.id, Decimal("0.0000"))
            out.append((v, balance, reservations))
        return out

    # -------------------------------------------------------------------------
    # Inventory Valuation Queries
    # -------------------------------------------------------------------------
    async def get_inventory_valuation_data(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> list[tuple[ProductVariant, StockBalance, list[InventoryBatch]]]:
        """Fetch variants, positive balances, and active batches for multi-method valuation."""
        # 1. Fetch balances with quantity > 0
        b_stmt = select(StockBalance).where(
            StockBalance.business_id == business_id,
            StockBalance.quantity_on_hand > 0,
        )
        if branch_id:
            b_stmt = b_stmt.where(StockBalance.branch_id == branch_id)

        b_res = await session.execute(b_stmt)
        balances = list(b_res.scalars().all())
        if not balances:
            return []

        variant_ids = list({b.product_variant_id for b in balances})

        # 2. Fetch variants with product and category
        v_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product).selectinload(Product.category))
            .where(ProductVariant.id.in_(variant_ids))
        )
        v_res = await session.execute(v_stmt)
        var_map = {v.id: v for v in v_res.scalars().all()}

        # 3. Fetch active batches for these variants
        batch_stmt = select(InventoryBatch).where(
            InventoryBatch.business_id == business_id,
            InventoryBatch.product_variant_id.in_(variant_ids),
            InventoryBatch.is_active.is_(True),
            InventoryBatch.quantity_on_hand > 0,
        )
        if branch_id:
            batch_stmt = batch_stmt.where(InventoryBatch.branch_id == branch_id)

        batch_stmt = batch_stmt.order_by(
            InventoryBatch.expiry_date.asc().nullslast(),
            InventoryBatch.created_at.asc(),
        )
        batch_res = await session.execute(batch_stmt)
        batches = list(batch_res.scalars().all())

        batch_map: dict[tuple[uuid.UUID, uuid.UUID], list[InventoryBatch]] = {}
        for bt in batches:
            key = (bt.branch_id, bt.product_variant_id)
            if key not in batch_map:
                batch_map[key] = []
            batch_map[key].append(bt)

        data = []
        for b in balances:
            variant = var_map.get(b.product_variant_id)
            if variant:
                b_batches = batch_map.get((b.branch_id, b.product_variant_id), [])
                data.append((variant, b, b_batches))

        return data

