"""Business logic and reporting aggregations for POS Analytics & Financial Reports."""

import csv
import io
import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.catalog.models import Product, ProductVariant
from app.modules.inventory.models import StockBalance
from app.modules.reports.schemas import (
    CustomerDuesSummaryOut,
    DashboardMetricsOut,
    PaymentMethodBreakdownItem,
    PaymentMethodBreakdownOut,
    SalesTimeSeriesOut,
    SalesTimeSeriesPoint,
    StockValuationItem,
    StockValuationOut,
    TopProductItem,
    TopProductsOut,
)
from app.modules.returns.models import Return
from app.modules.sales.models import Customer, PaymentTender, Sale, SaleItem


class ReportsService:
    """Analytical query engine for executive KPIs, sales velocity, and inventory valuation."""

    def _normalize_date_range(
        self,
        start_date: datetime | None,
        end_date: datetime | None,
    ) -> tuple[datetime, datetime]:
        """Resolves date bounds defaulting to the current 24-hour UTC window (naive for asyncpg)."""
        now = datetime.now(UTC).replace(tzinfo=None)
        if end_date is None:
            end_date = now
        elif end_date.tzinfo is not None:
            end_date = end_date.astimezone(UTC).replace(tzinfo=None)

        if start_date is None:
            # Default to start of current day
            start_date = end_date.replace(hour=0, minute=0, second=0, microsecond=0)
        elif start_date.tzinfo is not None:
            start_date = start_date.astimezone(UTC).replace(tzinfo=None)

        return start_date, end_date

    async def get_dashboard_metrics(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        branch_id: uuid.UUID | None = None,
    ) -> DashboardMetricsOut:
        """Computes executive high-level metrics for the specified reporting period."""
        p_start, p_end = self._normalize_date_range(start_date, end_date)

        # 1. Sales query
        sales_stmt = select(
            func.coalesce(func.sum(Sale.grand_total), Decimal("0.0000")).label("gross_sales"),
            func.coalesce(func.sum(Sale.tax_total), Decimal("0.0000")).label("total_tax"),
            func.coalesce(func.sum(Sale.discount_total), Decimal("0.0000")).label("total_discount"),
            func.count(Sale.id).label("total_orders"),
        ).where(
            Sale.business_id == business_id,
            Sale.created_at >= p_start,
            Sale.created_at <= p_end,
            Sale.status.in_(["COMPLETED", "PARTIALLY_REFUNDED", "REFUNDED"]),
        )
        if branch_id:
            sales_stmt = sales_stmt.where(Sale.branch_id == branch_id)

        sales_res = (await session.execute(sales_stmt)).one()
        gross_sales = Decimal(str(sales_res.gross_sales or "0.0000"))
        total_tax = Decimal(str(sales_res.total_tax or "0.0000"))
        total_discount = Decimal(str(sales_res.total_discount or "0.0000"))
        total_orders = int(sales_res.total_orders or 0)

        # 2. Returns query
        returns_stmt = select(
            func.coalesce(func.sum(Return.refund_total), Decimal("0.0000")).label("total_refunds")
        ).where(
            Return.business_id == business_id,
            Return.created_at >= p_start,
            Return.created_at <= p_end,
            Return.status == "COMPLETED",
        )
        if branch_id:
            returns_stmt = returns_stmt.where(Return.branch_id == branch_id)

        total_refunds = Decimal(str((await session.execute(returns_stmt)).scalar() or "0.0000"))
        net_sales = max(Decimal("0.0000"), gross_sales - total_refunds)

        # 3. Cost of Goods Sold & Units Sold from Line Items
        items_stmt = (
            select(
                func.coalesce(func.sum(SaleItem.quantity), Decimal("0.0000")).label("units_sold"),
                func.coalesce(
                    func.sum(SaleItem.quantity * SaleItem.unit_cost_snapshot), Decimal("0.0000")
                ).label("cogs"),
            )
            .join(Sale, SaleItem.sale_id == Sale.id)
            .where(
                Sale.business_id == business_id,
                Sale.created_at >= p_start,
                Sale.created_at <= p_end,
                Sale.status.in_(["COMPLETED", "PARTIALLY_REFUNDED", "REFUNDED"]),
            )
        )
        if branch_id:
            items_stmt = items_stmt.where(Sale.branch_id == branch_id)

        items_res = (await session.execute(items_stmt)).one()
        total_items_sold = Decimal(str(items_res.units_sold or "0.0000"))
        cogs = Decimal(str(items_res.cogs or "0.0000"))

        gross_profit = net_sales - cogs
        profit_margin_pct = (
            (gross_profit / net_sales * Decimal("100.0")).quantize(Decimal("0.01"))
            if net_sales > Decimal("0.0000")
            else Decimal("0.0000")
        )
        avg_basket = (
            (net_sales / Decimal(str(total_orders))).quantize(Decimal("0.01"))
            if total_orders > 0
            else Decimal("0.0000")
        )

        # 4. Tender collections vs customer dues
        tender_stmt = (
            select(
                PaymentTender.method,
                func.coalesce(func.sum(PaymentTender.amount), Decimal("0.0000")).label("amount"),
            )
            .join(Sale, PaymentTender.sale_id == Sale.id)
            .where(
                Sale.business_id == business_id,
                Sale.created_at >= p_start,
                Sale.created_at <= p_end,
                Sale.status.in_(["COMPLETED", "PARTIALLY_REFUNDED", "REFUNDED"]),
            )
            .group_by(PaymentTender.method)
        )
        if branch_id:
            tender_stmt = tender_stmt.where(Sale.branch_id == branch_id)

        tender_rows = (await session.execute(tender_stmt)).fetchall()
        total_collected = Decimal("0.0000")
        total_due_issued = Decimal("0.0000")
        for row in tender_rows:
            if row.method == "DUE":
                total_due_issued += Decimal(str(row.amount))
            else:
                total_collected += Decimal(str(row.amount))

        # 5. Inventory Threshold Alerts
        stock_stmt = (
            select(
                func.count(StockBalance.product_variant_id)
                .filter(StockBalance.quantity_on_hand <= 0)
                .label("out_of_stock"),
                func.count(StockBalance.product_variant_id)
                .filter(StockBalance.quantity_on_hand > 0, StockBalance.quantity_on_hand <= 10)
                .label("low_stock"),
            )
            .join(ProductVariant, StockBalance.product_variant_id == ProductVariant.id)
            .where(
                StockBalance.business_id == business_id,
                ProductVariant.is_active.is_(True),
                ProductVariant.track_stock.is_(True),
            )
        )
        if branch_id:
            stock_stmt = stock_stmt.where(StockBalance.branch_id == branch_id)

        stock_res = (await session.execute(stock_stmt)).one()
        out_of_stock_count = int(stock_res.out_of_stock or 0)
        low_stock_count = int(stock_res.low_stock or 0)

        return DashboardMetricsOut(
            period_start=p_start,
            period_end=p_end,
            gross_sales=gross_sales,
            net_sales=net_sales,
            total_orders=total_orders,
            total_items_sold=total_items_sold,
            average_basket_value=avg_basket,
            gross_profit=gross_profit,
            profit_margin_pct=profit_margin_pct,
            total_tax=total_tax,
            total_discount=total_discount,
            total_refunds=total_refunds,
            total_collected=total_collected,
            total_due_issued=total_due_issued,
            low_stock_count=low_stock_count,
            out_of_stock_count=out_of_stock_count,
        )

    async def get_sales_time_series(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        interval: str = "daily",
        branch_id: uuid.UUID | None = None,
    ) -> SalesTimeSeriesOut:
        """Generates time-bucketed sales velocity and profit trends."""
        p_start, p_end = self._normalize_date_range(start_date, end_date)
        trunc_unit = "hour" if interval == "hourly" else "day"

        date_col = func.date_trunc(trunc_unit, Sale.created_at).label("time_bucket")

        stmt = (
            select(
                date_col,
                func.count(Sale.id).label("sales_count"),
                func.coalesce(func.sum(Sale.grand_total), Decimal("0.0000")).label("gross_sales"),
            )
            .where(
                Sale.business_id == business_id,
                Sale.created_at >= p_start,
                Sale.created_at <= p_end,
                Sale.status.in_(["COMPLETED", "PARTIALLY_REFUNDED", "REFUNDED"]),
            )
            .group_by(date_col)
            .order_by(date_col.asc())
        )
        if branch_id:
            stmt = stmt.where(Sale.branch_id == branch_id)

        rows = (await session.execute(stmt)).fetchall()
        points: list[SalesTimeSeriesPoint] = []

        for r in rows:
            bucket_dt: datetime = r.time_bucket
            label = bucket_dt.strftime("%Y-%m-%d %H:00" if trunc_unit == "hour" else "%Y-%m-%d")
            gross = Decimal(str(r.gross_sales or "0.0000"))
            points.append(
                SalesTimeSeriesPoint(
                    period_label=label,
                    sales_count=int(r.sales_count or 0),
                    gross_sales=gross,
                    net_sales=gross,
                    profit=gross * Decimal("0.25"),  # Estimated or baseline margin if unjoined
                )
            )

        return SalesTimeSeriesOut(interval=interval, points=points)

    async def get_stock_valuation(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        low_stock_threshold: Decimal = Decimal("10.0000"),
    ) -> StockValuationOut:
        """Aggregates inventory asset valuation, capital investments, and alert items."""
        stmt = (
            select(
                ProductVariant.id.label("variant_id"),
                Product.name.label("product_name"),
                ProductVariant.name.label("variant_name"),
                Product.sku,
                ProductVariant.barcode,
                StockBalance.quantity_on_hand,
                ProductVariant.cost_price,
                ProductVariant.selling_price,
            )
            .join(Product, ProductVariant.product_id == Product.id)
            .join(StockBalance, StockBalance.product_variant_id == ProductVariant.id)
            .where(
                ProductVariant.business_id == business_id,
                ProductVariant.is_active.is_(True),
            )
        )
        if branch_id:
            stmt = stmt.where(StockBalance.branch_id == branch_id)

        rows = (await session.execute(stmt)).fetchall()

        total_units = Decimal("0.0000")
        total_cost = Decimal("0.0000")
        total_retail = Decimal("0.0000")
        low_stock_items: list[StockValuationItem] = []
        low_count = 0
        out_count = 0

        for r in rows:
            qty = Decimal(str(r.quantity_on_hand or "0.0000"))
            cost = Decimal(str(r.cost_price or "0.0000"))
            sell = Decimal(str(r.selling_price or "0.0000"))

            line_cost = qty * cost
            line_retail = qty * sell

            total_units += qty
            total_cost += line_cost
            total_retail += line_retail

            is_out = qty <= Decimal("0.0000")
            is_low = qty > Decimal("0.0000") and qty <= low_stock_threshold

            if is_out:
                out_count += 1
            elif is_low:
                low_count += 1

            if is_out or is_low:
                low_stock_items.append(
                    StockValuationItem(
                        variant_id=r.variant_id,
                        product_name=r.product_name,
                        variant_name=r.variant_name,
                        sku=r.sku,
                        barcode=r.barcode,
                        quantity_on_hand=qty,
                        cost_price=cost,
                        selling_price=sell,
                        stock_cost_value=line_cost,
                        stock_retail_value=line_retail,
                        is_low_stock=is_low,
                        is_out_of_stock=is_out,
                    )
                )

        potential_profit = max(Decimal("0.0000"), total_retail - total_cost)

        return StockValuationOut(
            total_variants_stocked=len(rows),
            total_units_on_hand=total_units,
            total_cost_value=total_cost,
            total_retail_value=total_retail,
            potential_gross_profit=potential_profit,
            low_stock_count=low_count,
            out_of_stock_count=out_count,
            low_stock_items=low_stock_items,
        )

    async def get_payment_methods(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        branch_id: uuid.UUID | None = None,
    ) -> PaymentMethodBreakdownOut:
        """Calculates volume and distribution of payment tenders."""
        p_start, p_end = self._normalize_date_range(start_date, end_date)

        stmt = (
            select(
                PaymentTender.method,
                func.coalesce(func.sum(PaymentTender.amount), Decimal("0.0000")).label(
                    "total_amount"
                ),
                func.count(PaymentTender.id).label("txn_count"),
            )
            .join(Sale, PaymentTender.sale_id == Sale.id)
            .where(
                Sale.business_id == business_id,
                Sale.created_at >= p_start,
                Sale.created_at <= p_end,
                Sale.status.in_(["COMPLETED", "PARTIALLY_REFUNDED", "REFUNDED"]),
            )
            .group_by(PaymentTender.method)
            .order_by(desc("total_amount"))
        )
        if branch_id:
            stmt = stmt.where(Sale.branch_id == branch_id)

        rows = (await session.execute(stmt)).fetchall()
        total_collected = sum((Decimal(str(r.total_amount)) for r in rows), Decimal("0.0000"))

        methods: list[PaymentMethodBreakdownItem] = []
        for r in rows:
            amt = Decimal(str(r.total_amount))
            pct = (
                (amt / total_collected * Decimal("100.0")).quantize(Decimal("0.01"))
                if total_collected > 0
                else Decimal("0.0000")
            )
            methods.append(
                PaymentMethodBreakdownItem(
                    method=r.method,
                    total_amount=amt,
                    transaction_count=int(r.txn_count or 0),
                    percentage=pct,
                )
            )

        return PaymentMethodBreakdownOut(total_collected=total_collected, methods=methods)

    async def get_top_products(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        branch_id: uuid.UUID | None = None,
        limit: int = 10,
    ) -> TopProductsOut:
        """Ranks products by total sales revenue and volume."""
        p_start, p_end = self._normalize_date_range(start_date, end_date)

        stmt = (
            select(
                ProductVariant.id.label("variant_id"),
                Product.name.label("product_name"),
                ProductVariant.name.label("variant_name"),
                Product.sku,
                func.coalesce(func.sum(SaleItem.quantity), Decimal("0.0000")).label("units_sold"),
                func.coalesce(func.sum(SaleItem.line_total), Decimal("0.0000")).label(
                    "gross_revenue"
                ),
                func.coalesce(
                    func.sum(SaleItem.quantity * SaleItem.unit_cost_snapshot), Decimal("0.0000")
                ).label("cogs"),
            )
            .join(Sale, SaleItem.sale_id == Sale.id)
            .join(ProductVariant, SaleItem.product_variant_id == ProductVariant.id)
            .join(Product, ProductVariant.product_id == Product.id)
            .where(
                Sale.business_id == business_id,
                Sale.created_at >= p_start,
                Sale.created_at <= p_end,
                Sale.status.in_(["COMPLETED", "PARTIALLY_REFUNDED", "REFUNDED"]),
            )
            .group_by(
                ProductVariant.id,
                Product.name,
                ProductVariant.name,
                Product.sku,
            )
            .order_by(desc("gross_revenue"))
            .limit(limit)
        )
        if branch_id:
            stmt = stmt.where(Sale.branch_id == branch_id)

        rows = (await session.execute(stmt)).fetchall()
        items: list[TopProductItem] = []

        for r in rows:
            rev = Decimal(str(r.gross_revenue or "0.0000"))
            cogs = Decimal(str(r.cogs or "0.0000"))
            profit = rev - cogs
            margin_pct = (
                (profit / rev * Decimal("100.0")).quantize(Decimal("0.01"))
                if rev > Decimal("0.0000")
                else Decimal("0.0000")
            )

            items.append(
                TopProductItem(
                    product_variant_id=r.variant_id,
                    product_name=r.product_name,
                    variant_name=r.variant_name,
                    sku=r.sku,
                    units_sold=Decimal(str(r.units_sold or "0.0000")),
                    gross_revenue=rev,
                    cogs=cogs,
                    profit=profit,
                    margin_pct=margin_pct,
                )
            )

        return TopProductsOut(items=items)

    async def get_customer_dues_report(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
    ) -> CustomerDuesSummaryOut:
        """Summarizes accounts receivable aging, total store credit liability, and key debtors."""
        due_stmt = (
            select(
                Sale.customer_id,
                func.coalesce(func.sum(Sale.due_total), Decimal("0.0000")).label("total_due"),
            )
            .where(
                Sale.business_id == business_id,
                Sale.due_total > Decimal("0.0000"),
                Sale.status.in_(["COMPLETED", "PARTIALLY_REFUNDED"]),
                Sale.customer_id.is_not(None),
            )
            .group_by(Sale.customer_id)
        )
        due_rows = (await session.execute(due_stmt)).fetchall()
        due_map = {r.customer_id: Decimal(str(r.total_due)) for r in due_rows}

        cust_stmt = select(Customer).where(
            Customer.business_id == business_id,
            Customer.is_active.is_(True),
        )
        customers = (await session.execute(cust_stmt)).scalars().all()

        total_due = Decimal("0.0000")
        total_limit = Decimal("0.0000")
        with_due = 0
        debtor_candidates: list[dict[str, object]] = []

        for c in customers:
            c_due = due_map.get(c.id, Decimal("0.0000"))
            total_due += c_due
            total_limit += c.credit_limit
            if c_due > Decimal("0.0000"):
                with_due += 1
                util_pct = (
                    (c_due / c.credit_limit * Decimal("100.0")).quantize(Decimal("0.01"))
                    if c.credit_limit > Decimal("0.0000")
                    else Decimal("100.00")
                )
                debtor_candidates.append(
                    {
                        "customer_id": str(c.id),
                        "name": c.name,
                        "phone": c.phone,
                        "due_balance": str(c_due),
                        "credit_limit": str(c.credit_limit),
                        "utilization_pct": str(util_pct),
                        "_due_raw": c_due,
                    }
                )

        debtor_candidates.sort(key=lambda d: Decimal(str(d["_due_raw"])), reverse=True)
        top_debtors = [
            {k: v for k, v in d.items() if k != "_due_raw"} for d in debtor_candidates[:20]
        ]

        overall_pct = (
            (total_due / total_limit * Decimal("100.0")).quantize(Decimal("0.01"))
            if total_limit > Decimal("0.0000")
            else Decimal("0.0000")
        )

        return CustomerDuesSummaryOut(
            total_customers_with_due=with_due,
            total_outstanding_due=total_due,
            total_credit_limit=total_limit,
            overall_credit_utilization_pct=overall_pct,
            top_debtors=top_debtors,
        )

    async def export_report_csv(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        report_type: str,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
        branch_id: uuid.UUID | None = None,
    ) -> str:
        """Generates formatted CSV string for tabular analytics download."""
        output = io.StringIO()
        writer = csv.writer(output)

        if report_type == "top_products":
            top = await self.get_top_products(
                session, business_id, start_date, end_date, branch_id, limit=100
            )
            writer.writerow(
                [
                    "SKU",
                    "Product Name",
                    "Variant",
                    "Units Sold",
                    "Revenue",
                    "COGS",
                    "Profit",
                    "Margin %",
                ]
            )
            for item in top.items:
                writer.writerow(
                    [
                        item.sku,
                        item.product_name,
                        item.variant_name,
                        str(item.units_sold),
                        str(item.gross_revenue),
                        str(item.cogs),
                        str(item.profit),
                        str(item.margin_pct),
                    ]
                )
        elif report_type == "stock_valuation":
            val = await self.get_stock_valuation(session, business_id, branch_id)
            writer.writerow(
                [
                    "SKU",
                    "Product Name",
                    "Variant",
                    "Qty on Hand",
                    "Cost Price",
                    "Selling Price",
                    "Cost Value",
                    "Retail Value",
                    "Status",
                ]
            )
            for it in val.low_stock_items:
                status = "OUT OF STOCK" if it.is_out_of_stock else "LOW STOCK"
                writer.writerow(
                    [
                        it.sku,
                        it.product_name,
                        it.variant_name,
                        str(it.quantity_on_hand),
                        str(it.cost_price),
                        str(it.selling_price),
                        str(it.stock_cost_value),
                        str(it.stock_retail_value),
                        status,
                    ]
                )
        elif report_type == "payment_methods":
            methods = await self.get_payment_methods(
                session, business_id, start_date, end_date, branch_id
            )
            writer.writerow(["Payment Method", "Total Collected", "Transactions", "Percentage"])
            for m in methods.methods:
                writer.writerow(
                    [m.method, str(m.total_amount), str(m.transaction_count), f"{m.percentage}%"]
                )
        elif report_type == "customer_dues":
            dues = await self.get_customer_dues_report(session, business_id)
            writer.writerow(
                ["Customer Name", "Phone", "Outstanding Due", "Credit Limit", "Utilization %"]
            )
            for d in dues.top_debtors:
                writer.writerow(
                    [
                        d["name"],
                        d["phone"] or "",
                        d["due_balance"],
                        d["credit_limit"],
                        f"{d['utilization_pct']}%",
                    ]
                )
        else:
            # Default sales summary
            dashboard = await self.get_dashboard_metrics(
                session, business_id, start_date, end_date, branch_id
            )
            writer.writerow(["Metric", "Value"])
            writer.writerow(["Gross Sales", str(dashboard.gross_sales)])
            writer.writerow(["Net Sales", str(dashboard.net_sales)])
            writer.writerow(["Total Orders", str(dashboard.total_orders)])
            writer.writerow(["Total Items Sold", str(dashboard.total_items_sold)])
            writer.writerow(["Average Basket Value", str(dashboard.average_basket_value)])
            writer.writerow(["Gross Profit", str(dashboard.gross_profit)])
            writer.writerow(["Profit Margin %", f"{dashboard.profit_margin_pct}%"])
            writer.writerow(["Total Tax", str(dashboard.total_tax)])
            writer.writerow(["Total Refunds", str(dashboard.total_refunds)])
            writer.writerow(["Total Collected", str(dashboard.total_collected)])
            writer.writerow(["Total Due Issued", str(dashboard.total_due_issued)])

        return output.getvalue()
