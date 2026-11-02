---
trigger: model_decision
description: Apply to authentication, authorization, licensing, tenant isolation, secrets, APIs, deployment, backups, and customer data.
---
# Security and Privacy
- Enforce authorization in backend services, not only in Flutter UI.
- Derive business/tenant and branch scope from authenticated membership.
- Hash passwords with Argon2id or a maintained secure password-hashing library.
- Store secrets in environment variables/secret manager; never commit secrets.
- Keep PostgreSQL private; expose only the HTTPS API.
- Rate-limit authentication and sensitive endpoints.
- Redact credentials and personal data from logs.
- Verify signed license payloads using an embedded public key; private signing key stays offline/server-side.
- No remote kill switch for perpetual licenses.
- Encrypt backups and test restore.
- Ask before destructive operations or production deployment.
