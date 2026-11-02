---
trigger: glob
globs: "**/*.dart"
description: Flutter and Dart conventions for the POS client.
---
# Flutter Conventions
- Use feature-first folders and Riverpod for state.
- Keep widgets focused; business rules belong in providers/use-cases or backend services.
- Use typed API models and centralized Dio client/error handling.
- Handle loading, empty, validation, offline, and failure states explicitly.
- Avoid putting database or HTTP calls directly inside build methods.
- Add widget/unit tests for important flows.
- Optimize checkout for keyboard, barcode scanner, touch, and small displays.
