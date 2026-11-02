---
name: implement-feature
description: Implements an approved POS feature in small vertical slices with tests, migrations, documentation, and verification.
---
# Implement an Approved Feature

1. Read the approved plan and relevant rules.
2. Confirm the current branch and working tree; never overwrite uncommitted user changes.
3. Implement backend contract and tests first where business logic is involved.
4. Add migration before relying on schema changes.
5. Implement Flutter UI against the agreed API contract.
6. Add loading, empty, validation, offline, and error states.
7. Run formatters, static analysis, targeted tests, and relevant builds.
8. Inspect the diff for unrelated edits, secrets, debug code, and weakened tests.
9. Update docs and report exact verification results.
10. Stop and ask before destructive migration, production data operations, or changing financial invariants.
