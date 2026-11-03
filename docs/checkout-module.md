# POS Checkout Module (Vertical Slice 2)

This document provides a comprehensive technical overview of the POS Checkout vertical slice implemented across the backend FastAPI service and the Flutter POS client application.

---

## 1. Overview & Architecture

The Checkout slice orchestrates retail sale transactions: scanning barcodes or picking catalog items into a cart, calculating mathematical financials with rounding precision, enforcing stock balance locks to eliminate race conditions, recording double-entry audit ledgers, allocating single or split payment tenders, generating sequential human-readable receipt numbers, and displaying thermal receipts.

```
+------------------------------------------------------------------------+
|                          Flutter POS Client                            |
|  - PosRegisterScreen (Dual-pane: Left Catalog/Search, Right Live Cart)  |
|  - CartNotifier & State (Exact Decimal Arithmetic, Item/Cart Discount) |
|  - PaymentDialog (Split Tenders, Quick Cash Chips, Change/Due Display) |
|  - ReceiptDialog (Verified Thermal Receipt View & Print Action)        |
|  - CheckoutApiService & ApiClient (Idempotency Key Injection)          |
+------------------------------------------------------------------------+
                                    | REST JSON (X-Idempotency-Key)
                                    v
+------------------------------------------------------------------------+
|                          FastAPI Backend                               |
|  - app.api.v1.sales (POST /sales/checkout, GET /sales/{id}, /receipt)  |
|  - CheckoutService (Atomic Tx, Stock Locking, Split Payment, Idemp)    |
|  - InventoryRepository (Pessimistic FOR UPDATE, Stock Movements)       |
|  - SalesRepository (Gapless Receipt Counters, Idempotency Records)     |
|  - PostgreSQL with Row-Level Locks & Multi-Tenant Isolation            |
+------------------------------------------------------------------------+
```

---

## 2. Backend REST API Endpoints

All sales endpoints are prefixed with `/api/v1` and require:
- Header: `Authorization: Bearer <JWT_ACCESS_TOKEN>` (Scoped to `business_id` and `user_id`).
- Header (Optional): `X-Idempotency-Key: <UUIDv4>` (Can also be in request body).
- Permission enforcement: `sales:create` for checking out, `sales:read` for viewing receipts.

### 2.1 Checkout Endpoints

| Method | Endpoint | Description | Permission |
|--------|----------|-------------|------------|
| `POST` | `/api/v1/sales/checkout` | Process atomic POS sale, decrement stock, allocate tenders | `sales:create` |
| `GET` | `/api/v1/sales/{sale_id}` | Retrieve sale details by primary key | `sales:read` |
| `GET` | `/api/v1/sales/receipt/{receipt_no}` | Retrieve sale details by human-readable receipt number | `sales:read` |

### 2.2 Checkout Request Payload

```json
{
  "idempotency_key": "c3d2e1f0-1234-5678-9abc-def012345678",
  "branch_id": "00000000-0000-0000-0000-000000000002",
  "customer_id": null,
  "items": [
    {
      "product_variant_id": "880e8400-e29b-41d4-a716-446655440000",
      "quantity": "2.0000",
      "unit_price": "100.0000",
      "discount": "10.0000"
    }
  ],
  "cart_discount": "5.0000",
  "tax_rate": "5.0000",
  "payments": [
    {
      "method": "CASH",
      "amount": "200.0000",
      "reference": null
    }
  ],
  "notes": "Walk-in cash customer"
}
```

### 2.3 Response (`201 Created` / `200 OK` on Idempotent Replay)

```json
{
  "id": "770e8400-e29b-41d4-a716-446655440000",
  "business_id": "00000000-0000-0000-0000-000000000001",
  "branch_id": "00000000-0000-0000-0000-000000000002",
  "receipt_no": "REC-20261103-MAIN-0001",
  "status": "COMPLETED",
  "cashier_id": "00000000-0000-0000-0000-000000000001",
  "customer_id": null,
  "financials": {
    "subtotal": "200.0000",
    "discount_total": "15.0000",
    "tax_total": "9.2500",
    "grand_total": "194.2500",
    "paid_total": "194.2500",
    "due_total": "0.0000",
    "change_amount": "5.7500"
  },
  "items": [
    {
      "id": "item-uuid-1",
      "product_variant_id": "880e8400-e29b-41d4-a716-446655440000",
      "product_name": "Ergonomic Mouse",
      "sku": "WM-01",
      "barcode": "11223344556677",
      "quantity": "2.0000",
      "unit_price": "100.0000",
      "unit_cost_snapshot": "60.0000",
      "discount": "10.0000",
      "line_total": "190.0000"
    }
  ],
  "payments": [
    {
      "id": "pay-uuid-1",
      "method": "CASH",
      "amount": "200.0000",
      "reference": null,
      "status": "CONFIRMED",
      "received_at": "2026-11-03T21:45:00Z"
    }
  ],
  "notes": "Walk-in cash customer",
  "created_at": "2026-11-03T21:45:00Z"
}
```

---

## 3. Core Principles & Guarantees

### 3.1 Pessimistic Concurrency & Deadlock Defense
- Variant IDs are lexicographically sorted prior to acquiring `FOR UPDATE` row locks in PostgreSQL (`sorted(requested_variant_ids)`).
- Multiple cashiers competing for the last unit of an item run concurrently: exactly one acquires the lock, completes the sale, and the other receives an instant `409 INSUFFICIENT_STOCK` rejection without deadlocks.

