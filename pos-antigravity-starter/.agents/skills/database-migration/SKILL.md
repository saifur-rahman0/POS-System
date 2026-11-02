---
name: database-migration
description: Designs and applies safe PostgreSQL schema changes using SQLAlchemy and Alembic, including rollback and data-integrity checks.
---
# Database Migration Procedure

1. Read the current SQLAlchemy models and migration history.
2. Identify affected tables, constraints, indexes, and existing data.
3. Prefer additive migrations. For renames/removals use expand-and-contract across releases.
4. Define nullability, defaults, FK behavior, uniqueness, tenant/branch scope, and indexes.
5. Generate an Alembic revision; inspect it manually. Never blindly trust autogeneration.
6. Include data migration only when required and make it safe to retry where possible.
7. Test upgrade from the current schema and downgrade where downgrade is safe.
8. Run integrity checks and relevant tests.
9. Never run migrations against production without explicit approval and a verified backup.
