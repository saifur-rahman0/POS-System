---
trigger: model_decision
description: Apply when implementing sales, payments, refunds, purchases, expenses, inventory, money, or database transactions.
---
# Financial and Inventory Integrity
- Use Decimal in Python and NUMERIC in PostgreSQL for money and quantities requiring precision.
- Checkout must be one atomic transaction: sale header, sale lines, payment allocation, stock movements, audit record, and idempotency result.
- Validate stock policy inside the transaction; prevent overselling unless an explicit backorder policy exists.
- Never mutate completed financial history silently. Use void, refund, reversal, and adjustment records.
- Stock ledger is the source of truth; balances are derived/maintained and reconciled.
- Add tests for duplicate requests, concurrent checkout, rollback, partial payment, returns, and rounding.
