# Suppliers, Purchasing & Stock Adjustments Module (Track 3)

## 1. Architectural Overview & Responsibility

The **Suppliers, Purchasing & Stock Adjustments** module handles vendor lifecycle management, purchase order drafting, atomic goods receiving with real-time wholesale cost updates, supplier disbursements with cash drawer debit integration, and physical stock count adjustments with an immutable movement ledger.

### Key Capabilities
- **Supplier Directory & Financial Tracking**: Business-scoped supplier management (`name`, `contact_person`, `phone`, `email`, `address`, `is_active`) tracking cumulative wholesale purchases, completed disbursements, and outstanding unpaid payables.
- **Purchase Order Management**: Create draft and active purchase orders (`status = "ORDERED"`) with multiple line items, quantity, negotiated unit cost, subtotal, and invoice-level discounts.
- **Atomic Goods Receiving (`receivePurchaseOrder`)**:
  - Increments physical stock on hand in `StockBalance.quantity_on_hand` with pessimistic row locking.
  - Updates `ProductVariant.cost_price` to the received unit cost, ensuring retail POS profit margins remain accurate against real wholesale procurement costs.
  - Appends an immutable `StockMovement(movement_type="PURCHASE_RECEIVE")` ledger entry.
  - Transitions order state to `RECEIVED`.
- **Disbursements & Cash Drawer Balancing**:
  - Record payments against supplier invoices.
  - When payment method is `CASH`, automatically logs a `CashTransaction(direction="OUT")` to debit the branch cash drawer, preventing unrecorded cash outflows.
- **Physical Stock Adjustments**:
  - Manual upward/downward corrections (`ADJUSTMENT_UP` / `ADJUSTMENT_DOWN`) with categorized audit reasons: `DAMAGE`, `SPOILAGE`, `THEFT`, `STOCKTAKE_CORRECTION`, `INTERNAL_USE`, `EXPIRED`, `OTHER`.
  - Enforces strict inventory invariants: downward adjustments cannot exceed current quantity on hand (`409 Conflict: INSUFFICIENT_STOCK`).
  - Appends an immutable `StockMovement` entry with signed quantity delta, current unit cost, user identifier, and notes.
- **Real-Time Stock Querying & Low-Stock Alerts**:
  - `GET /api/v1/inventory/balances`: Real-time stock levels across all active variants for branch.
  - Catalog list view displays live stock on hand badges with low-stock warnings (`Low: X` when stock ≤ 5, `Out of Stock` when 0).
  - Quick action buttons directly from the catalog table for "Adjust Physical Stock" and "Stock Movement Ledger".

---

## 2. API Contract Specification

### 2.1 Suppliers
- `GET /api/v1/suppliers`
  - Query params: `search`, `is_active`, `page`, `page_size`.
  - Response: `PaginatedSuppliers` (`items`, `total`, `page`, `page_size`, `total_pages`).
- `POST /api/v1/suppliers`
  - Payload: `SupplierCreate` (`name`, `contact_person`, `phone`, `email`, `address`).
  - Response: `201 Created` with `SupplierOut`.
- `GET /api/v1/suppliers/{id}`
  - Response: `SupplierOut` (includes `total_purchases_amount`, `total_purchases_count`, `unpaid_balance`).
- `PUT /api/v1/suppliers/{id}`
  - Payload: `SupplierUpdate` (`name`, `contact_person`, `phone`, `email`, `address`, `is_active`).

### 2.2 Purchase Orders & Goods Receiving
- `GET /api/v1/purchasing/orders`
  - Query params: `status` (`ORDERED`, `RECEIVED`, `CANCELLED`), `supplier_id`, `branch_id`, `page`, `page_size`.
  - Response: `PaginatedPurchases`.
- `POST /api/v1/purchasing/orders`
  - Payload: `PurchaseCreate` (`supplier_id`, `branch_id`, `reference_no`, `discount`, `notes`, `items: [{product_variant_id, quantity, unit_cost}]`).
  - Response: `201 Created` with `PurchaseOut`.
- `POST /api/v1/purchasing/orders/{id}/receive`
  - Atomically receives goods, locks and updates inventory balances, updates variant cost prices, and records ledger movements.
  - Response: `200 OK` with updated `PurchaseOut(status="RECEIVED")`.
