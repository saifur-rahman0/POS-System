# Multi-Store, Stock Transfers & Terminal Offline Sync Module

This document outlines the architectural specifications, API endpoints, transactional boundaries, and Flutter client integration for **Track 5: Multi-Store & Branch Sync**.

---

## 1. Domain Overview & Multi-Branch Architecture

Retail businesses operate across multiple physical outlets (main shop, warehouse, retail branches). This module provides:
- **Tenant-Scoped Branch Registry**: Branches with unique store codes (`MAIN`, `BR-DHK`, etc.), active flags, and contact details.
- **Inter-Store Stock Transfers**: Strict multi-step workflow (`DRAFT` $\to$ `IN_TRANSIT` $\to$ `RECEIVED` or `CANCELLED`) ensuring atomic stock custody transfer.
- **Cross-Branch Stock Visibility**: Real-time aggregation of item stock balances across all active retail branches without revealing confidential margin figures.
- **Offline Terminal Delta Sync**: Bi-directional synchronization enabling cashiers to work offline during network outages and reconcile sales in batch upon reconnecting.

---

## 2. API Specifications

### Branch Registry Endpoints
- `GET /api/v1/branches`: List all active branches for the authenticated business. Includes stock summary KPIs (`total_variants_stocked`, `total_units_on_hand`).
- `POST /api/v1/branches`: Create a new branch. Enforces store code uppercase format and business-scoped uniqueness (returns `409 Conflict` on duplicate code).
- `GET /api/v1/branches/{branch_id}`: Retrieve branch details and performance metrics.
- `PUT /api/v1/branches/{branch_id}`: Update branch name, phone, address, or active status.

### Stock Transfers Endpoints
- `GET /api/v1/transfers`: Paginated list of transfer orders with optional status, source, and destination filters.
- `POST /api/v1/transfers`: Create a new transfer order in `DRAFT` status with line items.
- `GET /api/v1/transfers/{transfer_id}`: Detailed view of a transfer order including items, audit timestamps, and dispatches.
- `POST /api/v1/transfers/{transfer_id}/dispatch`: Transition status to `IN_TRANSIT`. Locks source inventory with `with_for_update()`, verifies sufficiency, deducts quantity from source `StockBalance`, and logs `StockMovement` of type `TRANSFER_DISPATCH`.
- `POST /api/v1/transfers/{transfer_id}/receive`: Transition status to `RECEIVED`. Increases destination `StockBalance` and logs `StockMovement` of type `TRANSFER_RECEIPT`.
- `POST /api/v1/transfers/{transfer_id}/cancel`: Available from `DRAFT` or `IN_TRANSIT`. If dispatched, restores deducted inventory back to source `StockBalance` with `TRANSFER_REVERSAL`.
- `GET /api/v1/transfers/cross-branch-stock/{variant_id}`: Real-time query returning on-hand quantity per branch for a selected product variant.

### Offline Synchronization Endpoints
- `GET /api/v1/sync/pull?since={timestamp}`: Terminal requests delta updates for products, variants, and customers created or modified since last sync.
- `POST /api/v1/sync/push`: Terminal pushes batch offline sales created during connectivity outage. Validates idempotency keys, locks inventory, completes checkout, and returns reconciliation report.

---

## 3. Concurrency & Precision Guarantees
- All stock movements and balances use `NUMERIC(12, 4)` / `Decimal` precision.
- Inter-branch dispatches apply row-level pessimistic locking (`with_for_update()`) on source `stock_balances` ordered by variant ID to eliminate deadlocks.
- Receipts are generated per branch with format `REC-YYYYMMDD-{BRANCH_CODE}-{SEQ:04d}` serialized by locking the parent `Branch` row.

---

## 4. Flutter Client Integration

- **Branch Navigation & Switcher**: Header bar in `ShellScreen` displays the current active branch with one-click dropdown to change terminal branch context.
- **Branches Screen (`branches_screen.dart`)**: Tabbed interface featuring "Retail Branches" directory and "Inter-Store Transfers".
- **Branch Form Dialog (`branch_form_dialog.dart`)**: Modal for creating or editing branch metadata.
- **Create Transfer Dialog (`create_transfer_dialog.dart`)**: Interactive modal with source/destination branch selectors, variant picker, and quantity validation.
- **Cross-Branch Stock Dialog (`cross_branch_stock_dialog.dart`)**: Real-time cross-store stock inquiry accessible directly from POS register or Catalog screen.
- **One-Tap Offline Sync**: Sync action icon in the shell header triggering delta pull and batch push with visual sync indicators.

