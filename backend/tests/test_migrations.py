"""Automated integration tests for database schema migrations.

These tests execute only against a disposable test database.
"""

import os
from collections.abc import AsyncGenerator
from typing import Any

import pytest
from alembic.config import Config
from sqlalchemy import Connection, inspect, pool, text
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

from alembic import command

TEST_DB_ASYNC_URL = os.getenv(
    "TEST_DATABASE_URL",
    os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://test_user:test_password@localhost:5433/pos_test_db",
    ),
)


@pytest.fixture
async def async_db_engine() -> AsyncGenerator[AsyncEngine, None]:
    """Fixture providing an async engine to the disposable test database."""
    engine = create_async_engine(
        TEST_DB_ASYNC_URL,
        poolclass=pool.NullPool,
        connect_args={"timeout": 5.0},
    )
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception as exc:
        pytest.skip(f"Disposable test database not reachable at {TEST_DB_ASYNC_URL}: {exc}")
    yield engine
    await engine.dispose()


@pytest.fixture(scope="module")
def alembic_cfg() -> Config:
    """Configures Alembic for the disposable test database."""
    backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ini_path = os.path.join(backend_dir, "alembic.ini")
    cfg = Config(ini_path)
    cfg.set_main_option("sqlalchemy.url", TEST_DB_ASYNC_URL)
    return cfg


@pytest.mark.asyncio
async def test_migration_upgrade_and_downgrade(
    async_db_engine: AsyncEngine,
    alembic_cfg: Config,
) -> None:
    """Test full cycle: upgrade head, inspect schema, downgrade base, and re-upgrade."""
    import asyncio

    # 1. Run upgrade head
    await asyncio.to_thread(command.upgrade, alembic_cfg, "head")

    async with async_db_engine.connect() as conn:
        existing_tables = await conn.run_sync(
            lambda sync_conn: set(inspect(sync_conn).get_table_names())
        )

    # 2. Verify all core domain tables are created
    expected_tables = {
        "businesses",
        "branches",
        "users",
        "memberships",
        "roles",
        "permissions",
        "role_permissions",
        "membership_roles",
        "devices",
        "categories",
        "brands",
        "products",
        "product_variants",
        "imei_devices",
        "stock_movements",
        "stock_balances",
        "stock_counts",
        "stock_count_lines",
        "suppliers",
        "purchases",
        "purchase_items",
        "purchase_payments",
        "customers",
        "sales",
        "sale_items",
        "payment_tenders",
        "returns",
        "return_items",
        "expenses",
        "cash_transactions",
        "audit_logs",
        "idempotency_records",
        "license_records",
        "backup_records",
        "sync_outbox",
    }
    assert expected_tables.issubset(existing_tables), (
        f"Missing tables: {expected_tables - existing_tables}"
    )

    # 3. Verify numeric precision on critical financial & inventory columns
    async with async_db_engine.connect() as conn:

        def _check_columns(sync_conn: Connection) -> tuple[Any, Any, Any, Any]:
            inspector = inspect(sync_conn)
            variant_cols = {col["name"]: col for col in inspector.get_columns("product_variants")}
            balance_cols = {col["name"]: col for col in inspector.get_columns("stock_balances")}
            pk_info = inspector.get_pk_constraint("stock_balances")
            sale_uqs = inspector.get_unique_constraints("sales")
            return variant_cols, balance_cols, pk_info, sale_uqs

        variant_cols, balance_cols, pk_info, sale_uqs = await conn.run_sync(_check_columns)

    assert str(variant_cols["selling_price"]["type"]) == "NUMERIC(19, 4)"
    assert str(variant_cols["cost_price"]["type"]) == "NUMERIC(19, 4)"
    assert str(balance_cols["quantity_on_hand"]["type"]) == "NUMERIC(12, 4)"

    # 4. Verify composite primary key on stock_balances
    assert set(pk_info["constrained_columns"]) == {
        "business_id",
        "branch_id",
        "product_variant_id",
    }

    # 5. Verify unique constraints on sales
    sale_uq_cols = [set(u["column_names"]) for u in sale_uqs]
    assert {"business_id", "receipt_no"} in sale_uq_cols
    assert {"business_id", "idempotency_key"} in sale_uq_cols

    # 6. Test downgrade base removes all domain tables
    await asyncio.to_thread(command.downgrade, alembic_cfg, "base")
    async with async_db_engine.connect() as conn:
        post_downgrade_tables = await conn.run_sync(
            lambda sync_conn: set(inspect(sync_conn).get_table_names())
        )
    assert post_downgrade_tables == {"alembic_version"}

    # 7. Re-upgrade to leave database in clean head state
    await asyncio.to_thread(command.upgrade, alembic_cfg, "head")
    async with async_db_engine.connect() as conn:
        final_tables = await conn.run_sync(
            lambda sync_conn: set(inspect(sync_conn).get_table_names())
        )
    assert expected_tables.issubset(final_tables)
