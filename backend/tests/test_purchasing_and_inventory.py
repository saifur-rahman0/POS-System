"""Tests for Track 3: Suppliers, Purchasing, Goods Receiving, and Stock Adjustments."""

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
        name=f"Purchasing Test Store {uuid.uuid4().hex[:6]}",
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
async def test_branch(db_session: AsyncSession, test_biz: Business) -> Branch:
    stmt = select(Branch).where(Branch.business_id == test_biz.id)
    res = await db_session.execute(stmt)
    return res.scalars().first()  # type: ignore


@pytest.fixture
async def test_cashier(db_session: AsyncSession) -> User:
    user = User(
        id=uuid.uuid4(),
        username=f"mgr_{uuid.uuid4().hex[:8]}",
        password_hash="test_pw_hash",
        display_name="Store Manager",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def test_product(
    db_session: AsyncSession, test_biz: Business, test_branch: Branch
) -> tuple[Product, ProductVariant]:
    prod = Product(
        id=uuid.uuid4(),
        business_id=test_biz.id,
        sku=f"SKU-RICE-{uuid.uuid4().hex[:6].upper()}",
        name="Miniket Rice 25kg",
        product_type="STANDARD",
        is_active=True,
    )
    db_session.add(prod)
    await db_session.flush()

    variant = ProductVariant(
        id=uuid.uuid4(),
        product_id=prod.id,
        business_id=test_biz.id,
        name="25kg Sack",
        barcode=f"BAR-{uuid.uuid4().hex[:8]}",
        selling_price=Decimal("1500.0000"),
        cost_price=Decimal("1200.0000"),
        track_stock=True,
        is_active=True,
    )
    db_session.add(variant)
    await db_session.flush()

    # Initial stock: 10 sacks
    balance = StockBalance(
        business_id=test_biz.id,
        branch_id=test_branch.id,
        product_variant_id=variant.id,
        quantity_on_hand=Decimal("10.0000"),
    )
    db_session.add(balance)
    await db_session.commit()
    await db_session.refresh(variant)
    return prod, variant


def make_auth(biz_id: uuid.UUID, user_id: uuid.UUID) -> dict[str, str]:
    token = create_access_token(
        user_id=user_id,
        business_id=biz_id,
        username="manager",
        permissions=["*"],
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_supplier_crud_and_uniqueness(
    client: AsyncClient,
    test_biz: Business,
    test_cashier: User,
) -> None:
    """Verifies creating, getting, updating, and duplicate rejection of suppliers."""
    headers = make_auth(test_biz.id, test_cashier.id)
    unique_name = f"Fresh Foods Distributor {uuid.uuid4().hex[:6]}"

    # 1. Create supplier
    res = await client.post(
        "/api/v1/suppliers",
        json={
            "name": unique_name,
            "contact_person": "Kamal Hossain",
            "phone": "01712345678",
            "email": "kamal@freshfoods.com",
            "address": "Khatunganj, Chittagong",
        },
        headers=headers,
    )
    assert res.status_code == 201
    data = res.json()
    assert data["name"] == unique_name
    assert data["contact_person"] == "Kamal Hossain"
    assert Decimal(str(data["total_purchases_amount"])) == Decimal("0.0000")
    supplier_id = data["id"]

    # 2. Duplicate supplier name within business rejected
    dup_res = await client.post(
        "/api/v1/suppliers",
        json={"name": unique_name},
        headers=headers,
    )
    assert dup_res.status_code == 409
    assert dup_res.json()["error"]["code"] == "SUPPLIER_ALREADY_EXISTS"

    # 3. Get single supplier
    get_res = await client.get(f"/api/v1/suppliers/{supplier_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["name"] == unique_name

    # 4. Update supplier
    update_res = await client.put(
        f"/api/v1/suppliers/{supplier_id}",
        json={"phone": "01899998888", "contact_person": "Kamal Ahmed"},
        headers=headers,
    )
    assert update_res.status_code == 200
    assert update_res.json()["phone"] == "01899998888"
    assert update_res.json()["contact_person"] == "Kamal Ahmed"

    # 5. List with search
    list_res = await client.get(f"/api/v1/suppliers?search={unique_name[:10]}", headers=headers)
    assert list_res.status_code == 200
    list_data = list_res.json()
    assert list_data["total"] >= 1
    assert any(s["id"] == supplier_id for s in list_data["items"])


@pytest.mark.asyncio
async def test_purchase_order_creation_and_receiving(
    client: AsyncClient,
    db_session: AsyncSession,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Verifies creating a PO, receiving goods into stock, updating cost price, and audit logging."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # 1. Create supplier
    sup_res = await client.post(
        "/api/v1/suppliers",
        json={"name": f"Grain Wholesaler {uuid.uuid4().hex[:6]}"},
        headers=headers,
    )
    supplier_id = sup_res.json()["id"]

    # 2. Create PO for 20 sacks at new cost ৳1150 (initial was ৳1200) with ৳500 discount
    # Subtotal: 20 * 1150 = 23000. Total: 23000 - 500 = 22500.
    po_res = await client.post(
        "/api/v1/purchasing/orders",
        json={
            "supplier_id": supplier_id,
            "branch_id": str(test_branch.id),
            "discount": "500.0000",
            "notes": "Bulk discount included",
            "items": [
                {
                    "product_variant_id": str(variant.id),
                    "quantity": "20.0000",
                    "unit_cost": "1150.0000",
                }
            ],
        },
        headers=headers,
    )
    assert po_res.status_code == 201
    po_data = po_res.json()
    assert po_data["status"] == "ORDERED"
    assert Decimal(str(po_data["subtotal"])) == Decimal("23000.0000")
    assert Decimal(str(po_data["discount"])) == Decimal("500.0000")
    assert Decimal(str(po_data["total"])) == Decimal("22500.0000")
    assert po_data["reference_no"].startswith("PO-")
    purchase_id = po_data["id"]

    # 3. Before receiving, stock is 10 and variant cost_price is 1200
    v_stmt = select(ProductVariant).where(ProductVariant.id == variant.id)
    v_curr = (await db_session.execute(v_stmt)).scalars().first()
    assert v_curr.cost_price == Decimal("1200.0000")

    # 4. Receive PO
    rec_res = await client.post(
        f"/api/v1/purchasing/orders/{purchase_id}/receive",
        headers=headers,
    )
    assert rec_res.status_code == 200
    assert rec_res.json()["status"] == "RECEIVED"

    # 5. Verify stock balance incremented: 10 + 20 = 30
    bal_stmt = select(StockBalance.quantity_on_hand).where(
        StockBalance.business_id == test_biz.id,
        StockBalance.branch_id == test_branch.id,
        StockBalance.product_variant_id == variant.id,
    )
    bal_res = await db_session.execute(bal_stmt)
    new_qty = bal_res.scalar_one()
    assert new_qty == Decimal("30.0000")

    # 6. Verify variant cost_price updated to 1150
    await db_session.refresh(v_curr)
    assert v_curr.cost_price == Decimal("1150.0000")

    # 7. Verify StockMovement ledger entry logged
    mov_stmt = (
        select(StockMovement)
        .where(
            StockMovement.business_id == test_biz.id,
            StockMovement.reference_id == uuid.UUID(purchase_id),
            StockMovement.movement_type == "PURCHASE_RECEIVE",
        )
    )
    mov = (await db_session.execute(mov_stmt)).scalars().first()
    assert mov is not None
    assert mov.quantity_delta == Decimal("20.0000")
    assert mov.unit_cost == Decimal("1150.0000")

    # 8. Receiving already received PO is rejected
    dup_rec = await client.post(
        f"/api/v1/purchasing/orders/{purchase_id}/receive",
        headers=headers,
    )
    assert dup_rec.status_code == 400
    assert dup_rec.json()["error"]["code"] == "ALREADY_RECEIVED"


@pytest.mark.asyncio
async def test_purchase_payment_disbursement_and_cash_drawer(
    client: AsyncClient,
    db_session: AsyncSession,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Verifies making payment on purchase order updates paid_total and logs CashTransaction."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # 1. Create supplier & PO
    sup_res = await client.post(
        "/api/v1/suppliers",
        json={"name": f"Agro Mills {uuid.uuid4().hex[:6]}"},
        headers=headers,
    )
    supplier_id = sup_res.json()["id"]

    po_res = await client.post(
        "/api/v1/purchasing/orders",
        json={
            "supplier_id": supplier_id,
            "branch_id": str(test_branch.id),
            "items": [
                {
                    "product_variant_id": str(variant.id),
                    "quantity": "5.0000",
                    "unit_cost": "1000.0000",
                }
            ],
        },
        headers=headers,
    )
    purchase_id = po_res.json()["id"]
    # Total is 5000.00

    # 2. Make partial cash payment ৳2000
    pay_res = await client.post(
        f"/api/v1/purchasing/orders/{purchase_id}/payments",
        json={
            "amount": "2000.0000",
            "method": "CASH",
            "reference": "RECEIPT-PO-01",
        },
        headers=headers,
    )
    assert pay_res.status_code == 201
    pay_data = pay_res.json()
    assert Decimal(str(pay_data["amount"])) == Decimal("2000.0000")

    # 3. Check purchase order reflects paid_total: 2000 and due_balance: 3000
    check_po = await client.get(f"/api/v1/purchasing/orders/{purchase_id}", headers=headers)
    assert Decimal(str(check_po.json()["paid_total"])) == Decimal("2000.0000")
    assert Decimal(str(check_po.json()["due_balance"])) == Decimal("3000.0000")

    # 4. Verify CashTransaction(direction="OUT") was recorded in cash drawer
    cash_stmt = select(CashTransaction).where(
        CashTransaction.business_id == test_biz.id,
        CashTransaction.reference_id == uuid.UUID(purchase_id),
        CashTransaction.direction == "OUT",
    )
    c_res = await db_session.execute(cash_stmt)
    cash_tx = c_res.scalars().first()
    assert cash_tx is not None
    assert Decimal(str(cash_tx.amount)) == Decimal("2000.0000")

    # 5. Overpaying unpaid balance rejected
    over_res = await client.post(
        f"/api/v1/purchasing/orders/{purchase_id}/payments",
        json={"amount": "4000.0000", "method": "BANK"},
        headers=headers,
    )
    assert over_res.status_code == 400
    assert over_res.json()["error"]["code"] == "PAYMENT_EXCEEDS_UNPAID"


@pytest.mark.asyncio
async def test_stock_adjustments_and_movements(
    client: AsyncClient,
    db_session: AsyncSession,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Verifies manual inventory adjustments (UP and DOWN) and movement audit list."""
    _, variant = test_product
    headers = make_auth(test_biz.id, test_cashier.id)

    # Initial stock is 10.0000
    # 1. Adjust up: +5 units due to STOCKTAKE_CORRECTION
    up_res = await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "branch_id": str(test_branch.id),
            "product_variant_id": str(variant.id),
            "adjustment_type": "ADJUSTMENT_UP",
            "quantity": "5.0000",
            "reason": "STOCKTAKE_CORRECTION",
            "notes": "Found extra box in storage",
        },
        headers=headers,
    )
    assert up_res.status_code == 201
    up_data = up_res.json()
    assert Decimal(str(up_data["previous_quantity"])) == Decimal("10.0000")
    assert Decimal(str(up_data["new_quantity"])) == Decimal("15.0000")
    assert Decimal(str(up_data["quantity_adjusted"])) == Decimal("5.0000")

    # 2. Adjust down: -3 units due to DAMAGE
    down_res = await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "branch_id": str(test_branch.id),
            "product_variant_id": str(variant.id),
            "adjustment_type": "ADJUSTMENT_DOWN",
            "quantity": "3.0000",
            "reason": "DAMAGE",
            "notes": "Water leakage in warehouse",
        },
        headers=headers,
    )
    assert down_res.status_code == 201
    down_data = down_res.json()
    assert Decimal(str(down_data["previous_quantity"])) == Decimal("15.0000")
    assert Decimal(str(down_data["new_quantity"])) == Decimal("12.0000")

    # 3. Excessive deduction rejected
    excess_res = await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "branch_id": str(test_branch.id),
            "product_variant_id": str(variant.id),
            "adjustment_type": "ADJUSTMENT_DOWN",
            "quantity": "50.0000",
            "reason": "THEFT",
        },
        headers=headers,
    )
    assert excess_res.status_code == 409
    assert excess_res.json()["error"]["code"] == "INSUFFICIENT_STOCK"

    # 4. View movements audit trail
    mov_res = await client.get(
        f"/api/v1/inventory/movements?product_variant_id={variant.id}",
        headers=headers,
    )
    assert mov_res.status_code == 200
    mov_data = mov_res.json()
    assert mov_data["total"] >= 2
    types = [m["movement_type"] for m in mov_data["items"]]
    assert "ADJUSTMENT_UP" in types
    assert "ADJUSTMENT_DOWN" in types


@pytest.mark.asyncio
async def test_tenant_isolation_on_purchasing_and_inventory(
    client: AsyncClient,
    db_session: AsyncSession,
    test_biz: Business,
    test_branch: Branch,
    test_cashier: User,
    test_product: tuple[Product, ProductVariant],
) -> None:
    """Verifies that another business tenant cannot view or modify suppliers, POs, or stock."""
    _, variant = test_product
    headers_a = make_auth(test_biz.id, test_cashier.id)

    # 1. Create supplier & PO in Business A
    sup_res = await client.post(
        "/api/v1/suppliers",
        json={"name": f"Isolated Supplier {uuid.uuid4().hex[:6]}"},
        headers=headers_a,
    )
    supplier_a_id = sup_res.json()["id"]

    po_res = await client.post(
        "/api/v1/purchasing/orders",
        json={
            "supplier_id": supplier_a_id,
            "branch_id": str(test_branch.id),
            "items": [{"product_variant_id": str(variant.id), "quantity": "1", "unit_cost": "100"}],
        },
        headers=headers_a,
    )
    po_a_id = po_res.json()["id"]

    # 2. Create Business B and user B
    biz_b = Business(
        id=uuid.uuid4(),
        name="Business B Store",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    user_b = User(
        id=uuid.uuid4(),
        username=f"user_b_{uuid.uuid4().hex[:6]}",
        password_hash="pw",
        display_name="User B",
        is_active=True,
    )
    db_session.add_all([biz_b, user_b])
    await db_session.commit()

    headers_b = make_auth(biz_b.id, user_b.id)

    # 3. User B cannot see Supplier A
    b_sup = await client.get(f"/api/v1/suppliers/{supplier_a_id}", headers=headers_b)
    assert b_sup.status_code == 404

    # 4. User B cannot see or receive PO A
    b_po = await client.get(f"/api/v1/purchasing/orders/{po_a_id}", headers=headers_b)
    assert b_po.status_code == 404

    b_rec = await client.post(f"/api/v1/purchasing/orders/{po_a_id}/receive", headers=headers_b)
    assert b_rec.status_code == 404

    # 5. User B cannot adjust stock on Variant A
    b_adj = await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "product_variant_id": str(variant.id),
            "adjustment_type": "ADJUSTMENT_UP",
            "quantity": "5",
        },
        headers=headers_b,
    )
    assert b_adj.status_code == 404