- `POST /api/v1/purchasing/orders/{id}/payments`
  - Payload: `PurchasePaymentCreate` (`amount`, `method`, `reference`).
  - If `method == "CASH"`, creates `CashTransaction(direction="OUT")`.
  - Response: `201 Created` with `PurchasePaymentOut`.

### 2.3 Physical Inventory & Movements
- `GET /api/v1/inventory/balances`
  - Query params: `branch_id`.
  - Response: `list[{product_variant_id, branch_id, quantity_on_hand}]`.
- `GET /api/v1/inventory/balances/{product_variant_id}`
  - Response: `{product_variant_id, branch_id, quantity_on_hand}`.
- `POST /api/v1/inventory/adjustments`
  - Payload: `StockAdjustmentCreate` (`product_variant_id`, `adjustment_type`, `quantity`, `reason`, `notes`, `branch_id`).
  - Response: `201 Created` with `StockAdjustmentOut` (`previous_quantity`, `new_quantity`, `quantity_adjusted`, `movement_id`).
- `GET /api/v1/inventory/movements`
  - Query params: `product_variant_id`, `branch_id`, `movement_type`, `start_date`, `end_date`, `page`, `page_size`.
  - Response: `PaginatedStockMovements`.

---

## 3. Flutter Presentation Layer

### Components
1. **`PurchasingScreen`**:
   - Master navigation tab with dual tabs:
     - **Purchase Orders**: Order listing, status filters (`All`, `ORDERED`, `RECEIVED`), total/paid/due totals, action to launch `PurchaseOrderDetailDialog`.
     - **Suppliers Directory**: Supplier cards, search by name/phone, contact details, balance status, create/edit actions.
2. **`CreatePurchaseOrderDialog`**:
   - Select supplier or create supplier inline.
   - Dynamic line items table with quantity, unit cost, line subtotal calculation.
   - Invoice discount, vendor bill reference, and notes.
3. **`PurchaseOrderDetailDialog`**:
   - Visual status badge (`ORDERED` amber, `RECEIVED` green).
   - Items list with unit costs.
   - Financial breakdown (Total, Discount, Paid, Due).
   - One-click "Confirm Goods Receiving" dialog.
   - "Add Payment" dialog with Cash drawer disbursement or Bank/MFS options.
4. **`StockAdjustmentDialog`**:
   - Live preview: Displays current stock on hand and dynamically calculates projected stock on quantity input.
   - Type toggle: Add Stock (+) vs Deduct Stock (-).
   - Categorized reason selection.
   - Validates non-negative bounds and prevents over-deductions.
5. **`StockMovementsDialog`**:
   - Immutable audit trail ledger table displaying timestamps, movement types (`PURCHASE_RECEIVE`, `SALE`, `ADJUSTMENT_UP`, `ADJUSTMENT_DOWN`), signed deltas, unit costs, and references.
6. **Catalog Integration**:
   - `ProductListView` renders a dedicated **Stock on Hand** column with color-coded badges (`In Stock`, `Low: X`, `Out of Stock`).
   - Action buttons for quick adjustment and audit history on every row.

---

## 4. Test Coverage & Verification

- **Backend Pytest**:
  - `test_supplier_crud_and_uniqueness`: Supplier creation, phone/name validation, and uniqueness.
  - `test_purchase_order_creation_and_receiving`: Validates stock increment, `ProductVariant.cost_price` update, and status change.
  - `test_purchase_payment_disbursement_and_cash_drawer`: Verifies payment recording and `CashTransaction(direction="OUT")` debiting.
  - `test_stock_adjustments_and_movements`: Verifies `ADJUSTMENT_UP` and `ADJUSTMENT_DOWN`, boundary checks on negative stock, and movement ledger immutability.
  - `test_tenant_isolation_on_purchasing_and_inventory`: Multi-tenant isolation for suppliers, POs, and stock balances.
  - **Result: 34 passed, 1 skipped, 0 failures**.
- **Frontend Flutter Tests**:
  - `purchasing_and_inventory_widget_test.dart`: 4 comprehensive widget tests covering adjustment calculations, movement tables, supplier forms, and master purchasing dashboard tabs.
  - **Result: All widget tests passed (100%)**.
  - `flutter analyze`: **0 issues found**.

