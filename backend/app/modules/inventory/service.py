"""Service for physical stock adjustments and inventory movement ledger."""

import uuid
from datetime import UTC, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.catalog.models import ProductVariant
from app.modules.inventory.models import (
    DamagedStockRecord,
    InventoryBatch,
    StockBalance,
    StockCount,
    StockCountLine,
    StockMovement,
    StockReservation,
)
from app.modules.inventory.repository import InventoryRepository
from app.modules.inventory.schemas import (
    AvailableStockOut,
    CategoryValuationOut,
    DamagedStockCreate,
    DamagedStockOut,
    ExpiryAlertOut,
    InventoryBatchCreate,
    InventoryBatchOut,
    InventoryValuationReportOut,
    PaginatedStockMovements,
    ReorderSuggestionOut,
    StockAdjustmentCreate,
    StockAdjustmentOut,
    StockCountCreate,
    StockCountLineOut,
    StockCountOut,
    StockCountScanRequest,
    StockMovementOut,
    StockReservationCreate,
    StockReservationOut,
    VariantThresholdUpdate,
)
from app.modules.purchasing.models import Supplier
from app.shared.exceptions import AppException


class InventoryService:
    """Manages stock adjustments and audit history."""

    def __init__(self) -> None:
        self.repo = InventoryRepository()

    async def get_balance(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        product_variant_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> Decimal:
        """Fetch quantity on hand for a specific product variant."""
        if not branch_id:
            b_stmt = (
                select(Branch)
                .where(Branch.business_id == business_id, Branch.is_active.is_(True))
                .limit(1)
            )
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                return Decimal("0.0000")
            branch_id = default_branch.id

        bal = await self.repo.get_balance(session, business_id, branch_id, product_variant_id)
        return bal.quantity_on_hand if bal else Decimal("0.0000")

    async def list_balances(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> list[dict]:
        """Fetch all stock balances for an active branch."""
        if not branch_id:
            b_stmt = (
                select(Branch)
                .where(Branch.business_id == business_id, Branch.is_active.is_(True))
                .limit(1)
            )
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                return []
            branch_id = default_branch.id

        stmt = select(StockBalance).where(
            StockBalance.business_id == business_id,
            StockBalance.branch_id == branch_id,
        )
        res = await session.execute(stmt)
        balances = res.scalars().all()
        return [
            {
                "product_variant_id": str(b.product_variant_id),
                "branch_id": str(b.branch_id),
                "quantity_on_hand": float(b.quantity_on_hand),
            }
            for b in balances
        ]

    async def adjust_stock(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: StockAdjustmentCreate,
    ) -> StockAdjustmentOut:
        """Applies manual stock adjustment (up or down) with audit tracking."""
        # 1. Validate variant
        v_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.id == payload.product_variant_id,
                ProductVariant.is_active.is_(True),
            )
        )
        v_res = await session.execute(v_stmt)
        variant = v_res.scalars().first()
        if not variant:
            raise AppException(
                "Product variant not found", code="VARIANT_NOT_FOUND", status_code=404
            )

        # 2. Resolve branch
        branch_id = payload.branch_id
        if not branch_id:
            b_stmt = (
                select(Branch)
                .where(Branch.business_id == business_id, Branch.is_active.is_(True))
                .limit(1)
            )
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                raise AppException(
                    "No active branch found", code="BRANCH_NOT_FOUND", status_code=404
                )
            branch_id = default_branch.id

        # 3. Lock balance row
        balance = await self.repo.get_balance(
            session, business_id, branch_id, variant.id, for_update=True
        )
        prev_qty = balance.quantity_on_hand if balance else Decimal("0.0000")

        # 4. Compute delta
        adj_type = payload.adjustment_type.upper()
        if adj_type not in ("ADJUSTMENT_UP", "ADJUSTMENT_DOWN"):
            raise AppException(
                "adjustment_type must be either ADJUSTMENT_UP or ADJUSTMENT_DOWN",
                code="INVALID_ADJUSTMENT_TYPE",
                status_code=400,
            )

        qty = payload.quantity.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        if adj_type == "ADJUSTMENT_DOWN":
            if prev_qty < qty:
                raise AppException(
                    f"Insufficient stock on hand to deduct {qty}. Current stock: {prev_qty}",
                    code="INSUFFICIENT_STOCK",
                    status_code=409,
                    details={"available": str(prev_qty), "requested_deduction": str(qty)},
                )
            delta = -qty
        else:
            delta = qty

        new_qty = prev_qty + delta

        # 5. Update or insert balance
        if balance:
            balance.quantity_on_hand = new_qty
        else:
            balance = StockBalance(
                business_id=business_id,
                branch_id=branch_id,
                product_variant_id=variant.id,
                quantity_on_hand=new_qty,
            )
            session.add(balance)

        # 6. Record movement ledger entry
        movement_id = uuid.uuid4()
        movement = StockMovement(
            id=movement_id,
            business_id=business_id,
            branch_id=branch_id,
            product_variant_id=variant.id,
            movement_type=adj_type,
            quantity_delta=delta,
            unit_cost=variant.cost_price,
            reference_type="STOCK_ADJUSTMENT",
            reference_id=movement_id,
            created_by=user_id,
        )
        session.add(movement)

        await session.commit()
        await session.refresh(movement)

        product_name = variant.product.name if variant.product else None

        return StockAdjustmentOut(
            movement_id=movement.id,
            business_id=movement.business_id,
            branch_id=movement.branch_id,
            product_variant_id=movement.product_variant_id,
            product_name=product_name,
            variant_name=variant.name,
            adjustment_type=adj_type,
            quantity_adjusted=qty,
            previous_quantity=prev_qty,
            new_quantity=new_qty,
            reason=payload.reason,
            notes=payload.notes,
            created_at=movement.created_at,
        )

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
    ) -> PaginatedStockMovements:
        """Fetch stock ledger audit movements with variant and product details."""
        total = await self.repo.count_movements(
            session, business_id, branch_id, product_variant_id, movement_type, start_date, end_date
        )
        movements = await self.repo.list_movements(
            session,
            business_id,
            branch_id,
            product_variant_id,
            movement_type,
            start_date,
            end_date,
            page,
            page_size,
        )

        # Batch load variants
        v_ids = list({m.product_variant_id for m in movements})
        v_map: dict[uuid.UUID, ProductVariant] = {}
        if v_ids:
            v_stmt = (
                select(ProductVariant)
                .options(selectinload(ProductVariant.product))
                .where(ProductVariant.id.in_(v_ids))
            )
            v_res = await session.execute(v_stmt)
            v_map = {v.id: v for v in v_res.scalars().all()}

        items_out: list[StockMovementOut] = []
        for m in movements:
            variant = v_map.get(m.product_variant_id)
            items_out.append(
                StockMovementOut(
                    id=m.id,
                    business_id=m.business_id,
                    branch_id=m.branch_id,
                    product_variant_id=m.product_variant_id,
                    product_name=variant.product.name if variant and variant.product else None,
                    variant_name=variant.name if variant else None,
                    sku=variant.product.sku if variant and variant.product else None,
                    movement_type=m.movement_type,
                    quantity_delta=m.quantity_delta,
                    unit_cost=m.unit_cost,
                    reference_type=m.reference_type,
                    reference_id=m.reference_id,
                    created_by=m.created_by,
                    created_at=m.created_at,
                )
            )

        total_pages = (total + page_size - 1) // page_size if total > 0 else 1

        return PaginatedStockMovements(
            items=items_out,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        )

    # -------------------------------------------------------------------------
    # Batch Tracking & Expiry
    # -------------------------------------------------------------------------
    async def create_batch(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: InventoryBatchCreate,
    ) -> InventoryBatchOut:
        """Record inward batch / lot and increment branch stock balance."""
        # 1. Resolve branch
        branch_id = payload.branch_id
        if not branch_id:
            b_stmt = (
                select(Branch)
                .where(Branch.business_id == business_id, Branch.is_active.is_(True))
                .limit(1)
            )
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                raise AppException("No active branch found", code="BRANCH_NOT_FOUND", status_code=404)
            branch_id = default_branch.id

        # 2. Check variant
        v_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.id == payload.product_variant_id,
                ProductVariant.is_active.is_(True),
            )
        )
        v_res = await session.execute(v_stmt)
        variant = v_res.scalars().first()
        if not variant:
            raise AppException("Product variant not found", code="VARIANT_NOT_FOUND", status_code=404)

        # 3. Check duplicate batch
        existing = await self.repo.get_batch_by_number(
            session, business_id, branch_id, payload.product_variant_id, payload.batch_number
        )
        if existing:
            raise AppException(
                f"Batch '{payload.batch_number}' already exists for this variant in this branch",
                code="DUPLICATE_BATCH",
                status_code=409,
            )

        # 4. Create batch
        batch = InventoryBatch(
            business_id=business_id,
            branch_id=branch_id,
            product_variant_id=payload.product_variant_id,
            batch_number=payload.batch_number,
            manufacturing_date=payload.manufacturing_date,
            expiry_date=payload.expiry_date,
            quantity_received=payload.quantity_received,
            quantity_on_hand=payload.quantity_received,
            cost_price=payload.cost_price,
            supplier_id=payload.supplier_id,
            is_active=True,
        )
        await self.repo.create_batch(session, batch)

        # 5. Enable batch tracking on variant if not enabled
        if not variant.has_batch_tracking:
            variant.has_batch_tracking = True

        # 6. Update StockBalance
        bal = await self.repo.get_balance(session, business_id, branch_id, variant.id, for_update=True)
        prev_qty = bal.quantity_on_hand if bal else Decimal("0.0000")
        new_qty = prev_qty + payload.quantity_received
        if bal:
            bal.quantity_on_hand = new_qty
        else:
            bal = StockBalance(
                business_id=business_id,
                branch_id=branch_id,
                product_variant_id=variant.id,
                quantity_on_hand=new_qty,
            )
            session.add(bal)

        # 7. Record StockMovement
        m_id = uuid.uuid4()
        movement = StockMovement(
            id=m_id,
            business_id=business_id,
            branch_id=branch_id,
            product_variant_id=variant.id,
            batch_id=batch.id,
            movement_type="PURCHASE_RECEIVE",
            quantity_delta=payload.quantity_received,
            unit_cost=payload.cost_price,
            reference_type="INVENTORY_BATCH",
            reference_id=batch.id,
            created_by=user_id,
        )
        await self.repo.record_movement(session, movement)

        await session.commit()
        await session.refresh(batch)

        today = datetime.now(UTC).date()
        days_to_expiry = (batch.expiry_date - today).days if batch.expiry_date else None
        expiry_status = self._compute_expiry_status(days_to_expiry)

        supplier_name = None
        if batch.supplier_id:
            s_res = await session.execute(select(Supplier.name).where(Supplier.id == batch.supplier_id))
            supplier_name = s_res.scalar_one_or_none()

        return InventoryBatchOut(
            id=batch.id,
            business_id=batch.business_id,
            branch_id=batch.branch_id,
            product_variant_id=batch.product_variant_id,
            product_name=variant.product.name if variant.product else None,
            variant_name=variant.name,
            sku=variant.product.sku if variant.product else None,
            batch_number=batch.batch_number,
            manufacturing_date=batch.manufacturing_date,
            expiry_date=batch.expiry_date,
            quantity_received=batch.quantity_received,
            quantity_on_hand=batch.quantity_on_hand,
            cost_price=batch.cost_price,
            supplier_id=batch.supplier_id,
            supplier_name=supplier_name,
            is_active=batch.is_active,
            days_to_expiry=days_to_expiry,
            expiry_status=expiry_status,
            created_at=batch.created_at,
        )

    def _compute_expiry_status(self, days: int | None) -> str:
        if days is None:
            return "GOOD"
        if days < 0:
            return "EXPIRED"
        if days <= 7:
            return "EXPIRING_7_DAYS"
        if days <= 30:
            return "EXPIRING_30_DAYS"
        if days <= 60:
            return "EXPIRING_60_DAYS"
        return "GOOD"

    async def list_batches(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        product_variant_id: uuid.UUID | None = None,
        is_active: bool | None = None,
    ) -> list[InventoryBatchOut]:
        """List inventory batches with expiry status."""
        batches = await self.repo.list_batches(
            session, business_id, branch_id, product_variant_id, is_active
        )
        if not batches:
            return []

        # Load variants
        v_ids = list({b.product_variant_id for b in batches})
        v_res = await session.execute(
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_(v_ids))
        )
        v_map = {v.id: v for v in v_res.scalars().all()}

        # Load suppliers
        sup_ids = list({b.supplier_id for b in batches if b.supplier_id})
        sup_map: dict[uuid.UUID, str] = {}
        if sup_ids:
            s_res = await session.execute(select(Supplier.id, Supplier.name).where(Supplier.id.in_(sup_ids)))
            sup_map = {row[0]: row[1] for row in s_res.all()}

        today = datetime.now(UTC).date()
        out: list[InventoryBatchOut] = []
        for b in batches:
            v = v_map.get(b.product_variant_id)
            days = (b.expiry_date - today).days if b.expiry_date else None
            out.append(
                InventoryBatchOut(
                    id=b.id,
                    business_id=b.business_id,
                    branch_id=b.branch_id,
                    product_variant_id=b.product_variant_id,
                    product_name=v.product.name if v and v.product else None,
                    variant_name=v.name if v else None,
                    sku=v.product.sku if v and v.product else None,
                    batch_number=b.batch_number,
                    manufacturing_date=b.manufacturing_date,
                    expiry_date=b.expiry_date,
                    quantity_received=b.quantity_received,
                    quantity_on_hand=b.quantity_on_hand,
                    cost_price=b.cost_price,
                    supplier_id=b.supplier_id,
                    supplier_name=sup_map.get(b.supplier_id) if b.supplier_id else None,
                    is_active=b.is_active,
                    days_to_expiry=days,
                    expiry_status=self._compute_expiry_status(days),
                    created_at=b.created_at,
                )
            )
        return out

    async def get_expiry_alerts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        days_threshold: int = 60,
    ) -> list[ExpiryAlertOut]:
        """Fetch alert items for expiring or expired batches."""
        batches = await self.repo.get_expiring_batches(
            session, business_id, branch_id, days_threshold
        )
        if not batches:
            return []

        v_ids = list({b.product_variant_id for b in batches})
        v_res = await session.execute(
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_(v_ids))
        )
        v_map = {v.id: v for v in v_res.scalars().all()}

        br_ids = list({b.branch_id for b in batches})
        br_res = await session.execute(select(Branch.id, Branch.name).where(Branch.id.in_(br_ids)))
        br_map = {row[0]: row[1] for row in br_res.all()}

        today = datetime.now(UTC).date()
        out: list[ExpiryAlertOut] = []
        for b in batches:
            v = v_map.get(b.product_variant_id)
            days = (b.expiry_date - today).days if b.expiry_date else 0
            if days < 0:
                urgency = "CRITICAL_EXPIRED"
            elif days <= 7:
                urgency = "HIGH_7_DAYS"
            elif days <= 30:
                urgency = "MEDIUM_30_DAYS"
            else:
                urgency = "LOW_60_DAYS"

            out.append(
                ExpiryAlertOut(
                    batch_id=b.id,
                    batch_number=b.batch_number,
                    product_variant_id=b.product_variant_id,
                    product_name=v.product.name if v and v.product else "Unknown Product",
                    variant_name=v.name if v else "Standard",
                    branch_id=b.branch_id,
                    branch_name=br_map.get(b.branch_id),
                    quantity_on_hand=b.quantity_on_hand,
                    expiry_date=b.expiry_date,  # type: ignore
                    days_remaining=days,
                    urgency=urgency,
                )
            )
        return out

    # -------------------------------------------------------------------------
    # Damaged Stock & Write-Offs
    # -------------------------------------------------------------------------
    async def record_damaged_stock(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: DamagedStockCreate,
    ) -> DamagedStockOut:
        """Write-off damaged stock with batch deduction and inventory movement."""
        # 1. Resolve branch
        branch_id = payload.branch_id
        if not branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id, Branch.is_active.is_(True)).limit(1)
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                raise AppException("No active branch found", code="BRANCH_NOT_FOUND", status_code=404)
            branch_id = default_branch.id

        # 2. Check variant
        v_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.id == payload.product_variant_id,
                ProductVariant.is_active.is_(True),
            )
        )
        v_res = await session.execute(v_stmt)
        variant = v_res.scalars().first()
        if not variant:
            raise AppException("Product variant not found", code="VARIANT_NOT_FOUND", status_code=404)

        qty = payload.quantity.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)

        # 3. Lock balance
        bal = await self.repo.get_balance(session, business_id, branch_id, variant.id, for_update=True)
        on_hand = bal.quantity_on_hand if bal else Decimal("0.0000")
        if on_hand < qty:
            raise AppException(
                f"Insufficient stock on hand to write off {qty}. Current stock: {on_hand}",
                code="INSUFFICIENT_STOCK",
                status_code=409,
            )

        # 4. Handle batch deduction if specified or if product has batch tracking
        batch_number = None
        unit_cost = payload.unit_cost or variant.cost_price

        if payload.batch_id:
            batch = await self.repo.get_batch(session, business_id, payload.batch_id, for_update=True)
            if not batch:
                raise AppException("Specified batch not found", code="BATCH_NOT_FOUND", status_code=404)
            if batch.quantity_on_hand < qty:
                raise AppException(
                    f"Batch '{batch.batch_number}' only has {batch.quantity_on_hand} on hand",
                    code="INSUFFICIENT_BATCH_STOCK",
                    status_code=409,
                )
            batch.quantity_on_hand -= qty
            batch_number = batch.batch_number
            if not payload.unit_cost:
                unit_cost = batch.cost_price
        elif variant.has_batch_tracking:
            # FEFO deduction across available batches
            fefo_batches = await self.repo.get_batches_fefo(session, business_id, branch_id, variant.id, for_update=True)
            remaining_to_deduct = qty
            for bt in fefo_batches:
                if remaining_to_deduct <= 0:
                    break
                deduct_here = min(bt.quantity_on_hand, remaining_to_deduct)
                bt.quantity_on_hand -= deduct_here
                remaining_to_deduct -= deduct_here
                if batch_number is None:
                    batch_number = bt.batch_number

        # 5. Deduct from balance
        bal.quantity_on_hand -= qty  # type: ignore

        # 6. Generate voucher & record
        voucher_no = await self.repo.get_next_damaged_voucher_no(session, business_id)
        total_loss = (qty * unit_cost).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)

        record = DamagedStockRecord(
            business_id=business_id,
            branch_id=branch_id,
            product_variant_id=variant.id,
            batch_id=payload.batch_id,
            voucher_no=voucher_no,
            quantity=qty,
            unit_cost=unit_cost,
            total_loss=total_loss,
            reason=payload.reason.upper(),
            disposal_method=payload.disposal_method.upper(),
            notes=payload.notes,
            reported_by=user_id,
        )
        await self.repo.create_damaged_record(session, record)

        # 7. Record StockMovement
        m_id = uuid.uuid4()
        movement = StockMovement(
            id=m_id,
            business_id=business_id,
            branch_id=branch_id,
            product_variant_id=variant.id,
            batch_id=payload.batch_id,
            movement_type="ADJUSTMENT_DOWN",
            quantity_delta=-qty,
            unit_cost=unit_cost,
            reference_type="DAMAGED_WRITE_OFF",
            reference_id=record.id,
            created_by=user_id,
        )
        await self.repo.record_movement(session, movement)

        await session.commit()
        await session.refresh(record)

        return DamagedStockOut(
            id=record.id,
            business_id=record.business_id,
            branch_id=record.branch_id,
            product_variant_id=record.product_variant_id,
            product_name=variant.product.name if variant.product else None,
            variant_name=variant.name,
            batch_id=record.batch_id,
            batch_number=batch_number,
            voucher_no=record.voucher_no,
            quantity=record.quantity,
            unit_cost=record.unit_cost,
            total_loss=record.total_loss,
            reason=record.reason,
            disposal_method=record.disposal_method,
            notes=record.notes,
            reported_by=record.reported_by,
            reporter_name=None,
            created_at=record.created_at,
        )

    async def list_damaged_records(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
    ) -> list[DamagedStockOut]:
        """Fetch damaged stock records."""
        records = await self.repo.list_damaged_records(
            session, business_id, branch_id, start_date, end_date
        )
        if not records:
            return []

        v_ids = list({r.product_variant_id for r in records})
        v_res = await session.execute(
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_(v_ids))
        )
        v_map = {v.id: v for v in v_res.scalars().all()}

        out: list[DamagedStockOut] = []
        for r in records:
            v = v_map.get(r.product_variant_id)
            out.append(
                DamagedStockOut(
                    id=r.id,
                    business_id=r.business_id,
                    branch_id=r.branch_id,
                    product_variant_id=r.product_variant_id,
                    product_name=v.product.name if v and v.product else None,
                    variant_name=v.name if v else None,
                    batch_id=r.batch_id,
                    batch_number=None,
                    voucher_no=r.voucher_no,
                    quantity=r.quantity,
                    unit_cost=r.unit_cost,
                    total_loss=r.total_loss,
                    reason=r.reason,
                    disposal_method=r.disposal_method,
                    notes=r.notes,
                    reported_by=r.reported_by,
                    reporter_name=None,
                    created_at=r.created_at,
                )
            )
        return out

    # -------------------------------------------------------------------------
    # Stock Reservations Engine
    # -------------------------------------------------------------------------
    async def get_available_stock(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        product_variant_id: uuid.UUID,
    ) -> AvailableStockOut:
        """Calculate available stock: on_hand minus active reservations."""
        bal = await self.repo.get_balance(session, business_id, branch_id, product_variant_id)
        on_hand = bal.quantity_on_hand if bal else Decimal("0.0000")
        reserved = await self.repo.get_active_reservations_qty(
            session, business_id, branch_id, product_variant_id
        )
        available = max(Decimal("0.0000"), on_hand - reserved)
        return AvailableStockOut(
            product_variant_id=product_variant_id,
            branch_id=branch_id,
            quantity_on_hand=on_hand,
            quantity_reserved=reserved,
            available_quantity=available,
        )

    async def create_reservation(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: StockReservationCreate,
    ) -> StockReservationOut:
        """Hold stock allocation ensuring zero-overselling."""
        branch_id = payload.branch_id
        if not branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id, Branch.is_active.is_(True)).limit(1)
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                raise AppException("No active branch found", code="BRANCH_NOT_FOUND", status_code=404)
            branch_id = default_branch.id

        # 1. Lock balance row
        bal = await self.repo.get_balance(session, business_id, branch_id, payload.product_variant_id, for_update=True)
        on_hand = bal.quantity_on_hand if bal else Decimal("0.0000")

        # 2. Check active reservations
        active_res = await self.repo.get_active_reservations_qty(
            session, business_id, branch_id, payload.product_variant_id
        )
        available = on_hand - active_res
        qty = payload.quantity.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)

        if available < qty:
            raise AppException(
                f"Insufficient unreserved stock to reserve {qty}. Available: {available} (On Hand: {on_hand}, Reserved: {active_res})",
                code="INSUFFICIENT_UNRESERVED_STOCK",
                status_code=409,
                details={"available": str(available), "on_hand": str(on_hand), "reserved": str(active_res)},
            )

        # 3. Create reservation
        reserved_until = datetime.now(UTC) + timedelta(hours=payload.duration_hours)
        reservation = StockReservation(
            business_id=business_id,
            branch_id=branch_id,
            product_variant_id=payload.product_variant_id,
            batch_id=payload.batch_id,
            quantity=qty,
            reference_type=payload.reference_type.upper(),
            reference_id=payload.reference_id,
            status="ACTIVE",
            reserved_until=reserved_until,
            created_by=user_id,
        )
        await self.repo.create_reservation(session, reservation)
        await session.commit()
        await session.refresh(reservation)

        # Fetch variant name
        v_res = await session.execute(
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id == payload.product_variant_id)
        )
        variant = v_res.scalars().first()

        return StockReservationOut(
            id=reservation.id,
            business_id=reservation.business_id,
            branch_id=reservation.branch_id,
            product_variant_id=reservation.product_variant_id,
            product_name=variant.product.name if variant and variant.product else None,
            variant_name=variant.name if variant else None,
            batch_id=reservation.batch_id,
            quantity=reservation.quantity,
            reference_type=reservation.reference_type,
            reference_id=reservation.reference_id,
            status=reservation.status,
            reserved_until=reservation.reserved_until,
            created_by=reservation.created_by,
            created_at=reservation.created_at,
        )

    async def release_reservation(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        reservation_id: uuid.UUID,
        status: str = "RELEASED",
    ) -> StockReservationOut:
        """Release or fulfill a stock hold."""
        reservation = await self.repo.get_reservation(session, business_id, reservation_id, for_update=True)
        if not reservation:
            raise AppException("Reservation not found", code="RESERVATION_NOT_FOUND", status_code=404)

        if reservation.status != "ACTIVE":
            raise AppException(
                f"Reservation is already {reservation.status}",
                code="INVALID_RESERVATION_STATUS",
                status_code=400,
            )

        reservation.status = status.upper()
        await session.commit()
        await session.refresh(reservation)

        v_res = await session.execute(
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id == reservation.product_variant_id)
        )
        variant = v_res.scalars().first()

        return StockReservationOut(
            id=reservation.id,
            business_id=reservation.business_id,
            branch_id=reservation.branch_id,
            product_variant_id=reservation.product_variant_id,
            product_name=variant.product.name if variant and variant.product else None,
            variant_name=variant.name if variant else None,
            batch_id=reservation.batch_id,
            quantity=reservation.quantity,
            reference_type=reservation.reference_type,
            reference_id=reservation.reference_id,
            status=reservation.status,
            reserved_until=reservation.reserved_until,
            created_by=reservation.created_by,
            created_at=reservation.created_at,
        )

    async def list_reservations(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        product_variant_id: uuid.UUID | None = None,
        status: str | None = None,
    ) -> list[StockReservationOut]:
        """List stock reservations."""
        reservations = await self.repo.list_reservations(
            session, business_id, branch_id, product_variant_id, status
        )
        if not reservations:
            return []

        v_ids = list({r.product_variant_id for r in reservations})
        v_res = await session.execute(
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_(v_ids))
        )
        v_map = {v.id: v for v in v_res.scalars().all()}

        out: list[StockReservationOut] = []
        for r in reservations:
            v = v_map.get(r.product_variant_id)
            out.append(
                StockReservationOut(
                    id=r.id,
                    business_id=r.business_id,
                    branch_id=r.branch_id,
                    product_variant_id=r.product_variant_id,
                    product_name=v.product.name if v and v.product else None,
                    variant_name=v.name if v else None,
                    batch_id=r.batch_id,
                    quantity=r.quantity,
                    reference_type=r.reference_type,
                    reference_id=r.reference_id,
                    status=r.status,
                    reserved_until=r.reserved_until,
                    created_by=r.created_by,
                    created_at=r.created_at,
                )
            )
        return out

    # -------------------------------------------------------------------------
    # Physical Stock Counts (Audits)
    # -------------------------------------------------------------------------
    async def create_stock_count(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: StockCountCreate,
    ) -> StockCountOut:
        """Initiate physical count session."""
        branch_id = payload.branch_id
        if not branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id, Branch.is_active.is_(True)).limit(1)
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                raise AppException("No active branch found", code="BRANCH_NOT_FOUND", status_code=404)
            branch_id = default_branch.id

        count = StockCount(
            business_id=business_id,
            branch_id=branch_id,
            status="DRAFT",
            notes=payload.notes,
            created_by=user_id,
        )
        await self.repo.create_stock_count(session, count)

        # If lines provided, add them; otherwise populate active tracked variants
        if payload.lines:
            for l_in in payload.lines:
                bal = await self.repo.get_balance(session, business_id, branch_id, l_in.product_variant_id)
                expected = bal.quantity_on_hand if bal else Decimal("0.0000")
                line = StockCountLine(
                    stock_count_id=count.id,
                    product_variant_id=l_in.product_variant_id,
                    expected_qty=expected,
                    counted_qty=l_in.counted_qty,
                    discrepancy_reason=l_in.discrepancy_reason,
                )
                session.add(line)
        else:
            # Auto-populate all tracked variants for this branch
            v_stmt = select(ProductVariant).where(
                ProductVariant.business_id == business_id,
                ProductVariant.is_active.is_(True),
                ProductVariant.track_stock.is_(True),
            )
            v_res = await session.execute(v_stmt)
            variants = list(v_res.scalars().all())
            v_ids = [v.id for v in variants]

            bal_stmt = select(StockBalance).where(
                StockBalance.business_id == business_id,
                StockBalance.branch_id == branch_id,
                StockBalance.product_variant_id.in_(v_ids),
            )
            bal_res = await session.execute(bal_stmt)
            bal_map = {sb.product_variant_id: sb.quantity_on_hand for sb in bal_res.scalars().all()}

            for v in variants:
                line = StockCountLine(
                    stock_count_id=count.id,
                    product_variant_id=v.id,
                    expected_qty=bal_map.get(v.id, Decimal("0.0000")),
                    counted_qty=Decimal("0.0000"),
                )
                session.add(line)

        await session.commit()
        return await self.get_stock_count(session, business_id, count.id)

    async def get_stock_count(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        count_id: uuid.UUID,
    ) -> StockCountOut:
        """Retrieve stock count session details with variance."""
        count = await self.repo.get_stock_count(session, business_id, count_id)
        if not count:
            raise AppException("Stock count session not found", code="STOCK_COUNT_NOT_FOUND", status_code=404)

        # Load variants
        v_ids = [line.product_variant_id for line in count.lines]
        v_map: dict[uuid.UUID, ProductVariant] = {}
        if v_ids:
            v_res = await session.execute(
                select(ProductVariant)
                .options(selectinload(ProductVariant.product))
                .where(ProductVariant.id.in_(v_ids))
            )
            v_map = {v.id: v for v in v_res.scalars().all()}

        lines_out: list[StockCountLineOut] = []
        for line in count.lines:
            v = v_map.get(line.product_variant_id)
            lines_out.append(
                StockCountLineOut(
                    id=line.id,
                    stock_count_id=line.stock_count_id,
                    product_variant_id=line.product_variant_id,
                    product_name=v.product.name if v and v.product else None,
                    variant_name=v.name if v else None,
                    barcode=v.barcode if v else None,
                    expected_qty=line.expected_qty,
                    counted_qty=line.counted_qty,
                    variance=line.counted_qty - line.expected_qty,
                    discrepancy_reason=line.discrepancy_reason,
                )
            )

        br_res = await session.execute(select(Branch.name).where(Branch.id == count.branch_id))
        branch_name = br_res.scalar_one_or_none()

        return StockCountOut(
            id=count.id,
            business_id=count.business_id,
            branch_id=count.branch_id,
            branch_name=branch_name,
            status=count.status,
            notes=count.notes,
            created_by=count.created_by,
            approved_by=count.approved_by,
            created_at=count.created_at,
            completed_at=count.completed_at,
            lines=lines_out,
        )

    async def list_stock_counts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        status: str | None = None,
    ) -> list[StockCountOut]:
        """List stock count audit sessions."""
        counts = await self.repo.list_stock_counts(session, business_id, branch_id, status)
        out: list[StockCountOut] = []
        for c in counts:
            out.append(await self.get_stock_count(session, business_id, c.id))
        return out

    async def scan_stock_count_item(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        count_id: uuid.UUID,
        payload: StockCountScanRequest,
    ) -> StockCountOut:
        """Scan barcode inside count session and increment counted_qty."""
        count = await self.repo.get_stock_count(session, business_id, count_id)
        if not count:
            raise AppException("Stock count session not found", code="STOCK_COUNT_NOT_FOUND", status_code=404)

        if count.status not in ("DRAFT", "IN_PROGRESS"):
            raise AppException(f"Cannot scan into a {count.status} session", code="INVALID_SESSION_STATUS", status_code=400)

        if count.status == "DRAFT":
            count.status = "IN_PROGRESS"

        variant = await self.repo.find_variant_by_barcode(session, business_id, payload.barcode)
        if not variant:
            raise AppException(f"No variant found with barcode '{payload.barcode}'", code="BARCODE_NOT_FOUND", status_code=404)

        # Look for existing line
        target_line = next((item for item in count.lines if item.product_variant_id == variant.id), None)
        if target_line:
            target_line.counted_qty += payload.increment_qty
        else:
            bal = await self.repo.get_balance(session, business_id, count.branch_id, variant.id)
            expected = bal.quantity_on_hand if bal else Decimal("0.0000")
            new_line = StockCountLine(
                stock_count_id=count.id,
                product_variant_id=variant.id,
                expected_qty=expected,
                counted_qty=payload.increment_qty,
            )
            session.add(new_line)

        await session.commit()
        return await self.get_stock_count(session, business_id, count.id)

    async def complete_stock_count(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        count_id: uuid.UUID,
    ) -> StockCountOut:
        """Finalize stock count: generate adjustment movements and reconcile balances."""
        count = await self.repo.get_stock_count(session, business_id, count_id)
        if not count:
            raise AppException("Stock count session not found", code="STOCK_COUNT_NOT_FOUND", status_code=404)

        if count.status not in ("DRAFT", "IN_PROGRESS"):
            raise AppException(f"Cannot complete a session with status {count.status}", code="INVALID_SESSION_STATUS", status_code=400)

        count.status = "COMPLETED"
        count.completed_at = datetime.now(UTC)
        count.approved_by = user_id

        # Reconcile lines
        for line in count.lines:
            variance = line.counted_qty - line.expected_qty
            if variance != 0:
                adj_type = "ADJUSTMENT_UP" if variance > 0 else "ADJUSTMENT_DOWN"

                # Lock and update balance
                bal = await self.repo.get_balance(session, business_id, count.branch_id, line.product_variant_id, for_update=True)
                if bal:
                    bal.quantity_on_hand = line.counted_qty
                else:
                    bal = StockBalance(
                        business_id=business_id,
                        branch_id=count.branch_id,
                        product_variant_id=line.product_variant_id,
                        quantity_on_hand=line.counted_qty,
                    )
                    session.add(bal)

                # Fetch variant cost price for valuation
                v_res = await session.execute(
                    select(ProductVariant.cost_price).where(ProductVariant.id == line.product_variant_id)
                )
                cost = v_res.scalar_one_or_none() or Decimal("0.0000")

                movement = StockMovement(
                    id=uuid.uuid4(),
                    business_id=business_id,
                    branch_id=count.branch_id,
                    product_variant_id=line.product_variant_id,
                    movement_type=adj_type,
                    quantity_delta=variance,
                    unit_cost=cost,
                    reference_type="STOCK_COUNT",
                    reference_id=count.id,
                    created_by=user_id,
                )
                await self.repo.record_movement(session, movement)

        await session.commit()
        return await self.get_stock_count(session, business_id, count.id)

    # -------------------------------------------------------------------------
    # Reorder Engine
    # -------------------------------------------------------------------------
    async def get_reorder_suggestions(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> list[ReorderSuggestionOut]:
        """Generate replenishment purchase suggestions for stock falling below min_stock_level."""
        if not branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id, Branch.is_active.is_(True)).limit(1)
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                return []
            branch_id = default_branch.id

        b_name_res = await session.execute(select(Branch.name).where(Branch.id == branch_id))
        branch_name = b_name_res.scalar_one_or_none()

        data = await self.repo.list_reorder_variants(session, business_id, branch_id)
        suggestions: list[ReorderSuggestionOut] = []

        for variant, balance, reservations in data:
            on_hand = balance.quantity_on_hand if balance else Decimal("0.0000")
            available = on_hand - reservations

            if available <= variant.min_stock_level:
                # Calculate suggested reorder qty
                if variant.reorder_quantity > 0:
                    suggested_qty = variant.reorder_quantity
                else:
                    suggested_qty = max(Decimal("1.0000"), (variant.min_stock_level * 2) - available)

                total_cost = (suggested_qty * variant.cost_price).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)

                suggestions.append(
                    ReorderSuggestionOut(
                        product_variant_id=variant.id,
                        product_name=variant.product.name if variant.product else "Unknown Product",
                        variant_name=variant.name,
                        sku=variant.product.sku if variant.product else None,
                        barcode=variant.barcode,
                        branch_id=branch_id,
                        branch_name=branch_name,
                        quantity_on_hand=on_hand,
                        active_reservations=reservations,
                        available_quantity=available,
                        min_stock_level=variant.min_stock_level,
                        suggested_reorder_qty=suggested_qty,
                        estimated_unit_cost=variant.cost_price,
                        estimated_total_cost=total_cost,
                        primary_supplier_id=None,
                        primary_supplier_name=None,
                    )
                )

        return suggestions

    async def update_variant_thresholds(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        variant_id: uuid.UUID,
        payload: VariantThresholdUpdate,
    ) -> ProductVariant:
        """Update min_stock_level, reorder_quantity, and batch tracking flag."""
        stmt = select(ProductVariant).where(
            ProductVariant.business_id == business_id,
            ProductVariant.id == variant_id,
        )
        res = await session.execute(stmt)
        variant = res.scalars().first()
        if not variant:
            raise AppException("Product variant not found", code="VARIANT_NOT_FOUND", status_code=404)

        variant.min_stock_level = payload.min_stock_level
        variant.reorder_quantity = payload.reorder_quantity
        if payload.has_batch_tracking is not None:
            variant.has_batch_tracking = payload.has_batch_tracking

        await session.commit()
        await session.refresh(variant)
        return variant

    # -------------------------------------------------------------------------
    # Inventory Valuation Report
    # -------------------------------------------------------------------------
    async def get_inventory_valuation(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> InventoryValuationReportOut:
        """Calculate multi-tier valuation report (FIFO Batch, WAC, Retail)."""
        data = await self.repo.get_inventory_valuation_data(session, business_id, branch_id)

        branch_name = None
        if branch_id:
            br_res = await session.execute(select(Branch.name).where(Branch.id == branch_id))
            branch_name = br_res.scalar_one_or_none()

        # Group by category
        cat_map: dict[str, dict] = {}
        total_variants = len(data)
        total_qty = Decimal("0.0000")
        total_fifo = Decimal("0.0000")
        total_wac = Decimal("0.0000")
        total_retail = Decimal("0.0000")

        for variant, balance, batches in data:
            qty = balance.quantity_on_hand
            total_qty += qty

            # WAC & Retail
            wac_val = (qty * variant.cost_price).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
            ret_val = (qty * variant.selling_price).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
            total_wac += wac_val
            total_retail += ret_val

            # FIFO Valuation
            if variant.has_batch_tracking and batches:
                fifo_val = Decimal("0.0000")
                rem_qty = qty
                for bt in batches:
                    if rem_qty <= 0:
                        break
                    lot_qty = min(rem_qty, bt.quantity_on_hand)
                    fifo_val += (lot_qty * bt.cost_price).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
                    rem_qty -= lot_qty
                if rem_qty > 0:
                    fifo_val += (rem_qty * variant.cost_price).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
            else:
                fifo_val = wac_val

            total_fifo += fifo_val

            # Category categorization
            category = variant.product.category if variant.product and variant.product.category else None
            cat_id = category.id if category else None
            cat_name = category.name if category else "Uncategorized"

            if cat_name not in cat_map:
                cat_map[cat_name] = {
                    "category_id": cat_id,
                    "category_name": cat_name,
                    "item_count": 0,
                    "total_units": Decimal("0.0000"),
                    "fifo_valuation": Decimal("0.0000"),
                    "wac_valuation": Decimal("0.0000"),
                    "retail_valuation": Decimal("0.0000"),
                }

            cat_map[cat_name]["item_count"] += 1
            cat_map[cat_name]["total_units"] += qty
            cat_map[cat_name]["fifo_valuation"] += fifo_val
            cat_map[cat_name]["wac_valuation"] += wac_val
            cat_map[cat_name]["retail_valuation"] += ret_val

        categories_out = [
            CategoryValuationOut(
                category_id=v["category_id"],
                category_name=v["category_name"],
                item_count=v["item_count"],
                total_units=v["total_units"],
                fifo_valuation=v["fifo_valuation"],
                wac_valuation=v["wac_valuation"],
                retail_valuation=v["retail_valuation"],
            )
            for v in cat_map.values()
        ]

        return InventoryValuationReportOut(
            business_id=business_id,
            branch_id=branch_id,
            branch_name=branch_name,
            as_of_date=datetime.now(UTC),
            total_variants=total_variants,
            total_quantity_on_hand=total_qty,
            total_fifo_valuation=total_fifo,
            total_wac_valuation=total_wac,
            total_retail_valuation=total_retail,
            categories=categories_out,
        )

