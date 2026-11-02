---
name: bug-investigation
description: Reproduces and diagnoses POS bugs systematically before making the smallest safe fix.
---
# Bug Investigation

1. Capture expected vs actual behavior and exact reproduction steps.
2. Identify affected layer: Flutter, API, database, network, printer, or deployment.
3. Reproduce with a focused test or minimal fixture.
4. Inspect logs without exposing secrets or customer data.
5. Identify root cause; do not patch symptoms only.
6. Add a regression test before or with the fix.
7. Make the smallest change that fixes the issue.
8. Run relevant tests and report any remaining uncertainty.