### 3.2 Double-Entry Inventory Ledger
- Stock is never mutated without recording a corresponding `StockMovement` row:
  - `movement_type`: `SALE`
  - `quantity_delta`: `-quantity`
  - `unit_cost`: `variant.cost_price` snapshot
  - `reference_id`: `sale.id`
  - `created_by`: Authenticated cashier UUID.

### 3.3 Exact Decimal Arithmetic & Rounding
- All monetary arithmetic uses `Decimal` and `NUMERIC(19, 4)`. Floating point calculations are prohibited in business logic.
- Rounding mode is `ROUND_HALF_UP` to 4 decimal places.
- VAT / Tax is calculated on `discounted_subtotal` (`max(0, subtotal - discount_total)`).

### 3.4 Idempotency Key Semantics
- Every transaction requires an `idempotency_key` (UUIDv4).
- Request payload hash (`SHA-256`) is stored alongside the key.
- **Exact Replay**: Submitting the same key with identical items returns the original receipt (`200 OK`, `X-Idempotent-Replay: true`) with zero secondary inventory deductions.
- **Tampered Replay**: Submitting the same key with altered items returns `422 IDEMPOTENCY_PAYLOAD_MISMATCH`.

### 3.5 Split Tenders & Due Credit Control
- Supports arbitrary combinations of `CASH`, `CARD`, `BKASH`, `NAGAD`, `ROCKET`, `DUE`.
- If tendered cash exceeds grand total, `change_amount` is calculated and returned. Non-cash overpayment is rejected (`400 EXCESS_NON_CASH_PAYMENT`).
- Partial payments (`due_total > 0`) require a registered customer profile (`400 CUSTOMER_REQUIRED_FOR_DUE`) and enforce the customer's credit limit (`409 CREDIT_LIMIT_EXCEEDED`).

---

## 4. Flutter POS Client Features

### 4.1 PosRegisterScreen (Dual-Pane)
- **Left Panel (Catalog & Quick Scanner)**:
  - Barcode search field with instant `<Enter>` scanner dispatch.
  - Category filter pills.
  - Product catalog cards with responsive price badges and "+ Add" triggers.
  - Variant picker modal for multi-variant products.
- **Right Panel (Live Cart)**:
  - Real-time item count and quick "Clear" action.
  - Quantity steppers (`[-]` `qty` `[+]`) and item removal.
  - Live financial card: Subtotal, Discount (with tap-to-edit cart discount), 5% VAT, and Grand Total.
  - Primary "Pay" button opening the payment dialog.

### 4.2 PaymentDialog
- Total payable header card with customer identification tag.
- Quick cash chips (`Exact`, `+50`, `+100`, `+500`, `+1000`).
- Multi-row split tender support with method dropdown, amount, and reference fields.
- Real-time change return (green badge) or remaining due (amber badge) computation.
- Inline error banner handling 409 conflict and stock errors gracefully.

### 4.3 ReceiptDialog
- Standard thermal receipt design:
  - Store header, branch name, receipt number (`REC-YYYYMMDD-BRANCH-SEQ`).
  - Cashier name, timestamp, and customer details.
  - Itemized table with quantity, unit price, and line totals.
  - Financial summary with tax, tendered payments, and change.
  - "Print Receipt" and "New Sale" buttons.

---

## 5. Automated Verification & Testing

### 5.1 Backend Test Matrix (`backend/tests/test_checkout.py`)

| Test Name | Validation Scope | Result |
|---|---|---|
| `test_checkout_permissions_enforced` | 401 unauthenticated & 403 missing permission | PASSED |
| `test_checkout_single_tender_success` | Full cash sale, stock balance decrement (-2), movement ledger write | PASSED |
| `test_checkout_split_tender_and_validation`| Split tender (Cash + bKash) and non-cash overpayment rejection | PASSED |
| `test_checkout_idempotency_behavior` | Exact replay 200 without double stock decrement; 422 payload mismatch | PASSED |
| `test_checkout_insufficient_stock_rejection`| Rejects order exceeding available stock (409); leaves stock intact | PASSED |
| `test_checkout_partial_payment_and_credit_limit`| Rejects walk-in due; enforces customer credit limit boundary | PASSED |
| `test_checkout_concurrent_race_condition` | 2 concurrent requests for 1 stock item: exactly 1 wins (201), 1 fails (409) | PASSED |

### 5.2 Flutter Client Test Matrix (`pos_system_application/test/checkout_widget_test.dart`)

| Test Name | Validation Scope | Result |
|---|---|---|
| `Calculates subtotal, discounts, tax, and grand total accurately` | Cart state calculations with steppers and discounts | PASSED |
| `addByBarcode matches barcode or SKU` | Barcode lookup in product catalog | PASSED |
| `Renders empty cart and catalog items, adds product on click` | Catalog grid rendering, cart addition, quantity increment | PASSED |
| `Tapping Pay button opens PaymentDialog` | Payment dialog presentation, quick cash chips, totals | PASSED |
| `Renders receipt details, line items, and print button` | Thermal receipt rendering, financials, print trigger | PASSED |

