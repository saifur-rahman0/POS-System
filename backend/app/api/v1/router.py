"""Consolidated API v1 router."""

from fastapi import APIRouter

from app.api.v1.catalog import router as catalog_router
from app.api.v1.customers import router as customers_router
from app.api.v1.health import router as health_router
from app.api.v1.inventory import router as inventory_router
from app.api.v1.purchases import router as purchases_router
from app.api.v1.sales import router as sales_router
from app.api.v1.shifts import router as shifts_router
from app.api.v1.suppliers import router as suppliers_router

api_v1_router = APIRouter(prefix="/api/v1")

# System & Health
api_v1_router.include_router(health_router)

# Catalog
api_v1_router.include_router(catalog_router)

# Sales & Checkout
api_v1_router.include_router(sales_router)

# Cash Drawer & Shifts
api_v1_router.include_router(shifts_router)

# Customers & Due Ledger
api_v1_router.include_router(customers_router)

# Suppliers & Purchasing
api_v1_router.include_router(suppliers_router)
api_v1_router.include_router(purchases_router)

# Inventory & Adjustments
api_v1_router.include_router(inventory_router)
