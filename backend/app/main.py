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
    generic_exception_handler,
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
        from app.modules.identity.models import Membership, MembershipRole, Role, User
        from app.modules.inventory.models import StockBalance
        from app.shared.auth import DEV_USER_ID
        from app.shared.roles import ROLE_LABELS, ROLE_PERMISSIONS

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

            # Ensure roles exist for dev business
            roles_map: dict[str, Role] = {}
            for r_name, r_label in ROLE_LABELS.items():
                r_stmt = select(Role).where(
                    Role.business_id == DEV_BUSINESS_ID,
                    Role.name == r_name,
                )
                r_obj = (await session.execute(r_stmt)).scalars().first()
                if not r_obj:
                    r_obj = Role(
                        business_id=DEV_BUSINESS_ID,
                        name=r_name,
                        description=r_label,
                    )
                    session.add(r_obj)
                    await session.flush()
                roles_map[r_name] = r_obj

            # Seed standard user profiles: Stall Owner (admin), Manager, Cashier, Stock Keeper
            seed_users = [
                {
                    "id": uuid.UUID("00000000-0000-0000-0000-000000000003"),
                    "username": "admin",
                    "display_name": "Stall Owner (Admin)",
                    "email": "owner@pos.local",
                    "role": "ADMIN",
                },
                {
                    "id": uuid.UUID("00000000-0000-0000-0000-000000000004"),
                    "username": "manager",
                    "display_name": "Store Manager",
                    "email": "manager@pos.local",
                    "role": "MANAGER",
                },
                {
                    "id": DEV_USER_ID,
                    "username": "dev_cashier",
                    "display_name": "Counter Cashier",
                    "email": "cashier@pos.local",
                    "role": "CASHIER",
                },
                {
                    "id": uuid.UUID("00000000-0000-0000-0000-000000000005"),
                    "username": "stock_keeper",
                    "display_name": "Warehouse & Stock Keeper",
                    "email": "stock@pos.local",
                    "role": "STOCK_KEEPER",
                },
            ]

            for u_data in seed_users:
                u_stmt = select(User).where(User.username == u_data["username"])
                user_obj = (await session.execute(u_stmt)).scalars().first()
                if not user_obj:
                    user_obj = User(
                        id=u_data["id"],
                        username=u_data["username"],
                        password_hash="dev_dummy_hash_not_for_prod",
                        display_name=u_data["display_name"],
                        email=u_data["email"],
                        is_active=True,
                    )
                    session.add(user_obj)
                    await session.flush()

                # Membership
                m_stmt = select(Membership).where(
                    Membership.business_id == DEV_BUSINESS_ID,
                    Membership.user_id == user_obj.id,
                )
                m_obj = (await session.execute(m_stmt)).scalars().first()
                if not m_obj:
                    m_obj = Membership(
                        business_id=DEV_BUSINESS_ID,
                        user_id=user_obj.id,
                        status="ACTIVE",
                    )
                    session.add(m_obj)
                    await session.flush()

                # MembershipRole
                r_obj = roles_map.get(u_data["role"])
                if r_obj:
                    mr_stmt = select(MembershipRole).where(
                        MembershipRole.membership_id == m_obj.id,
                        MembershipRole.role_id == r_obj.id,
                    )
                    if not (await session.execute(mr_stmt)).scalars().first():
                        session.add(MembershipRole(membership_id=m_obj.id, role_id=r_obj.id))

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
    except Exception as exc:
        import logging

        logging.getLogger(__name__).warning("Dev database seeding skipped: %s", exc)


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
    app.add_exception_handler(Exception, generic_exception_handler)  # type: ignore

    # Mount API v1 router
    app.include_router(api_v1_router)

    # Root /health alias (in addition to /api/v1/health) for standard orchestrator probes
    app.include_router(health_router)

    @app.get("/", include_in_schema=False)
    async def root_redirect() -> RedirectResponse:
        return RedirectResponse(url="/health")

    return app


app = create_app()
