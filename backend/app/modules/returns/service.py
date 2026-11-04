"""Business service for processing customer returns, inventory restocking, and sales voids."""

import uuid
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.business.models import Branch
from app.modules.catalog.models import ProductVariant
from app.modules.inventory.models import StockMovement
from app.modules.inventory.repository import InventoryRepository
from app.modules.returns.models import Return, ReturnItem
from app.modules.returns.repository import ReturnsRepository
from app.modules.returns.schemas import (
    ReturnCreateRequest,
    ReturnItemOut,
    ReturnOut,
    SaleReturnableItem,
)
from app.modules.sales.models import Sale, SaleItem
from app.modules.sales.schemas import (
    PaymentTenderOut,
    SaleFinancials,
    SaleItemOut,
    SaleOut,
    VoidSaleRequest,
)
from app.shared.exceptions import AppException


class ReturnsService:
    """Orchestrates atomic customer sales returns, inventory ledger updates, and voiding."""

    def __init__(self) -> None:
        self.returns_repo = ReturnsRepository()
        self.inventory_repo = InventoryRepository()

    async def get_returnable_items(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        sale_id: uuid.UUID,
    ) -> list[SaleReturnableItem]:
        """Calculates current remaining returnable quantity for each line item on a sale."""
        sale_stmt = (
            select(Sale)
            .options(
                selectinload(Sale.items),
            )
            .where(Sale.business_id == business_id, Sale.id == sale_id)
        )
        sale_res = await session.execute(sale_stmt)
        sale = sale_res.scalars().first()
        if not sale:
            raise AppException("Sale not found", code="SALE_NOT_FOUND", status_code=404)

        returned_map = await self.returns_repo.get_returned_quantities(
            session, business_id, sale_id
        )

        # Load product variant information
        variant_ids = [item.product_variant_id for item in sale.items]
        var_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_(variant_ids))
        )
        var_res = await session.execute(var_stmt)
        variant_map = {v.id: v for v in var_res.scalars().all()}

        results: list[SaleReturnableItem] = []
        for item in sale.items:
            variant = variant_map.get(item.product_variant_id)
            p_name = variant.product.name if variant and variant.product else "Unknown Product"
            sku = variant.product.sku if variant and variant.product else "UNKNOWN"
            qty_returned = returned_map.get(item.id, Decimal("0.0000"))
            qty_returnable = max(Decimal("0.0000"), item.quantity - qty_returned)

            results.append(
                SaleReturnableItem(
                    sale_item_id=item.id,
                    product_variant_id=item.product_variant_id,
                    product_name=p_name,
                    sku=sku,
                    quantity_sold=item.quantity,
                    quantity_returned=qty_returned,
                    quantity_returnable=qty_returnable,
                    unit_price=item.unit_price,
                    line_total=item.line_total,
                )
            )

        return results

    async def create_return(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        cashier_id: uuid.UUID,
        sale_id: uuid.UUID,
        payload: ReturnCreateRequest,
    ) -> ReturnOut:
        """Processes partial or full customer sales return within an atomic transaction.

        Restores physical stock in inventory balances and writes immutable SALE_RETURN movements.
        """
        # 1. Pessimistic lock on the Sale header
        stmt = (
            select(Sale)
            .options(
                selectinload(Sale.items),
                selectinload(Sale.payments),
            )
            .where(Sale.business_id == business_id, Sale.id == sale_id)
            .with_for_update()
        )
        result = await session.execute(stmt)
        sale = result.scalars().first()
        if not sale:
            raise AppException("Sale not found", code="SALE_NOT_FOUND", status_code=404)

        if sale.status == "VOIDED":
            raise AppException(
                "Cannot process return for a voided sale",
                code="CANNOT_RETURN_VOIDED_SALE",
                status_code=400,
            )

        # 2. Get Branch for return numbering
        branch_stmt = select(Branch).where(
            Branch.business_id == business_id, Branch.id == sale.branch_id
        )
        b_res = await session.execute(branch_stmt)
        branch = b_res.scalars().first()
        if not branch:
            raise AppException("Branch not found", code="BRANCH_NOT_FOUND", status_code=404)

        # 3. Retrieve prior return totals per sale item
        returned_map = await self.returns_repo.get_returned_quantities(
            session, business_id, sale_id
        )
        sale_items_map = {item.id: item for item in sale.items}

        # 4. Validate items to return
        return_items_to_create: list[ReturnItem] = []
        stock_restock_list: list[tuple[SaleItem, Decimal]] = []
        total_refund_amount = Decimal("0.0000")

        return_id = uuid.uuid4()
        return_no = await self.returns_repo.generate_return_number(session, business_id, branch)

        return_obj = Return(
            id=return_id,
            business_id=business_id,
            branch_id=sale.branch_id,
            original_sale_id=sale.id,
            return_no=return_no,
            status="COMPLETED",
            refund_total=Decimal("0.0000"),  # updated below
            reason=payload.reason,
            created_by=cashier_id,
        )

        for req_item in payload.items:
            sale_item = sale_items_map.get(req_item.original_sale_item_id)
            if not sale_item:
                raise AppException(
                    f"Line item '{req_item.original_sale_item_id}' does not belong to sale '{sale.receipt_no}'",
                    code="INVALID_RETURN_ITEM",
                    status_code=400,
                )

            already_returned = returned_map.get(sale_item.id, Decimal("0.0000"))
            returnable = sale_item.quantity - already_returned
            if req_item.quantity > returnable:
                raise AppException(
                    f"Requested return quantity {req_item.quantity} exceeds remaining returnable quantity {returnable}",
                    code="RETURN_QUANTITY_EXCEEDED",
                    status_code=400,
                )

            # Calculate refund amount
            if req_item.refund_amount is not None:
                item_refund = req_item.refund_amount
            else:
                unit_effective_price = (sale_item.line_total / sale_item.quantity).quantize(
                    Decimal("0.0001"), rounding=ROUND_HALF_UP
                )
                item_refund = (unit_effective_price * req_item.quantity).quantize(
                    Decimal("0.0001"), rounding=ROUND_HALF_UP
                )

            total_refund_amount += item_refund

            return_item = ReturnItem(
                id=uuid.uuid4(),
                return_id=return_id,
                original_sale_item_id=sale_item.id,
                product_variant_id=sale_item.product_variant_id,
                quantity=req_item.quantity,
                refund_amount=item_refund,
                restock_status=req_item.restock_status if req_item.restock else "SCRAPPED",
            )
            return_items_to_create.append(return_item)

            if req_item.restock and req_item.restock_status == "RESTOCKED":
                stock_restock_list.append((sale_item, req_item.quantity))

            # Update running tally for multiple return items referring to same sale item
            returned_map[sale_item.id] = already_returned + req_item.quantity

        return_obj.refund_total = total_refund_amount

        # 5. Persist return and items
        session.add(return_obj)
        for r_item in return_items_to_create:
            session.add(r_item)

        # 6. Apply stock restocking and audit movements
        if stock_restock_list:
            variant_ids = [s_item.product_variant_id for s_item, _ in stock_restock_list]
            balances = await self.inventory_repo.get_balances_for_update(
                session, business_id, sale.branch_id, variant_ids
            )

            for s_item, qty in stock_restock_list:
                bal = balances.get(s_item.product_variant_id)
                if bal:
                    bal.quantity_on_hand += qty
                else:
                    await self.inventory_repo.set_balance(
                        session, business_id, sale.branch_id, s_item.product_variant_id, qty
                    )

                movement = StockMovement(
                    business_id=business_id,
                    branch_id=sale.branch_id,
                    product_variant_id=s_item.product_variant_id,
                    imei_device_id=s_item.imei_device_id,
                    movement_type="SALE_RETURN",
                    quantity_delta=qty,  # Positive delta restores inventory
                    unit_cost=s_item.unit_cost_snapshot,
                    reference_type="RETURN",
                    reference_id=return_obj.id,
                    created_by=cashier_id,
                )
                await self.inventory_repo.record_movement(session, movement)

        # 7. Update Sale status (PARTIALLY_REFUNDED vs REFUNDED)
        all_returned = True
        for s_item in sale.items:
            if returned_map.get(s_item.id, Decimal("0.0000")) < s_item.quantity:
                all_returned = False
                break

        sale.status = "REFUNDED" if all_returned else "PARTIALLY_REFUNDED"

        await session.commit()
        await session.refresh(return_obj)

        # Load variant info for presentation
        var_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_([ri.product_variant_id for ri in return_items_to_create]))
        )
        v_res = await session.execute(var_stmt)
        variant_map = {v.id: v for v in v_res.scalars().all()}

        items_out: list[ReturnItemOut] = []
        for ri in return_items_to_create:
            variant = variant_map.get(ri.product_variant_id)
            p_name = variant.product.name if variant and variant.product else "Unknown Product"
            sku = variant.product.sku if variant and variant.product else "UNKNOWN"
            items_out.append(
                ReturnItemOut(
                    id=ri.id,
                    return_id=ri.return_id,
                    original_sale_item_id=ri.original_sale_item_id,
                    product_variant_id=ri.product_variant_id,
                    product_name=p_name,
                    sku=sku,
                    quantity=ri.quantity,
                    refund_amount=ri.refund_amount,
                    restock_status=ri.restock_status,
                )
            )

        return ReturnOut(
            id=return_obj.id,
            business_id=return_obj.business_id,
            branch_id=return_obj.branch_id,
            original_sale_id=return_obj.original_sale_id,
            return_no=return_obj.return_no,
            status=return_obj.status,
            refund_total=return_obj.refund_total,
            reason=return_obj.reason,
            created_by=return_obj.created_by,
            created_at=return_obj.created_at,
            items=items_out,
        )

    async def void_sale(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        cashier_id: uuid.UUID,
        sale_id: uuid.UUID,
        payload: VoidSaleRequest,
    ) -> SaleOut:
        """Voids an existing completed sale, reversing stock and marking tenders voided."""
        stmt = (
            select(Sale)
            .options(
                selectinload(Sale.items),
                selectinload(Sale.payments),
            )
            .where(Sale.business_id == business_id, Sale.id == sale_id)
            .with_for_update()
        )
        result = await session.execute(stmt)
        sale = result.scalars().first()
        if not sale:
            raise AppException("Sale not found", code="SALE_NOT_FOUND", status_code=404)

        if sale.status == "VOIDED":
            raise AppException("Sale is already voided", code="ALREADY_VOIDED", status_code=400)

        if sale.status in ("REFUNDED", "PARTIALLY_REFUNDED"):
            raise AppException(
                "Cannot void a sale that already has active returns or refunds",
                code="CANNOT_VOID_REFUNDED_SALE",
                status_code=400,
            )

        # 1. Reverse stock for each sale item
        variant_ids = [item.product_variant_id for item in sale.items]
        balances = await self.inventory_repo.get_balances_for_update(
            session, business_id, sale.branch_id, variant_ids
        )

        for item in sale.items:
            bal = balances.get(item.product_variant_id)
            if bal:
                bal.quantity_on_hand += item.quantity
            else:
                await self.inventory_repo.set_balance(
                    session, business_id, sale.branch_id, item.product_variant_id, item.quantity
                )

            movement = StockMovement(
                business_id=business_id,
                branch_id=sale.branch_id,
                product_variant_id=item.product_variant_id,
                imei_device_id=item.imei_device_id,
                movement_type="SALE_RETURN",
                quantity_delta=item.quantity,
                unit_cost=item.unit_cost_snapshot,
                reference_type="SALE",
                reference_id=sale.id,
                created_by=cashier_id,
            )
            await self.inventory_repo.record_movement(session, movement)

        # 2. Void all payment tenders
        for tender in sale.payments:
            tender.status = "VOIDED"

        # 3. Update Sale header
        sale.status = "VOIDED"
        void_note = f"[VOIDED]: {payload.reason.strip()}"
        sale.notes = f"{sale.notes}\n{void_note}" if sale.notes else void_note

        await session.commit()
        await session.refresh(sale)

        # Build SaleOut representation
        var_stmt = (
            select(ProductVariant)
            .options(selectinload(ProductVariant.product))
            .where(ProductVariant.id.in_(variant_ids))
        )
        v_res = await session.execute(var_stmt)
        variant_map = {v.id: v for v in v_res.scalars().all()}

        items_out: list[SaleItemOut] = []
        for item in sale.items:
            variant = variant_map.get(item.product_variant_id)
            p_name = variant.product.name if variant and variant.product else "Unknown Product"
            sku = variant.product.sku if variant and variant.product else "UNKNOWN"
            barcode = variant.barcode if variant else None
            items_out.append(
                SaleItemOut(
                    id=item.id,
                    product_variant_id=item.product_variant_id,
                    product_name=p_name,
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

        financials = SaleFinancials(
            subtotal=sale.subtotal,
            discount_total=sale.discount_total,
            tax_total=sale.tax_total,
            grand_total=sale.grand_total,
            paid_total=sale.paid_total,
            due_total=sale.due_total,
            change_amount=max(Decimal("0.0000"), sale.paid_total - sale.grand_total),
        )

        return SaleOut(
            id=sale.id,
            business_id=sale.business_id,
            branch_id=sale.branch_id,
            receipt_no=sale.receipt_no,
            status=sale.status,
            cashier_id=sale.cashier_id,
            customer_id=sale.customer_id,
            customer_name=None,
            financials=financials,
            items=items_out,
            payments=payments_out,
            notes=sale.notes,
            idempotency_key=sale.idempotency_key,
            created_at=sale.created_at,
        )
