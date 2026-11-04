# Analytics Dashboard & Financial Reports Module

This document outlines the architectural specifications, financial ledger algorithms, REST endpoints, and Flutter presentation layer for **Track 6: Analytics Dashboard & Financial Reports**.

---

## 1. Domain Architecture & Financial Precision

The reports module provides business intelligence, profit margin accounting, capital inventory valuation, and debtor risk management for retail owners, managers, and accountants.

### Key Financial Algorithms:
- **Gross Sales**: $\sum \text{Sale.grand\_total}$ for all completed, non-voided transactions within the reporting window.
- **Customer Refunds**: $\sum \text{Return.refund\_total}$ for completed sales returns.
- **Net Sales**: $\max(0, \text{Gross Sales} - \text{Customer Refunds})$.
- **Cost of Goods Sold (COGS)**: $\sum (\text{SaleItem.quantity} \times \text{SaleItem.unit\_cost\_snapshot})$. Using the immutable snapshot captured at the moment of sale guarantees historical margin integrity even if catalog supplier costs fluctuate later.
- **Gross Profit**: $\text{Net Sales} - \text{COGS}$.
- **Profit Margin %**: $(\text{Gross Profit} / \text{Net Sales}) \times 100$.
- **Average Basket Size**: $\text{Net Sales} / \text{Total Orders}$.
- **Stock Capital Valuation (Cost Basis)**: $\sum (\text{StockBalance.quantity\_on\_hand} \times \text{ProductVariant.cost\_price})$.
- **Stock Potential Revenue (Retail Basis)**: $\sum (\text{StockBalance.quantity\_on\_hand} \times \text{ProductVariant.selling\_price})$.
- **Projected Gross Margin**: $\text{Potential Retail Revenue} - \text{Cost Capital Invested}$.

All currency amounts and margins maintain decimal precision (`NUMERIC(19, 4)` in PostgreSQL and `double` rounded via `NumberFormat.currency(symbol: '৳ ')` in Flutter).

---

## 2. API Endpoints

All endpoints are authenticated with tenant isolation (`business_id`), optional date filters (`start_date`, `end_date`), and optional branch filters (`branch_id`).

### Summary & Trend
- `GET /api/v1/reports/dashboard`: Returns `DashboardMetricsOut` with gross/net sales, total orders, units sold, gross profit, margin %, VAT collected, discounts, refunds, actual collections, dues granted, and inventory alert counts.
- `GET /api/v1/reports/sales?interval={daily|hourly}`: Returns time-bucketed sales velocity dataset for visual charts.
- `GET /api/v1/reports/top-products?limit={10}`: Product performance leaderboard ranked by gross revenue, units sold, COGS, and profit margin %.

### Assets & Receivables
- `GET /api/v1/reports/stock`: Inventory asset balance, capital invested, potential retail revenue, unrealized profit, and low-stock/out-of-stock alerts.
- `GET /api/v1/reports/payment-methods`: Breakdown of payment tenders across Cash, Card, bKash, Nagad, Rocket, and Due with total amount, transaction counts, and percentage share.
- `GET /api/v1/reports/customer-dues`: Outstanding accounts receivable aging, total store credit allowance, credit utilization %, and top 20 debtor accounts.

### Data Export
- `GET /api/v1/reports/export?report_type={summary|top_products|stock_valuation|payment_methods|customer_dues}`: Streams a formatted CSV file (`text/csv; charset=utf-8`) with `Content-Disposition: attachment; filename=pos_report_{type}_{date}.csv`.

---

## 3. Flutter Presentation Layer

Located under `pos_system_application/lib/features/reports/`:
- **`ReportsScreen`**: Main analytical interface organized into 5 dedicated sub-tabs:
  1. **Executive Overview**: 4 primary KPI cards (Gross Sales, Net Sales, Gross Profit, Avg Basket), secondary operational cards (Collections vs Dues, Inventory Alerts), and an interactive time-series sales velocity bar chart.
  2. **Top Products**: Ranked leaderboard table showing sales volume, gross revenue, COGS, and profit margin badges.
  3. **Stock Valuation**: Capital investment KPI cards and Low-Stock / Out-of-Stock alert reorder table.
  4. **Payment Breakdown**: Visual distribution cards and progress indicators for each tender method.
  5. **Customer Dues**: Accounts receivable KPIs and top debtor exposure table with credit utilization badges.
- **Global Filters**: Quick date chips (`Today`, `Yesterday`, `Last 7 Days`, `Last 30 Days`, `This Month`), outlet selector (`All Outlets` or specific branch), and one-click `Export CSV` button.
- **Shell Integration**: Active on navigation index 6 ("Reports") in `ShellScreen`.

