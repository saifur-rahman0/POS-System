"""Unit and integration tests for Register Shifts, Cash Drawer Control, and Z-Reports."""

import uuid
from collections.abc import AsyncGenerator
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session_maker
from app.modules.business.models import Branch, Business
from app.modules.identity.models import User
from app.shared.auth import create_access_token


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    session_factory = get_session_maker()
    async with session_factory() as session:
        yield session


@pytest.fixture
async def test_business(db_session: AsyncSession) -> Business:
    biz = Business(
        id=uuid.uuid4(),
        name=f"Shift Test Store {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.flush()

    branch = Branch(
        id=uuid.uuid4(),
        business_id=biz.id,
        name="Main Outlet",
        code="MAIN",
        is_active=True,
    )
    db_session.add(branch)
    await db_session.commit()
    await db_session.refresh(biz)
    return biz


@pytest.fixture
async def test_user(db_session: AsyncSession) -> User:
    user = User(
        id=uuid.uuid4(),
        username=f"cashier_{uuid.uuid4().hex[:8]}",
        password_hash="test_hash_cashier",
        display_name="Shift Cashier",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def auth_headers(test_business: Business, test_user: User) -> dict[str, str]:
    token = create_access_token(
        user_id=test_user.id,
        business_id=test_business.id,
        username=test_user.username,
        permissions=["*"],
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
async def test_business_b(db_session: AsyncSession) -> Business:
    biz = Business(
        id=uuid.uuid4(),
        name=f"Shift Tenant B Store {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.flush()

    branch = Branch(
        id=uuid.uuid4(),
        business_id=biz.id,
        name="Branch B",
        code="BR-B",
        is_active=True,
    )
    db_session.add(branch)
    await db_session.commit()
    await db_session.refresh(biz)
    return biz


@pytest.fixture
async def test_user_b(db_session: AsyncSession) -> User:
    user = User(
        id=uuid.uuid4(),
        username=f"cashier_b_{uuid.uuid4().hex[:8]}",
        password_hash="test_hash_cashier_b",
        display_name="Cashier Tenant B",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def auth_headers_tenant_b(test_business_b: Business, test_user_b: User) -> dict[str, str]:
    token = create_access_token(
        user_id=test_user_b.id,
        business_id=test_business_b.id,
        username=test_user_b.username,
        permissions=["*"],
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_shift_open_and_prevent_duplicate_open(
    client: AsyncClient,
    auth_headers: dict[str, str],
    db_session: AsyncSession,
) -> None:
    """Test opening a shift with float, and verify duplicate active open shift is prevented."""
    open_payload = {
        "opening_cash": "1500.0000",
        "notes": "Morning cashier shift starting float",
    }
    resp = await client.post("/api/v1/shifts/open", json=open_payload, headers=auth_headers)
    assert resp.status_code == 201, resp.text
    data = resp.json()

    shift_id = data["id"]
    assert data["status"] == "OPEN"
    assert Decimal(str(data["opening_cash"])) == Decimal("1500.0000")
    assert data["opening_notes"] == "Morning cashier shift starting float"

    # Verify live totals
    assert data["totals"] is not None
    assert Decimal(str(data["totals"]["expected_cash"])) == Decimal("1500.0000")

    # Verify CashTransaction for opening float exists
    tx_res = await client.get("/api/v1/shifts/current", headers=auth_headers)
    assert tx_res.status_code == 200
    current_data = tx_res.json()
    assert current_data["id"] == shift_id
    assert current_data["status"] == "OPEN"

    # Attempt to open another shift while one is active -> 409 Conflict
    dup_resp = await client.post("/api/v1/shifts/open", json=open_payload, headers=auth_headers)
    assert dup_resp.status_code == 409
    assert dup_resp.json()["error"]["code"] == "SHIFT_ALREADY_OPEN"

    # Clean up / Close shift
    close_resp = await client.post(
        f"/api/v1/shifts/{shift_id}/close",
        json={"closing_cash_counted": "1500.0000", "notes": "Shift closed cleanly"},
        headers=auth_headers,
    )
    assert close_resp.status_code == 200
    assert close_resp.json()["status"] == "CLOSED"


@pytest.mark.asyncio
async def test_shift_cash_in_and_cash_out(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    """Test manual cash deposits (Cash In) and withdrawals (Cash Out) with bounds checking."""
    # 1. Open shift with 1000 float
    open_resp = await client.post(
        "/api/v1/shifts/open",
        json={"opening_cash": "1000.0000", "notes": "Cash in/out test shift"},
        headers=auth_headers,
    )
    assert open_resp.status_code == 201
    shift_id = open_resp.json()["id"]

    # 2. Record Cash In of 500
    in_resp = await client.post(
        f"/api/v1/shifts/{shift_id}/cash-in",
        json={"amount": "500.0000", "reason": "Mid-day float topup", "notes": "Added from main safe"},
        headers=auth_headers,
    )
    assert in_resp.status_code == 201
    in_data = in_resp.json()
    assert in_data["direction"] == "IN"
    assert Decimal(str(in_data["amount"])) == Decimal("500.0000")

    # Check live drawer balance: 1000 + 500 = 1500
    cur_res = await client.get("/api/v1/shifts/current", headers=auth_headers)
    assert cur_res.status_code == 200
    assert Decimal(str(cur_res.json()["totals"]["cash_in"])) == Decimal("500.0000")
    assert Decimal(str(cur_res.json()["totals"]["expected_cash"])) == Decimal("1500.0000")

    # 3. Record Cash Out of 300
    out_resp = await client.post(
        f"/api/v1/shifts/{shift_id}/cash-out",
        json={"amount": "300.0000", "reason": "Shop refreshments & stationery"},
        headers=auth_headers,
    )
    assert out_resp.status_code == 201
    out_data = out_resp.json()
    assert out_data["direction"] == "OUT"
    assert Decimal(str(out_data["amount"])) == Decimal("300.0000")

    # Check live drawer balance: 1500 - 300 = 1200
    cur_res2 = await client.get("/api/v1/shifts/current", headers=auth_headers)
    assert Decimal(str(cur_res2.json()["totals"]["cash_out"])) == Decimal("300.0000")
    assert Decimal(str(cur_res2.json()["totals"]["expected_cash"])) == Decimal("1200.0000")

    # 4. Attempt to withdraw 5000 (exceeds 1200 expected cash) -> 409 Conflict
    excess_resp = await client.post(
        f"/api/v1/shifts/{shift_id}/cash-out",
        json={"amount": "5000.0000", "reason": "Excessive drop"},
        headers=auth_headers,
    )
    assert excess_resp.status_code == 409
    assert excess_resp.json()["error"]["code"] == "INSUFFICIENT_DRAWER_CASH"

    # Close shift
    await client.post(
        f"/api/v1/shifts/{shift_id}/close",
        json={"closing_cash_counted": "1200.0000"},
        headers=auth_headers,
    )


@pytest.mark.asyncio
async def test_shift_reconciliation_and_close_with_variance(
    client: AsyncClient,
    auth_headers: dict[str, str],
    db_session: AsyncSession,
) -> None:
    """Test shift reconciliation with sales, computing overage/shortage variance."""
    # 1. Create a product variant with stock
    prod_payload = {
        "sku": f"SH-VAR-{uuid.uuid4().hex[:6].upper()}",
        "name": "Shift Test Item",
        "selling_price": "250.0000",
        "cost_price": "150.0000",
        "track_stock": True,
    }
    p_res = await client.post("/api/v1/products", json=prod_payload, headers=auth_headers)
    assert p_res.status_code == 201
    variant_id = p_res.json()["primary_variant"]["id"]

    # Adjust stock to 20
    await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "product_variant_id": variant_id,
            "adjustment_type": "ADJUSTMENT_UP",
            "quantity": "20.0000",
            "reason": "STOCKTAKE_CORRECTION",
        },
        headers=auth_headers,
    )

    # 2. Open shift with float 800
    open_res = await client.post(
        "/api/v1/shifts/open",
        json={"opening_cash": "800.0000", "notes": "Shift with sales"},
        headers=auth_headers,
    )
    assert open_res.status_code == 201
    shift_id = open_res.json()["id"]

    # 3. Checkout a sale: 2 units * 250 = 500 (Paid in cash)
    sale_payload = {
        "idempotency_key": f"shift-sale-{uuid.uuid4()}",
        "items": [
            {
                "product_variant_id": variant_id,
                "quantity": "2.0000",
                "discount": "0.0000",
            }
        ],
        "discount_total": "0.0000",
        "payments": [
            {
                "method": "CASH",
                "amount": "500.0000",
            }
        ],
    }
    sale_res = await client.post("/api/v1/sales/checkout", json=sale_payload, headers=auth_headers)
    assert sale_res.status_code == 201

    # Live check: Expected cash = 800 float + 500 cash sale = 1300
    cur_res = await client.get("/api/v1/shifts/current", headers=auth_headers)
    assert cur_res.status_code == 200
    totals = cur_res.json()["totals"]
    assert Decimal(str(totals["cash_sales"])) == Decimal("500.0000")
    assert Decimal(str(totals["expected_cash"])) == Decimal("1300.0000")

    # 4. Close shift with physical count of 1250 (Shortage of 50)
    close_payload = {
        "closing_cash_counted": "1250.0000",
        "notes": "Shortage of 50 Taka reported at register close",
        "denominations": {"1000": 1, "200": 1, "50": 1},
    }
    close_res = await client.post(f"/api/v1/shifts/{shift_id}/close", json=close_payload, headers=auth_headers)
    assert close_res.status_code == 200
    c_data = close_res.json()
    assert c_data["status"] == "CLOSED"
    assert Decimal(str(c_data["closing_cash_expected"])) == Decimal("1300.0000")
    assert Decimal(str(c_data["closing_cash_counted"])) == Decimal("1250.0000")
    assert Decimal(str(c_data["cash_difference"])) == Decimal("-50.0000")


@pytest.mark.asyncio
async def test_z_report_generation_and_tenders_breakdown(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    """Test generating a comprehensive daily Z-Report with tender breakdown and sales summary."""
    # 1. Open shift
    open_res = await client.post(
        "/api/v1/shifts/open",
        json={"opening_cash": "2000.0000"},
        headers=auth_headers,
    )
    assert open_res.status_code == 201
    shift_id = open_res.json()["id"]

    # 2. Close shift
    await client.post(
        f"/api/v1/shifts/{shift_id}/close",
        json={"closing_cash_counted": "2000.0000"},
        headers=auth_headers,
    )

    # 3. Request Z-Report
    z_res = await client.get(f"/api/v1/shifts/{shift_id}/z-report", headers=auth_headers)
    assert z_res.status_code == 200
    z_data = z_res.json()

    assert z_data["shift_id"] == shift_id
    assert z_data["status"] == "CLOSED"
    assert "cash_reconciliation" in z_data
    recon = z_data["cash_reconciliation"]
    assert Decimal(str(recon["opening_float"])) == Decimal("2000.0000")
    assert Decimal(str(recon["expected_in_drawer"])) == Decimal("2000.0000")
    assert Decimal(str(recon["actual_counted"])) == Decimal("2000.0000")
    assert recon["variance_status"] == "BALANCED"

    assert "tenders_breakdown" in z_data
    methods = [t["method"] for t in z_data["tenders_breakdown"]]
    assert "CASH" in methods
    assert "CARD" in methods
    assert "BKASH" in methods

    assert "sales_summary" in z_data
    summary = z_data["sales_summary"]
    assert "gross_sales" in summary
    assert "net_sales" in summary
    assert "completed_sales" in summary


@pytest.mark.asyncio
async def test_tenant_isolation_on_shifts(
    client: AsyncClient,
    auth_headers: dict[str, str],
    auth_headers_tenant_b: dict[str, str],
) -> None:
    """Ensure shifts and cash transactions are strictly isolated across tenants."""
    # Tenant A opens a shift
    a_res = await client.post(
        "/api/v1/shifts/open",
        json={"opening_cash": "500.0000"},
        headers=auth_headers,
    )
    assert a_res.status_code == 201
    shift_a_id = a_res.json()["id"]

    # Tenant B tries to view Tenant A's shift Z-report -> 404
    b_z_res = await client.get(f"/api/v1/shifts/{shift_a_id}/z-report", headers=auth_headers_tenant_b)
    assert b_z_res.status_code == 404

    # Tenant B tries to cash-in to Tenant A's shift -> 404
    b_in_res = await client.post(
        f"/api/v1/shifts/{shift_a_id}/cash-in",
        json={"amount": "100.0000", "reason": "Unauthorized"},
        headers=auth_headers_tenant_b,
    )
    assert b_in_res.status_code == 404

    # Tenant B can independently open their own shift
    b_open = await client.post(
        "/api/v1/shifts/open",
        json={"opening_cash": "700.0000"},
        headers=auth_headers_tenant_b,
    )
    assert b_open.status_code == 201
    shift_b_id = b_open.json()["id"]
    assert shift_b_id != shift_a_id

    # Clean up both shifts
    await client.post(f"/api/v1/shifts/{shift_a_id}/close", json={"closing_cash_counted": "500.0000"}, headers=auth_headers)
    await client.post(f"/api/v1/shifts/{shift_b_id}/close", json={"closing_cash_counted": "700.0000"}, headers=auth_headers_tenant_b)
