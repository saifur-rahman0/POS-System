# Customers, Store Credit & Due Settlement Module

## 1. Architectural Overview & Responsibility

The **Customers, Store Credit & Due Settlement** module manages registered customer profiles, credit limit enforcement, partial/deferred payment ("DUE") handling during POS checkout, atomic debt repayments against unpaid sales (FIFO allocation), and chronological account ledger statements.

### Key Capabilities
- **Customer Directory & CRUD**: Register and maintain customer records with business-scoped unique phone numbers and configurable credit limits.
- **Credit Limit & Checkout Due Enforcement**: During checkout, any unpaid portion is tracked under `sale.due_total`. If a customer's total outstanding dues plus the new debt exceeds their `credit_limit`, the transaction is blocked with `409 Conflict (CREDIT_LIMIT_EXCEEDED)`.
- **FIFO Due Repayment Engine**: When a customer makes a debt repayment, funds are automatically allocated to their unpaid sales in chronological order (`created_at ASC`). Each affected sale's `due_total` decreases, `paid_total` increases, and a confirmed `PaymentTender` is logged.
- **Cash Drawer Integration**: For `CASH` repayments, a `CashTransaction(direction="IN")` entry is logged to maintain an audit trail for the branch cash drawer.
- **Account Ledger Statement**: A double-entry style chronological ledger (`GET /api/v1/customers/{id}/ledger`) detailing debit purchases, credit payments, receipt references, and real-time running balances.
- **Flutter POS & Management UI**:
  - `CustomerSelectionDialog`: Searchable modal for selecting or quick-adding customers in the POS register.
  - `PosRegisterScreen`: Customer bar displaying linked account, outstanding due, and available credit.
  - `CollectDueDialog`: Counter repayment interface with quick amount shortcuts and method selection (Cash, Card, bKash, Nagad, Rocket).
  - `CustomerLedgerDialog`: Account statement viewer.
  - `CustomersScreen`: Central customer management dashboard with KPI cards for total customers and business-wide outstanding dues.

---

## 2. API Contract Specification

### 2.1 Customer CRUD
- `GET /api/v1/customers`
  - Query Params: `search` (name/phone), `is_active`, `page`, `page_size`.
  - Response: `PaginatedCustomers` (items, total, total_pages, total_outstanding_dues).
- `POST /api/v1/customers`
  - Payload: `CustomerCreate` (`name`, `phone`, `email`, `address`, `credit_limit`).
  - Response: `201 Created` with `CustomerOut`.
  - Errors: `409 Conflict (PHONE_ALREADY_EXISTS)`.
- `GET /api/v1/customers/{id}`
  - Response: `CustomerOut` including computed `due_balance` and `available_credit`.
- `PUT /api/v1/customers/{id}`
  - Payload: `CustomerUpdate`.

### 2.2 Due Repayment Collection
- `POST /api/v1/customers/{id}/payments`
  - Query Params: `branch_id` (optional, defaults to active branch).
  - Payload:
    ```json
    {
      "amount": "500.0000",
      "payment_method": "CASH",
      "reference": "TrxID992",
      "notes": "Paid at front counter",
      "sale_id": null
    }
    ```
  - Response: `201 Created` with `CustomerDuePaymentOut`:
    ```json
    {
      "customer_id": "uuid",
      "customer_name": "Rahim Uddin",
      "amount_paid": "500.0000",
      "previous_due": "900.0000",
      "remaining_due": "400.0000",
      "payment_method": "CASH",
      "reference": "TrxID992",
      "allocated_sales": [
        {
          "sale_id": "uuid",
          "receipt_no": "REC-20261103-MAIN-0001",
          "allocated_amount": "500.0000",
          "remaining_sale_due": "400.0000"
        }
      ],
      "created_at": "2026-11-03T18:00:00Z"
    }
    ```

### 2.3 Customer Ledger Statement
- `GET /api/v1/customers/{id}/ledger`
  - Response: Chronological list of `CustomerLedgerEntry`:
    ```json
    [
      {
        "date": "2026-11-01T10:00:00Z",
        "entry_type": "SALE_CHARGE",
        "receipt_no": "REC-20261101-MAIN-0010",
        "description": "Purchase: REC-20261101-MAIN-0010",
        "debit": "900.0000",
        "credit": "0.0000",
        "balance": "900.0000"
      },
      {
        "date": "2026-11-03T14:30:00Z",
        "entry_type": "PAYMENT",
        "receipt_no": "REC-20261101-MAIN-0010",
        "description": "Payment (CASH) against REC-20261101-MAIN-0010",
        "debit": "0.0000",
        "credit": "500.0000",
        "balance": "400.0000"
      }
    ]
    ```

---

## 3. Automated Test Verification

| Test Suite | File | Tests | Result |
|---|---|---|---|
| Customer CRUD, Validation & Isolation | `backend/tests/test_customers.py` | 5 | PASSED |
| POS Checkout & DUE Payments | `backend/tests/test_checkout.py` | 7 | PASSED |
| Sales Returns & History | `backend/tests/test_returns_and_sales_history.py` | 6 | PASSED |
| Full Backend Pytest Suite | `backend/tests/` | 30 (29 pass, 1 skipped) | PASSED |
| Flutter Customers Widget Tests | `pos_system_application/test/customers_widget_test.dart` | 5 | PASSED |
| Full Flutter Widget Suite | `pos_system_application/test/` | 17 | PASSED |
| Flutter Analyzer | `flutter analyze` | 0 issues | PASSED |
| Backend Lint & Typing | `ruff`, `mypy` | 0 issues | PASSED |
