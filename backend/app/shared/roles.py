"""Role-Based Access Control (RBAC) definitions and permissions matrix."""

from typing import Final

# Granular capabilities across POS system modules
SYSTEM_PERMISSIONS: Final[dict[str, str]] = {
    "pos": "Access POS register terminal and scan products",
    "sales:create": "Execute checkout transactions and accept payments",
    "sales:read": "View sales receipts and order history",
    "sales:refund": "Process returns, issue refunds, and credit notes",
    "shifts:manage": "Open/close cash shifts, register cash in/out, view drawer balance",
    "catalog:read": "Browse product catalog, variants, and categories",
    "catalog:write": "Create, edit, and archive products and categories",
    "inventory:read": "View stock levels, batches, expiry alerts, and valuation",
    "inventory:write": "Perform inventory audits, write off damaged stock, inward batches",
    "transfers:read": "View stock transfers between branches",
    "transfers:write": "Create and dispatch store branch transfers",
    "purchasing:read": "View purchase orders and suppliers",
    "purchasing:write": "Create purchase orders, receive shipments, record payments",
    "expenses:read": "View operating expense vouchers and categories",
    "expenses:write": "Create expense vouchers and record petty cash payments",
    "accounts:read": "View liquid accounts (safe, register drawer, commercial bank)",
    "accounts:write": "Execute account transfers and balance adjustments",
    "customers:read": "Browse customer profiles, loyalty balances, and credit dues",
    "customers:write": "Create and edit customer records, issue gift cards",
    "reports:read": "View financial, sales, tax, and executive reports",
    "settings:read": "View store preferences, hardware configuration, and licensing",
    "settings:write": "Modify store profile, printer settings, and database backups",
    "users:manage": "Manage staff accounts, assign roles and customize permissions",
}

# Standard retail business roles and their default permission bundles
ROLE_PERMISSIONS: Final[dict[str, list[str]]] = {
    "ADMIN": [
        "*",  # Wildcard for complete stall owner authority
    ],
    "MANAGER": [
        "pos",
        "sales:create",
        "sales:read",
        "sales:refund",
        "shifts:manage",
        "catalog:read",
        "catalog:write",
        "inventory:read",
        "inventory:write",
        "transfers:read",
        "transfers:write",
        "purchasing:read",
        "purchasing:write",
        "expenses:read",
        "expenses:write",
        "customers:read",
        "customers:write",
        "reports:read",
        "settings:read",
    ],
    "CASHIER": [
        "pos",
        "sales:create",
        "sales:read",
        "shifts:manage",
        "customers:read",
        "customers:write",
    ],
    "STOCK_KEEPER": [
        "catalog:read",
        "catalog:write",
        "inventory:read",
        "inventory:write",
        "transfers:read",
        "transfers:write",
        "purchasing:read",
        "purchasing:write",
    ],
}

ROLE_LABELS: Final[dict[str, str]] = {
    "ADMIN": "Stall Owner (Admin)",
    "MANAGER": "Store Manager",
    "CASHIER": "Cashier",
    "STOCK_KEEPER": "Inventory / Stock Keeper",
}
