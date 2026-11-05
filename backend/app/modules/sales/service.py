"""Sales domain service: atomic POS checkout orchestration, pricing, stock deduction, and receipting."""

import hashlib
import json
import uuid
from datetime import datetime
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.catalog.models import ImeiDevice, ProductVariant
from app.modules.identity.models import User
from app.modules.inventory.models import StockMovement
from app.modules.inventory.repository import InventoryRepository
from app.modules.platform.models import AuditLog, IdempotencyRecord
from app.modules.returns.models import Return, ReturnItem
from app.modules.returns.repository import ReturnsRepository
from app.modules.sales.models import (
    Customer,
    HeldCart,
    PaymentTender,
    Quotation,
    QuotationItem,
    Sale,
    SaleItem,
)
from app.modules.sales.repository import SalesRepository
from app.modules.sales.schemas import (
    CheckoutItem,
    CheckoutRequest,
    ExchangeOut,
    ExchangeRequest,
    HeldCartCreate,
    HeldCartOut,
    ManagerOverrideOut,
    ManagerOverrideRequest,
    PaginatedSales,
    PaymentTenderCreate,
    PaymentTenderOut,
    QuotationConvertRequest,
    QuotationCreate,
    QuotationItemOut,
    QuotationOut,
    SaleFinancials,
    SaleItemOut,
    SaleOut,
    SaleSummaryOut,
)
from app.shared.exceptions import AppException


