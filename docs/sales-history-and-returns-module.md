# Sales History, Order Details, and Customer Returns Module

## 1. Overview & Architectural Scope

The **Sales History and Returns Module** completes the retail sales transaction lifecycle. It provides store cashiers, managers, and accountants with the capability to:
1. Search, filter, and audit past sales transactions across branches, date ranges, and statuses.
2. Inspect line-item breakdowns, pricing, applied taxes/discounts, and payment tender allocations.
3. Reprint customer receipts on thermal receipt printers or view digital summaries.
4. Process customer sales returns and refunds (partial or full) with automatic stock replenishment into physical inventory balances and audit logging into the immutable stock ledger (`SALE_RETURN`).
5. Void erroneous transactions with reason tracking, reversing both payments and inventory deductions.

---

## 2. API Contracts

### 2.1 List Sales (`GET /api/v1/sales`)
- **Permission**: `sales:read`
- **Query Parameters**:
  - `page`: Integer (default: 1)
  - `page_size`: Integer (default: 20, max: 100)
  - `start_date`: ISO 8601 DateTime (optional)
  - `end_date`: ISO 8601 DateTime (optional)
  - `cashier_id`: UUID (optional)
  - `status`: String (`COMPLETED`, `PARTIALLY_REFUNDED`, `REFUNDED`, `VOIDED`, `ALL`)
  - `search`: String (searches `receipt_no`)
  - `branch_id`: UUID (optional)
- **Response**: `PaginatedSales` with `items`, `total`, `page`, `page_size`, `total_pages`.

### 2.2 Process Customer Return (`POST /api/v1/sales/{sale_id}/returns`)
- **Permission**: `sales:create`
- **Request Body**:
```json
{
  "items": [
    {
      "original_sale_item_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "quantity": "2.0000",
      "refund_amount": "300.0000",
      "restock": true,
      "restock_status": "RESTOCKED"
    }
  ],
  "reason": "Customer ordered wrong variant",
  "refund_method": "CASH"
}
```
- **Invariants Enforced**:
  - Pessimistic row locking on the `Sale` header (`FOR UPDATE`).
  - Total returned quantity across prior returns + current return cannot exceed `quantity_sold`.
  - Voided sales cannot be returned.
  - Automatically updates `sales.status` to `PARTIALLY_REFUNDED` or `REFUNDED`.
  - If `restock=true`, increments `stock_balances.quantity_on_hand` and appends an immutable `stock_movements` record with `movement_type='SALE_RETURN'`.

### 2.3 Returnable Items Inspection (`GET /api/v1/sales/{sale_id}/returnable-items`)
- **Permission**: `sales:read`
- **Response**: List of items on the sale with `quantity_sold`, `quantity_returned`, and `quantity_returnable`.

### 2.4 Void Sale (`POST /api/v1/sales/{sale_id}/void`)
- **Permission**: `sales:write`
- **Request Body**:
```json
{
  "reason": "Cashier double billed transaction by mistake"
}
```
- **Invariants Enforced**:
  - Only sales in status `COMPLETED` can be voided.
  - Sales with partial or full refunds cannot be voided.
  - Restores stock for all line items with `SALE_RETURN` movements.
  - Marks all associated `payment_tenders.status = 'VOIDED'`.
  - Sets `sales.status = 'VOIDED'` and appends reason to `sales.notes`.

---

## 3. Inventory & Financial Ledger Invariants

```
+-------------------------------------------------------------------------------+
|                            PESSIMISTIC DB TRANSACTION                         |
|                                                                               |
|  1. SELECT * FROM sales WHERE id = :id FOR UPDATE;                            |
|  2. Verify: status != 'VOIDED'                                                |
|  3. Validate: prior_returned_qty + return_qty <= sale_item_qty                 |
|  4. INSERT INTO returns (id, return_no, refund_total, status)                 |
|  5. INSERT INTO return_items (return_id, original_sale_item_id, qty, amount)  |
|  6. If restock == true:                                                       |
|       UPDATE stock_balances SET quantity_on_hand += return_qty;               |
|       INSERT INTO stock_movements (movement_type='SALE_RETURN', delta=qty);   |
|  7. UPDATE sales SET status = ('REFUNDED' or 'PARTIALLY_REFUNDED');           |
|  8. COMMIT;                                                                   |
+-------------------------------------------------------------------------------+
```

---

## 4. Flutter Client Implementation

- **Navigation Integration**: Wired to index 2 (`Sales History`) in `ShellScreen`.
- **`SalesHistoryScreen`**: Responsive data table with date range chips (`All Time`, `Today`, `Yesterday`, `Last 7 Days`), status filter dropdown, receipt search, and pagination.
- **`SaleDetailDrawer`**: Slide-in inspection panel displaying line items, payment breakdown, and historical return credits.
- **`ReturnDialog`**: Interactive refund modal with counter spinboxes bounded by `returnable_quantity`, restock switch, reason input, and dynamic refund total calculation.
- **`ReceiptDialog` Integration**: One-click thermal receipt reprinting.

---

## 5. Automated Verification & Test Results

- **Backend Tests** (`backend/tests/test_returns_and_sales_history.py`):
  - `test_sales_list_and_filters`: PASSED
  - `test_sale_return_partial_and_stock_restoration`: PASSED
  - `test_sale_return_exceeding_quantity_rejected`: PASSED
  - `test_sale_return_full_refund_status`: PASSED
  - `test_sale_void_restores_inventory_and_marks_tenders`: PASSED
  - `test_tenant_isolation_on_sales_and_returns`: PASSED
- **Total Backend Suite**: 24 PASSED, 1 SKIPPED (100% passing).
- **Backend Lint & Types**: `ruff check app` (0 errors), `mypy app` (0 errors in 43 files).
- **Flutter Analyzer**: `flutter analyze` (No issues found).
- **Flutter Widget Tests** (`pos_system_application/test/sales_history_widget_test.dart`):
  - `SalesHistoryScreen renders sales table with receipt details`: PASSED
  - `ReturnDialog increments return quantity and calculates refund total`: PASSED
  - `SaleDetailDrawer renders breakdown and action buttons`: PASSED
- **Total Flutter Suite**: 12 PASSED (100% passing across 4 test suites).
