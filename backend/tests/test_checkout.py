"""Tests for POS Checkout vertical slice (pricing, inventory locks, idempotency, split tenders, concurrency)."""

import asyncio
import uuid
from collections.abc import AsyncGenerator
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session_maker
from app.modules.business.models import Branch, Business
from app.modules.catalog.models import Product, ProductVariant
from app.modules.identity.models import User
from app.modules.inventory.models import StockBalance, StockMovement
from app.modules.sales.models import Customer
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
        name=f"Checkout Test Store {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.flush()

    branch = Branch(
        id=uuid.uuid4(),
        business_id=biz.id,
        name="Main Store",
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
        password_hash="dummy_hash_for_test",
        display_name="Test Cashier",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def test_branch(db_session: AsyncSession, test_business: Business) -> Branch:
    from sqlalchemy import select

    stmt = select(Branch).where(Branch.business_id == test_business.id)
    res = await db_session.execute(stmt)
    return res.scalars().first()  # type: ignore


@pytest.fixture
async def test_product_and_variant(
    db_session: AsyncSession, test_business: Business, test_branch: Branch
) -> tuple[Product, ProductVariant]:
    prod = Product(
        id=uuid.uuid4(),
        business_id=test_business.id,
        sku=f"SKU-{uuid.uuid4().hex[:6].upper()}",
        name="Ergonomic Mouse",
        product_type="STANDARD",
        is_active=True,
    )
    db_session.add(prod)
    await db_session.flush()

    variant = ProductVariant(
        id=uuid.uuid4(),
        product_id=prod.id,
        business_id=test_business.id,
        name="Standard",
        barcode=f"BAR-{uuid.uuid4().hex[:8]}",
        selling_price=Decimal("100.0000"),
        cost_price=Decimal("60.0000"),
        track_stock=True,
        is_active=True,
    )
    db_session.add(variant)
    await db_session.flush()

    # Initial stock: 10 units
    balance = StockBalance(
        business_id=test_business.id,
        branch_id=test_branch.id,
        product_variant_id=variant.id,
        quantity_on_hand=Decimal("10.0000"),
    )
    db_session.add(balance)
    await db_session.commit()
    await db_session.refresh(variant)
    return prod, variant


@pytest.fixture
def auth_headers(test_business: Business, test_user: User) -> dict[str, str]:
    token = create_access_token(
        user_id=test_user.id,
        business_id=test_business.id,
        username=test_user.username,
        permissions=["sales:create", "sales:read"],
    )
    return {"Authorization": f"Bearer {token}"}


# -----------------------------------------------------------------------------
# 1. Permissions & Authentication Enforcement
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_checkout_permissions_enforced(
    client: AsyncClient,
    test_business: Business,
    test_branch: Branch,
    test_product_and_variant: tuple[Product, ProductVariant],
) -> None:
    _, variant = test_product_and_variant
    payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [{"method": "CASH", "amount": "100.0000"}],
    }

    # Unauthenticated
    unauth_res = await client.post("/api/v1/sales/checkout", json=payload)
    assert unauth_res.status_code == 401

    # Authenticated without sales:create permission
    no_perm_token = create_access_token(
        user_id=uuid.uuid4(),
        business_id=test_business.id,
        username="no_perm_user",
        permissions=["catalog:read"],
    )
    forbidden_res = await client.post(
        "/api/v1/sales/checkout",
        json=payload,
        headers={"Authorization": f"Bearer {no_perm_token}"},
    )
    assert forbidden_res.status_code == 403
    assert forbidden_res.json()["error"]["code"] == "PERMISSION_DENIED"


