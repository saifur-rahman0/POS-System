"""Comprehensive tests for Customer CRM, Credit Limits, Due Checkouts, and Debt Collection."""

import uuid
from collections.abc import AsyncGenerator
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session_maker
from app.modules.business.models import Branch, Business
from app.modules.catalog.models import Product, ProductVariant
from app.modules.expenses.models import CashTransaction
from app.modules.identity.models import User
from app.modules.inventory.models import StockBalance
from app.shared.auth import create_access_token


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    session_factory = get_session_maker()
    async with session_factory() as session:
        yield session


@pytest.fixture
async def test_biz(db_session: AsyncSession) -> Business:
    biz = Business(
        id=uuid.uuid4(),
        name=f"Customer Test Store {uuid.uuid4().hex[:6]}",
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
async def test_biz_b(db_session: AsyncSession) -> Business:
    biz = Business(
        id=uuid.uuid4(),
        name=f"Customer Store B {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.commit()
    await db_session.refresh(biz)
    return biz


@pytest.fixture
async def test_cashier(db_session: AsyncSession) -> User:
    user = User(
        id=uuid.uuid4(),
        username=f"cashier_{uuid.uuid4().hex[:8]}",
        password_hash="test_pw_hash",
        display_name="Main Cashier",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def test_branch(db_session: AsyncSession, test_biz: Business) -> Branch:
    stmt = select(Branch).where(Branch.business_id == test_biz.id)
    res = await db_session.execute(stmt)
    return res.scalars().first()  # type: ignore


@pytest.fixture
async def test_product(
    db_session: AsyncSession, test_biz: Business, test_branch: Branch
) -> tuple[Product, ProductVariant]:
    prod = Product(
        id=uuid.uuid4(),
        business_id=test_biz.id,
        sku=f"CUST-PROD-{uuid.uuid4().hex[:6].upper()}",
        name="Basmati Rice 5kg",
        product_type="STANDARD",
        is_active=True,
    )
    db_session.add(prod)
    await db_session.flush()

    variant = ProductVariant(
        id=uuid.uuid4(),
        product_id=prod.id,
        business_id=test_biz.id,
        name="5kg Sack",
        barcode=f"CUST-BAR-{uuid.uuid4().hex[:8]}",
        selling_price=Decimal("450.0000"),
        cost_price=Decimal("380.0000"),
        track_stock=True,
        is_active=True,
    )
    db_session.add(variant)
    await db_session.flush()

    # Initial stock: 100 sacks
    balance = StockBalance(
        business_id=test_biz.id,
        branch_id=test_branch.id,
        product_variant_id=variant.id,
        quantity_on_hand=Decimal("100.0000"),
    )
    db_session.add(balance)
    await db_session.commit()
    await db_session.refresh(variant)
    return prod, variant


def make_auth(biz_id: uuid.UUID, user_id: uuid.UUID) -> dict[str, str]:
    token = create_access_token(
        user_id=user_id,
        business_id=biz_id,
        username="test_user",
        permissions=["sales:read", "sales:create", "sales:write"],
    )
    return {"Authorization": f"Bearer {token}"}


# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_customer_crud_and_uniqueness(
    client: AsyncClient,
    test_biz: Business,
    test_cashier: User,
) -> None:
    """Verifies creating, getting, updating, and phone uniqueness constraint for customers."""
    headers = make_auth(test_biz.id, test_cashier.id)
    unique_phone = f"01711{uuid.uuid4().hex[:6]}"

    # 1. Create customer
    create_payload = {
        "name": "Hasan Mahmud",
        "phone": unique_phone,
        "email": "hasan@example.com",
        "address": "Dhanmondi, Dhaka",
        "credit_limit": "2000.0000",
    }
    res = await client.post("/api/v1/customers", json=create_payload, headers=headers)
    assert res.status_code == 201
    cust_data = res.json()
    cust_id = cust_data["id"]
    assert cust_data["name"] == "Hasan Mahmud"
    assert cust_data["phone"] == unique_phone
    assert Decimal(str(cust_data["credit_limit"])) == Decimal("2000.0000")
    assert Decimal(str(cust_data["due_balance"])) == Decimal("0.0000")
    assert Decimal(str(cust_data["available_credit"])) == Decimal("2000.0000")

    # 2. Duplicate phone is rejected with 409
    dup_res = await client.post(
        "/api/v1/customers",
        json={"name": "Hasan Clone", "phone": unique_phone},
        headers=headers,
    )
    assert dup_res.status_code == 409
    assert dup_res.json()["error"]["code"] == "PHONE_ALREADY_EXISTS"

    # 3. Get customer
    get_res = await client.get(f"/api/v1/customers/{cust_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["name"] == "Hasan Mahmud"

    # 4. Update customer
    update_res = await client.put(
        f"/api/v1/customers/{cust_id}",
        json={"address": "Gulshan 1, Dhaka", "credit_limit": "3000.0000"},
        headers=headers,
    )
    assert update_res.status_code == 200
    assert update_res.json()["address"] == "Gulshan 1, Dhaka"
    assert Decimal(str(update_res.json()["credit_limit"])) == Decimal("3000.0000")


@pytest.mark.asyncio
async def test_customer_list_and_search(
    client: AsyncClient,
    test_biz: Business,
    test_cashier: User,
) -> None:
    """Verifies listing customers with search by name and phone."""
    headers = make_auth(test_biz.id, test_cashier.id)
    search_token = uuid.uuid4().hex[:6]
    name = f"Farhan {search_token}"
    phone = f"01811{search_token}"

    res = await client.post(
        "/api/v1/customers",
        json={"name": name, "phone": phone, "credit_limit": "1000.0000"},
        headers=headers,
    )
    assert res.status_code == 201

    # Search by name
    list_name = await client.get(f"/api/v1/customers?search={name}", headers=headers)
    assert list_name.status_code == 200
    data_name = list_name.json()
    assert data_name["total"] >= 1
    assert any(c["name"] == name for c in data_name["items"])

    # Search by phone
    list_phone = await client.get(f"/api/v1/customers?search={phone}", headers=headers)
    assert list_phone.status_code == 200
    data_phone = list_phone.json()
    assert data_phone["total"] >= 1
    assert any(c["phone"] == phone for c in data_phone["items"])


@pytest.mark.asyncio
async def test_customer_due_checkout_and_credit_limit(
    client: AsyncClient,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Verifies checkout with DUE tender increments customer balance and enforces credit limit."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # 1. Create customer with credit_limit = 1000
    cust_res = await client.post(
        "/api/v1/customers",
        json={
            "name": f"Debtor Customer {uuid.uuid4().hex[:6]}",
            "phone": f"01911{uuid.uuid4().hex[:6]}",
            "credit_limit": "1000.0000",
        },
        headers=headers,
    )
    cust_id = cust_res.json()["id"]

    # 2. Checkout 1 unit (৳450) with ৳150 Cash + ৳300 Due
    chk_payload = {
        "idempotency_key": f"chk-due-test-{uuid.uuid4()}",
        "branch_id": str(test_branch.id),
        "customer_id": cust_id,
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [
            {"method": "CASH", "amount": "150.00"},
            {"method": "DUE", "amount": "300.00"},
        ],
    }
    chk_res = await client.post("/api/v1/sales/checkout", json=chk_payload, headers=headers)
    assert chk_res.status_code == 201
    sale_data = chk_res.json()
    assert Decimal(str(sale_data["financials"]["due_total"])) == Decimal("300.0000")

    # 3. Verify customer due_balance is now 300 and available_credit is 700
    c_check = await client.get(f"/api/v1/customers/{cust_id}", headers=headers)
    assert c_check.status_code == 200
    assert Decimal(str(c_check.json()["due_balance"])) == Decimal("300.0000")
    assert Decimal(str(c_check.json()["available_credit"])) == Decimal("700.0000")

    # 4. Attempt second checkout with ৳800 Due (300 + 800 = 1100 > 1000 credit limit) -> Rejected
    over_payload = {
        "idempotency_key": f"chk-over-credit-{uuid.uuid4()}",
        "branch_id": str(test_branch.id),
        "customer_id": cust_id,
        "items": [{"product_variant_id": str(variant.id), "quantity": "2.0000"}],  # ৳900 total
        "payments": [
            {"method": "CASH", "amount": "100.00"},
            {"method": "DUE", "amount": "800.00"},
        ],
    }
    over_res = await client.post("/api/v1/sales/checkout", json=over_payload, headers=headers)
    assert over_res.status_code == 409
    assert over_res.json()["error"]["code"] == "CREDIT_LIMIT_EXCEEDED"


@pytest.mark.asyncio
async def test_customer_due_repayment_collection(
    client: AsyncClient,
    db_session: AsyncSession,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Verifies collecting repayment against customer due reduces balance and adds CashTransaction."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # 1. Create customer with credit_limit = 2000
    cust_res = await client.post(
        "/api/v1/customers",
        json={
            "name": f"Repaying Customer {uuid.uuid4().hex[:6]}",
            "phone": f"01611{uuid.uuid4().hex[:6]}",
            "credit_limit": "2000.0000",
        },
        headers=headers,
    )
    cust_id = cust_res.json()["id"]

    # 2. Buy 2 sacks (৳900) entirely on DUE
    chk_res = await client.post(
        "/api/v1/sales/checkout",
        json={
            "idempotency_key": f"chk-repay-test-{uuid.uuid4()}",
            "branch_id": str(test_branch.id),
            "customer_id": cust_id,
            "items": [{"product_variant_id": str(variant.id), "quantity": "2.0000"}],
            "payments": [{"method": "DUE", "amount": "900.00"}],
        },
        headers=headers,
    )
    assert chk_res.status_code == 201
    sale_id = chk_res.json()["id"]

    # 3. Customer pays ৳500 cash to reduce due
    pay_res = await client.post(
        f"/api/v1/customers/{cust_id}/payments",
        json={
            "amount": "500.0000",
            "payment_method": "CASH",
            "notes": "Paid at counter",
        },
        headers=headers,
    )
    assert pay_res.status_code == 201
    pay_data = pay_res.json()
    assert Decimal(str(pay_data["amount_paid"])) == Decimal("500.0000")
    assert Decimal(str(pay_data["remaining_due"])) == Decimal("400.0000")
    assert len(pay_data["allocated_sales"]) == 1
    assert Decimal(str(pay_data["allocated_sales"][0]["allocated_amount"])) == Decimal("500.0000")
    assert Decimal(str(pay_data["allocated_sales"][0]["remaining_sale_due"])) == Decimal("400.0000")

    # 4. Verify sale receipt itself reflects paid_total: 500, due_total: 400
    sale_check = await client.get(f"/api/v1/sales/{sale_id}", headers=headers)
    assert sale_check.status_code == 200
    assert Decimal(str(sale_check.json()["financials"]["paid_total"])) == Decimal("500.0000")
    assert Decimal(str(sale_check.json()["financials"]["due_total"])) == Decimal("400.0000")

    # 5. Verify CashTransaction was added to drawer ledger
    cash_stmt = (
        select(CashTransaction)
        .where(
            CashTransaction.business_id == test_biz.id,
            CashTransaction.reference_id == uuid.UUID(sale_id),
            CashTransaction.direction == "IN",
        )
        .order_by(CashTransaction.created_at.desc())
    )
    c_res = await db_session.execute(cash_stmt)
    cash_tx = c_res.scalars().first()
    assert cash_tx is not None
    assert Decimal(str(cash_tx.amount)) == Decimal("500.0000")

    # 6. Verify Customer Ledger
    ledger_res = await client.get(f"/api/v1/customers/{cust_id}/ledger", headers=headers)
    assert ledger_res.status_code == 200
    entries = ledger_res.json()
    assert len(entries) >= 2
    # Last entry balance should be 400
    assert Decimal(str(entries[-1]["balance"])) == Decimal("400.0000")


@pytest.mark.asyncio
async def test_tenant_isolation_on_customers(
    client: AsyncClient,
    test_biz: Business,
    test_biz_b: Business,
    test_cashier: User,
) -> None:
    """Store B cannot read, edit, or collect dues on Store A's customers."""
    headers_a = make_auth(test_biz.id, test_cashier.id)
    headers_b = make_auth(test_biz_b.id, test_cashier.id)

    # Store A customer
    res_a = await client.post(
        "/api/v1/customers",
        json={"name": "Exclusive Customer A", "phone": f"01511{uuid.uuid4().hex[:6]}"},
        headers=headers_a,
    )
    cust_id = res_a.json()["id"]

    # Store B attempts to fetch -> 404
    b_get = await client.get(f"/api/v1/customers/{cust_id}", headers=headers_b)
    assert b_get.status_code == 404

    # Store B attempts to collect payment -> 404
    b_pay = await client.post(
        f"/api/v1/customers/{cust_id}/payments",
        json={"amount": "100.00", "payment_method": "CASH"},
        headers=headers_b,
    )
    assert b_pay.status_code == 404
