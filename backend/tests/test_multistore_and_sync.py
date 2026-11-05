"""Integration tests for Track 5: Multi-Store & Branch Sync.

Verifies:
1. Branch management (CRUD, unique codes, store KPIs).
2. Inter-branch stock transfer workflow (DRAFT -> IN_TRANSIT -> RECEIVED).
3. Insufficient stock rejection during transfer dispatch (409 Conflict).
4. Transfer cancellation rollback and inventory restoration.
5. Cross-branch inventory visibility.
6. Offline sync protocol (incremental /pull and batch /push sales).
"""

import uuid
from collections.abc import AsyncGenerator
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session_maker
from app.modules.business.models import Branch, Business
from app.modules.identity.models import User
from app.modules.inventory.models import StockBalance
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
        name=f"Sync Test Biz {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.flush()

    branch = Branch(
        id=uuid.uuid4(),
        business_id=biz.id,
        name="Main Store",
        code=f"MAIN-{uuid.uuid4().hex[:4].upper()}",
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
        username=f"admin_{uuid.uuid4().hex[:8]}",
        password_hash="dummy_hash_for_test",
        display_name="Test Store Admin",
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
        permissions=[
            "branches:read",
            "branches:write",
            "transfers:read",
            "transfers:write",
            "inventory:read",
            "inventory:write",
            "catalog:read",
            "catalog:write",
            "sales:create",
            "sales:read",
        ],
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_branch_crud_and_uniqueness(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    """Tests creating, listing, updating, and duplicate code prevention for retail branches."""
    # 1. Create a new branch
    code_suffix = uuid.uuid4().hex[:4].upper()
    branch_payload = {
        "name": f"Downtown Branch {code_suffix}",
        "code": f"DT-{code_suffix}",
        "address": "123 Commercial St, Zone 2",
        "phone": "+8801700112233",
        "is_active": True,
    }
    resp = await client.post(
        "/api/v1/branches",
        json=branch_payload,
        headers=auth_headers,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == branch_payload["name"]
    assert data["code"] == branch_payload["code"]
    branch_id = data["id"]

    # 2. Prevent duplicate branch code
    dup_resp = await client.post(
        "/api/v1/branches",
        json=branch_payload,
        headers=auth_headers,
    )
    assert dup_resp.status_code == 409

    # 3. List branches
    list_resp = await client.get(
        "/api/v1/branches",
        headers=auth_headers,
    )
    assert list_resp.status_code == 200
    branches = list_resp.json()
    assert any(b["id"] == branch_id for b in branches)

    # 4. Get branch detail with stock metrics
    detail_resp = await client.get(
        f"/api/v1/branches/{branch_id}",
        headers=auth_headers,
    )
    assert detail_resp.status_code == 200
    detail_data = detail_resp.json()
    assert detail_data["total_variants_in_stock"] == 0

    # 5. Update branch
    update_payload = {
        "name": f"Downtown Flagship {code_suffix}",
        "address": "456 Renovated Blvd",
        "is_active": True,
    }
    patch_resp = await client.put(
        f"/api/v1/branches/{branch_id}",
        json=update_payload,
        headers=auth_headers,
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["name"] == f"Downtown Flagship {code_suffix}"


@pytest.mark.asyncio
async def test_stock_transfer_lifecycle(
    client: AsyncClient,
    auth_headers: dict[str, str],
    db_session: AsyncSession,
) -> None:
    """Verifies DRAFT -> IN_TRANSIT (deducts source) -> RECEIVED (adds to destination)."""
    # Create two branches
    code1 = uuid.uuid4().hex[:4].upper()
    code2 = uuid.uuid4().hex[:4].upper()
    b1_resp = await client.post(
        "/api/v1/branches",
        json={"name": f"Source Branch {code1}", "code": f"SRC-{code1}"},
        headers=auth_headers,
    )
    b2_resp = await client.post(
        "/api/v1/branches",
        json={"name": f"Dest Branch {code2}", "code": f"DST-{code2}"},
        headers=auth_headers,
    )
    b1_id = b1_resp.json()["id"]
    b2_id = b2_resp.json()["id"]

    # Create category & product
    cat_resp = await client.post(
        "/api/v1/categories",
        json={"name": f"Hardware {code1}"},
        headers=auth_headers,
    )
    assert cat_resp.status_code == 201
    cat_id = cat_resp.json()["id"]

    prod_resp = await client.post(
        "/api/v1/products",
        json={
            "name": f"Hammer {code1}",
            "sku": f"HMR-{code1}",
            "category_id": cat_id,
            "product_type": "STANDARD",
            "selling_price": 25.0,
            "cost_price": 15.0,
            "track_stock": True,
        },
        headers=auth_headers,
    )
    assert prod_resp.status_code == 201
    variant_id = prod_resp.json()["variants"][0]["id"]

    # Seed stock at source branch: 50 units
    transfer_in_adj = {
        "branch_id": b1_id,
        "product_variant_id": variant_id,
        "adjustment_type": "ADJUSTMENT_UP",
        "quantity": 50.0,
        "reason": "STOCKTAKE_CORRECTION",
        "notes": "Transfer test stock",
    }
    adj_resp = await client.post(
        "/api/v1/inventory/adjustments",
        json=transfer_in_adj,
        headers=auth_headers,
    )
    assert adj_resp.status_code == 201

    # 1. Create Stock Transfer Draft (20 units)
    transfer_payload = {
        "source_branch_id": b1_id,
        "destination_branch_id": b2_id,
        "notes": "Inter-store restock",
        "items": [
            {
                "product_variant_id": variant_id,
                "quantity": 20.0,
            }
        ],
    }
    create_resp = await client.post(
        "/api/v1/transfers",
        json=transfer_payload,
        headers=auth_headers,
    )
    assert create_resp.status_code == 201
    transfer_data = create_resp.json()
    transfer_id = transfer_data["id"]
    assert transfer_data["status"] == "DRAFT"

    # Verify source stock still 50 (draft does not decrement)
    b1_stock_stmt = select(StockBalance.quantity_on_hand).where(
        StockBalance.branch_id == uuid.UUID(b1_id),
        StockBalance.product_variant_id == uuid.UUID(variant_id),
    )
    b1_qty = (await db_session.execute(b1_stock_stmt)).scalar_one()
    assert b1_qty == Decimal("50.0000")

    # 2. Dispatch / Send Transfer -> IN_TRANSIT
    send_resp = await client.post(
        f"/api/v1/transfers/{transfer_id}/send",
        headers=auth_headers,
    )
    assert send_resp.status_code == 200
    assert send_resp.json()["status"] == "IN_TRANSIT"

    # Verify source stock is decremented to 30
    db_session.expire_all()
    b1_qty = (await db_session.execute(b1_stock_stmt)).scalar_one()
    assert b1_qty == Decimal("30.0000")

    # 3. Receive Transfer at Destination -> RECEIVED
    recv_resp = await client.post(
        f"/api/v1/transfers/{transfer_id}/receive",
        headers=auth_headers,
    )
    assert recv_resp.status_code == 200
    assert recv_resp.json()["status"] == "RECEIVED"

    # Verify destination stock is now 20
    b2_stock_stmt = select(StockBalance.quantity_on_hand).where(
        StockBalance.branch_id == uuid.UUID(b2_id),
        StockBalance.product_variant_id == uuid.UUID(variant_id),
    )
    b2_qty = (await db_session.execute(b2_stock_stmt)).scalar_one()
    assert b2_qty == Decimal("20.0000")


@pytest.mark.asyncio
async def test_transfer_insufficient_stock_rejected(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    """Verifies that sending a transfer with insufficient source balance raises 409 Conflict."""
    code = uuid.uuid4().hex[:4].upper()
    b1 = (
        await client.post(
            "/api/v1/branches",
            json={"name": f"Branch A {code}", "code": f"BA-{code}"},
            headers=auth_headers,
        )
    ).json()["id"]
    b2 = (
        await client.post(
            "/api/v1/branches",
            json={"name": f"Branch B {code}", "code": f"BB-{code}"},
            headers=auth_headers,
        )
    ).json()["id"]

    cat_id = (
        await client.post(
            "/api/v1/categories",
            json={"name": f"Low Stock Cat {code}"},
            headers=auth_headers,
        )
    ).json()["id"]

    prod = (
        await client.post(
            "/api/v1/products",
            json={
                "name": f"Drill {code}",
                "sku": f"DRL-{code}",
                "category_id": cat_id,
                "selling_price": 50.0,
                "track_stock": True,
            },
            headers=auth_headers,
        )
    ).json()
    variant_id = prod["variants"][0]["id"]

    # We do not seed stock at Branch A (available is 0)
    transfer = (
        await client.post(
            "/api/v1/transfers",
            json={
                "source_branch_id": b1,
                "destination_branch_id": b2,
                "items": [{"product_variant_id": variant_id, "quantity": 5.0}],
            },
            headers=auth_headers,
        )
    ).json()

    # Attempt to send should fail with 409
    send_resp = await client.post(
        f"/api/v1/transfers/{transfer['id']}/send",
        headers=auth_headers,
    )
    assert send_resp.status_code == 409
    assert send_resp.json()["error"]["code"] == "INSUFFICIENT_STOCK"


@pytest.mark.asyncio
async def test_transfer_cancellation_restores_inventory(
    client: AsyncClient,
    auth_headers: dict[str, str],
    db_session: AsyncSession,
) -> None:
    """Verifies that cancelling an in-transit transfer refunds deducted stock back to source."""
    code = uuid.uuid4().hex[:4].upper()
    b1 = (
        await client.post(
            "/api/v1/branches",
            json={"name": f"Branch C {code}", "code": f"BC-{code}"},
            headers=auth_headers,
        )
    ).json()["id"]
    b2 = (
        await client.post(
            "/api/v1/branches",
            json={"name": f"Branch D {code}", "code": f"BD-{code}"},
            headers=auth_headers,
        )
    ).json()["id"]

    cat_id = (
        await client.post(
            "/api/v1/categories",
            json={"name": f"Tools {code}"},
            headers=auth_headers,
        )
    ).json()["id"]

    prod = (
        await client.post(
            "/api/v1/products",
            json={
                "name": f"Wrench {code}",
                "sku": f"WRC-{code}",
                "category_id": cat_id,
                "selling_price": 10.0,
                "track_stock": True,
            },
            headers=auth_headers,
        )
    ).json()
    variant_id = prod["variants"][0]["id"]

    # Seed 15 units at B1
    await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "branch_id": b1,
            "product_variant_id": variant_id,
            "adjustment_type": "ADJUSTMENT_UP",
            "quantity": 15.0,
            "reason": "STOCKTAKE_CORRECTION",
        },
        headers=auth_headers,
    )

    transfer = (
        await client.post(
            "/api/v1/transfers",
            json={
                "source_branch_id": b1,
                "destination_branch_id": b2,
                "items": [{"product_variant_id": variant_id, "quantity": 10.0}],
            },
            headers=auth_headers,
        )
    ).json()
    transfer_id = transfer["id"]

    # Dispatch: Source drops to 5
    await client.post(f"/api/v1/transfers/{transfer_id}/send", headers=auth_headers)

    # Cancel transfer: Source must revert to 15
    cancel_resp = await client.post(
        f"/api/v1/transfers/{transfer_id}/cancel",
        headers=auth_headers,
    )
    assert cancel_resp.status_code == 200
    assert cancel_resp.json()["status"] == "CANCELLED"

    db_session.expire_all()
    b1_stock_stmt = select(StockBalance.quantity_on_hand).where(
        StockBalance.branch_id == uuid.UUID(b1),
        StockBalance.product_variant_id == uuid.UUID(variant_id),
    )
    b1_qty = (await db_session.execute(b1_stock_stmt)).scalar_one()
    assert b1_qty == Decimal("15.0000")


@pytest.mark.asyncio
async def test_cross_branch_stock_lookup(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    """Verifies querying stock of a single product variant across all branches."""
    code = uuid.uuid4().hex[:4].upper()
    b1 = (
        await client.post(
            "/api/v1/branches",
            json={"name": f"Branch X {code}", "code": f"BX-{code}"},
            headers=auth_headers,
        )
    ).json()["id"]
    b2 = (
        await client.post(
            "/api/v1/branches",
            json={"name": f"Branch Y {code}", "code": f"BY-{code}"},
            headers=auth_headers,
        )
    ).json()["id"]

    cat_id = (
        await client.post(
            "/api/v1/categories",
            json={"name": f"Stock Cat {code}"},
            headers=auth_headers,
        )
    ).json()["id"]

    prod = (
        await client.post(
            "/api/v1/products",
            json={
                "name": f"Pliers {code}",
                "sku": f"PLR-{code}",
                "category_id": cat_id,
                "selling_price": 12.0,
                "track_stock": True,
            },
            headers=auth_headers,
        )
    ).json()
    variant_id = prod["variants"][0]["id"]

    # Stock at Branch X: 8 units
    await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "branch_id": b1,
            "product_variant_id": variant_id,
            "adjustment_type": "ADJUSTMENT_UP",
            "quantity": 8.0,
            "reason": "STOCKTAKE_CORRECTION",
        },
        headers=auth_headers,
    )
    # Stock at Branch Y: 14 units
    await client.post(
        "/api/v1/inventory/adjustments",
        json={
            "branch_id": b2,
            "product_variant_id": variant_id,
            "adjustment_type": "ADJUSTMENT_UP",
            "quantity": 14.0,
            "reason": "STOCKTAKE_CORRECTION",
        },
        headers=auth_headers,
    )

    lookup_resp = await client.get(
        f"/api/v1/transfers/cross-branch-stock/{variant_id}",
        headers=auth_headers,
    )
    assert lookup_resp.status_code == 200
    data = lookup_resp.json()
    assert isinstance(data, list)
    assert len(data) >= 2

    branch_stock_map = {b["branch_id"]: Decimal(str(b["quantity_on_hand"])) for b in data}
    assert branch_stock_map[b1] == Decimal("8.0")
    assert branch_stock_map[b2] == Decimal("14.0")


@pytest.mark.asyncio
async def test_offline_sync_pull_and_push(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    """Verifies incremental /sync/pull for catalog/branches and offline /sync/push sales."""
    # 1. Pull current deltas
    pull_resp = await client.get("/api/v1/sync/pull", headers=auth_headers)
    assert pull_resp.status_code == 200
    pull_data = pull_resp.json()
    assert "branches" in pull_data
    assert "categories" in pull_data
    assert "products" in pull_data

    # 2. Push an offline sale
    code = uuid.uuid4().hex[:4].upper()
    cat_id = (
        await client.post(
            "/api/v1/categories",
            json={"name": f"Sync Cat {code}"},
            headers=auth_headers,
        )
    ).json()["id"]

    prod = (
        await client.post(
            "/api/v1/products",
            json={
                "name": f"Sync Prod {code}",
                "sku": f"SNC-{code}",
                "category_id": cat_id,
                "selling_price": 40.0,
                "track_stock": False,
            },
            headers=auth_headers,
        )
    ).json()
    variant_id = prod["variants"][0]["id"]

    sale_key = str(uuid.uuid4())
    push_payload = {
        "client_terminal_id": "POS-TERM-01",
        "sales": [
            {
                "idempotency_key": sale_key,
                "items": [{"product_variant_id": variant_id, "quantity": 2.0}],
                "cart_discount": 0.0,
                "tax_rate": 0.0,
                "payments": [{"method": "CASH", "amount": 80.0}],
            }
        ],
    }

    push_resp = await client.post(
        "/api/v1/sync/push",
        json=push_payload,
        headers=auth_headers,
    )
    assert push_resp.status_code == 200
    push_res = push_resp.json()
    assert push_res["total_successful"] == 1
    assert push_res["total_failed"] == 0
    assert push_res["results"][0]["receipt_no"].startswith("REC-")
