"""Comprehensive tests for Track 9: Advanced Sales, Held Carts, Quotations, Discounts, Exchanges, and Manager Overrides."""

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
from app.modules.inventory.models import StockBalance
from app.modules.sales.models import Quotation
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
        name=f"Advanced POS {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.flush()

    branch = Branch(
        id=uuid.uuid4(),
        business_id=biz.id,
        name="Dhaka Central Branch",
        code="DHK",
        is_active=True,
    )
    db_session.add(branch)
    await db_session.commit()
    await db_session.refresh(biz)
    return biz


@pytest.fixture
async def test_branch(db_session: AsyncSession, test_biz: Business) -> Branch:
    stmt = select(Branch).where(Branch.business_id == test_biz.id)
    res = await db_session.execute(stmt)
    return res.scalars().first()  # type: ignore


@pytest.fixture
async def test_cashier(db_session: AsyncSession) -> User:
    user = User(
        id=uuid.uuid4(),
        username=f"cashier_{uuid.uuid4().hex[:8]}",
        password_hash="test_pw_hash",
        display_name="Senior Cashier",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def auth_headers(test_biz: Business, test_cashier: User) -> dict[str, str]:
    token = create_access_token(
        user_id=test_cashier.id,
        business_id=test_biz.id,
        username=test_cashier.username,
        permissions={"*"},
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
async def products(
    db_session: AsyncSession, test_biz: Business, test_branch: Branch
) -> tuple[ProductVariant, ProductVariant]:
    """Create two products with stock balances for testing sales and exchanges."""
    p1 = Product(
        id=uuid.uuid4(),
        business_id=test_biz.id,
        sku=f"PROD-A-{uuid.uuid4().hex[:6].upper()}",
        name="Ergonomic Mouse",
        product_type="STANDARD",
        is_active=True,
    )
    db_session.add(p1)
    await db_session.flush()

    v1 = ProductVariant(
        id=uuid.uuid4(),
        product_id=p1.id,
        business_id=test_biz.id,
        name="Black",
        barcode=f"BAR-A-{uuid.uuid4().hex[:8]}",
        selling_price=Decimal("1200.0000"),
        cost_price=Decimal("800.0000"),
        track_stock=True,
        is_active=True,
    )
    db_session.add(v1)
    await db_session.flush()

    sb1 = StockBalance(
        business_id=test_biz.id,
        branch_id=test_branch.id,
        product_variant_id=v1.id,
        quantity_on_hand=Decimal("50.0000"),
    )
    db_session.add(sb1)

    p2 = Product(
        id=uuid.uuid4(),
        business_id=test_biz.id,
        sku=f"PROD-B-{uuid.uuid4().hex[:6].upper()}",
        name="Mechanical Keyboard",
        product_type="STANDARD",
        is_active=True,
    )
    db_session.add(p2)
    await db_session.flush()

    v2 = ProductVariant(
        id=uuid.uuid4(),
        product_id=p2.id,
        business_id=test_biz.id,
        name="RGB Blue Switch",
        barcode=f"BAR-B-{uuid.uuid4().hex[:8]}",
        selling_price=Decimal("3000.0000"),
        cost_price=Decimal("2000.0000"),
        track_stock=True,
        is_active=True,
    )
    db_session.add(v2)
    await db_session.flush()

    sb2 = StockBalance(
        business_id=test_biz.id,
        branch_id=test_branch.id,
        product_variant_id=v2.id,
        quantity_on_hand=Decimal("30.0000"),
    )
    db_session.add(sb2)

    await db_session.commit()
    await db_session.refresh(v1)
    await db_session.refresh(v2)
    return v1, v2


@pytest.mark.asyncio
async def test_held_carts_lifecycle(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_branch: Branch,
    products: tuple[ProductVariant, ProductVariant],
    db_session: AsyncSession,
) -> None:
    """Test parking, retrieving, resuming, and deleting held carts."""
    v1, _ = products

    # 1. Park cart
    held_payload = {
        "branch_id": str(test_branch.id),
        "label": "Counter 1 - Mr. Karim",
        "customer_name": "Karim Ahmed",
        "items": [
            {
                "product_variant_id": str(v1.id),
                "quantity": "2.0000",
                "unit_price": "1200.0000",
                "discount": "100.0000",
            }
        ],
        "cart_discount": "50.0000",
        "tax_rate": "5.0000",
        "delivery_charge": "0.0000",
        "notes": "Customer went to ATM",
    }
    create_res = await client.post(
        "/api/v1/sales/held-carts", json=held_payload, headers=auth_headers
    )
    assert create_res.status_code == 201
    held_data = create_res.json()
    held_id = held_data["id"]
    assert held_data["label"] == "Counter 1 - Mr. Karim"
    assert held_data["customer_name"] == "Karim Ahmed"

    # 2. List held carts
    list_res = await client.get(
        f"/api/v1/sales/held-carts?branch_id={test_branch.id}", headers=auth_headers
    )
    assert list_res.status_code == 200
    list_data = list_res.json()
    assert any(c["id"] == held_id for c in list_data)

    # 3. Get single held cart
    get_res = await client.get(f"/api/v1/sales/held-carts/{held_id}", headers=auth_headers)
    assert get_res.status_code == 200
    assert get_res.json()["notes"] == "Customer went to ATM"

    # 4. Resume and Checkout (passing held_cart_id so it gets automatically purged)
    checkout_payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "held_cart_id": held_id,
        "items": [
            {
                "product_variant_id": str(v1.id),
                "quantity": 2,
                "unit_price": 1200.0,
                "discount": 100.0,
            }
        ],
        "cart_discount": 50.0,
        "tax_rate": 5.0,
        "payments": [{"method": "CASH", "amount": 2500.0}],
    }
    co_res = await client.post(
        "/api/v1/sales/checkout", json=checkout_payload, headers=auth_headers
    )
    assert co_res.status_code == 201
    assert co_res.json()["status"] == "COMPLETED"

    # 5. Verify held cart is now deleted
    get_deleted_res = await client.get(f"/api/v1/sales/held-carts/{held_id}", headers=auth_headers)
    assert get_deleted_res.status_code == 404

    # 6. Test manual delete of another held cart
    create_res2 = await client.post(
        "/api/v1/sales/held-carts", json=held_payload, headers=auth_headers
    )
    held_id2 = create_res2.json()["id"]
    del_res = await client.delete(f"/api/v1/sales/held-carts/{held_id2}", headers=auth_headers)
    assert del_res.status_code == 204


@pytest.mark.asyncio
async def test_quotations_lifecycle_and_conversion(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_biz: Business,
    test_branch: Branch,
    products: tuple[ProductVariant, ProductVariant],
    db_session: AsyncSession,
) -> None:
    """Test issuing a pro-forma price quotation and converting it to a sale."""
    v1, v2 = products

    # Initial stock checks
    b1_before = (
        await db_session.execute(
            select(StockBalance.quantity_on_hand).where(
                StockBalance.business_id == test_biz.id,
                StockBalance.product_variant_id == v1.id,
            )
        )
    ).scalar_one()

    # 1. Create quotation
    q_payload = {
        "branch_id": str(test_branch.id),
        "customer_name": "Apex Footwear Ltd",
        "items": [
            {
                "product_variant_id": str(v1.id),
                "quantity": "5.0000",
                "unit_price": "1200.0000",
                "discount": "200.0000",
            },
            {
                "product_variant_id": str(v2.id),
                "quantity": "2.0000",
                "unit_price": "3000.0000",
                "discount": "0.0000",
            },
        ],
        "cart_discount": "500.0000",
        "tax_rate": "5.0000",
        "delivery_charge": "150.0000",
        "notes": "Valid for 15 days",
    }
    q_res = await client.post("/api/v1/sales/quotations", json=q_payload, headers=auth_headers)
    assert q_res.status_code == 201
    q_data = q_res.json()
    q_id = q_data["id"]

    assert q_data["quotation_no"].startswith("QT-")
    assert q_data["status"] == "ISSUED"
    assert Decimal(str(q_data["delivery_charge"])) == Decimal("150.0000")

    # 2. Check that stock was NOT deducted during quotation creation
    b1_after_quote = (
        await db_session.execute(
            select(StockBalance.quantity_on_hand).where(
                StockBalance.business_id == test_biz.id,
                StockBalance.product_variant_id == v1.id,
            )
        )
    ).scalar_one()
    assert b1_after_quote == b1_before

    # 3. List quotations
    list_res = await client.get("/api/v1/sales/quotations", headers=auth_headers)
    assert list_res.status_code == 200
    assert any(q["id"] == q_id for q in list_res.json())

    # 4. Get quotation details
    detail_res = await client.get(f"/api/v1/sales/quotations/{q_id}", headers=auth_headers)
    assert detail_res.status_code == 200
    assert len(detail_res.json()["items"]) == 2

    # 5. Convert quotation to sale
    grand_total = Decimal(str(q_data["grand_total"]))
    convert_payload = {
        "idempotency_key": str(uuid.uuid4()),
        "payments": [{"method": "CARD", "amount": float(grand_total), "reference": "TXN-9988"}],
        "notes": "Client accepted pro-forma quotation",
    }
    conv_res = await client.post(
        f"/api/v1/sales/quotations/{q_id}/convert",
        json=convert_payload,
        headers=auth_headers,
    )
    assert conv_res.status_code == 200
    sale_data = conv_res.json()
    assert sale_data["status"] == "COMPLETED"

    # 6. Verify quotation status is now CONVERTED
    q_db = await db_session.get(Quotation, uuid.UUID(q_id))
    await db_session.refresh(q_db)
    assert q_db.status == "CONVERTED"
    assert str(q_db.converted_sale_id) == sale_data["id"]

    # 7. Verify stock WAS deducted now upon conversion
    b1_after_sale = (
        await db_session.execute(
            select(StockBalance.quantity_on_hand).where(
                StockBalance.business_id == test_biz.id,
                StockBalance.product_variant_id == v1.id,
            )
        )
    ).scalar_one()
    assert b1_after_sale == b1_before - Decimal("5.0000")


@pytest.mark.asyncio
async def test_advanced_checkout_discounts_and_delivery(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_branch: Branch,
    products: tuple[ProductVariant, ProductVariant],
) -> None:
    """Test line item percentage discount, discount reason, and delivery charges."""
    v1, _ = products

    # 1 unit of v1 (1200 BDT)
    # Line discount: 10% (= 120 BDT)
    # Line total: 1080 BDT
    # Cart discount: 80 BDT -> Discounted Subtotal = 1000 BDT
    # Tax 5%: 50 BDT
    # Delivery charge: 100 BDT
    # Grand Total: 1150 BDT
    payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "items": [
            {
                "product_variant_id": str(v1.id),
                "quantity": 1,
                "unit_price": 1200.0,
                "discount": 10.0,  # 10%
                "discount_type": "PERCENTAGE",
                "discount_reason": "CLEARANCE_SALE",
            }
        ],
        "cart_discount": 80.0,
        "tax_rate": 5.0,
        "delivery_charge": 100.0,
        "payments": [{"method": "CASH", "amount": 1150.0}],
    }

    res = await client.post("/api/v1/sales/checkout", json=payload, headers=auth_headers)
    assert res.status_code == 201
    data = res.json()

    fin = data["financials"]
    assert Decimal(str(fin["subtotal"])) == Decimal("1200.0000")
    # total discount = 120 (line) + 80 (cart) = 200
    assert Decimal(str(fin["discount_total"])) == Decimal("200.0000")
    assert Decimal(str(fin["tax_total"])) == Decimal("50.0000")
    assert Decimal(str(fin["delivery_charge"])) == Decimal("100.0000")
    assert Decimal(str(fin["grand_total"])) == Decimal("1150.0000")

    item_out = data["items"][0]
    assert item_out["discount_type"] == "PERCENTAGE"
    assert item_out["discount_reason"] == "CLEARANCE_SALE"
    assert Decimal(str(item_out["discount"])) == Decimal("10.0000")
    assert Decimal(str(item_out["line_total"])) == Decimal("1080.0000")


