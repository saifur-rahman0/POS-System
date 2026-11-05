"""Pure unit tests for Track 12: Advanced Pricing, PriceResolver, and Promotions."""

import uuid
from datetime import date
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.modules.catalog.models import ProductVariant
from app.modules.pricing.bulk_import import BulkImportProcessor
from app.modules.pricing.models import (
    BranchPriceOverride,
    CustomerGroup,
    PriceList,
    PriceListItem,
    Promotion,
)
from app.modules.pricing.price_resolver import PriceContext, PriceResolver
from app.modules.pricing.repository import PricingRepository
from app.modules.pricing.schemas import (
    PromotionValidateIn,
)
from app.modules.pricing.service import PricingService

TEST_BIZ_ID = uuid.UUID("11111111-1111-1111-1111-111111111111")
TEST_BRANCH_ID = uuid.UUID("22222222-2222-2222-2222-222222222222")
TEST_VARIANT_ID = uuid.UUID("33333333-3333-3333-3333-333333333333")
TEST_CUSTOMER_ID = uuid.UUID("44444444-4444-4444-4444-444444444444")
TEST_GROUP_ID = uuid.UUID("55555555-5555-5555-5555-555555555555")
TEST_PRICE_LIST_ID = uuid.UUID("66666666-6666-6666-6666-666666666666")


# ============================================================================
# 1. PriceResolver Priority Chain Tests
# ============================================================================
@pytest.mark.asyncio
async def test_price_resolution_branch_override() -> None:
    """Priority 1: Active branch override wins over everything."""
    mock_session = AsyncMock()
    mock_repo = MagicMock(spec=PricingRepository)
    resolver = PriceResolver(mock_repo)

    override = BranchPriceOverride(
        id=uuid.uuid4(),
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        product_variant_id=TEST_VARIANT_ID,
        selling_price=Decimal("999.0000"),
        is_active=True,
    )

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = override
    mock_session.execute.return_value = mock_result

    ctx = PriceContext(
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        customer_id=TEST_CUSTOMER_ID,
        quantity=Decimal("1.0000"),
        sale_date=date(2026, 11, 5),
    )

    resolved = await resolver.resolve(mock_session, TEST_VARIANT_ID, ctx)
    assert resolved.unit_price == Decimal("999.0000")
    assert resolved.source == "BRANCH_OVERRIDE"


@pytest.mark.asyncio
async def test_price_resolution_customer_group_price_list() -> None:
    """Priority 2: Matching customer group price list applies."""
    mock_session = AsyncMock()
    mock_repo = MagicMock(spec=PricingRepository)
    resolver = PriceResolver(mock_repo)

    group = CustomerGroup(id=TEST_GROUP_ID, business_id=TEST_BIZ_ID, name="VIP")
    pl = PriceList(
        id=TEST_PRICE_LIST_ID,
        business_id=TEST_BIZ_ID,
        name="VIP Price List",
        customer_group_id=TEST_GROUP_ID,
        is_active=True,
    )
    item = PriceListItem(
        id=uuid.uuid4(),
        price_list_id=TEST_PRICE_LIST_ID,
        product_variant_id=TEST_VARIANT_ID,
        min_quantity=Decimal("1.0000"),
        price=Decimal("750.0000"),
        is_active=True,
    )

    mock_repo.get_customer_primary_group = AsyncMock(return_value=group)
    mock_repo.get_price_list_for_group = AsyncMock(return_value=pl)

    # First execute: override query (returns None)
    # Second execute: price list items query (returns [item])
    mock_res_override = MagicMock()
    mock_res_override.scalar_one_or_none.return_value = None

    mock_res_items = MagicMock()
    mock_res_items.scalars.return_value.all.return_value = [item]

    mock_session.execute.side_effect = [mock_res_override, mock_res_items]

    ctx = PriceContext(
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        customer_id=TEST_CUSTOMER_ID,
        quantity=Decimal("1.0000"),
        sale_date=date(2026, 11, 5),
    )

    resolved = await resolver.resolve(mock_session, TEST_VARIANT_ID, ctx)
    assert resolved.unit_price == Decimal("750.0000")
    assert resolved.source == "PRICE_LIST"
    assert resolved.price_list_name == "VIP Price List"


