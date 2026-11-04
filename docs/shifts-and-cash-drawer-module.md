# Cash Drawer, Register Shifts & Daily Z-Report Module (Track 4)

## Overview
The Shifts and Cash Drawer module provides end-to-end register shift management, drawer reconciliation, and formal audit receipting (Z-Report) for retail point-of-sale systems.

---

## 1. Mathematical Formulas & Reconciliation Policies

### Expected Cash Calculation
$$\text{Expected Cash} = \text{Opening Float} + \text{Cash Sales} + \text{Cash In} - \text{Cash Out} - \text{Cash Refunds}$$

### Discrepancy & Variance
$$\text{Variance} = \text{Closing Cash Counted} - \text{Expected Cash}$$

### Variance Status:
- $\text{Variance} == 0.00$: `BALANCED` (drawer is exact)
- $\text{Variance} < 0.00$: `SHORTAGE` (missing cash)
- $\text{Variance} > 0.00$: `OVERAGE` (excess cash)
- Shift still active: `PENDING_CLOSE`

---

## 2. API Endpoints

| Method | Endpoint | Description | Role / Scope |
|---|---|---|---|
| `POST` | `/api/v1/shifts/open` | Open a new register shift with starting float | `sales:create` |
| `GET` | `/api/v1/shifts/current` | Retrieve active open shift for current branch/user | `sales:read` |
| `POST` | `/api/v1/shifts/{id}/cash-in` | Record cash injection (petty cash replenishment) | `sales:create` |
| `POST` | `/api/v1/shifts/{id}/cash-out` | Record cash removal/safe drop with balance check | `sales:create` |
| `POST` | `/api/v1/shifts/{id}/close` | Close shift with counted cash & denominations breakdown | `sales:create` |
| `GET` | `/api/v1/shifts/{id}/z-report` | Generate comprehensive Z-Report (financial audit receipt) | `sales:read` |
| `GET` | `/api/v1/shifts` | Query paginated historical shift records and audits | `sales:read` |

---

## 3. Z-Report Structure (80mm Thermal Receipt Layout)

The Z-Report aggregates all transactions executed during the register shift lifetime:
1. **Header**: Store name, Branch code, Shift ID, Cashier name, Opened at, Closed at.
2. **Drawer Reconciliation**:
   - Starting Cash Float
   - Cash Sales (+)
   - Cash In Operations (+)
   - Cash Out Drops (-)
   - Cash Refunds (-)
   - Net Expected Cash
   - Closing Counted Cash
   - Variance ($\pm\text{Difference}$) & Reconciliation Status (`BALANCED`, `SHORTAGE`, `OVERAGE`)
3. **Tender Breakdown**: Total collections per payment method (`CASH`, `CARD`, `MOBILE_BANKING`, `STORE_CREDIT`).
4. **Sales Performance**: Total transactions count, Gross sales, Discounts given, Taxes collected, Net revenue, and Average basket size.
5. **Denominations Audit**: Counted physical notes (৳1000, ৳500, ৳200, ৳100, ৳50, ৳20, ৳10).

---

## 4. Frontend Components

- **ShiftStatusBar**: Live real-time register ribbon placed on the POS Register screen showing drawer cash, shift status, and action buttons (`Cash In`, `Cash Out`, `X-Report`, `Close Shift`).
- **OpenShiftDialog**: Starting float input with quick shortcut chips (+৳500, +৳1000, +৳2000, +৳5000) and notes.
- **CashInOutDialog**: Segmented toggle for Cash In vs Cash Out with reason presets and expected cash safety validation.
- **CloseShiftDialog**: Physical cash note denomination counters with live variance computation and color-coded status badges.
- **ZReportDialog**: Formatted thermal 80mm receipt preview with one-click print simulation and ledger audit details.

