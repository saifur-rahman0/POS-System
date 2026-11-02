---
trigger: glob
globs: "**/*.py"
description: FastAPI, SQLAlchemy, and Python backend conventions.
---
# Python Backend Conventions
- Use type hints and Pydantic request/response schemas.
- Keep routers thin; business logic in service/use-case modules.
- Use SQLAlchemy 2.x patterns and explicit transaction scopes.
- Use Alembic migrations for all schema changes.
- Never construct SQL using untrusted string concatenation.
- Use dependency injection for DB sessions and authenticated principals.
- Test authorization and transaction rollback, not only happy paths.
