"""Integration & unit tests for Track 12: Advanced Product and Pricing."""

import uuid
from datetime import UTC, date, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from app.database import get_db
from app.main import app
from app.modules.pricing.schemas import (
    BranchPriceOverrideOut,
    BulkImportResult,
    CustomerGroupOut,
    PriceListItemOut,
    PriceListOut,
    PriceResolveItemOut,
    PriceResolveOut,
    ProductBundleItemOut,
    ProductBundleOut,
    PromotionOut,
    PromotionValidateOut,
)
from app.modules.pricing.service import PricingService
from app.shared.auth import create_access_token

TEST_BIZ_ID = uuid.UUID("11111111-1111-1111-1111-111111111111")
TEST_BRANCH_ID = uuid.UUID("22222222-2222-2222-2222-222222222222")
TEST_USER_ID = uuid.UUID("33333333-3333-3333-3333-333333333333")
TEST_VARIANT_ID = uuid.UUID("44444444-4444-4444-4444-444444444444")
TEST_GROUP_ID = uuid.UUID("55555555-5555-5555-5555-555555555555")
TEST_PRICE_LIST_ID = uuid.UUID("66666666-6666-6666-6666-666666666666")
TEST_BUNDLE_ID = uuid.UUID("77777777-7777-7777-7777-777777777777")
TEST_PROMO_ID = uuid.UUID("88888888-8888-8888-8888-888888888888")
TEST_CUSTOMER_ID = uuid.UUID("99999999-9999-9999-9999-999999999999")


@pytest.fixture(autouse=True)
def override_db() -> AsyncMock:
    mock_session = AsyncMock()

    async def _mock_get_db():
        yield mock_session

    app.dependency_overrides[get_db] = _mock_get_db
    return mock_session


@pytest.fixture
def auth_headers() -> dict[str, str]:
    token = create_access_token(
        user_id=TEST_USER_ID,
        business_id=TEST_BIZ_ID,
        username="pricing_admin",
        permissions={"*"},
    )
    return {"Authorization": f"Bearer {token}"}


