# Hardware Integration, Offline Licensing & Desktop Packaging

## Overview
This document specifies the architecture, hardware drivers, cryptographic licensing protocol, and desktop packaging implemented for the Retail POS System under Track 8.

---

## 1. Thermal Receipt Printing (ESC/POS)
The application generates hardware-standard ESC/POS binary command streams for 80mm and 58mm thermal receipt printers (Epson, Citizen, Star Micronics, Bixolon, Xprinter, POS-80/58):

### Supported Hardware Commands:
- **Printer Initialization:** `[0x1B, 0x40]` (`ESC @`)
- **Justification:** Left `[0x1B, 0x61, 0x00]`, Center `[0x1B, 0x61, 0x01]`, Right `[0x1B, 0x61, 0x02]`
- **Typography:** Bold on/off, Double height `[0x1D, 0x21, 0x01]`, Double size `[0x1D, 0x21, 0x11]`
- **Automatic Cash Drawer Kick:**
  - Pin 2 pulse: `[0x1B, 0x70, 0x00, 0x19, 0xFA]` (50ms on / 500ms off)
  - Pin 5 pulse: `[0x1B, 0x70, 0x01, 0x19, 0xFA]`
- **Paper Cutting:**
  - Full cut: `[0x1D, 0x56, 0x00]`
  - Partial cut with feed: `[0x1D, 0x56, 0x42, 0x00]` (`GS V 66 0`)

### Receipt Layout Elements:
1. **Header:** Centered store brand, registered branch location, telephone, and tax invoice memo.
2. **Transaction Metadata:** Authoritative receipt number, ISO timestamp, cashier ID, and customer name.
3. **Itemized Table:** Fixed-pitch columns (80mm: 24/12/12 chars; 58mm: 16/4/12 chars) with quantity, unit selling price, discount lines, and line totals.
4. **Financial Totals:** Subtotal, discount deductions, 5% VAT breakdown, and bold double-height **GRAND TOTAL**.
5. **Tender Allocations:** Breakdown of Cash, Card, Mobile Banking (bKash/Nagad), Customer Due balance, and Change Given.
6. **Footer & Spooling:** Return policy notice and offline certification watermark, followed by paper feed and automatic partial blade cut.

---

## 2. Hardware Barcode Scanner Integration
Hardware USB and Bluetooth barcode scanners (Handheld Honeywell, Zebra, Datalogic, Netum, Eyoyo) operate in **HID Keyboard Wedge** mode.

### Detection Mechanism:
- Intercepts key events globally via `HardwareKeyboard.instance.addHandler`.
- Differentiates human typing from laser scanner bursts:
  - Scanner keystroke interval: Typically **10ms – 45ms** (< 65ms threshold).
  - Human typist keystroke interval: Typically **100ms – 300ms**.
  - Burst terminator: `LogicalKeyboardKey.enter` or `LogicalKeyboardKey.tab`.
- Automatically calls `CartNotifier.addByBarcode(scannedBarcode, catalog)`:
  - Adds or increments the item quantity instantly.
  - Requires **zero text field focus**; the cashier can scan products continuously while browsing or during payment.

---

## 3. Offline Cryptographic Licensing Protocol
To support operations during complete internet outages, licensing relies on asymmetric / HMAC cryptographic tokens that can be verified entirely locally.

### Token Architecture:
`<base64_url_encoded_payload>.<sha256_hmac_signature>`

```json
{
  "license_key_id": "LIC-20261104-A1B2C3D4",
  "business_id": "00000000-0000-0000-0000-000000000001",
  "plan_name": "ENTERPRISE",
  "device_limit": 10,
  "features": ["MULTI_STORE", "ANALYTICS", "HARDWARE_PRINTING", "DATA_BACKUP"],
  "issued_at": "2026-11-04T12:00:00Z",
  "expires_at": "2027-11-04T12:00:00Z"
}
```

### Endpoints:
- `GET /api/v1/license/status`: Returns current license validity, plan, days remaining, and feature entitlements. Falls back to a 30-day evaluation trial if unactivated.
- `POST /api/v1/license/activate`: Validates signature, verifies business UUID match, checks expiry, and persists record to `license_records`.
- `POST /api/v1/license/generate`: Administrative tool for issuing digitally signed certificates to retail tenants.

---

## 4. Disaster Recovery & Database Backups
Automated database preservation ensures resilience against drive corruption, ransomware, or hardware failure.

### Backup Process:
1. `POST /api/v1/backups/create`:
   - Dumps operational tables (`businesses`, `branches`, `catalog`, `stock_balances`, `customers`, `suppliers`, `sales`, `movements`, `shifts`, `licenses`).
   - Compresses output via `gzip` (`.json.gz`).
   - Computes 64-character SHA-256 checksum.
   - Saves archive to `backend/backups/`.
   - Records metadata in `backup_records`.
2. `GET /api/v1/backups`: Lists all historical backups with size and status.
3. `POST /api/v1/backups/{id}/restore`: Verifies file presence on disk, recalculates SHA-256 hash against database record, decompresses payload, and verifies schema structure before staging recovery.

---

## 5. Desktop Packaging & Production Deployment
- **Batch Launcher:** `launcher/run_pos_desktop.bat` orchestrates the PostgreSQL Docker container, FastAPI backend service, and Flutter client.
- **Inno Setup Script:** `installer/pos_system_setup.iss` builds a standalone Windows x64 installer bundling client binaries, dependencies, desktop shortcuts, and Windows auto-start hooks.

