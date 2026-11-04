"""Pydantic schemas for analytics dashboard and financial reports."""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class DashboardMetricsOut(BaseModel):
    """Executive KPI summary for the selected period."""

    period_start: datetime
    period_end: datetime
    gross_sales: Decimal = Field(
        default=Decimal("0.0000"), description="Total sales before deductions"
    )
    net_sales: Decimal = Field(
        default=Decimal("0.0000"), description="Gross sales minus returns/refunds"
    )
    total_orders: int = Field(default=0, description="Completed sales transactions count")
    total_items_sold: Decimal = Field(
        default=Decimal("0.0000"), description="Total units of merchandise sold"
    )
    average_basket_value: Decimal = Field(
        default=Decimal("0.0000"), description="Net sales / total orders"
    )
    gross_profit: Decimal = Field(default=Decimal("0.0000"), description="Net sales minus COGS")
    profit_margin_pct: Decimal = Field(
        default=Decimal("0.0000"), description="Gross profit percentage"
    )
    total_tax: Decimal = Field(default=Decimal("0.0000"), description="VAT/Tax collected")
    total_discount: Decimal = Field(default=Decimal("0.0000"), description="Discounts granted")
    total_refunds: Decimal = Field(
        default=Decimal("0.0000"), description="Customer returns/refunds issued"
    )
    total_collected: Decimal = Field(
        default=Decimal("0.0000"), description="Actual funds collected (cash/electronic)"
    )
    total_due_issued: Decimal = Field(
        default=Decimal("0.0000"), description="Customer credit/due granted"
    )
    low_stock_count: int = Field(
        default=0, description="Active variants with stock < low stock threshold"
    )
    out_of_stock_count: int = Field(
        default=0, description="Active variants with 0 or negative stock"
    )

    model_config = ConfigDict(from_attributes=True)


class SalesTimeSeriesPoint(BaseModel):
    """Aggregated sales data point for charting."""

    period_label: str = Field(description="Hourly (HH:00) or Daily (YYYY-MM-DD)")
    sales_count: int = 0
    gross_sales: Decimal = Decimal("0.0000")
    net_sales: Decimal = Decimal("0.0000")
    profit: Decimal = Decimal("0.0000")


class SalesTimeSeriesOut(BaseModel):
    """Time-series dataset for sales performance trend visualization."""

    interval: str = Field(description="hourly, daily, or monthly")
    points: list[SalesTimeSeriesPoint]


class StockValuationItem(BaseModel):
    """Detailed variant stock valuation and threshold status."""

    variant_id: uuid.UUID
    product_name: str
    variant_name: str
    sku: str
    barcode: str | None = None
    quantity_on_hand: Decimal
    cost_price: Decimal
    selling_price: Decimal
    stock_cost_value: Decimal
    stock_retail_value: Decimal
    is_low_stock: bool
    is_out_of_stock: bool


class StockValuationOut(BaseModel):
    """Inventory valuation and capital asset metrics."""

    total_variants_stocked: int
    total_units_on_hand: Decimal
    total_cost_value: Decimal = Field(description="Asset value at cost basis (COGS invested)")
    total_retail_value: Decimal = Field(description="Potential gross revenue at retail price")
    potential_gross_profit: Decimal = Field(description="Retail value - Cost value")
    low_stock_count: int
    out_of_stock_count: int
    low_stock_items: list[StockValuationItem]


class PaymentMethodBreakdownItem(BaseModel):
    """Payment method volume and ratio."""

    method: str
    total_amount: Decimal
    transaction_count: int
    percentage: Decimal


class PaymentMethodBreakdownOut(BaseModel):
    """Distribution of payments received across payment methods."""

    total_collected: Decimal
    methods: list[PaymentMethodBreakdownItem]


class TopProductItem(BaseModel):
    """Best performing product variant."""

    product_variant_id: uuid.UUID
    product_name: str
    variant_name: str
    sku: str
    units_sold: Decimal
    gross_revenue: Decimal
    cogs: Decimal
    profit: Decimal
    margin_pct: Decimal


class TopProductsOut(BaseModel):
    """Top products ranked by sales performance."""

    items: list[TopProductItem]


class CustomerDuesSummaryOut(BaseModel):
    """Accounts receivable overview and top debtors."""

    total_customers_with_due: int
    total_outstanding_due: Decimal
    total_credit_limit: Decimal
    overall_credit_utilization_pct: Decimal
    top_debtors: list[dict[str, Any]]