# -----------------------------------------------------------------------------
# 2. Standard Sale & Exact Stock Ledger Deduction
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_checkout_single_tender_success(
    client: AsyncClient,
    db_session: AsyncSession,
    test_business: Business,
    test_branch: Branch,
    test_product_and_variant: tuple[Product, ProductVariant],
    auth_headers: dict[str, str],
) -> None:
    _, variant = test_product_and_variant
    idemp_key = str(uuid.uuid4())

    payload = {
        "idempotency_key": idemp_key,
        "branch_id": str(test_branch.id),
        "items": [
            {
                "product_variant_id": str(variant.id),
                "quantity": "2.0000",
                "unit_price": "100.0000",
                "discount": "10.0000",
            }
        ],
        "cart_discount": "5.0000",
        "tax_rate": "5.0000",  # 5%
        "payments": [{"method": "CASH", "amount": "200.0000"}],
        "notes": "Single tender cash purchase",
    }

    # Calculation:
    # subtotal = 2 * 100 = 200.0000
    # total_discount = 10 (item) + 5 (cart) = 15.0000
    # discounted_subtotal = 185.0000
    # tax = 185 * 0.05 = 9.2500
    # grand_total = 185 + 9.25 = 194.2500
    # paid = 194.2500, change = 200 - 194.25 = 5.7500

    response = await client.post("/api/v1/sales/checkout", json=payload, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()

    assert data["status"] == "COMPLETED"
    assert data["receipt_no"].startswith("REC-")
    assert "-MAIN-" in data["receipt_no"]
    assert Decimal(data["financials"]["subtotal"]) == Decimal("200.0000")
    assert Decimal(data["financials"]["discount_total"]) == Decimal("15.0000")
    assert Decimal(data["financials"]["tax_total"]) == Decimal("9.2500")
    assert Decimal(data["financials"]["grand_total"]) == Decimal("194.2500")
    assert Decimal(data["financials"]["change_amount"]) == Decimal("5.7500")
    assert Decimal(data["financials"]["due_total"]) == Decimal("0.0000")

    # Verify inventory was decremented from 10 to 8
    bal = await db_session.get(
        StockBalance, (test_business.id, test_branch.id, variant.id)
    )
    assert bal is not None
    await db_session.refresh(bal)
    assert bal.quantity_on_hand == Decimal("8.0000")

    # Verify StockMovement ledger
    from sqlalchemy import select

    m_stmt = select(StockMovement).where(
        StockMovement.business_id == test_business.id,
        StockMovement.product_variant_id == variant.id,
    )
    m_res = await db_session.execute(m_stmt)
    movement = m_res.scalars().first()
    assert movement is not None
    assert movement.movement_type == "SALE"
    assert movement.quantity_delta == Decimal("-2.0000")
    assert movement.unit_cost == Decimal("60.0000")


# -----------------------------------------------------------------------------
# 3. Split Tender Payment & Overpayment Validation
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_checkout_split_tender_and_validation(
    client: AsyncClient,
    test_branch: Branch,
    test_product_and_variant: tuple[Product, ProductVariant],
    auth_headers: dict[str, str],
) -> None:
    _, variant = test_product_and_variant

    # Grand total = 100.0000
    # Split: Cash 60.0000, bKash 40.0000
    payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [
            {"method": "CASH", "amount": "60.0000"},
            {"method": "BKASH", "amount": "40.0000", "reference": "TRX123456"},
        ],
    }

    res = await client.post("/api/v1/sales/checkout", json=payload, headers=auth_headers)
    assert res.status_code == 201
    data = res.json()
    assert len(data["payments"]) == 2
    assert Decimal(data["financials"]["paid_total"]) == Decimal("100.0000")
    assert Decimal(data["financials"]["due_total"]) == Decimal("0.0000")

    # Non-cash overpayment should be rejected
    invalid_overpay_payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [{"method": "BKASH", "amount": "150.0000", "reference": "TRX999"}],
    }
    overpay_res = await client.post(
        "/api/v1/sales/checkout", json=invalid_overpay_payload, headers=auth_headers
    )
    assert overpay_res.status_code == 400
    assert overpay_res.json()["error"]["code"] == "EXCESS_NON_CASH_PAYMENT"


# -----------------------------------------------------------------------------
# 4. Idempotency Replay & Payload Mismatch
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_checkout_idempotency_behavior(
    client: AsyncClient,
    db_session: AsyncSession,
    test_business: Business,
    test_branch: Branch,
    test_product_and_variant: tuple[Product, ProductVariant],
    auth_headers: dict[str, str],
) -> None:
    _, variant = test_product_and_variant
    idemp_key = str(uuid.uuid4())

    payload = {
        "idempotency_key": idemp_key,
        "branch_id": str(test_branch.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [{"method": "CASH", "amount": "100.0000"}],
    }

    # First request: 201 Created
    res1 = await client.post("/api/v1/sales/checkout", json=payload, headers=auth_headers)
    assert res1.status_code == 201
    receipt_no = res1.json()["receipt_no"]

    # Check stock after 1st request (was 10, now 9)
    bal1 = await db_session.get(StockBalance, (test_business.id, test_branch.id, variant.id))
    assert bal1 is not None
    await db_session.refresh(bal1)
    assert bal1.quantity_on_hand == Decimal("9.0000")

    # Second request with identical key & payload: 200 OK Replay
    res2 = await client.post("/api/v1/sales/checkout", json=payload, headers=auth_headers)
    assert res2.status_code == 200
    assert res2.headers.get("x-idempotent-replay") == "true"
    assert res2.json()["receipt_no"] == receipt_no

    # Ensure stock was NOT decremented a second time (must still be 9)
    bal2 = await db_session.get(StockBalance, (test_business.id, test_branch.id, variant.id))
    assert bal2 is not None
    await db_session.refresh(bal2)
    assert bal2.quantity_on_hand == Decimal("9.0000")

    # Reusing same key with altered payload -> 422 Payload Mismatch
    tampered_payload = {
        "idempotency_key": idemp_key,
        "branch_id": str(test_branch.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "2.0000"}],
        "payments": [{"method": "CASH", "amount": "200.0000"}],
    }
    mismatch_res = await client.post(
        "/api/v1/sales/checkout", json=tampered_payload, headers=auth_headers
    )
    assert mismatch_res.status_code == 422
    assert mismatch_res.json()["error"]["code"] == "IDEMPOTENCY_PAYLOAD_MISMATCH"


