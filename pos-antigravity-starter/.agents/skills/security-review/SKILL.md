---
name: security-review
description: Performs a focused security review of POS authentication, tenant isolation, permissions, licensing, API exposure, backups, and secrets.
---
# Security Review

1. Map trust boundaries: Flutter client, local API, local DB, optional VPS, update and license services.
2. Check authentication, session expiry, password storage, and brute-force controls.
3. Check every tenant/branch-scoped query and object-level authorization.
4. Check input validation, SQL injection, file upload, path traversal, and unsafe deserialization.
5. Confirm PostgreSQL is not publicly exposed.
6. Check secrets, logs, backups, and license signing key handling.
7. Check that license-server outage cannot disable perpetual local usage.
8. Report findings with severity, exploit scenario, affected code, and remediation.
9. Do not attempt destructive testing against live systems.
