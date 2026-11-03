"""FastAPI application entry point."""

import uuid
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from app.api.v1.health import router as health_router
from app.api.v1.router import api_v1_router
from app.config import get_settings
from app.database import close_db_connection, get_session_maker
from app.logging_config import setup_logging
from app.modules.business.models import Business
from app.shared.auth import DEV_BUSINESS_ID
from app.shared.exceptions import (
    AppException,
    app_exception_handler,
    database_timeout_exception_handler,
    validation_exception_handler,
)

DEV_BRANCH_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")


async def _seed_dev_business() -> None:
    """Ensures default dev business, branch, and stock exist in database for local exploration."""
    try:
        from decimal import Decimal

        from sqlalchemy import select

        from app.modules.business.models import Branch
        from app.modules.catalog.models import ProductVariant
        from app.modules.inventory.models import StockBalance

        session_factory = get_session_maker()
        async with session_factory() as session:
            existing_biz = await session.get(Business, DEV_BUSINESS_ID)
            if not existing_biz:
                dev_biz = Business(
                    id=DEV_BUSINESS_ID,
                    name="Retail POS Store (Development)",
                    timezone="Asia/Dhaka",
                    currency="BDT",
                    is_active=True,
                )
                session.add(dev_biz)
                await session.flush()

            existing_branch = await session.get(Branch, DEV_BRANCH_ID)
            if not existing_branch:
                dev_branch = Branch(
                    id=DEV_BRANCH_ID,
                    business_id=DEV_BUSINESS_ID,
                    name="Main Store",
                    code="MAIN",
                    is_active=True,
                )
                session.add(dev_branch)
                await session.flush()

            # Ensure all variants belonging to dev business have a positive stock balance
            var_stmt = select(ProductVariant).where(ProductVariant.business_id == DEV_BUSINESS_ID)
            var_res = await session.execute(var_stmt)
            for variant in var_res.scalars().all():
                bal_stmt = select(StockBalance).where(
                    StockBalance.business_id == DEV_BUSINESS_ID,
                    StockBalance.branch_id == DEV_BRANCH_ID,
                    StockBalance.product_variant_id == variant.id,
                )
                bal_res = await session.execute(bal_stmt)
                if not bal_res.scalars().first():
                    session.add(
                        StockBalance(
                            business_id=DEV_BUSINESS_ID,
                            branch_id=DEV_BRANCH_ID,
                            product_variant_id=variant.id,
                            quantity_on_hand=Decimal("100.0000"),
                        )
                    )

            await session.commit()
    except Exception:
        # Ignore startup seeding errors if database is not yet migrated/ready
        pass


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Lifespan context manager for database connection pool cleanup."""
    # Startup
    settings = get_settings()
    setup_logging(debug=settings.DEBUG)
    if settings.ENVIRONMENT == "development":
        await _seed_dev_business()
    yield
    # Shutdown
    await close_db_connection()


def create_app() -> FastAPI:
    """Application factory for the POS FastAPI backend."""
    settings = get_settings()

    app = FastAPI(
        title="Retail POS System Backend",
        description="Local-first POS and Inventory management API for retail shops.",
        version="0.1.0",
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
        lifespan=lifespan,
    )

    # CORS configuration for Shop LAN terminals
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Exception Handlers
    app.add_exception_handler(AppException, app_exception_handler)  # type: ignore
    app.add_exception_handler(RequestValidationError, validation_exception_handler)  # type: ignore
    app.add_exception_handler(TimeoutError, database_timeout_exception_handler)  # type: ignore

    # Mount API v1 router
    app.include_router(api_v1_router)

    # Root /health alias (in addition to /api/v1/health) for standard orchestrator probes
    app.include_router(health_router)

    @app.get("/", include_in_schema=False)
    async def root_redirect() -> RedirectResponse:
        return RedirectResponse(url="/health")

    return app


app = create_app()
