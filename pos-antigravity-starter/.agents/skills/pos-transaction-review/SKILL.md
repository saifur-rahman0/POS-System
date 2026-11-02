---
name: pos-transaction-review
description: Reviews checkout, payment, refund, return, purchase, expense, and inventory transaction code for financial correctness and concurrency risks.
---
# POS Transaction Review

Review:
- Is the operation atomic?
- Are money and quantity types precise?
- Are duplicate requests prevented with idempotency?
- Are concurrent checkouts and stock changes safe?
- Is the stock ledger correct?
- Are partial payments, change, split tender, and due balances correct?
- Are returns linked to original sale lines and limited by returnable quantity?
- Are audit records created?
- Are permissions checked server-side?
- Does failure roll back every related write?
- Are tests present for success, duplicate request, concurrency, and rollback?

Return findings by severity with file/line references. Do not modify code unless asked.