# -----------------------------------------------------------------------------
# 5. Insufficient Stock Failure
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_checkout_insufficient_stock_rejection(
    client: AsyncClient,
    db_session: AsyncSession,
    test_business: Business,
    test_branch: Branch,
    test_product_and_variant: tuple[Product, ProductVariant],
    auth_headers: dict[str, str],
) -> None:
    _, variant = test_product_and_variant

    # Request 50 units when only 10 available
    payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "50.0000"}],
        "payments": [{"method": "CASH", "amount": "5000.0000"}],
    }

    res = await client.post("/api/v1/sales/checkout", json=payload, headers=auth_headers)
    assert res.status_code == 409
    err = res.json()["error"]
    assert err["code"] == "INSUFFICIENT_STOCK"


# -----------------------------------------------------------------------------
# 6. Partial Payment & Customer Credit Limit Enforcement
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_checkout_partial_payment_and_credit_limit(
    client: AsyncClient,
    db_session: AsyncSession,
    test_business: Business,
    test_branch: Branch,
    test_product_and_variant: tuple[Product, ProductVariant],
    auth_headers: dict[str, str],
) -> None:
    _, variant = test_product_and_variant

    # Partial payment without customer -> 400 Bad Request
    walkin_due_payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "customer_id": None,
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [{"method": "CASH", "amount": "40.0000"}],  # 60 due
    }
    walkin_res = await client.post(
        "/api/v1/sales/checkout", json=walkin_due_payload, headers=auth_headers
    )
    assert walkin_res.status_code == 400
    assert walkin_res.json()["error"]["code"] == "CUSTOMER_REQUIRED_FOR_DUE"

    # Create customer with credit limit of 50.0000
    cust = Customer(
        id=uuid.uuid4(),
        business_id=test_business.id,
        name="Credit Test Customer",
        phone=f"01700{uuid.uuid4().hex[:6]}",
        credit_limit=Decimal("50.0000"),
    )
    db_session.add(cust)
    await db_session.commit()

    # Attempt due of 60.0000 (exceeds credit limit of 50.0000) -> 409 Conflict
    cust_over_due_payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "customer_id": str(cust.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [{"method": "CASH", "amount": "40.0000"}],
    }
    over_res = await client.post(
        "/api/v1/sales/checkout", json=cust_over_due_payload, headers=auth_headers
    )
    assert over_res.status_code == 409
    assert over_res.json()["error"]["code"] == "CREDIT_LIMIT_EXCEEDED"

    # Due within credit limit (e.g. 70 paid, 30 due <= 50 limit) -> 201 Created
    cust_valid_due_payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "customer_id": str(cust.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [{"method": "CASH", "amount": "70.0000"}],
    }
    valid_res = await client.post(
        "/api/v1/sales/checkout", json=cust_valid_due_payload, headers=auth_headers
    )
    assert valid_res.status_code == 201
    assert Decimal(valid_res.json()["financials"]["due_total"]) == Decimal("30.0000")


# -----------------------------------------------------------------------------
# 7. Concurrent Checkout Concurrency & Race Condition
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_checkout_concurrent_race_condition(
    client: AsyncClient,
    db_session: AsyncSession,
    test_business: Business,
    test_branch: Branch,
    test_product_and_variant: tuple[Product, ProductVariant],
    auth_headers: dict[str, str],
) -> None:
    """Simulates 2 cashiers attempting to buy the last 1 item concurrently."""
    _, variant = test_product_and_variant

    # Set exact stock to 1 unit
    bal = await db_session.get(StockBalance, (test_business.id, test_branch.id, variant.id))
    assert bal is not None
    bal.quantity_on_hand = Decimal("1.0000")
    await db_session.commit()

    payload_a = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [{"method": "CASH", "amount": "100.0000"}],
    }
    payload_b = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
        "payments": [{"method": "CASH", "amount": "100.0000"}],
    }

    # Run both checkouts concurrently
    res_a, res_b = await asyncio.gather(
        client.post("/api/v1/sales/checkout", json=payload_a, headers=auth_headers),
        client.post("/api/v1/sales/checkout", json=payload_b, headers=auth_headers),
    )

    statuses = [res_a.status_code, res_b.status_code]
    # Exactly one must succeed (201) and exactly one must fail (409)
    assert 201 in statuses, f"Expected one 201, got {statuses}"
    assert 409 in statuses, f"Expected one 409, got {statuses}"

    # Verify final stock is exactly 0.0000 (never negative)
    await db_session.refresh(bal)
    assert bal.quantity_on_hand == Decimal("0.0000")
