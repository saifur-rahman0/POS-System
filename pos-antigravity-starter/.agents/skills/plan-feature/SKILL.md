---
name: plan-feature
description: Plans a bounded POS feature before implementation, including acceptance criteria, data changes, API contracts, risks, tests, and rollout.
---
# Plan a POS Feature

1. Read `AGENTS.md`, product requirements, architecture, and relevant module docs.
2. Inspect the repository and existing patterns.
3. Clarify only decisions that materially block implementation; otherwise record assumptions.
4. Write a plan with:
   - user story and business value
   - scope and explicit non-goals
   - user flow
   - data model changes
   - API contract changes
   - authorization rules
   - failure and edge cases
   - tests and acceptance criteria
   - migration and rollback considerations
5. Identify files to create/change.
6. Do not implement until the user approves the plan for high-risk or cross-module changes.
7. Save the plan under `docs/plans/` if requested.