# ============================================================================
# 1. Customer Groups Tests
# ============================================================================
@pytest.mark.asyncio
async def test_list_and_create_customer_group(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    now = datetime.now(UTC)
    mock_group = CustomerGroupOut(
        id=TEST_GROUP_ID,
        business_id=TEST_BIZ_ID,
        name="Wholesale VIP",
        description="High volume wholesale buyers",
        is_active=True,
        created_at=now,
        member_count=5,
    )

    with (
        patch.object(PricingService, "list_customer_groups", AsyncMock(return_value=[mock_group])),
        patch.object(PricingService, "create_customer_group", AsyncMock(return_value=mock_group)),
    ):
        res_list = await client.get("/api/v1/pricing/customer-groups", headers=auth_headers)
        assert res_list.status_code == 200
        data = res_list.json()
        assert len(data) == 1
        assert data[0]["name"] == "Wholesale VIP"
        assert data[0]["member_count"] == 5

        res_create = await client.post(
            "/api/v1/pricing/customer-groups",
            headers=auth_headers,
            json={"name": "Wholesale VIP", "description": "High volume wholesale buyers"},
        )
        assert res_create.status_code == 201
        assert res_create.json()["name"] == "Wholesale VIP"


# ============================================================================
# 2. Price Lists & Price List Items Tests
# ============================================================================
@pytest.mark.asyncio
async def test_price_lists_crud(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    now = datetime.now(UTC)
    mock_item = PriceListItemOut(
        id=uuid.uuid4(),
        price_list_id=TEST_PRICE_LIST_ID,
        product_variant_id=TEST_VARIANT_ID,
        min_quantity=Decimal("5.0000"),
        price=Decimal("450.0000"),
        start_date=None,
        end_date=None,
        is_active=True,
        created_at=now,
        variant_name="Test Variant",
    )
    mock_pl = PriceListOut(
        id=TEST_PRICE_LIST_ID,
        business_id=TEST_BIZ_ID,
        name="Wholesale Tier 1",
        description="Tier 1 pricing",
        currency="BDT",
        is_default=False,
        is_active=True,
        customer_group_id=TEST_GROUP_ID,
        created_at=now,
        updated_at=now,
        items=[mock_item],
    )

    with (
        patch.object(PricingService, "list_price_lists", AsyncMock(return_value=[mock_pl])),
        patch.object(PricingService, "create_price_list", AsyncMock(return_value=mock_pl)),
        patch.object(PricingService, "get_price_list", AsyncMock(return_value=mock_pl)),
        patch.object(PricingService, "add_or_update_price_list_item", AsyncMock(return_value=mock_item)),
    ):
        res_list = await client.get("/api/v1/pricing/price-lists", headers=auth_headers)
        assert res_list.status_code == 200
        assert len(res_list.json()) == 1

        res_get = await client.get(f"/api/v1/pricing/price-lists/{TEST_PRICE_LIST_ID}", headers=auth_headers)
        assert res_get.status_code == 200
        assert res_get.json()["name"] == "Wholesale Tier 1"
        assert len(res_get.json()["items"]) == 1

        res_add_item = await client.post(
            f"/api/v1/pricing/price-lists/{TEST_PRICE_LIST_ID}/items",
            headers=auth_headers,
            json={
                "product_variant_id": str(TEST_VARIANT_ID),
                "min_quantity": "5.0000",
                "price": "450.0000",
            },
        )
        assert res_add_item.status_code == 201
        assert Decimal(res_add_item.json()["price"]) == Decimal("450.0000")


# ============================================================================
# 3. Branch Price Overrides Tests
# ============================================================================
@pytest.mark.asyncio
async def test_branch_price_overrides(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    now = datetime.now(UTC)
    mock_override = BranchPriceOverrideOut(
        id=uuid.uuid4(),
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        product_variant_id=TEST_VARIANT_ID,
        selling_price=Decimal("620.0000"),
        is_active=True,
        created_at=now,
        updated_at=now,
        variant_name="Special Variant",
    )

    with (
        patch.object(PricingService, "list_branch_overrides", AsyncMock(return_value=[mock_override])),
        patch.object(PricingService, "upsert_branch_override", AsyncMock(return_value=mock_override)),
        patch.object(PricingService, "delete_branch_override", AsyncMock(return_value={"message": "Deleted"})),
    ):
        res_list = await client.get(
            f"/api/v1/pricing/branch-overrides?branch_id={TEST_BRANCH_ID}",
            headers=auth_headers,
        )
        assert res_list.status_code == 200
        assert len(res_list.json()) == 1
        assert Decimal(res_list.json()[0]["selling_price"]) == Decimal("620.0000")

        res_post = await client.post(
            "/api/v1/pricing/branch-overrides",
            headers=auth_headers,
            json={
                "branch_id": str(TEST_BRANCH_ID),
                "product_variant_id": str(TEST_VARIANT_ID),
                "selling_price": "620.0000",
            },
        )
        assert res_post.status_code == 200
        assert Decimal(res_post.json()["selling_price"]) == Decimal("620.0000")


# ============================================================================
# 4. Dynamic Price Resolution Tests (Priority Chain)
# ============================================================================
@pytest.mark.asyncio
async def test_price_resolution_endpoint(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    mock_resolved = PriceResolveOut(
        results=[
            PriceResolveItemOut(
                variant_id=TEST_VARIANT_ID,
                unit_price=Decimal("450.0000"),
                source="PRICE_LIST",
                price_list_id=TEST_PRICE_LIST_ID,
                price_list_name="Wholesale Tier 1",
            )
        ]
    )

    with patch.object(PricingService, "resolve_prices", AsyncMock(return_value=mock_resolved)):
        res = await client.post(
            "/api/v1/pricing/resolve",
            headers=auth_headers,
            json={
                "branch_id": str(TEST_BRANCH_ID),
                "customer_id": str(TEST_CUSTOMER_ID),
                "items": [{"variant_id": str(TEST_VARIANT_ID), "quantity": "5.0000"}],
            },
        )
        assert res.status_code == 200
        res_data = res.json()["results"][0]
        assert Decimal(res_data["unit_price"]) == Decimal("450.0000")
        assert res_data["source"] == "PRICE_LIST"
        assert res_data["price_list_name"] == "Wholesale Tier 1"


# ============================================================================
# 5. Product Bundles & Kits Tests
# ============================================================================
@pytest.mark.asyncio
async def test_product_bundles(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    now = datetime.now(UTC)
    comp_id = uuid.uuid4()
    mock_bundle_item = ProductBundleItemOut(
        id=uuid.uuid4(),
        bundle_id=TEST_BUNDLE_ID,
        component_variant_id=comp_id,
        quantity=Decimal("2.0000"),
        is_optional=False,
        component_name="Included Battery",
    )
    mock_bundle = ProductBundleOut(
        id=TEST_BUNDLE_ID,
        business_id=TEST_BIZ_ID,
        product_id=uuid.uuid4(),
        name="Solar Inverter Kit",
        bundle_price=Decimal("12500.0000"),
        is_kit=False,
        is_active=True,
        created_at=now,
        items=[mock_bundle_item],
    )

    with (
        patch.object(PricingService, "list_bundles", AsyncMock(return_value=[mock_bundle])),
        patch.object(PricingService, "create_bundle", AsyncMock(return_value=mock_bundle)),
    ):
        res_list = await client.get("/api/v1/pricing/bundles", headers=auth_headers)
        assert res_list.status_code == 200
        assert len(res_list.json()) == 1
        assert res_list.json()[0]["name"] == "Solar Inverter Kit"
        assert len(res_list.json()[0]["items"]) == 1


# ============================================================================
# 6. Promotions & Coupon Validation Tests
# ============================================================================
@pytest.mark.asyncio
async def test_promotions_and_validation(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    now = datetime.now(UTC)
    mock_promo = PromotionOut(
        id=TEST_PROMO_ID,
        business_id=TEST_BIZ_ID,
        name="New Year 20% Off",
        code="NEWYEAR20",
        discount_type="PERCENTAGE",
        discount_value=Decimal("20.0000"),
        min_spend=Decimal("1000.0000"),
        max_discount_cap=Decimal("500.0000"),
        usage_limit=100,
        times_used=3,
        valid_from=date(2026, 1, 1),
        valid_until=date(2026, 12, 31),
        applies_to="ALL",
        scope_ids=[],
        is_active=True,
        created_at=now,
        updated_at=now,
    )
    mock_val_out = PromotionValidateOut(
        is_valid=True,
        promotion_id=TEST_PROMO_ID,
        discount_type="PERCENTAGE",
        discount_value=Decimal("20.0000"),
        calculated_discount=Decimal("500.0000"),
        message="Promotion applied successfully",
    )

    with (
        patch.object(PricingService, "list_promotions", AsyncMock(return_value=[mock_promo])),
        patch.object(PricingService, "create_promotion", AsyncMock(return_value=mock_promo)),
        patch.object(PricingService, "validate_promotion", AsyncMock(return_value=mock_val_out)),
    ):
        res_list = await client.get("/api/v1/pricing/promotions", headers=auth_headers)
        assert res_list.status_code == 200
        assert res_list.json()[0]["code"] == "NEWYEAR20"

        res_val = await client.post(
            "/api/v1/pricing/promotions/validate",
            headers=auth_headers,
            json={
                "code": "NEWYEAR20",
                "branch_id": str(TEST_BRANCH_ID),
                "subtotal": "3500.0000",
            },
        )
        assert res_val.status_code == 200
        assert res_val.json()["is_valid"] is True
        assert Decimal(res_val.json()["calculated_discount"]) == Decimal("500.0000")


# ============================================================================
# 7. Bulk CSV Import Tests
# ============================================================================
@pytest.mark.asyncio
async def test_bulk_csv_import(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    mock_result = BulkImportResult(
        total_rows=2,
        created_count=2,
        updated_count=0,
        error_count=0,
        errors=[],
    )

    with (
        patch.object(PricingService, "process_bulk_import", AsyncMock(return_value=mock_result)),
        patch.object(
            PricingService,
            "generate_csv_template",
            lambda _: "product_sku,product_name,variant_name,cost_price,selling_price\n",
        ),
    ):
        res_template = await client.get("/api/v1/pricing/bulk-import/template", headers=auth_headers)
        assert res_template.status_code == 200
        assert "product_sku" in res_template.text

        csv_data = (
            b"product_sku,product_name,variant_name,cost_price,selling_price\n"
            b"SKU-1,Prod 1,Default,10.00,20.00\n"
            b"SKU-2,Prod 2,Default,15.00,30.00\n"
        )
        res_import = await client.post(
            "/api/v1/pricing/bulk-import",
            headers=auth_headers,
            content=csv_data,
        )
        assert res_import.status_code == 200
        assert res_import.json()["created_count"] == 2
        assert res_import.json()["error_count"] == 0