@pytest.mark.asyncio
async def test_product_exchange_atomic(
    client: AsyncClient,
    auth_headers: dict[str, str],
    test_branch: Branch,
    products: tuple[ProductVariant, ProductVariant],
    db_session: AsyncSession,
) -> None:
    """Test atomic product exchange: return Item A and buy Item B, settling net price difference."""
    v1, v2 = products  # v1 = 1200 BDT, v2 = 3000 BDT

    # Step 1: Buy 2 units of v1 (total 2400 BDT)
    sale_payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "items": [
            {
                "product_variant_id": str(v1.id),
                "quantity": 2,
                "unit_price": 1200.0,
                "discount": 0.0,
            }
        ],
        "cart_discount": 0.0,
        "tax_rate": 0.0,
        "delivery_charge": 0.0,
        "payments": [{"method": "CASH", "amount": 2400.0}],
    }
    s_res = await client.post("/api/v1/sales/checkout", json=sale_payload, headers=auth_headers)
    assert s_res.status_code == 201
    orig_sale = s_res.json()
    orig_sale_id = orig_sale["id"]
    orig_item_id = orig_sale["items"][0]["id"]

    # Step 2: Customer brings back 1 unit of v1 (credit = 1200 BDT) and wants to take 1 unit of v2 (price = 3000 BDT)
    # Net difference to pay = 3000 - 1200 = 1800 BDT
    exchange_payload = {
        "idempotency_key": str(uuid.uuid4()),
        "branch_id": str(test_branch.id),
        "original_sale_id": orig_sale_id,
        "return_items": [
            {
                "original_sale_item_id": orig_item_id,
                "quantity": 1,
                "reason": "Exchanging for higher model",
            }
        ],
        "new_items": [
            {
                "product_variant_id": str(v2.id),
                "quantity": 1,
                "unit_price": 3000.0,
                "discount": 0.0,
            }
        ],
        "cart_discount": 0.0,
        "tax_rate": 0.0,
        "delivery_charge": 0.0,
        "payments": [{"method": "CASH", "amount": 1800.0}],
        "notes": "Exchange customer swap",
    }

    ex_res = await client.post("/api/v1/sales/exchange", json=exchange_payload, headers=auth_headers)
    assert ex_res.status_code == 201
    ex_data = ex_res.json()

    assert ex_data["return_no"].startswith("RET-")
    assert Decimal(str(ex_data["return_total"])) == Decimal("1200.0000")
    assert Decimal(str(ex_data["net_difference"])) == Decimal("1800.0000")
    assert ex_data["new_sale"]["sale_type"] == "EXCHANGE"
    assert ex_data["new_sale"]["exchange_return_id"] == ex_data["return_order_id"]


@pytest.mark.asyncio
async def test_manager_override(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    """Test manager override authorization endpoint."""
    # Valid PIN
    valid_payload = {
        "pin": "1234",
        "action": "HIGH_DISCOUNT",
        "reason": "Customer VIP 30% discount approved",
    }
    res = await client.post("/api/v1/sales/manager-override", json=valid_payload, headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["approved"] is True
    assert "token" in data
    assert "manager_id" in data

    # Invalid PIN
    invalid_payload = {
        "pin": "wrong_pin_0000",
        "action": "PRICE_OVERRIDE",
        "reason": "Unauthorized attempt",
    }
    fail_res = await client.post("/api/v1/sales/manager-override", json=invalid_payload, headers=auth_headers)
    assert fail_res.status_code == 401
