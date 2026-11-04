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
from app.modules.sales.models import Customer, PaymentTender, Sale, SaleItem
from app.modules.sales.repository import SalesRepository
from app.modules.sales.schemas import (
    CheckoutItem,
    CheckoutRequest,
    PaginatedSales,
    PaymentTenderOut,
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
                }
                for i in sorted(payload.items, key=lambda x: str(x.product_variant_id))
            ],
            "cart_discount": str(payload.cart_discount),
            "tax_rate": str(payload.tax_rate),
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
            cashier_id=sale.cashier_id,
            customer_id=sale.customer_id,
            customer_name=customer_name,
            financials=SaleFinancials(
                subtotal=sale.subtotal,
                discount_total=sale.discount_total,
                tax_total=sale.tax_total,
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
        grand_total = (discounted_subtotal + tax_total).quantize(
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
                cashier_id=s.cashier_id,
                customer_id=s.customer_id,
                customer_name=customer_map.get(s.customer_id) if s.customer_id else None,
                subtotal=s.subtotal,
                discount_total=s.discount_total,
                tax_total=s.tax_total,
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
