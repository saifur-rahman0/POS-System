"""Business logic service for Suppliers, Purchase Orders, Receiving, and Payments."""

import uuid
from datetime import datetime
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.catalog.models import ProductVariant
from app.modules.expenses.models import CashTransaction
from app.modules.inventory.models import StockBalance, StockMovement
from app.modules.inventory.repository import InventoryRepository
from app.modules.purchasing.models import Purchase, PurchaseItem, PurchasePayment, Supplier
from app.modules.purchasing.repository import PurchasingRepository
from app.modules.purchasing.schemas import (
    PaginatedPurchases,
    PaginatedSuppliers,
    PurchaseCreate,
    PurchaseItemOut,
    PurchaseOut,
    PurchasePaymentCreate,
    PurchasePaymentOut,
    SupplierCreate,
    SupplierOut,
    SupplierUpdate,
)
from app.shared.exceptions import AppException


class PurchasingService:
    """Orchestrates vendor purchasing, inventory receipts, and supplier disbursements."""

    def __init__(self) -> None:
        self.repo = PurchasingRepository()
        self.inventory_repo = InventoryRepository()

    # -------------------------------------------------------------------------
    # Suppliers
    # -------------------------------------------------------------------------

    async def create_supplier(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: SupplierCreate,
    ) -> SupplierOut:
        """Creates a new vendor profile with unique name validation."""
        existing = await self.repo.get_supplier_by_name(session, business_id, payload.name)
        if existing:
            raise AppException(
                f"A supplier with name '{payload.name}' already exists",
                code="SUPPLIER_ALREADY_EXISTS",
                status_code=409,
            )

        supplier = Supplier(
            id=uuid.uuid4(),
            business_id=business_id,
            name=payload.name.strip(),
            contact_person=payload.contact_person.strip() if payload.contact_person else None,
            phone=payload.phone.strip() if payload.phone else None,
            email=payload.email.strip() if payload.email else None,
            address=payload.address.strip() if payload.address else None,
            is_active=True,
        )
        session.add(supplier)
        await session.commit()
        await session.refresh(supplier)

        return SupplierOut(
            id=supplier.id,
            business_id=supplier.business_id,
            name=supplier.name,
            contact_person=supplier.contact_person,
            phone=supplier.phone,
            email=supplier.email,
            address=supplier.address,
            is_active=supplier.is_active,
            total_purchases_count=0,
            total_purchases_amount=Decimal("0.0000"),
            unpaid_balance=Decimal("0.0000"),
            created_at=supplier.created_at,
        )

    async def update_supplier(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        supplier_id: uuid.UUID,
        payload: SupplierUpdate,
    ) -> SupplierOut:
        """Updates an existing vendor."""
        supplier = await self.repo.get_supplier_by_id(session, business_id, supplier_id)
        if not supplier:
            raise AppException("Supplier not found", code="SUPPLIER_NOT_FOUND", status_code=404)

        if payload.name is not None and payload.name.strip().lower() != supplier.name.lower():
            dup = await self.repo.get_supplier_by_name(session, business_id, payload.name)
            if dup:
                raise AppException(
                    f"A supplier with name '{payload.name}' already exists",
                    code="SUPPLIER_ALREADY_EXISTS",
                    status_code=409,
                )
            supplier.name = payload.name.strip()

        if payload.contact_person is not None:
            supplier.contact_person = (
                payload.contact_person.strip() if payload.contact_person else None
            )
        if payload.phone is not None:
            supplier.phone = payload.phone.strip() if payload.phone else None
        if payload.email is not None:
            supplier.email = payload.email.strip() if payload.email else None
        if payload.address is not None:
            supplier.address = payload.address.strip() if payload.address else None
        if payload.is_active is not None:
            supplier.is_active = payload.is_active

        await session.commit()
        await session.refresh(supplier)

        count, amount, due = await self.repo.get_supplier_financial_metrics(
            session, business_id, supplier_id
        )

        return SupplierOut(
            id=supplier.id,
            business_id=supplier.business_id,
            name=supplier.name,
            contact_person=supplier.contact_person,
            phone=supplier.phone,
            email=supplier.email,
            address=supplier.address,
            is_active=supplier.is_active,
            total_purchases_count=count,
            total_purchases_amount=amount,
            unpaid_balance=due,
            created_at=supplier.created_at,
        )

    async def get_supplier(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        supplier_id: uuid.UUID,
    ) -> SupplierOut:
        """Fetch supplier profile with live financial metrics."""
        supplier = await self.repo.get_supplier_by_id(session, business_id, supplier_id)
        if not supplier:
            raise AppException("Supplier not found", code="SUPPLIER_NOT_FOUND", status_code=404)

        count, amount, due = await self.repo.get_supplier_financial_metrics(
            session, business_id, supplier_id
        )

        return SupplierOut(
            id=supplier.id,
            business_id=supplier.business_id,
            name=supplier.name,
            contact_person=supplier.contact_person,
            phone=supplier.phone,
            email=supplier.email,
            address=supplier.address,
            is_active=supplier.is_active,
            total_purchases_count=count,
            total_purchases_amount=amount,
            unpaid_balance=due,
            created_at=supplier.created_at,
        )

    async def list_suppliers(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        search: str | None = None,
        is_active: bool | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedSuppliers:
        """Lists paginated suppliers."""
        total = await self.repo.count_suppliers(session, business_id, search, is_active)
        suppliers = await self.repo.list_suppliers(
            session, business_id, search, is_active, page, page_size
        )

        items_out: list[SupplierOut] = []
        for s in suppliers:
            count, amount, due = await self.repo.get_supplier_financial_metrics(
                session, business_id, s.id
            )
            items_out.append(
                SupplierOut(
                    id=s.id,
                    business_id=s.business_id,
                    name=s.name,
                    contact_person=s.contact_person,
                    phone=s.phone,
                    email=s.email,
                    address=s.address,
                    is_active=s.is_active,
                    total_purchases_count=count,
                    total_purchases_amount=amount,
                    unpaid_balance=due,
                    created_at=s.created_at,
                )
            )

        total_pages = (total + page_size - 1) // page_size if total > 0 else 1

        return PaginatedSuppliers(
            items=items_out,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        )

    # -------------------------------------------------------------------------
    # Purchases
    # -------------------------------------------------------------------------

    async def create_purchase(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: PurchaseCreate,
    ) -> PurchaseOut:
        """Creates a purchase order in ORDERED state."""
        # Validate supplier
        supplier = await self.repo.get_supplier_by_id(session, business_id, payload.supplier_id)
        if not supplier:
            raise AppException("Supplier not found", code="SUPPLIER_NOT_FOUND", status_code=404)
        if not supplier.is_active:
            raise AppException("Supplier is inactive", code="INACTIVE_SUPPLIER", status_code=400)

        # Resolve branch
        branch_id = payload.branch_id
        if not branch_id:
            b_stmt = select(Branch).where(Branch.business_id == business_id, Branch.is_active.is_(True)).limit(1)
            b_res = await session.execute(b_stmt)
            default_branch = b_res.scalars().first()
            if not default_branch:
                raise AppException("No active branch found", code="BRANCH_NOT_FOUND", status_code=404)
            branch_id = default_branch.id

        # Validate product variants
        req_variant_ids = [item.product_variant_id for item in payload.items]
        v_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.id.in_(req_variant_ids),
                ProductVariant.is_active.is_(True),
            )
        )
        v_res = await session.execute(v_stmt)
        variants_map = {v.id: v for v in v_res.scalars().all()}

        for item in payload.items:
            if item.product_variant_id not in variants_map:
                raise AppException(
                    f"Product variant '{item.product_variant_id}' not found or inactive",
                    code="VARIANT_NOT_FOUND",
                    status_code=404,
                )

        # Calculate exact financial line items
        subtotal = Decimal("0.0000")
        purchase_id = uuid.uuid4()
        purchase_items: list[PurchaseItem] = []

        for item in payload.items:
            qty = item.quantity.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
            cost = item.unit_cost.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
            line_total = (qty * cost).quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
            subtotal += line_total

            p_item = PurchaseItem(
                id=uuid.uuid4(),
                purchase_id=purchase_id,
                product_variant_id=item.product_variant_id,
                quantity=qty,
                unit_cost=cost,
                line_total=line_total,
            )
            purchase_items.append(p_item)

        discount = payload.discount.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        total = max(Decimal("0.0000"), subtotal - discount)

        # Reference number
        reference_no = payload.reference_no
        if reference_no:
            existing_ref = await self.repo.get_purchase_by_reference_no(
                session, business_id, reference_no
            )
            if existing_ref:
                raise AppException(
                    f"Purchase reference '{reference_no}' already exists",
                    code="PURCHASE_REFERENCE_EXISTS",
                    status_code=409,
                )
        else:
            reference_no = await self.repo.generate_reference_no(session, business_id)

        purchase = Purchase(
            id=purchase_id,
            business_id=business_id,
            branch_id=branch_id,
            supplier_id=supplier.id,
            reference_no=reference_no,
            status="ORDERED",
            subtotal=subtotal,
            discount=discount,
            total=total,
            paid_total=Decimal("0.0000"),
            notes=payload.notes,
            created_by=user_id,
        )

        await self.repo.create_purchase(session, purchase, purchase_items)
        await session.commit()

        # Reload with eager loaded items
        loaded_purchase = await self.repo.get_purchase_by_id(session, business_id, purchase_id)
        assert loaded_purchase is not None
        return self._map_purchase_out(loaded_purchase, supplier.name, variants_map)

    async def receive_purchase(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        purchase_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> PurchaseOut:
        """Receives purchase order, increments inventory, updates cost price, and logs stock movements atomically."""
        purchase = await self.repo.get_purchase_by_id(
            session, business_id, purchase_id, for_update=True
        )
        if not purchase:
            raise AppException("Purchase order not found", code="PURCHASE_NOT_FOUND", status_code=404)

        if purchase.status == "RECEIVED":
            raise AppException(
                "Purchase order has already been received",
                code="ALREADY_RECEIVED",
                status_code=400,
            )
        if purchase.status == "CANCELLED":
            raise AppException(
                "Cancelled purchase orders cannot be received",
                code="PURCHASE_CANCELLED",
                status_code=400,
            )

        # Load variants for updating cost price
        variant_ids = [item.product_variant_id for item in purchase.items]
        v_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.id.in_(variant_ids),
            )
            .with_for_update()
        )
        v_res = await session.execute(v_stmt)
        variants_map = {v.id: v for v in v_res.scalars().all()}

        # Lock and update stock balances
        for item in purchase.items:
            variant = variants_map.get(item.product_variant_id)
            if not variant:
                continue

            # Update variant cost_price to latest received purchase price
            variant.cost_price = item.unit_cost

            # Update stock balance
            if variant.track_stock:
                balance = await self.inventory_repo.get_balance(
                    session,
                    business_id,
                    purchase.branch_id,
                    item.product_variant_id,
                    for_update=True,
                )
                if balance:
                    balance.quantity_on_hand += item.quantity
                else:
                    balance = StockBalance(
                        business_id=business_id,
                        branch_id=purchase.branch_id,
                        product_variant_id=item.product_variant_id,
                        quantity_on_hand=item.quantity,
                    )
                    session.add(balance)

                # Record stock ledger movement
                movement = StockMovement(
                    id=uuid.uuid4(),
                    business_id=business_id,
                    branch_id=purchase.branch_id,
                    product_variant_id=item.product_variant_id,
                    movement_type="PURCHASE_RECEIVE",
                    quantity_delta=item.quantity,
                    unit_cost=item.unit_cost,
                    reference_type="PURCHASE",
                    reference_id=purchase.id,
                    created_by=user_id,
                )
                session.add(movement)

        purchase.status = "RECEIVED"
        await session.commit()

        # Reload
        reloaded = await self.repo.get_purchase_by_id(session, business_id, purchase_id)
        assert reloaded is not None
        supplier = await self.repo.get_supplier_by_id(session, business_id, reloaded.supplier_id)
        supplier_name = supplier.name if supplier else None
        return self._map_purchase_out(reloaded, supplier_name, variants_map)

    async def add_purchase_payment(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        purchase_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: PurchasePaymentCreate,
    ) -> PurchasePaymentOut:
        """Records a disbursement payment towards a purchase order invoice."""
        purchase = await self.repo.get_purchase_by_id(
            session, business_id, purchase_id, for_update=True
        )
        if not purchase:
            raise AppException("Purchase order not found", code="PURCHASE_NOT_FOUND", status_code=404)

        if purchase.status == "CANCELLED":
            raise AppException("Cannot pay for a cancelled purchase order", code="PURCHASE_CANCELLED", status_code=400)

        unpaid = purchase.total - purchase.paid_total
        if payload.amount > unpaid:
            raise AppException(
                f"Payment amount ৳{payload.amount} exceeds unpaid purchase balance ৳{unpaid}",
                code="PAYMENT_EXCEEDS_UNPAID",
                status_code=400,
                details={"unpaid_balance": str(unpaid)},
            )

        payment = PurchasePayment(
            id=uuid.uuid4(),
            purchase_id=purchase.id,
            business_id=business_id,
            amount=payload.amount,
            method=payload.method,
            reference=payload.reference,
        )
        session.add(payment)
        purchase.paid_total += payload.amount

        # Log CashTransaction if cash payment was disbursed
        if payload.method == "CASH":
            cash_tx = CashTransaction(
                id=uuid.uuid4(),
                business_id=business_id,
                branch_id=purchase.branch_id,
                account_id="MAIN_CASH_DRAWER",
                direction="OUT",
                amount=payload.amount,
                reference_type="PURCHASE",
                reference_id=purchase.id,
                note=f"Disbursement payment for {purchase.reference_no}",
                created_by=user_id,
            )
            session.add(cash_tx)

        await session.commit()
        await session.refresh(payment)

        return PurchasePaymentOut(
            id=payment.id,
            purchase_id=payment.purchase_id,
            business_id=payment.business_id,
            amount=payment.amount,
            method=payment.method,
            reference=payment.reference,
            paid_at=payment.paid_at,
        )

    async def get_purchase(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        purchase_id: uuid.UUID,
    ) -> PurchaseOut:
        """Fetch purchase details."""
        purchase = await self.repo.get_purchase_by_id(session, business_id, purchase_id)
        if not purchase:
            raise AppException("Purchase order not found", code="PURCHASE_NOT_FOUND", status_code=404)

        supplier = await self.repo.get_supplier_by_id(session, business_id, purchase.supplier_id)
        supplier_name = supplier.name if supplier else None

        variant_ids = [item.product_variant_id for item in purchase.items]
        v_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_(variant_ids))
        )
        v_res = await session.execute(v_stmt)
        v_map = {v.id: v for v in v_res.scalars().all()}

        return self._map_purchase_out(purchase, supplier_name, v_map)

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
    ) -> PaginatedPurchases:
        """Fetch paginated purchases."""
        total = await self.repo.count_purchases(
            session, business_id, branch_id, supplier_id, status, start_date, end_date
        )
        purchases = await self.repo.list_purchases(
            session, business_id, branch_id, supplier_id, status, start_date, end_date, page, page_size
        )

        # Batch load suppliers
        supplier_ids = list({p.supplier_id for p in purchases})
        s_stmt = select(Supplier).where(Supplier.id.in_(supplier_ids))
        s_res = await session.execute(s_stmt)
        suppliers_map = {s.id: s.name for s in s_res.scalars().all()}

        # Batch load variants
        all_variant_ids = list({item.product_variant_id for p in purchases for item in p.items})
        v_map: dict[uuid.UUID, ProductVariant] = {}
        if all_variant_ids:
            v_stmt = (
                select(ProductVariant)
                .options(selectinload(ProductVariant.product))
                .where(ProductVariant.id.in_(all_variant_ids))
            )
            v_res = await session.execute(v_stmt)
            v_map = {v.id: v for v in v_res.scalars().all()}

        items_out = [
            self._map_purchase_out(p, suppliers_map.get(p.supplier_id), v_map)
            for p in purchases
        ]
        total_pages = (total + page_size - 1) // page_size if total > 0 else 1

        return PaginatedPurchases(
            items=items_out,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        )

    def _map_purchase_out(
        self,
        purchase: Purchase,
        supplier_name: str | None,
        variants_map: dict[uuid.UUID, ProductVariant],
    ) -> PurchaseOut:
        items_out: list[PurchaseItemOut] = []
        for item in purchase.items:
            variant = variants_map.get(item.product_variant_id)
            items_out.append(
                PurchaseItemOut(
                    id=item.id,
                    product_variant_id=item.product_variant_id,
                    product_name=variant.product.name if variant and variant.product else None,
                    variant_name=variant.name if variant else None,
                    sku=variant.product.sku if variant and variant.product else None,
                    quantity=item.quantity,
                    unit_cost=item.unit_cost,
                    line_total=item.line_total,
                )
            )

        payments_out: list[PurchasePaymentOut] = [
            PurchasePaymentOut(
                id=pm.id,
                purchase_id=pm.purchase_id,
                business_id=pm.business_id,
                amount=pm.amount,
                method=pm.method,
                reference=pm.reference,
                paid_at=pm.paid_at,
            )
            for pm in purchase.payments
        ]

        due_balance = max(Decimal("0.0000"), purchase.total - purchase.paid_total)

        return PurchaseOut(
            id=purchase.id,
            business_id=purchase.business_id,
            branch_id=purchase.branch_id,
            supplier_id=purchase.supplier_id,
            supplier_name=supplier_name,
            reference_no=purchase.reference_no,
            status=purchase.status,
            subtotal=purchase.subtotal,
            discount=purchase.discount,
            total=purchase.total,
            paid_total=purchase.paid_total,
            due_balance=due_balance,
            notes=purchase.notes,
            created_by=purchase.created_by,
            created_at=purchase.created_at,
            items=items_out,
            payments=payments_out,
        )