@pytest.mark.asyncio
async def test_price_resolution_volume_break() -> None:
    """Higher min_quantity tier wins when requested quantity qualifies."""
    mock_session = AsyncMock()
    mock_repo = MagicMock(spec=PricingRepository)
    resolver = PriceResolver(mock_repo)

    pl = PriceList(id=TEST_PRICE_LIST_ID, business_id=TEST_BIZ_ID, name="Wholesale", is_default=True)
    item_tier2 = PriceListItem(
        id=uuid.uuid4(),
        price_list_id=TEST_PRICE_LIST_ID,
        product_variant_id=TEST_VARIANT_ID,
        min_quantity=Decimal("10.0000"),
        price=Decimal("400.0000"),
        is_active=True,
    )

    mock_repo.get_customer_primary_group = AsyncMock(return_value=None)
    mock_repo.get_default_price_list = AsyncMock(return_value=pl)

    mock_res_override = MagicMock()
    mock_res_override.scalar_one_or_none.return_value = None

    mock_res_items = MagicMock()
    mock_res_items.scalars.return_value.all.return_value = [item_tier2]

    mock_session.execute.side_effect = [mock_res_override, mock_res_items]

    ctx = PriceContext(
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        customer_id=None,
        quantity=Decimal("15.0000"),
        sale_date=date(2026, 11, 5),
    )

    resolved = await resolver.resolve(mock_session, TEST_VARIANT_ID, ctx)
    assert resolved.unit_price == Decimal("400.0000")
    assert resolved.source == "PRICE_LIST"


@pytest.mark.asyncio
async def test_price_resolution_fallback_to_base_price() -> None:
    """Priority 3: Fall back to variant.selling_price if no overrides/lists."""
    mock_session = AsyncMock()
    mock_repo = MagicMock(spec=PricingRepository)
    resolver = PriceResolver(mock_repo)

    variant = ProductVariant(
        id=TEST_VARIANT_ID,
        business_id=TEST_BIZ_ID,
        name="Standard Item",
        selling_price=Decimal("500.0000"),
        cost_price=Decimal("300.0000"),
    )

    mock_repo.get_customer_primary_group = AsyncMock(return_value=None)
    mock_repo.get_default_price_list = AsyncMock(return_value=None)

    mock_res_override = MagicMock()
    mock_res_override.scalar_one_or_none.return_value = None

    mock_res_variant = MagicMock()
    mock_res_variant.scalar_one_or_none.return_value = variant

    mock_session.execute.side_effect = [mock_res_override, mock_res_variant]

    ctx = PriceContext(
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        customer_id=None,
        quantity=Decimal("1.0000"),
        sale_date=date(2026, 11, 5),
    )

    resolved = await resolver.resolve(mock_session, TEST_VARIANT_ID, ctx)
    assert resolved.unit_price == Decimal("500.0000")
    assert resolved.source == "BASE_PRICE"


# ============================================================================
# 2. Promotion Validation Unit Tests
# ============================================================================
@pytest.mark.asyncio
async def test_promotion_percentage_validation_with_cap() -> None:
    mock_session = AsyncMock()
    mock_repo = MagicMock(spec=PricingRepository)
    service = PricingService(repo=mock_repo)

    promo = Promotion(
        id=uuid.uuid4(),
        business_id=TEST_BIZ_ID,
        name="Mega 50% Off",
        code="MEGA50",
        discount_type="PERCENTAGE",
        discount_value=Decimal("50.0000"),
        min_spend=Decimal("500.0000"),
        max_discount_cap=Decimal("400.0000"),
        usage_limit=10,
        times_used=2,
        valid_from=date(2026, 1, 1),
        valid_until=date(2026, 12, 31),
        is_active=True,
    )
    mock_repo.get_promotion_by_code = AsyncMock(return_value=promo)

    payload = PromotionValidateIn(
        code="MEGA50",
        branch_id=TEST_BRANCH_ID,
        subtotal=Decimal("2000.0000"),  # 50% = 1000, but cap is 400
    )

    val = await service.validate_promotion(mock_session, TEST_BIZ_ID, payload)
    assert val.is_valid is True
    assert val.calculated_discount == Decimal("400.0000")


