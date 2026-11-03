"""Tests for Product Categories and Products Catalog vertical slice."""

import uuid
from collections.abc import AsyncGenerator
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session_maker
from app.modules.business.models import Business
from app.shared.auth import create_access_token


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    session_factory = get_session_maker()
    async with session_factory() as session:
        yield session


@pytest.fixture
async def business_a(db_session: AsyncSession) -> Business:
    biz = Business(
        id=uuid.uuid4(),
        name=f"Test Store A {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.commit()
    await db_session.refresh(biz)
    return biz


@pytest.fixture
async def business_b(db_session: AsyncSession) -> Business:
    biz = Business(
        id=uuid.uuid4(),
        name=f"Test Store B {uuid.uuid4().hex[:6]}",
        timezone="Asia/Dhaka",
        currency="BDT",
    )
    db_session.add(biz)
    await db_session.commit()
    await db_session.refresh(biz)
    return biz


def make_headers(
    business_id: uuid.UUID,
    permissions: list[str] | set[str] | None = None,
) -> dict[str, str]:
    perms = list(permissions) if permissions is not None else ["catalog:read", "catalog:write"]
    token = create_access_token(
        user_id=uuid.uuid4(),
        business_id=business_id,
        username="cashier_test",
        permissions=perms,
    )
    return {"Authorization": f"Bearer {token}"}


# -----------------------------------------------------------------------------
# 1. Authorization & Permission Tests
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_catalog_endpoints_require_authentication(client: AsyncClient) -> None:
    """Endpoints reject requests missing Authorization header."""
    res1 = await client.get("/api/v1/categories")
    assert res1.status_code == 401
    assert res1.json()["error"]["code"] == "UNAUTHORIZED"

    res2 = await client.get("/api/v1/products")
    assert res2.status_code == 401


@pytest.mark.asyncio
async def test_catalog_permissions_enforced(client: AsyncClient, business_a: Business) -> None:
    """Read-only user cannot write, and user lacking read cannot query."""
    read_only_headers = make_headers(business_a.id, permissions=["catalog:read"])
    no_perm_headers = make_headers(business_a.id, permissions=[])

    # Missing catalog:write on category creation
    res1 = await client.post(
        "/api/v1/categories",
        headers=read_only_headers,
        json={"name": "Accessories"},
    )
    assert res1.status_code == 403
    assert res1.json()["error"]["code"] == "PERMISSION_DENIED"

    # Missing catalog:read on category list
    res2 = await client.get("/api/v1/categories", headers=no_perm_headers)
    assert res2.status_code == 403
    assert res2.json()["error"]["code"] == "PERMISSION_DENIED"


# -----------------------------------------------------------------------------
# 2. Category CRUD Tests
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_category_crud_and_uniqueness(client: AsyncClient, business_a: Business) -> None:
    """Test creating category, hierarchy, duplicate name prevention, and updating."""
    headers = make_headers(business_a.id)

    # 1. Create root category
    res = await client.post(
        "/api/v1/categories",
        headers=headers,
        json={"name": "Smartphones"},
    )
    assert res.status_code == 201
    cat1 = res.json()
    assert cat1["name"] == "Smartphones"
    assert cat1["parent_id"] is None
    assert cat1["is_active"] is True

    # 2. Duplicate category under same parent fails
    res_dup = await client.post(
        "/api/v1/categories",
        headers=headers,
        json={"name": "Smartphones"},
    )
    assert res_dup.status_code == 409
    assert res_dup.json()["error"]["code"] == "DUPLICATE_CATEGORY"

    # 3. Create subcategory with parent_id
    res_sub = await client.post(
        "/api/v1/categories",
        headers=headers,
        json={"name": "Android", "parent_id": cat1["id"]},
    )
    assert res_sub.status_code == 201
    assert res_sub.json()["parent_id"] == cat1["id"]

    # 4. List categories
    res_list = await client.get("/api/v1/categories", headers=headers)
    assert res_list.status_code == 200
    names = [c["name"] for c in res_list.json()]
    assert "Smartphones" in names
    assert "Android" in names

    # 5. Update category
    res_update = await client.put(
        f"/api/v1/categories/{cat1['id']}",
        headers=headers,
        json={"name": "Flagship Smartphones", "is_active": False},
    )
    assert res_update.status_code == 200
    assert res_update.json()["name"] == "Flagship Smartphones"
    assert res_update.json()["is_active"] is False


# -----------------------------------------------------------------------------
# 3. Product CRUD & Invariant Tests
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_product_crud_and_validation(client: AsyncClient, business_a: Business) -> None:
    """Test product creation with default variant, pricing, duplicate SKU/barcode checks."""
    headers = make_headers(business_a.id)

    # Create category first
    cat_res = await client.post(
        "/api/v1/categories",
        headers=headers,
        json={"name": f"Laptops {uuid.uuid4().hex[:4]}"},
    )
    cat_id = cat_res.json()["id"]

    # 1. Create product
    sku = f"MAC-{uuid.uuid4().hex[:6].upper()}"
    barcode = f"BAR-{uuid.uuid4().hex[:8]}"

    payload = {
        "sku": sku,
        "name": "MacBook Air M2",
        "category_id": cat_id,
        "product_type": "STANDARD",
        "selling_price": "125000.0000",
        "cost_price": "110000.0000",
        "barcode": barcode,
        "track_stock": True,
        "is_active": True,
        "attributes_json": {"color": "Midnight", "ram": "16GB"},
    }

    res = await client.post("/api/v1/products", headers=headers, json=payload)
    assert res.status_code == 201
    product = res.json()
    assert product["sku"] == sku
    assert product["name"] == "MacBook Air M2"
    assert product["primary_variant"]["barcode"] == barcode
    assert Decimal(product["primary_variant"]["selling_price"]) == Decimal("125000.0000")

    # 2. Duplicate SKU rejected
    dup_sku_payload = {
        "sku": sku,
        "name": "Another Laptop",
        "selling_price": "90000.0000",
    }
    res_dup_sku = await client.post("/api/v1/products", headers=headers, json=dup_sku_payload)
    assert res_dup_sku.status_code == 409
    assert res_dup_sku.json()["error"]["code"] == "DUPLICATE_SKU"

    # 3. Duplicate Barcode rejected
    dup_bar_payload = {
        "sku": f"DIFF-{uuid.uuid4().hex[:4].upper()}",
        "name": "Different Laptop",
        "selling_price": "90000.0000",
        "barcode": barcode,
    }
    res_dup_bar = await client.post("/api/v1/products", headers=headers, json=dup_bar_payload)
    assert res_dup_bar.status_code == 409
    assert res_dup_bar.json()["error"]["code"] == "DUPLICATE_BARCODE"

    # 4. Barcode scanner lookup endpoint
    res_lookup = await client.get(f"/api/v1/products/barcode/{barcode}", headers=headers)
    assert res_lookup.status_code == 200
    assert res_lookup.json()["id"] == product["id"]

    # 5. Non-existent barcode lookup returns 404
    res_lookup_404 = await client.get("/api/v1/products/barcode/UNKNOWN_CODE_9999", headers=headers)
    assert res_lookup_404.status_code == 404
    assert res_lookup_404.json()["error"]["code"] == "BARCODE_NOT_FOUND"

    # 6. Negative price rejected by validation
    neg_payload = {
        "sku": f"NEG-{uuid.uuid4().hex[:4].upper()}",
        "name": "Negative Price Item",
        "selling_price": "-10.0000",
    }
    res_neg = await client.post("/api/v1/products", headers=headers, json=neg_payload)
    assert res_neg.status_code == 422


# -----------------------------------------------------------------------------
# 4. Pagination & Search Filtering Tests
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_product_search_and_pagination(client: AsyncClient, business_a: Business) -> None:
    """Test searching by term, filtering by active status, and paginating."""
    headers = make_headers(business_a.id)

    prefix = uuid.uuid4().hex[:4].upper()
    for i in range(5):
        await client.post(
            "/api/v1/products",
            headers=headers,
            json={
                "sku": f"{prefix}-SKU-{i}",
                "name": f"{prefix} Unique Gadget {i}",
                "selling_price": f"{1000 + i * 100}.0000",
                "is_active": (i % 2 == 0),
            },
        )

    # Search by keyword
    search_res = await client.get(
        f"/api/v1/products?search={prefix}&limit=2&page=1",
        headers=headers,
    )
    assert search_res.status_code == 200
    data = search_res.json()
    assert data["total"] == 5
    assert len(data["items"]) == 2
    assert data["pages"] == 3
    assert data["page"] == 1

    # Filter active only
    active_res = await client.get(
        f"/api/v1/products?search={prefix}&is_active=true",
        headers=headers,
    )
    assert active_res.status_code == 200
    assert active_res.json()["total"] == 3


# -----------------------------------------------------------------------------
# 5. Tenant Scoping Isolation Tests
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_tenant_isolation_on_catalog(
    client: AsyncClient, business_a: Business, business_b: Business
) -> None:
    """Business B cannot see or query products belonging to Business A."""
    headers_a = make_headers(business_a.id)
    headers_b = make_headers(business_b.id)

    sku = f"ISO-{uuid.uuid4().hex[:6].upper()}"
    p_res = await client.post(
        "/api/v1/products",
        headers=headers_a,
        json={"sku": sku, "name": "Isolated Product", "selling_price": "500.0000"},
    )
    product_id = p_res.json()["id"]

    # Business B attempts to fetch product created by Business A
    res_b = await client.get(f"/api/v1/products/{product_id}", headers=headers_b)
    assert res_b.status_code == 404
    assert res_b.json()["error"]["code"] == "PRODUCT_NOT_FOUND"

    # Business B can reuse the same SKU without conflict
    res_b_create = await client.post(
        "/api/v1/products",
        headers=headers_b,
        json={"sku": sku, "name": "Business B Version", "selling_price": "600.0000"},
    )
    assert res_b_create.status_code == 201
