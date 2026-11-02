---
trigger: always_on
description: Core POS architecture and product boundaries.
---
# Architecture Rule
Use a modular monolith. Flutter clients call FastAPI; FastAPI owns business rules and writes to PostgreSQL. PostgreSQL is authoritative for shop data. Local client SQLite is not a substitute for the shared shop database. Keep the first release local-first; optional VPS/cloud work must not be a prerequisite for checkout.
