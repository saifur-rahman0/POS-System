"""Consolidated API v1 router."""

from fastapi import APIRouter

from app.api.v1.catalog import router as catalog_router
from app.api.v1.customers import router as customers_router
from app.api.v1.health import router as health_router
from app.api.v1.sales import router as sales_router

api_v1_router = APIRouter(prefix="/api/v1")

# System & Health
api_v1_router.include_router(health_router)

# Catalog
api_v1_router.include_router(catalog_router)

# Sales & Checkout
api_v1_router.include_router(sales_router)

# Customers & Due Ledger
api_v1_router.include_router(customers_router)
