"""Comprehensive tests for Sales History, Order Details, Customer Returns, and Sale Voids."""

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
from app.modules.identity.models import User
from app.modules.inventory.models import StockBalance, StockMovement
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
        name=f"Returns Store {uuid.uuid4().hex[:6]}",
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
        name=f"Store B {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.flush()

    branch = Branch(
        id=uuid.uuid4(),
        business_id=biz.id,
        name="Branch B",
        code="BRB",
        is_active=True,
    )
    db_session.add(branch)
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
        sku=f"RET-SKU-{uuid.uuid4().hex[:6].upper()}",
        name="Wireless Keyboard",
        product_type="STANDARD",
        is_active=True,
    )
    db_session.add(prod)
    await db_session.flush()

    variant = ProductVariant(
        id=uuid.uuid4(),
        product_id=prod.id,
        business_id=test_biz.id,
        name="Standard",
        barcode=f"RET-BAR-{uuid.uuid4().hex[:8]}",
        selling_price=Decimal("150.0000"),
        cost_price=Decimal("90.0000"),
        track_stock=True,
        is_active=True,
    )
    db_session.add(variant)
    await db_session.flush()

    # Initial stock: 20 units
    balance = StockBalance(
        business_id=test_biz.id,
        branch_id=test_branch.id,
        product_variant_id=variant.id,
        quantity_on_hand=Decimal("20.0000"),
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
async def test_sales_list_and_filters(
    client: AsyncClient,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Verifies listing sales with pagination, search, and status filters."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # 1. Create two sales
    for i in range(2):
        payload = {
            "idempotency_key": f"sale-list-{i}-{uuid.uuid4()}",
            "branch_id": str(test_branch.id),
            "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
            "payments": [{"method": "CASH", "amount": "150.00"}],
        }
        res = await client.post("/api/v1/sales/checkout", json=payload, headers=headers)
        assert res.status_code == 201

    # 2. Query sales list
    list_res = await client.get("/api/v1/sales?page=1&page_size=10", headers=headers)
    assert list_res.status_code == 200
    data = list_res.json()
    assert data["total"] >= 2
    assert len(data["items"]) >= 2
    assert "receipt_no" in data["items"][0]
    assert data["items"][0]["status"] == "COMPLETED"

    # 3. Test search by receipt number
    target_receipt = data["items"][0]["receipt_no"]
    search_res = await client.get(f"/api/v1/sales?search={target_receipt}", headers=headers)
    assert search_res.status_code == 200
    s_data = search_res.json()
    assert s_data["total"] == 1
    assert s_data["items"][0]["receipt_no"] == target_receipt


@pytest.mark.asyncio
async def test_sale_return_partial_and_stock_restoration(
    client: AsyncClient,
    db_session: AsyncSession,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Tests returning part of a sale, verifying stock replenishment and SALE_RETURN movement."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # 1. Buy 5 units (stock goes from 20 to 15)
    checkout_payload = {
        "idempotency_key": f"chk-return-test-{uuid.uuid4()}",
        "branch_id": str(test_branch.id),
        "items": [{"product_variant_id": str(variant.id), "quantity": "5.0000"}],
        "payments": [{"method": "CASH", "amount": "750.00"}],
    }
    chk_res = await client.post("/api/v1/sales/checkout", json=checkout_payload, headers=headers)
    assert chk_res.status_code == 201
    sale_data = chk_res.json()
    sale_id = sale_data["id"]
    sale_item_id = sale_data["items"][0]["id"]

    # Verify stock dropped to 15
    bal_stmt = select(StockBalance).where(
        StockBalance.business_id == test_biz.id,
        StockBalance.branch_id == test_branch.id,
        StockBalance.product_variant_id == variant.id,
    )
    b_res = await db_session.execute(bal_stmt)
    bal = b_res.scalars().first()
    assert bal is not None
    assert Decimal(str(bal.quantity_on_hand)) == Decimal("15.0000")

    # 2. Return 2 units with restock=True
    return_payload = {
        "items": [
            {
                "original_sale_item_id": sale_item_id,
                "quantity": "2.0000",
                "restock": True,
                "restock_status": "RESTOCKED",
            }
        ],
        "reason": "Customer ordered wrong variant",
        "refund_method": "CASH",
    }
    ret_res = await client.post(
        f"/api/v1/sales/{sale_id}/returns", json=return_payload, headers=headers
    )
    assert ret_res.status_code == 201
    ret_data = ret_res.json()
    assert ret_data["status"] == "COMPLETED"
    assert Decimal(str(ret_data["refund_total"])) == Decimal("300.0000")
    assert ret_data["return_no"].startswith("RET-")

    # 3. Check physical stock restored to 17 (15 + 2)
    await db_session.refresh(bal)
    assert Decimal(str(bal.quantity_on_hand)) == Decimal("17.0000")

    # 4. Check StockMovement ledger entry
    mov_stmt = (
        select(StockMovement)
        .where(
            StockMovement.reference_id == uuid.UUID(ret_data["id"]),
            StockMovement.movement_type == "SALE_RETURN",
        )
        .order_by(StockMovement.created_at.desc())
    )
    m_res = await db_session.execute(mov_stmt)
    movement = m_res.scalars().first()
    assert movement is not None
    assert Decimal(str(movement.quantity_delta)) == Decimal("2.0000")
    assert Decimal(str(movement.unit_cost)) == Decimal("90.0000")

    # 5. Check Sale status transitioned to PARTIALLY_REFUNDED
    sale_check = await client.get(f"/api/v1/sales/{sale_id}", headers=headers)
    assert sale_check.status_code == 200
    assert sale_check.json()["status"] == "PARTIALLY_REFUNDED"

    # 6. Check returnable-items endpoint reflects remaining returnable quantity: 3.0000
    returnable_res = await client.get(
        f"/api/v1/sales/{sale_id}/returnable-items", headers=headers
    )
    assert returnable_res.status_code == 200
    returnables = returnable_res.json()
    assert len(returnables) == 1
    assert Decimal(str(returnables[0]["quantity_returned"])) == Decimal("2.0000")
    assert Decimal(str(returnables[0]["quantity_returnable"])) == Decimal("3.0000")


@pytest.mark.asyncio
async def test_sale_return_exceeding_quantity_rejected(
    client: AsyncClient,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Cannot return more quantity than was originally sold or remains returnable."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # Buy 2 units
    chk_res = await client.post(
        "/api/v1/sales/checkout",
        json={
            "idempotency_key": f"chk-exceed-{uuid.uuid4()}",
            "branch_id": str(test_branch.id),
            "items": [{"product_variant_id": str(variant.id), "quantity": "2.0000"}],
            "payments": [{"method": "CASH", "amount": "300.00"}],
        },
        headers=headers,
    )
    sale_data = chk_res.json()
    sale_id = sale_data["id"]
    sale_item_id = sale_data["items"][0]["id"]

    # Try to return 5 units
    excess_res = await client.post(
        f"/api/v1/sales/{sale_id}/returns",
        json={
            "items": [{"original_sale_item_id": sale_item_id, "quantity": "5.0000"}],
            "refund_method": "CASH",
        },
        headers=headers,
    )
    assert excess_res.status_code == 400
    assert excess_res.json()["error"]["code"] == "RETURN_QUANTITY_EXCEEDED"


@pytest.mark.asyncio
async def test_sale_return_full_refund_status(
    client: AsyncClient,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Returning all sold items flips the sale status to REFUNDED."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # Buy 2 units
    chk_res = await client.post(
        "/api/v1/sales/checkout",
        json={
            "idempotency_key": f"chk-full-ret-{uuid.uuid4()}",
            "branch_id": str(test_branch.id),
            "items": [{"product_variant_id": str(variant.id), "quantity": "2.0000"}],
            "payments": [{"method": "CASH", "amount": "300.00"}],
        },
        headers=headers,
    )
    sale_data = chk_res.json()
    sale_id = sale_data["id"]
    sale_item_id = sale_data["items"][0]["id"]

    # Return all 2 units
    ret_res = await client.post(
        f"/api/v1/sales/{sale_id}/returns",
        json={
            "items": [{"original_sale_item_id": sale_item_id, "quantity": "2.0000"}],
            "refund_method": "CASH",
        },
        headers=headers,
    )
    assert ret_res.status_code == 201

    # Verify status is REFUNDED
    sale_check = await client.get(f"/api/v1/sales/{sale_id}", headers=headers)
    assert sale_check.status_code == 200
    assert sale_check.json()["status"] == "REFUNDED"


@pytest.mark.asyncio
async def test_sale_void_restores_inventory_and_marks_tenders(
    client: AsyncClient,
    db_session: AsyncSession,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Voiding a sale restores stock, marks tenders voided, and sets status to VOIDED."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # 1. Buy 3 units
    chk_res = await client.post(
        "/api/v1/sales/checkout",
        json={
            "idempotency_key": f"chk-void-{uuid.uuid4()}",
            "branch_id": str(test_branch.id),
            "items": [{"product_variant_id": str(variant.id), "quantity": "3.0000"}],
            "payments": [{"method": "CASH", "amount": "450.00"}],
        },
        headers=headers,
    )
    sale_id = chk_res.json()["id"]

    # Fetch stock before void
    bal_stmt = select(StockBalance).where(
        StockBalance.business_id == test_biz.id,
        StockBalance.branch_id == test_branch.id,
        StockBalance.product_variant_id == variant.id,
    )
    b_res = await db_session.execute(bal_stmt)
    bal = b_res.scalars().first()
    assert bal is not None
    stock_before_void = Decimal(str(bal.quantity_on_hand))

    # 2. Void sale
    void_res = await client.post(
        f"/api/v1/sales/{sale_id}/void",
        json={"reason": "Customer card double charged by mistake"},
        headers=headers,
    )
    assert void_res.status_code == 200
    void_data = void_res.json()
    assert void_data["status"] == "VOIDED"
    assert void_data["payments"][0]["status"] == "VOIDED"

    # 3. Check stock restored by 3 units
    await db_session.refresh(bal)
    assert Decimal(str(bal.quantity_on_hand)) == stock_before_void + Decimal("3.0000")

    # 4. Cannot void already voided sale
    dup_void = await client.post(
        f"/api/v1/sales/{sale_id}/void",
        json={"reason": "Second void attempt"},
        headers=headers,
    )
    assert dup_void.status_code == 400
    assert dup_void.json()["error"]["code"] == "ALREADY_VOIDED"


@pytest.mark.asyncio
async def test_tenant_isolation_on_sales_and_returns(
    client: AsyncClient,
    test_biz: Business,
    test_biz_b: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Store B cannot read, return, or void Store A's sales."""
    _, variant = test_product
    headers_a = make_auth(test_biz.id, test_cashier.id)
    headers_b = make_auth(test_biz_b.id, test_cashier.id)

    # Store A checkout
    chk_res = await client.post(
        "/api/v1/sales/checkout",
        json={
            "idempotency_key": f"chk-isolation-{uuid.uuid4()}",
            "branch_id": str(test_branch.id),
            "items": [{"product_variant_id": str(variant.id), "quantity": "1.0000"}],
            "payments": [{"method": "CASH", "amount": "150.00"}],
        },
        headers=headers_a,
    )
    sale_id = chk_res.json()["id"]

    # Store B attempts to read Store A sale -> 404
    b_get = await client.get(f"/api/v1/sales/{sale_id}", headers=headers_b)
    assert b_get.status_code == 404

    # Store B attempts to return Store A sale -> 404
    b_ret = await client.post(
        f"/api/v1/sales/{sale_id}/returns",
        json={
            "items": [
                {
                    "original_sale_item_id": chk_res.json()["items"][0]["id"],
                    "quantity": "1.0000",
                }
            ],
            "refund_method": "CASH",
        },
        headers=headers_b,
    )
    assert b_ret.status_code == 404