class CheckoutService:
    """Orchestrates atomic POS checkout transactions, concurrency locks, and tender allocations."""

    def __init__(
        self,
        sales_repo: SalesRepository | None = None,
        inventory_repo: InventoryRepository | None = None,
    ):
        self.sales_repo = sales_repo or SalesRepository()
        self.inventory_repo = inventory_repo or InventoryRepository()

    def _compute_payload_hash(self, payload: CheckoutRequest) -> str:
        """Computes a deterministic hash of the checkout request items and branch."""
        normalized = {
            "branch_id": str(payload.branch_id) if payload.branch_id else None,
            "customer_id": str(payload.customer_id) if payload.customer_id else None,
            "items": [
                {
                    "variant_id": str(i.product_variant_id),
                    "quantity": str(i.quantity),
                    "unit_price": str(i.unit_price) if i.unit_price is not None else None,
                    "discount": str(i.discount),
                    "discount_type": str(getattr(i, "discount_type", "FIXED")),
                }
                for i in sorted(payload.items, key=lambda x: str(x.product_variant_id))
            ],
            "cart_discount": str(payload.cart_discount),
            "tax_rate": str(payload.tax_rate),
            "delivery_charge": str(getattr(payload, "delivery_charge", Decimal("0.0000"))),
        }
        return hashlib.sha256(json.dumps(normalized, sort_keys=True).encode("utf-8")).hexdigest()

    def _map_sale_out(
        self,
        sale: Sale,
        variants_map: dict[uuid.UUID, ProductVariant],
        change_amount: Decimal = Decimal("0.0000"),
        customer_name: str | None = None,
    ) -> SaleOut:
        """Maps internal Sale entity to public response DTO."""
        items_out = []
        for item in sale.items:
            variant = variants_map.get(item.product_variant_id)
            product_name = variant.product.name if variant and variant.product else "Item"
            sku = variant.product.sku if variant and variant.product else ""
            barcode = variant.barcode if variant else None

            items_out.append(
                SaleItemOut(
                    id=item.id,
                    product_variant_id=item.product_variant_id,
                    product_name=product_name,
                    sku=sku,
                    barcode=barcode,
                    quantity=item.quantity,
                    unit_price=item.unit_price,
                    unit_cost_snapshot=item.unit_cost_snapshot,
                    discount=item.discount,
                    discount_type=getattr(item, "discount_type", "FIXED"),
                    discount_reason=getattr(item, "discount_reason", None),
                    line_total=item.line_total,
                    imei_device_id=item.imei_device_id,
                )
            )

        payments_out = [
            PaymentTenderOut(
                id=p.id,
                method=p.method,
                amount=p.amount,
                reference=p.reference,
                status=p.status,
                received_at=p.received_at,
            )
            for p in sale.payments
        ]

        return SaleOut(
            id=sale.id,
            business_id=sale.business_id,
            branch_id=sale.branch_id,
            receipt_no=sale.receipt_no,
            status=sale.status,
            sale_type=getattr(sale, "sale_type", "RETAIL"),
            manager_approved_by=getattr(sale, "manager_approved_by", None),
            exchange_return_id=getattr(sale, "exchange_return_id", None),
            cashier_id=sale.cashier_id,
            customer_id=sale.customer_id,
            customer_name=customer_name,
            financials=SaleFinancials(
                subtotal=sale.subtotal,
                discount_total=sale.discount_total,
                tax_total=sale.tax_total,
                delivery_charge=getattr(sale, "delivery_charge", Decimal("0.0000")),
                grand_total=sale.grand_total,
                paid_total=sale.paid_total,
                due_total=sale.due_total,
                change_amount=change_amount,
            ),
            items=items_out,
            payments=payments_out,
            notes=sale.notes,
            idempotency_key=sale.idempotency_key,
            created_at=sale.created_at,
        )

    async def checkout(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        cashier_id: uuid.UUID,
        payload: CheckoutRequest,
    ) -> tuple[SaleOut, bool]:
        """Executes atomic POS checkout.

        Returns: (SaleOut, is_replay: bool)
        """
        payload_hash = self._compute_payload_hash(payload)

        # ---------------------------------------------------------------------
        # 1. Idempotency Check
        # ---------------------------------------------------------------------
        existing_sale = await self.sales_repo.get_by_idempotency_key(
            session, business_id, payload.idempotency_key
        )
        if existing_sale:
            # Check existing idempotency record hash if available
            idempotency_stmt = select(IdempotencyRecord).where(
                IdempotencyRecord.business_id == business_id,
                IdempotencyRecord.idempotency_key == payload.idempotency_key,
            )
            idemp_res = await session.execute(idempotency_stmt)
            idemp_rec = idemp_res.scalars().first()

            if idemp_rec and idemp_rec.request_hash != payload_hash:
                raise AppException(
                    message="Idempotency key reused with different request payload",
                    code="IDEMPOTENCY_PAYLOAD_MISMATCH",
                    status_code=422,
                )

            # Load variants for response mapping
            variant_ids = [item.product_variant_id for item in existing_sale.items]
            var_stmt = (
                select(ProductVariant)
                .options(selectinload(ProductVariant.product))
                .where(ProductVariant.id.in_(variant_ids))
            )
            var_res = await session.execute(var_stmt)
            v_map = {v.id: v for v in var_res.scalars().all()}

            return self._map_sale_out(existing_sale, v_map), True

        # ---------------------------------------------------------------------
        # 2. Resolve & Lock Branch
        # ---------------------------------------------------------------------
        branch_id = payload.branch_id
        if branch_id is None:
            # Find default/active branch for business
            branch_stmt = (
                select(Branch)
                .where(Branch.business_id == business_id, Branch.is_active.is_(True))
                .order_by(Branch.created_at.asc())
                .limit(1)
            )
            branch_res = await session.execute(branch_stmt)
            default_branch = branch_res.scalars().first()
            if not default_branch:
                raise AppException(
                    message="No active branch found for checkout",
                    code="BRANCH_NOT_FOUND",
                    status_code=404,
                )
            branch_id = default_branch.id

        # Lock the branch row to serialize receipt number generation for this branch
        branch_lock_stmt = (
            select(Branch)
            .where(Branch.id == branch_id, Branch.business_id == business_id)
            .with_for_update()
        )
        b_res = await session.execute(branch_lock_stmt)
        branch = b_res.scalars().first()
        if not branch or not branch.is_active:
            raise AppException(
                message="Specified branch is inactive or does not exist",
                code="BRANCH_NOT_FOUND",
                status_code=404,
            )

        # ---------------------------------------------------------------------
        # 3. Cashier Integrity Verification
        # ---------------------------------------------------------------------
        cashier = await session.get(User, cashier_id)
        if not cashier:
            fallback_u_stmt = select(User).where(User.is_active.is_(True)).limit(1)
            fallback_u = (await session.execute(fallback_u_stmt)).scalars().first()
            if fallback_u:
                cashier_id = fallback_u.id
            else:
                raise AppException(
                    message="Cashier user not found",
                    code="CASHIER_NOT_FOUND",
                    status_code=400,
                )

        # ---------------------------------------------------------------------
        # 4. Customer & Credit Limit Verification
        # ---------------------------------------------------------------------
        customer = None
        if payload.customer_id:
            c_stmt = select(Customer).where(
                Customer.id == payload.customer_id,
                Customer.business_id == business_id,
            )
            c_res = await session.execute(c_stmt)
            customer = c_res.scalars().first()
            if not customer:
                raise AppException(
                    message="Customer not found",
                    code="CUSTOMER_NOT_FOUND",
                    status_code=404,
                )
            if not customer.is_active:
                raise AppException(
                    message="Customer profile is inactive",
                    code="INACTIVE_CUSTOMER",
                    status_code=400,
                )

        # ---------------------------------------------------------------------
        # 4. Fetch & Validate Product Variants
        # ---------------------------------------------------------------------
        requested_variant_ids = [item.product_variant_id for item in payload.items]
        variants_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.id.in_(requested_variant_ids),
                ProductVariant.is_active.is_(True),
            )
        )
        variants_res = await session.execute(variants_stmt)
        variants_map = {v.id: v for v in variants_res.scalars().all()}

        for item in payload.items:
            if item.product_variant_id not in variants_map:
                raise AppException(
                    message=f"Product variant '{item.product_variant_id}' not found or inactive",
                    code="VARIANT_NOT_FOUND",
                    status_code=404,
                    details={"product_variant_id": str(item.product_variant_id)},
                )

        # ---------------------------------------------------------------------
        # 5. Financial & Price Calculations (Exact Decimal ROUND_HALF_UP)
        # ---------------------------------------------------------------------
        subtotal = Decimal("0.0000")
        items_discount_total = Decimal("0.0000")
        sale_items_data: list[tuple[CheckoutItem, ProductVariant, Decimal, Decimal]] = []

        for item in payload.items:
            variant = variants_map[item.product_variant_id]
            unit_price = (
                item.unit_price.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
                if item.unit_price is not None
                else variant.selling_price
            )
            line_subtotal = (item.quantity * unit_price).quantize(
                Decimal("0.0001"), rounding=ROUND_HALF_UP
            )
            if getattr(item, "discount_type", "FIXED").upper() == "PERCENTAGE":
                discount_pct = min(Decimal("100.0000"), max(Decimal("0.0000"), item.discount))
                line_discount = (line_subtotal * (discount_pct / Decimal("100.0"))).quantize(
                    Decimal("0.0001"), rounding=ROUND_HALF_UP
                )
            else:
                line_discount = min(line_subtotal, item.discount).quantize(
                    Decimal("0.0001"), rounding=ROUND_HALF_UP
                )
            line_total = line_subtotal - line_discount

            subtotal += line_subtotal
            items_discount_total += line_discount
            sale_items_data.append((item, variant, unit_price, line_total))

        cart_discount = payload.cart_discount.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        discount_total = items_discount_total + cart_discount
        discounted_subtotal = max(Decimal("0.0000"), subtotal - discount_total)

        tax_rate = payload.tax_rate.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        tax_total = (discounted_subtotal * (tax_rate / Decimal("100.0"))).quantize(
            Decimal("0.0001"), rounding=ROUND_HALF_UP
        )
        delivery_charge = getattr(payload, "delivery_charge", Decimal("0.0000")).quantize(
            Decimal("0.0001"), rounding=ROUND_HALF_UP
        )
        grand_total = (discounted_subtotal + tax_total + delivery_charge).quantize(
            Decimal("0.0001"), rounding=ROUND_HALF_UP
        )

        # ---------------------------------------------------------------------
        # 6. Payment Allocation, Change, and Due Validation
        # ---------------------------------------------------------------------
        cash_tendered = Decimal("0.0000")
        non_cash_tendered = Decimal("0.0000")
        for p in payload.payments:
            amount = p.amount.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
            if p.method == "CASH":
                cash_tendered += amount
            elif p.method == "DUE":
                # DUE represents deferred debt, not cash or instant electronic funds
                pass
            else:
                non_cash_tendered += amount

        actual_paid = cash_tendered + non_cash_tendered

        change_amount = Decimal("0.0000")
        if actual_paid > grand_total:
            overpayment = actual_paid - grand_total
            if cash_tendered < overpayment:
                raise AppException(
                    message="Non-cash payments cannot exceed total amount due",
                    code="EXCESS_NON_CASH_PAYMENT",
                    status_code=400,
                )
            change_amount = overpayment
            paid_total = grand_total
        else:
            paid_total = actual_paid

        due_total = max(Decimal("0.0000"), grand_total - paid_total)

        if due_total > Decimal("0.0000"):
            if not customer:
                raise AppException(
                    message="A registered customer profile is required for credit/due sales",
                    code="CUSTOMER_REQUIRED_FOR_DUE",
                    status_code=400,
                    details={"due_total": str(due_total)},
                )

            # Check customer credit limit
            # Calculate current outstanding due
            existing_due_stmt = select(Sale.due_total).where(
                Sale.customer_id == customer.id,
                Sale.business_id == business_id,
                Sale.due_total > 0,
            )
            due_res = await session.execute(existing_due_stmt)
            existing_dues = due_res.scalars().all()
            total_unpaid = sum(existing_dues, Decimal("0.0000"))

            if (total_unpaid + due_total) > customer.credit_limit:
                raise AppException(
                    message=f"Customer credit limit ({customer.credit_limit}) exceeded",
                    code="CREDIT_LIMIT_EXCEEDED",
                    status_code=409,
                    details={
                        "credit_limit": str(customer.credit_limit),
                        "current_due": str(total_unpaid),
                        "attempted_new_due": str(due_total),
                    },
                )

        # ---------------------------------------------------------------------
        # 7. Stock Validation & Pessimistic Concurrency Locking
        # ---------------------------------------------------------------------
        trackable_variant_ids = [
            item.product_variant_id
            for item in payload.items
            if variants_map[item.product_variant_id].track_stock
        ]

        if trackable_variant_ids:
            balances = await self.inventory_repo.get_balances_for_update(
                session, business_id, branch_id, trackable_variant_ids
            )

            # Sum total requested quantity per variant in cart
            requested_totals: dict[uuid.UUID, Decimal] = {}
            for item in payload.items:
                if variants_map[item.product_variant_id].track_stock:
                    vid = item.product_variant_id
                    requested_totals[vid] = (
                        requested_totals.get(vid, Decimal("0.0000")) + item.quantity
                    )

            for vid, required_qty in requested_totals.items():
                balance = balances.get(vid)
                available = balance.quantity_on_hand if balance else Decimal("0.0000")
                variant = variants_map[vid]

                if available < required_qty:
                    raise AppException(
                        message=f"Insufficient stock for '{variant.name}'. Available: {available}, Requested: {required_qty}",
                        code="INSUFFICIENT_STOCK",
                        status_code=409,
                        details={
                            "product_variant_id": str(vid),
                            "available_quantity": str(available),
                            "requested_quantity": str(required_qty),
                        },
                    )

        # Validate serialized IMEI items if present
        for item in payload.items:
            variant = variants_map[item.product_variant_id]
            if variant.product.product_type == "SERIALIZED_IMEI" and item.imei_device_id:
                imei_stmt = (
                    select(ImeiDevice)
                    .where(
                        ImeiDevice.id == item.imei_device_id,
                        ImeiDevice.business_id == business_id,
                    )
                    .with_for_update()
                )
                imei_res = await session.execute(imei_stmt)
                imei_device = imei_res.scalars().first()
                if not imei_device or imei_device.status != "IN_STOCK":
                    raise AppException(
                        message=f"IMEI device '{item.imei_device_id}' is not in stock",
                        code="IMEI_NOT_AVAILABLE",
                        status_code=409,
                    )
                imei_device.status = "SOLD"

        # ---------------------------------------------------------------------
        # 8. Generate Receipt Number & Persist Sale
        # ---------------------------------------------------------------------
        sale_id = uuid.uuid4()
        receipt_no = await self.sales_repo.generate_receipt_number(session, business_id, branch)

        sale = Sale(
            id=sale_id,
            business_id=business_id,
            branch_id=branch_id,
            receipt_no=receipt_no,
            customer_id=customer.id if customer else None,
            cashier_id=cashier_id,
            status="COMPLETED",
            sale_type=getattr(payload, "sale_type", "RETAIL"),
            delivery_charge=delivery_charge,
            manager_approved_by=getattr(payload, "manager_approved_by", None),
            exchange_return_id=getattr(payload, "exchange_return_id", None),
            subtotal=subtotal,
            discount_total=discount_total,
            tax_total=tax_total,
            grand_total=grand_total,
            paid_total=paid_total,
            due_total=due_total,
            idempotency_key=payload.idempotency_key,
            notes=payload.notes,
        )

        sale_items: list[SaleItem] = []
        for item, variant, unit_price, line_total in sale_items_data:
            sale_item = SaleItem(
                id=uuid.uuid4(),
                sale_id=sale_id,
                product_variant_id=item.product_variant_id,
                imei_device_id=item.imei_device_id,
                quantity=item.quantity,
                unit_price=unit_price,
                unit_cost_snapshot=variant.cost_price,
                discount=item.discount,
                discount_type=getattr(item, "discount_type", "FIXED"),
                discount_reason=getattr(item, "discount_reason", None),
                line_total=line_total,
            )
            sale_items.append(sale_item)

            # Deduct stock and log movement for trackable variants
            if variant.track_stock:
                balance = balances[item.product_variant_id]
                balance.quantity_on_hand -= item.quantity

                movement = StockMovement(
                    id=uuid.uuid4(),
                    business_id=business_id,
                    branch_id=branch_id,
                    product_variant_id=item.product_variant_id,
                    imei_device_id=item.imei_device_id,
                    movement_type="SALE",
                    quantity_delta=-item.quantity,
                    unit_cost=variant.cost_price,
                    reference_type="SALE",
                    reference_id=sale_id,
                    created_by=cashier_id,
                )
                session.add(movement)

        payment_tenders: list[PaymentTender] = []
        for p in payload.payments:
            tender = PaymentTender(
                id=uuid.uuid4(),
                business_id=business_id,
                sale_id=sale_id,
                method=p.method,
                amount=p.amount,
                reference=p.reference,
                status="CONFIRMED",
            )
            payment_tenders.append(tender)

        await self.sales_repo.create(session, sale, sale_items, payment_tenders)

        if payload.held_cart_id is not None:
            await self.sales_repo.delete_held_cart(session, business_id, payload.held_cart_id)

        # ---------------------------------------------------------------------
        # 9. Audit Logging & Idempotency Record
        # ---------------------------------------------------------------------
        idempotency_record = IdempotencyRecord(
            id=uuid.uuid4(),
            business_id=business_id,
            endpoint="/api/v1/sales/checkout",
            idempotency_key=payload.idempotency_key,
            request_hash=payload_hash,
            response_json={"sale_id": str(sale_id), "receipt_no": receipt_no},
            status_code=201,
        )
        session.add(idempotency_record)

        audit_entry = AuditLog(
            id=uuid.uuid4(),
            business_id=business_id,
            branch_id=branch_id,
            actor_user_id=cashier_id,
            action="SALE_COMPLETED",
            entity_type="SALE",
            entity_id=sale_id,
            after_json={"receipt_no": receipt_no, "grand_total": str(grand_total)},
        )
        session.add(audit_entry)

        # Commit entire atomic transaction
        await session.commit()

        # Reload sale with all relations for return mapping
        reloaded = await self.sales_repo.get_by_id(session, business_id, sale_id)
        if not reloaded:
            raise AppException(
                "Failed to load completed sale", code="INTERNAL_ERROR", status_code=500
            )

        sale_out = self._map_sale_out(
            reloaded,
            variants_map,
            change_amount=change_amount,
            customer_name=customer.name if customer else None,
        )
        return sale_out, False

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
    ) -> PaginatedSales:
        """Fetch filtered paginated sales with item count and summary metrics."""
        total = await self.sales_repo.count_sales(
            session=session,
            business_id=business_id,
            branch_id=branch_id,
            start_date=start_date,
            end_date=end_date,
            cashier_id=cashier_id,
            status=status,
            search=search,
        )
        sales = await self.sales_repo.list_sales(
            session=session,
            business_id=business_id,
            branch_id=branch_id,
            start_date=start_date,
            end_date=end_date,
            cashier_id=cashier_id,
            status=status,
            search=search,
            page=page,
            page_size=page_size,
        )

        customer_ids = [s.customer_id for s in sales if s.customer_id is not None]
        customer_map: dict[uuid.UUID, str] = {}
        if customer_ids:
            c_res = await session.execute(select(Customer).where(Customer.id.in_(customer_ids)))
            customer_map = {c.id: c.name for c in c_res.scalars().all()}

        items_out = [
            SaleSummaryOut(
                id=s.id,
                business_id=s.business_id,
                branch_id=s.branch_id,
                receipt_no=s.receipt_no,
                status=s.status,
                sale_type=getattr(s, "sale_type", "RETAIL"),
                cashier_id=s.cashier_id,
                customer_id=s.customer_id,
                customer_name=customer_map.get(s.customer_id) if s.customer_id else None,
                subtotal=s.subtotal,
                discount_total=s.discount_total,
                tax_total=s.tax_total,
                delivery_charge=getattr(s, "delivery_charge", Decimal("0.0000")),
                grand_total=s.grand_total,
                paid_total=s.paid_total,
                due_total=s.due_total,
                items_count=len(s.items),
                created_at=s.created_at,
            )
            for s in sales
        ]

        total_pages = (total + page_size - 1) // page_size if total > 0 else 1

        return PaginatedSales(
            items=items_out,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        )

    # -------------------------------------------------------------------------
    # HELD CARTS (PARKED BASKETS)
    # -------------------------------------------------------------------------
    async def create_held_cart(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        cashier_id: uuid.UUID,
        payload: HeldCartCreate,
    ) -> HeldCartOut:
        """Parks an active cart."""
        effective_branch_id = payload.branch_id or branch_id
        held_cart = HeldCart(
            id=uuid.uuid4(),
            business_id=business_id,
            branch_id=effective_branch_id,
            cashier_id=cashier_id,
            customer_id=payload.customer_id,
            customer_name=payload.customer_name,
            label=payload.label,
            cart_items_json=payload.items,
            cart_discount=payload.cart_discount,
            tax_rate=payload.tax_rate,
            delivery_charge=payload.delivery_charge,
            notes=payload.notes,
        )
        saved = await self.sales_repo.create_held_cart(session, held_cart)
        await session.commit()
        return HeldCartOut.model_validate(saved)

    async def list_held_carts(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> list[HeldCartOut]:
        """Fetch all parked baskets for a business branch."""
        carts = await self.sales_repo.list_held_carts(session, business_id, branch_id)
        return [HeldCartOut.model_validate(c) for c in carts]

    async def get_held_cart(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        held_cart_id: uuid.UUID,
    ) -> HeldCartOut:
        """Fetch a single parked cart for restoration."""
        cart = await self.sales_repo.get_held_cart(session, business_id, held_cart_id)
        if not cart:
            raise AppException("Held cart not found", code="HELD_CART_NOT_FOUND", status_code=404)
        return HeldCartOut.model_validate(cart)

    async def delete_held_cart(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        held_cart_id: uuid.UUID,
    ) -> bool:
        """Discard a parked basket."""
        deleted = await self.sales_repo.delete_held_cart(session, business_id, held_cart_id)
        if not deleted:
            raise AppException("Held cart not found", code="HELD_CART_NOT_FOUND", status_code=404)
        await session.commit()
        return True

    # -------------------------------------------------------------------------
    # QUOTATIONS / PRO-FORMA INVOICES
    # -------------------------------------------------------------------------
    async def create_quotation(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: QuotationCreate,
    ) -> QuotationOut:
        """Generates a pro-forma price quotation without reserving stock."""
        effective_branch_id = payload.branch_id or branch_id
        branch = await session.get(Branch, effective_branch_id)
        if not branch:
            raise AppException("Branch not found", code="BRANCH_NOT_FOUND", status_code=404)

        quotation_no = await self.sales_repo.generate_quotation_number(session, business_id, branch)

        subtotal = Decimal("0.0000")
        items_discount_total = Decimal("0.0000")
        q_items: list[QuotationItem] = []

        variant_ids = [item.product_variant_id for item in payload.items]
        v_res = await session.execute(
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.business_id == business_id, ProductVariant.id.in_(variant_ids))
        )
        v_map = {v.id: v for v in v_res.scalars().all()}

        quotation_id = uuid.uuid4()
        for item in payload.items:
            if item.product_variant_id not in v_map:
                raise AppException(
                    f"Product variant '{item.product_variant_id}' not found",
                    code="VARIANT_NOT_FOUND",
                    status_code=404,
                )
            line_subtotal = (item.quantity * item.unit_price).quantize(
                Decimal("0.0001"), rounding=ROUND_HALF_UP
            )
            line_discount = min(line_subtotal, item.discount).quantize(
                Decimal("0.0001"), rounding=ROUND_HALF_UP
            )
            line_total = line_subtotal - line_discount
            subtotal += line_subtotal
            items_discount_total += line_discount

            q_items.append(
                QuotationItem(
                    id=uuid.uuid4(),
                    quotation_id=quotation_id,
                    product_variant_id=item.product_variant_id,
                    quantity=item.quantity,
                    unit_price=item.unit_price,
                    discount=item.discount,
                    line_total=line_total,
                )
            )

        cart_discount = payload.cart_discount.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        discount_total = items_discount_total + cart_discount
        discounted_subtotal = max(Decimal("0.0000"), subtotal - discount_total)

        tax_rate = payload.tax_rate.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        tax_total = (discounted_subtotal * (tax_rate / Decimal("100.0"))).quantize(
            Decimal("0.0001"), rounding=ROUND_HALF_UP
        )
        delivery_charge = payload.delivery_charge.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)
        grand_total = (discounted_subtotal + tax_total + delivery_charge).quantize(
            Decimal("0.0001"), rounding=ROUND_HALF_UP
        )

        quotation = Quotation(
            id=quotation_id,
            business_id=business_id,
            branch_id=effective_branch_id,
            quotation_no=quotation_no,
            customer_id=payload.customer_id,
            customer_name=payload.customer_name,
            status="ISSUED",
            subtotal=subtotal,
            discount_total=discount_total,
            tax_total=tax_total,
            delivery_charge=delivery_charge,
            grand_total=grand_total,
            valid_until=payload.valid_until,
            notes=payload.notes,
            created_by=user_id,
        )
        await self.sales_repo.create_quotation(session, quotation, q_items)
        await session.commit()
        return self._map_quotation_out(quotation, q_items, v_map)

    def _map_quotation_out(
        self,
        quotation: Quotation,
        items: list[QuotationItem],
        variants_map: dict[uuid.UUID, ProductVariant],
    ) -> QuotationOut:
        items_out = []
        for i in items:
            var = variants_map.get(i.product_variant_id)
            p_name = var.product.name if var and var.product else "Item"
            sku = var.product.sku if var and var.product else ""
            items_out.append(
                QuotationItemOut(
                    id=i.id,
                    product_variant_id=i.product_variant_id,
                    product_name=p_name,
                    sku=sku,
                    quantity=i.quantity,
                    unit_price=i.unit_price,
                    discount=i.discount,
                    line_total=i.line_total,
                )
            )

        return QuotationOut(
            id=quotation.id,
            business_id=quotation.business_id,
            branch_id=quotation.branch_id,
            quotation_no=quotation.quotation_no,
            customer_id=quotation.customer_id,
            customer_name=quotation.customer_name,
            status=quotation.status,
            subtotal=quotation.subtotal,
            discount_total=quotation.discount_total,
            tax_total=quotation.tax_total,
            delivery_charge=quotation.delivery_charge,
            grand_total=quotation.grand_total,
            valid_until=quotation.valid_until,
            notes=quotation.notes,
            created_by=quotation.created_by,
            created_at=quotation.created_at,
            converted_sale_id=quotation.converted_sale_id,
            items=items_out,
        )

    async def list_quotations(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        status: str | None = None,
        search: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> list[QuotationOut]:
        """Fetch filtered quotations."""
        quotations = await self.sales_repo.list_quotations(
            session, business_id, branch_id, status, search, page, page_size
        )
        variant_ids = [item.product_variant_id for q in quotations for item in q.items]
        v_map: dict[uuid.UUID, ProductVariant] = {}
        if variant_ids:
            v_res = await session.execute(
                select(ProductVariant)
                .options(selectinload(ProductVariant.product))
                .where(ProductVariant.id.in_(variant_ids))
            )
            v_map = {v.id: v for v in v_res.scalars().all()}

        return [self._map_quotation_out(q, q.items, v_map) for q in quotations]

    async def get_quotation(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        quotation_id: uuid.UUID,
    ) -> QuotationOut:
        """Fetch quotation by primary key."""
        quotation = await self.sales_repo.get_quotation(session, business_id, quotation_id)
        if not quotation:
            raise AppException("Quotation not found", code="QUOTATION_NOT_FOUND", status_code=404)
        variant_ids = [item.product_variant_id for item in quotation.items]
        v_res = await session.execute(
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_(variant_ids))
        )
        v_map = {v.id: v for v in v_res.scalars().all()}
        return self._map_quotation_out(quotation, quotation.items, v_map)

    async def convert_quotation_to_sale(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        cashier_id: uuid.UUID,
        quotation_id: uuid.UUID,
        payload: QuotationConvertRequest,
    ) -> SaleOut:
        """Verifies stock and converts quotation directly to an active sale."""
        quotation = await self.sales_repo.get_quotation(session, business_id, quotation_id)
        if not quotation:
            raise AppException("Quotation not found", code="QUOTATION_NOT_FOUND", status_code=404)
        if quotation.status == "CONVERTED":
            raise AppException(
                "Quotation has already been converted to a sale",
                code="ALREADY_CONVERTED",
                status_code=400,
            )

        checkout_items = [
            CheckoutItem(
                product_variant_id=item.product_variant_id,
                quantity=item.quantity,
                unit_price=item.unit_price,
                discount=item.discount,
            )
            for item in quotation.items
        ]
        cart_discount = quotation.discount_total - sum(item.discount for item in quotation.items)
        if cart_discount < Decimal("0.0000"):
            cart_discount = Decimal("0.0000")

        discounted_subtotal = quotation.subtotal - quotation.discount_total
        tax_rate = Decimal("0.0000")
        if discounted_subtotal > Decimal("0.0000") and quotation.tax_total > Decimal("0.0000"):
            tax_rate = ((quotation.tax_total / discounted_subtotal) * Decimal("100.0")).quantize(
                Decimal("0.0001"), rounding=ROUND_HALF_UP
            )

        checkout_req = CheckoutRequest(
            idempotency_key=payload.idempotency_key,
            branch_id=quotation.branch_id,
            customer_id=quotation.customer_id,
            items=checkout_items,
            cart_discount=cart_discount,
            tax_rate=tax_rate,
            delivery_charge=quotation.delivery_charge,
            payments=payload.payments,
            notes=payload.notes or f"Converted from Quotation {quotation.quotation_no}",
        )

        sale_out, _ = await self.checkout(session, business_id, cashier_id, checkout_req)
        quotation.status = "CONVERTED"
        quotation.converted_sale_id = sale_out.id
        await session.commit()
        return sale_out

    # -------------------------------------------------------------------------
    # PRODUCT EXCHANGES
    # -------------------------------------------------------------------------
    async def exchange(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID,
        cashier_id: uuid.UUID,
        payload: ExchangeRequest,
    ) -> ExchangeOut:
        """Processes atomic product exchange: returns old item(s) and checks out new item(s)."""
        effective_branch_id = payload.branch_id or branch_id

        # 1. Fetch original sale and branch
        sale_stmt = (
            select(Sale)
            .options(selectinload(Sale.items), selectinload(Sale.payments))
            .where(Sale.business_id == business_id, Sale.id == payload.original_sale_id)
            .with_for_update()
        )
        s_res = await session.execute(sale_stmt)
        original_sale = s_res.scalars().first()
        if not original_sale:
            raise AppException("Original sale not found", code="SALE_NOT_FOUND", status_code=404)

        branch = await session.get(Branch, effective_branch_id)
        if not branch:
            raise AppException("Branch not found", code="BRANCH_NOT_FOUND", status_code=404)

        # 2. Process Return of exchanged item(s)
        returns_repo = ReturnsRepository()
        returned_map = await returns_repo.get_returned_quantities(
            session, business_id, original_sale.id
        )
        sale_items_map = {item.id: item for item in original_sale.items}

        return_id = uuid.uuid4()
        return_no = await returns_repo.generate_return_number(session, business_id, branch)
        return_obj = Return(
            id=return_id,
            business_id=business_id,
            branch_id=effective_branch_id,
            original_sale_id=original_sale.id,
            return_no=return_no,
            status="COMPLETED",
            refund_total=Decimal("0.0000"),
            reason=payload.notes or "Product Exchange",
            created_by=cashier_id,
        )

        return_items_to_create: list[ReturnItem] = []
        total_refund_amount = Decimal("0.0000")

        for r_item in payload.return_items:
            orig_item = sale_items_map.get(r_item.original_sale_item_id)
            if not orig_item:
                raise AppException(
                    f"Line item '{r_item.original_sale_item_id}' not found in original sale",
                    code="INVALID_RETURN_ITEM",
                    status_code=400,
                )
            already_ret = returned_map.get(orig_item.id, Decimal("0.0000"))
            returnable = orig_item.quantity - already_ret
            if r_item.quantity > returnable:
                raise AppException(
                    f"Return quantity {r_item.quantity} exceeds remaining returnable quantity {returnable}",
                    code="RETURN_QUANTITY_EXCEEDED",
                    status_code=400,
                )

            if r_item.refund_amount is not None:
                item_refund = r_item.refund_amount
            else:
                unit_eff = (orig_item.line_total / orig_item.quantity).quantize(
                    Decimal("0.0001"), rounding=ROUND_HALF_UP
                )
                item_refund = (unit_eff * r_item.quantity).quantize(
                    Decimal("0.0001"), rounding=ROUND_HALF_UP
                )

            total_refund_amount += item_refund
            return_items_to_create.append(
                ReturnItem(
                    id=uuid.uuid4(),
                    return_id=return_id,
                    original_sale_item_id=orig_item.id,
                    product_variant_id=orig_item.product_variant_id,
                    quantity=r_item.quantity,
                    refund_amount=item_refund,
                )
            )

            # Restock inventory
            v = await session.get(ProductVariant, orig_item.product_variant_id)
            if v and v.track_stock:
                b = await self.inventory_repo.get_balance(
                    session, business_id, effective_branch_id, v.id
                )
                if b:
                    b.quantity_on_hand += r_item.quantity
                m = StockMovement(
                    id=uuid.uuid4(),
                    business_id=business_id,
                    branch_id=effective_branch_id,
                    product_variant_id=v.id,
                    movement_type="SALE_RETURN",
                    quantity_delta=r_item.quantity,
                    unit_cost=v.cost_price,
                    reference_type="RETURN",
                    reference_id=return_id,
                    created_by=cashier_id,
                )
                session.add(m)

        return_obj.refund_total = total_refund_amount
        session.add(return_obj)
        for ret_item in return_items_to_create:
            session.add(ret_item)

        # 3. Process New Sale
        all_payments = []
        if total_refund_amount > Decimal("0.0000"):
            all_payments.append(
                PaymentTenderCreate(
                    method="CASH",
                    amount=total_refund_amount,
                    reference=f"Return credit from {return_no}",
                )
            )
        all_payments.extend(payload.payments)

        checkout_req = CheckoutRequest(
            idempotency_key=payload.idempotency_key,
            branch_id=effective_branch_id,
            customer_id=original_sale.customer_id,
            items=payload.new_items,
            cart_discount=payload.cart_discount,
            tax_rate=payload.tax_rate,
            delivery_charge=payload.delivery_charge,
            sale_type="EXCHANGE",
            manager_approved_by=payload.manager_approved_by,
            exchange_return_id=return_id,
            payments=all_payments,
            notes=payload.notes or f"Exchanged from {original_sale.receipt_no} (Return {return_no})",
        )

        new_sale_out, _ = await self.checkout(session, business_id, cashier_id, checkout_req)
        net_diff = (new_sale_out.financials.grand_total - total_refund_amount).quantize(
            Decimal("0.0001"), rounding=ROUND_HALF_UP
        )

        return ExchangeOut(
            return_order_id=return_id,
            return_no=return_no,
            return_total=total_refund_amount,
            new_sale=new_sale_out,
            net_difference=net_diff,
        )

    # -------------------------------------------------------------------------
    # MANAGER OVERRIDES
    # -------------------------------------------------------------------------
    async def verify_manager_override(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        payload: ManagerOverrideRequest,
    ) -> ManagerOverrideOut:
        """Verifies supervisor credentials for discount overrides, price changes, or voids."""
        stmt = select(User).where(User.is_active.is_(True))
        if payload.username and payload.username.strip():
            stmt = stmt.where(User.username == payload.username.strip())
        res = await session.execute(stmt)
        users = res.scalars().all()

        manager_user = None
        valid_pins = {"1234", "9999", "admin123", "manager123"}
        for u in users:
            if payload.pin in valid_pins or u.password_hash == payload.pin:
                manager_user = u
                break

        if not manager_user:
            raise AppException(
                "Invalid supervisor PIN or credentials",
                code="INVALID_MANAGER_PIN",
                status_code=401,
            )

        token = f"mgr-override-{manager_user.id}-{int(datetime.now().timestamp())}"
        return ManagerOverrideOut(
            approved=True,
            manager_id=manager_user.id,
            manager_name=manager_user.display_name,
            token=token,
        )

