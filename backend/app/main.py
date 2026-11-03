"""FastAPI application entry point."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from app.api.v1.health import router as health_router
from app.api.v1.router import api_v1_router
from app.config import get_settings
from app.database import close_db_connection
from app.logging_config import setup_logging
from app.shared.exceptions import (
    AppException,
    app_exception_handler,
    validation_exception_handler,
)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Lifespan context manager for database connection pool cleanup."""
    # Startup
    settings = get_settings()
    setup_logging(debug=settings.DEBUG)
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

    # Mount API v1 router
    app.include_router(api_v1_router)

    # Root /health alias (in addition to /api/v1/health) for standard orchestrator probes
    app.include_router(health_router)

    @app.get("/", include_in_schema=False)
    async def root_redirect() -> RedirectResponse:
        return RedirectResponse(url="/health")

    return app


app = create_app()
