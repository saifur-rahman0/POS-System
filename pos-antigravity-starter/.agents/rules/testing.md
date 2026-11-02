---
trigger: model_decision
description: Apply whenever adding or changing application behavior, APIs, schema, or integrations.
---
# Testing Requirements
- Every feature includes tests for success, validation failure, permission failure, and relevant edge cases.
- Financial features require transaction rollback and idempotency tests.
- Database tests use isolated test databases/transactions, never production.
- Do not mock away the behavior being tested.
- Run targeted tests first, then the full relevant suite.
- Report exact commands and outcomes; never claim unexecuted tests passed.
