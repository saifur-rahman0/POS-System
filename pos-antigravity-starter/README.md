# POS Antigravity Starter Pack

A planning and agent-guidance pack for building a local-first, perpetual-license POS for small retailers.

## Product decisions captured
- Frontend: Flutter + Dart
- State: Riverpod
- Local persistence/cache: Drift + SQLite (client-side only where needed)
- Backend: Python + FastAPI
- Database: PostgreSQL
- ORM/migrations: SQLAlchemy 2.x + Alembic
- API: REST + WebSockets
- Deployment: local shop server first; optional VPS services later
- Licensing: offline-verifiable perpetual license
- Business model: one-time software license; optional paid AMC, installation, customization and cloud services

## Important architecture clarification
For the first production release, use **one authoritative PostgreSQL database per shop installation**, hosted on the shop's local server. All terminals connect to the local FastAPI service. Do not let each terminal independently write to its own database.

A VPS is optional. Initially use it for off-site backups or later cloud synchronization. Do not build bidirectional sync until local sales, inventory, returns, and audit flows are correct.

## How to use
1. Extract this folder.
2. Open the extracted project root in Google Antigravity.
3. Ask the agent to read `AGENTS.md` and all `docs/` documents before implementation.
4. Start with `prompts/00_PROJECT_BOOTSTRAP.md`.
5. Review plans and diffs before allowing broad changes.
6. Implement one vertical slice at a time.
7. Commit working milestones to Git.

## Antigravity customizations
- Persistent rules: `.agents/rules/*.md`
- Reusable skills: `.agents/skills/<skill-name>/SKILL.md`
- Project-level guidance: `AGENTS.md`
- Agent role briefs: `docs/agent-playbook.md`

Google Antigravity's current documentation uses Agent Skills under `.agents/skills`. Legacy workflows were scheduled to stop being indexed after 19 October 2026, so this pack uses Skills rather than legacy `.agents/workflows`. See `docs/antigravity-setup.md`.

## Do not ask an agent to build the entire POS in one task
Ask it to plan first, then implement one bounded feature with tests and a walkthrough.
