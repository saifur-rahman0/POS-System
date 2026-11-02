---
name: release-check
description: Runs a pre-release quality, migration, security, packaging, backup, and recovery checklist for the POS product.
---
# Release Checklist

- Confirm release scope and version.
- Check clean Git working tree and tagged commit.
- Run backend formatting, lint/type checks, tests.
- Run Flutter format, analyze, unit/widget tests, Windows build.
- Test fresh install and upgrade from previous supported version.
- Test database migration and backup restore.
- Test checkout, partial payment, return, stock adjustment, and duplicate request.
- Test LAN multi-terminal operation and internet outage behavior.
- Verify license offline activation and no-expiry behavior.
- Inspect installer, signing, configuration, logs, and secrets.
- Prepare release notes and known limitations.
- Do not deploy or publish without explicit approval.
