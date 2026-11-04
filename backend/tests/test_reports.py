"""Unit and integration tests for Analytics Dashboard & Financial Reports (Track 6)."""

import uuid
from collections.abc import AsyncGenerator
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session_maker
from app.modules.business.models import Branch, Business
from app.modules.catalog.models import Category, Product, ProductVariant
from app.modules.identity.models import User
from app.modules.inventory.models import StockBalance
from app.modules.sales.models import Customer, PaymentTender, Sale, SaleItem
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
        name=f"Analytics Test Store {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.flush()

    branch = Branch(
        id=uuid.uuid4(),
        business_id=biz.id,
        name="Main Outlet",
        code=f"MN-{uuid.uuid4().hex[:4].upper()}",
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
        display_name="Reports Cashier",
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
async def seeded_catalog_and_sales(
    db_session: AsyncSession, test_business: Business, test_user: User
) -> dict[str, object]:
    """Populates categories, products, stock balances, customers, sales, and tenders."""
    branch = (
        await db_session.execute(
            select(Branch).where(Branch.business_id == test_business.id).limit(1)
        )
    ).scalar_one()

    # 1. Category
    cat = Category(
        id=uuid.uuid4(),
        business_id=test_business.id,
        name="Beverages",
        is_active=True,
    )
    db_session.add(cat)
    await db_session.flush()

    # 2. Product 1 (High margin)
    p1 = Product(
        id=uuid.uuid4(),
        business_id=test_business.id,
        category_id=cat.id,
        sku=f"BEV-{uuid.uuid4().hex[:6].upper()}",
        name="Energy Drink 250ml",
        is_active=True,
    )
    db_session.add(p1)
    await db_session.flush()

    v1 = ProductVariant(
        id=uuid.uuid4(),
        product_id=p1.id,
        business_id=test_business.id,
        name="Can",
        cost_price=Decimal("40.0000"),
        selling_price=Decimal("70.0000"),
        track_stock=True,
        is_active=True,
    )
    db_session.add(v1)
    await db_session.flush()

    # Stock balance: 50 units (Well stocked)
    db_session.add(
        StockBalance(
            business_id=test_business.id,
            branch_id=branch.id,
            product_variant_id=v1.id,
            quantity_on_hand=Decimal("50.0000"),
        )
    )

    # 3. Product 2 (Low stock)
    p2 = Product(
        id=uuid.uuid4(),
        business_id=test_business.id,
        category_id=cat.id,
        sku=f"BEV-{uuid.uuid4().hex[:6].upper()}",
        name="Mineral Water 500ml",
        is_active=True,
    )
    db_session.add(p2)
    await db_session.flush()

    v2 = ProductVariant(
        id=uuid.uuid4(),
        product_id=p2.id,
        business_id=test_business.id,
        name="Bottle",
        cost_price=Decimal("12.0000"),
        selling_price=Decimal("20.0000"),
        track_stock=True,
        is_active=True,
    )
    db_session.add(v2)
    await db_session.flush()

    # Stock balance: 4 units (Low stock threshold is <= 10)
    db_session.add(
        StockBalance(
            business_id=test_business.id,
            branch_id=branch.id,
            product_variant_id=v2.id,
            quantity_on_hand=Decimal("4.0000"),
        )
    )

    # 4. Customer
    cust = Customer(
        id=uuid.uuid4(),
        business_id=test_business.id,
        name="Tanvir Ahmed",
        phone=f"017{uuid.uuid4().hex[:8]}",
        credit_limit=Decimal("5000.0000"),
        is_active=True,
    )
    db_session.add(cust)
    await db_session.flush()

    # 5. Sale 1: Paid with Cash
    sale1_id = uuid.uuid4()
    sale1 = Sale(
        id=sale1_id,
        business_id=test_business.id,
        branch_id=branch.id,
        receipt_no=f"REC-{uuid.uuid4().hex[:6].upper()}",
        cashier_id=test_user.id,
        status="COMPLETED",
        subtotal=Decimal("140.0000"),
        discount_total=Decimal("0.0000"),
        tax_total=Decimal("7.0000"),
        grand_total=Decimal("147.0000"),
        paid_total=Decimal("147.0000"),
        due_total=Decimal("0.0000"),
        idempotency_key=str(uuid.uuid4()),
    )
    db_session.add(sale1)
    db_session.add(
        SaleItem(
            id=uuid.uuid4(),
            sale_id=sale1_id,
            product_variant_id=v1.id,
            quantity=Decimal("2.0000"),
            unit_price=Decimal("70.0000"),
            unit_cost_snapshot=Decimal("40.0000"),
            discount=Decimal("0.0000"),
            line_total=Decimal("140.0000"),
        )
    )
    db_session.add(
        PaymentTender(
            id=uuid.uuid4(),
            business_id=test_business.id,
            sale_id=sale1_id,
            method="CASH",
            amount=Decimal("147.0000"),
            status="CONFIRMED",
        )
    )

    # 6. Sale 2: Split tender with DUE debt for customer
    sale2_id = uuid.uuid4()
    sale2 = Sale(
        id=sale2_id,
        business_id=test_business.id,
        branch_id=branch.id,
        receipt_no=f"REC-{uuid.uuid4().hex[:6].upper()}",
        cashier_id=test_user.id,
        customer_id=cust.id,
        status="COMPLETED",
        subtotal=Decimal("100.0000"),
        discount_total=Decimal("10.0000"),
        tax_total=Decimal("4.5000"),
        grand_total=Decimal("94.5000"),
        paid_total=Decimal("44.5000"),
        due_total=Decimal("50.0000"),
        idempotency_key=str(uuid.uuid4()),
    )
    db_session.add(sale2)
    db_session.add(
        SaleItem(
            id=uuid.uuid4(),
            sale_id=sale2_id,
            product_variant_id=v2.id,
            quantity=Decimal("5.0000"),
            unit_price=Decimal("20.0000"),
            unit_cost_snapshot=Decimal("12.0000"),
            discount=Decimal("10.0000"),
            line_total=Decimal("90.0000"),
        )
    )
    db_session.add(
        PaymentTender(
            id=uuid.uuid4(),
            business_id=test_business.id,
            sale_id=sale2_id,
            method="BKASH",
            amount=Decimal("44.5000"),
            status="CONFIRMED",
        )
    )
    db_session.add(
        PaymentTender(
            id=uuid.uuid4(),
            business_id=test_business.id,
            sale_id=sale2_id,
            method="DUE",
            amount=Decimal("50.0000"),
            status="CONFIRMED",
        )
    )

    await db_session.commit()

    return {
        "branch": branch,
        "variant1": v1,
        "variant2": v2,
        "customer": cust,
        "sale1": sale1,
        "sale2": sale2,
    }


@pytest.mark.asyncio
async def test_dashboard_metrics(
    client: AsyncClient,
    auth_headers: dict[str, str],
    seeded_catalog_and_sales: dict[str, object],
) -> None:
    """Verifies executive KPI calculations including gross sales, COGS profit, tax, and low stock."""
    res = await client.get("/api/v1/reports/dashboard", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()

    # Total Gross: 147.0000 + 94.5000 = 241.5000
    assert Decimal(data["gross_sales"]) == Decimal("241.5000")
    assert Decimal(data["net_sales"]) == Decimal("241.5000")
    assert data["total_orders"] == 2

    # Total Items Sold: 2 + 5 = 7
    assert Decimal(data["total_items_sold"]) == Decimal("7.0000")

    # COGS: (2 * 40.00) + (5 * 12.00) = 80 + 60 = 140.00
    # Gross Profit: 241.50 - 140.00 = 101.50
    assert Decimal(data["gross_profit"]) == Decimal("101.5000")

    # Tender collections: 147.00 (Cash) + 44.50 (bKash) = 191.50
    assert Decimal(data["total_collected"]) == Decimal("191.5000")
    # Due issued: 50.00
    assert Decimal(data["total_due_issued"]) == Decimal("50.0000")

    # Low stock alert: v2 has 4 units (<= 10)
    assert data["low_stock_count"] >= 1


@pytest.mark.asyncio
async def test_sales_time_series(
    client: AsyncClient,
    auth_headers: dict[str, str],
    seeded_catalog_and_sales: dict[str, object],
) -> None:
    """Verifies daily and hourly time-series aggregation."""
    res = await client.get("/api/v1/reports/sales?interval=daily", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["interval"] == "daily"
    assert len(data["points"]) >= 1

    point = data["points"][0]
    assert point["sales_count"] >= 2
    assert Decimal(point["gross_sales"]) >= Decimal("241.5000")


@pytest.mark.asyncio
async def test_stock_valuation_report(
    client: AsyncClient,
    auth_headers: dict[str, str],
    seeded_catalog_and_sales: dict[str, object],
) -> None:
    """Verifies inventory asset capital calculation (cost basis vs retail value)."""
    res = await client.get("/api/v1/reports/stock", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()

    assert data["total_variants_stocked"] >= 2
    # v1 (50 units) + v2 (4 units) = 54 units
    assert Decimal(data["total_units_on_hand"]) == Decimal("54.0000")

    # Cost: (50 * 40) + (4 * 12) = 2000 + 48 = 2048.00
    assert Decimal(data["total_cost_value"]) == Decimal("2048.0000")
    # Retail: (50 * 70) + (4 * 20) = 3500 + 80 = 3580.00
    assert Decimal(data["total_retail_value"]) == Decimal("3580.0000")
    assert Decimal(data["potential_gross_profit"]) == Decimal("1532.0000")

    # Low stock list contains v2
    low_skus = [item["sku"] for item in data["low_stock_items"]]
    assert any("BEV-" in s for s in low_skus)


@pytest.mark.asyncio
async def test_payment_methods_distribution(
    client: AsyncClient,
    auth_headers: dict[str, str],
    seeded_catalog_and_sales: dict[str, object],
) -> None:
    """Verifies payment tender breakdown across CASH, BKASH, and DUE."""
    res = await client.get("/api/v1/reports/payment-methods", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()

    methods_dict = {m["method"]: Decimal(m["total_amount"]) for m in data["methods"]}
    assert methods_dict["CASH"] == Decimal("147.0000")
    assert methods_dict["BKASH"] == Decimal("44.5000")
    assert methods_dict["DUE"] == Decimal("50.0000")


@pytest.mark.asyncio
async def test_top_products_ranking(
    client: AsyncClient,
    auth_headers: dict[str, str],
    seeded_catalog_and_sales: dict[str, object],
) -> None:
    """Verifies top-selling product ranking by gross revenue."""
    res = await client.get("/api/v1/reports/top-products?limit=5", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    items = data["items"]
    assert len(items) >= 2

    # First item should be Energy Drink (140.00 gross) followed by Mineral Water (90.00 gross)
    assert items[0]["product_name"] == "Energy Drink 250ml"
    assert Decimal(items[0]["gross_revenue"]) == Decimal("140.0000")
    assert Decimal(items[0]["cogs"]) == Decimal("80.0000")
    assert Decimal(items[0]["profit"]) == Decimal("60.0000")


@pytest.mark.asyncio
async def test_customer_dues_report(
    client: AsyncClient,
    auth_headers: dict[str, str],
    seeded_catalog_and_sales: dict[str, object],
) -> None:
    """Verifies accounts receivable summary and debtor list."""
    res = await client.get("/api/v1/reports/customer-dues", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()

    assert data["total_customers_with_due"] >= 1
    assert Decimal(data["total_outstanding_due"]) == Decimal("50.0000")
    assert Decimal(data["total_credit_limit"]) >= Decimal("5000.0000")

    debtors = data["top_debtors"]
    assert len(debtors) >= 1
    assert debtors[0]["name"] == "Tanvir Ahmed"
    assert Decimal(debtors[0]["due_balance"]) == Decimal("50.0000")


@pytest.mark.asyncio
async def test_csv_export_endpoint(
    client: AsyncClient,
    auth_headers: dict[str, str],
    seeded_catalog_and_sales: dict[str, object],
) -> None:
    """Verifies CSV generation and streaming for reports."""
    # 1. Summary CSV
    res1 = await client.get("/api/v1/reports/export?report_type=summary", headers=auth_headers)
    assert res1.status_code == 200
    assert "text/csv" in res1.headers["content-type"]
    assert "Gross Sales" in res1.text

    # 2. Top Products CSV
    res2 = await client.get("/api/v1/reports/export?report_type=top_products", headers=auth_headers)
    assert res2.status_code == 200
    assert "Energy Drink 250ml" in res2.text

    # 3. Stock Valuation CSV
    res3 = await client.get("/api/v1/reports/export?report_type=stock_valuation", headers=auth_headers)
    assert res3.status_code == 200
    assert "Bottle" in res3.text


@pytest.mark.asyncio
async def test_reports_tenant_isolation(
    client: AsyncClient,
    db_session: AsyncSession,
    seeded_catalog_and_sales: dict[str, object],
) -> None:
    """Ensures another business tenant cannot view first tenant's analytical or financial reports."""
    biz_b = Business(
        id=uuid.uuid4(),
        name=f"Tenant B Shop {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz_b)
    user_b = User(
        id=uuid.uuid4(),
        username=f"cashier_b_{uuid.uuid4().hex[:8]}",
        password_hash="test_hash_b",
        display_name="Cashier B",
        is_active=True,
    )
    db_session.add(user_b)
    await db_session.commit()

    token_b = create_access_token(
        user_id=user_b.id,
        business_id=biz_b.id,
        username=user_b.username,
        permissions=["*"],
    )
    headers_b = {"Authorization": f"Bearer {token_b}"}

    res = await client.get("/api/v1/reports/dashboard", headers=headers_b)
    assert res.status_code == 200
    data = res.json()
    # Tenant B has no sales, so all metrics must be zero
    assert Decimal(data["gross_sales"]) == Decimal("0.0000")
    assert data["total_orders"] == 0
    assert Decimal(data["total_collected"]) == Decimal("0.0000")