@pytest.mark.asyncio
async def test_promotion_expired_validation() -> None:
    mock_session = AsyncMock()
    mock_repo = MagicMock(spec=PricingRepository)
    service = PricingService(repo=mock_repo)

    promo = Promotion(
        id=uuid.uuid4(),
        business_id=TEST_BIZ_ID,
        name="Expired Promo",
        code="OLD20",
        discount_type="FIXED_AMOUNT",
        discount_value=Decimal("100.0000"),
        min_spend=Decimal("0.0000"),
        valid_from=date(2025, 1, 1),
        valid_until=date(2025, 12, 31),  # Expired
        is_active=True,
    )
    mock_repo.get_promotion_by_code = AsyncMock(return_value=promo)

    payload = PromotionValidateIn(
        code="OLD20",
        branch_id=TEST_BRANCH_ID,
        subtotal=Decimal("500.0000"),
    )

    val = await service.validate_promotion(mock_session, TEST_BIZ_ID, payload)
    assert val.is_valid is False
    assert "expired" in val.message.lower()


@pytest.mark.asyncio
async def test_promotion_usage_limit_reached() -> None:
    mock_session = AsyncMock()
    mock_repo = MagicMock(spec=PricingRepository)
    service = PricingService(repo=mock_repo)

    promo = Promotion(
        id=uuid.uuid4(),
        business_id=TEST_BIZ_ID,
        name="Limited Promo",
        code="LIMITED",
        discount_type="FIXED_AMOUNT",
        discount_value=Decimal("50.0000"),
        min_spend=Decimal("0.0000"),
        usage_limit=5,
        times_used=5,  # Max reached
        valid_from=date(2026, 1, 1),
        valid_until=date(2026, 12, 31),
        is_active=True,
    )
    mock_repo.get_promotion_by_code = AsyncMock(return_value=promo)

    payload = PromotionValidateIn(
        code="LIMITED",
        branch_id=TEST_BRANCH_ID,
        subtotal=Decimal("500.0000"),
    )

    val = await service.validate_promotion(mock_session, TEST_BIZ_ID, payload)
    assert val.is_valid is False
    assert "limit" in val.message.lower()


# ============================================================================
# 3. Bulk CSV Importer Unit Tests
# ============================================================================
@pytest.mark.asyncio
async def test_bulk_csv_processor_success() -> None:
    importer = BulkImportProcessor()
    mock_session = AsyncMock()

    csv_bytes = (
        b"product_sku,product_name,variant_name,cost_price,selling_price\n"
        b"SKU-USB-01,USB Flash Drive,64GB,450.00,700.00\n"
        b"SKU-USB-01,USB Flash Drive,128GB,750.00,1100.00\n"
    )

    # Empty products/variants found -> creates
    mock_res_empty = MagicMock()
    mock_res_empty.scalar_one_or_none.return_value = None
    mock_session.execute.return_value = mock_res_empty

    result = await importer.process_csv(mock_session, TEST_BIZ_ID, csv_bytes)
    assert result.total_rows == 2
    assert result.created_count == 2
    assert result.error_count == 0


@pytest.mark.asyncio
async def test_bulk_csv_processor_validation_error() -> None:
    importer = BulkImportProcessor()
    mock_session = AsyncMock()

    csv_bytes = (
        b"product_sku,product_name,variant_name,cost_price,selling_price\n"
        b"SKU-BAD,Product Name,Default,-50.00,100.00\n"
    )

    result = await importer.process_csv(mock_session, TEST_BIZ_ID, csv_bytes)
    assert result.total_rows == 1
    assert result.error_count == 1
    assert "negative" in result.errors[0].message.lower()
