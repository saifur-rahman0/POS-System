"""Comprehensive integration & unit tests for Track 11: Advanced Inventory."""

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from app.database import get_db
from app.main import app
from app.modules.inventory.schemas import (
    AvailableStockOut,
    CategoryValuationOut,
    DamagedStockOut,
    ExpiryAlertOut,
    InventoryBatchOut,
    InventoryValuationReportOut,
    ReorderSuggestionOut,
    StockCountLineOut,
    StockCountOut,
    StockReservationOut,
)
from app.modules.inventory.service import InventoryService
from app.shared.auth import create_access_token

TEST_BIZ_ID = uuid.UUID("11111111-1111-1111-1111-111111111111")
TEST_BRANCH_ID = uuid.UUID("22222222-2222-2222-2222-222222222222")
TEST_USER_ID = uuid.UUID("33333333-3333-3333-3333-333333333333")
TEST_VARIANT_ID = uuid.UUID("44444444-4444-4444-4444-444444444444")
TEST_BATCH_ID = uuid.UUID("55555555-5555-5555-5555-555555555555")
TEST_COUNT_ID = uuid.UUID("66666666-6666-6666-6666-666666666666")
TEST_RES_ID = uuid.UUID("77777777-7777-7777-7777-777777777777")


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
        username="inv_manager",
        permissions={"*"},
    )
    return {"Authorization": f"Bearer {token}"}


# ============================================================================
# 1. Batch Tracking & Expiry Alerts
# ============================================================================
@pytest.mark.asyncio
async def test_create_and_list_batches(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    today = datetime.now(UTC).date()
    fake_batch_out = InventoryBatchOut(
        id=TEST_BATCH_ID,
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        product_variant_id=TEST_VARIANT_ID,
        product_name="Paracetamol 500mg",
        variant_name="Box of 100",
        sku="MED-PARA-100",
        batch_number="BATCH-2026-A1",
        manufacturing_date=today - timedelta(days=90),
        expiry_date=today + timedelta(days=15),
        quantity_received=Decimal("100.0000"),
        quantity_on_hand=Decimal("100.0000"),
        cost_price=Decimal("120.0000"),
        supplier_id=None,
        supplier_name=None,
        is_active=True,
        days_to_expiry=15,
        expiry_status="EXPIRING_30_DAYS",
        created_at=datetime.now(UTC),
    )

    with patch.object(
        InventoryService, "create_batch", new_callable=AsyncMock
    ) as mock_create, patch.object(
        InventoryService, "list_batches", new_callable=AsyncMock
    ) as mock_list, patch.object(
        InventoryService, "get_expiry_alerts", new_callable=AsyncMock
    ) as mock_alerts:
        mock_create.return_value = fake_batch_out
        mock_list.return_value = [fake_batch_out]
        mock_alerts.return_value = [
            ExpiryAlertOut(
                batch_id=TEST_BATCH_ID,
                batch_number="BATCH-2026-A1",
                product_variant_id=TEST_VARIANT_ID,
                product_name="Paracetamol 500mg",
                variant_name="Box of 100",
                branch_id=TEST_BRANCH_ID,
                branch_name="Main Central Store",
                quantity_on_hand=Decimal("100.0000"),
                expiry_date=today + timedelta(days=15),
                days_remaining=15,
                urgency="MEDIUM_30_DAYS",
            )
        ]

        # 1. Inward batch
        payload = {
            "branch_id": str(TEST_BRANCH_ID),
            "product_variant_id": str(TEST_VARIANT_ID),
            "batch_number": "BATCH-2026-A1",
            "quantity_received": 100.0,
            "cost_price": 120.0,
            "expiry_date": str(today + timedelta(days=15)),
        }
        res = await client.post("/api/v1/inventory/batches", json=payload, headers=auth_headers)
        assert res.status_code == 201
        data = res.json()
        assert data["batch_number"] == "BATCH-2026-A1"
        assert data["expiry_status"] == "EXPIRING_30_DAYS"
        assert Decimal(str(data["quantity_on_hand"])) == Decimal("100.0000")

        # 2. List batches
        list_res = await client.get(
            f"/api/v1/inventory/batches?branch_id={TEST_BRANCH_ID}", headers=auth_headers
        )
        assert list_res.status_code == 200
        assert len(list_res.json()) == 1

        # 3. Expiry alerts
        alert_res = await client.get(
            f"/api/v1/inventory/batches/alerts?branch_id={TEST_BRANCH_ID}", headers=auth_headers
        )
        assert alert_res.status_code == 200
        alerts = alert_res.json()
        assert len(alerts) == 1
        assert alerts[0]["urgency"] == "MEDIUM_30_DAYS"


# ============================================================================
# 2. Damaged Stock Write-Off
# ============================================================================
@pytest.mark.asyncio
async def test_damaged_stock_write_off(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    fake_damaged_out = DamagedStockOut(
        id=uuid.uuid4(),
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        product_variant_id=TEST_VARIANT_ID,
        product_name="Paracetamol 500mg",
        variant_name="Box of 100",
        batch_id=TEST_BATCH_ID,
        batch_number="BATCH-2026-A1",
        voucher_no="DAM-20261105-0001",
        quantity=Decimal("5.0000"),
        unit_cost=Decimal("120.0000"),
        total_loss=Decimal("600.0000"),
        reason="WATER_DAMAGE",
        disposal_method="DESTROYED",
        notes="Damaged due to roof leak",
        reported_by=TEST_USER_ID,
        reporter_name="Inventory Manager",
        created_at=datetime.now(UTC),
    )

    with patch.object(
        InventoryService, "record_damaged_stock", new_callable=AsyncMock
    ) as mock_record, patch.object(
        InventoryService, "list_damaged_records", new_callable=AsyncMock
    ) as mock_list:
        mock_record.return_value = fake_damaged_out
        mock_list.return_value = [fake_damaged_out]

        # 1. Post Damaged Stock
        payload = {
            "branch_id": str(TEST_BRANCH_ID),
            "product_variant_id": str(TEST_VARIANT_ID),
            "batch_id": str(TEST_BATCH_ID),
            "quantity": 5.0,
            "reason": "WATER_DAMAGE",
            "disposal_method": "DESTROYED",
            "notes": "Damaged due to roof leak",
        }
        res = await client.post("/api/v1/inventory/damaged", json=payload, headers=auth_headers)
        assert res.status_code == 201
        data = res.json()
        assert data["voucher_no"] == "DAM-20261105-0001"
        assert Decimal(str(data["total_loss"])) == Decimal("600.0000")

        # 2. List damaged records
        list_res = await client.get(
            f"/api/v1/inventory/damaged?branch_id={TEST_BRANCH_ID}", headers=auth_headers
        )
        assert list_res.status_code == 200
        assert len(list_res.json()) == 1


# ============================================================================
# 3. Stock Reservations & Availability
# ============================================================================
@pytest.mark.asyncio
async def test_stock_reservations_and_available_stock(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    fake_avail = AvailableStockOut(
        product_variant_id=TEST_VARIANT_ID,
        branch_id=TEST_BRANCH_ID,
        quantity_on_hand=Decimal("30.0000"),
        quantity_reserved=Decimal("10.0000"),
        available_quantity=Decimal("20.0000"),
    )

    fake_res = StockReservationOut(
        id=TEST_RES_ID,
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        product_variant_id=TEST_VARIANT_ID,
        product_name="Paracetamol 500mg",
        variant_name="Box of 100",
        batch_id=None,
        quantity=Decimal("10.0000"),
        reference_type="QUOTATION",
        reference_id=uuid.uuid4(),
        status="ACTIVE",
        reserved_until=datetime.now(UTC) + timedelta(hours=48),
        created_by=TEST_USER_ID,
        created_at=datetime.now(UTC),
    )

    fake_released = fake_res.model_copy(update={"status": "RELEASED"})

    with patch.object(
        InventoryService, "get_available_stock", new_callable=AsyncMock
    ) as mock_avail, patch.object(
        InventoryService, "create_reservation", new_callable=AsyncMock
    ) as mock_res, patch.object(
        InventoryService, "release_reservation", new_callable=AsyncMock
    ) as mock_rel, patch.object(
        InventoryService, "list_reservations", new_callable=AsyncMock
    ) as mock_list:
        mock_avail.return_value = fake_avail
        mock_res.return_value = fake_res
        mock_rel.return_value = fake_released
        mock_list.return_value = [fake_res]

        # 1. Available check
        av_res = await client.get(
            f"/api/v1/inventory/available/{TEST_VARIANT_ID}?branch_id={TEST_BRANCH_ID}",
            headers=auth_headers,
        )
        assert av_res.status_code == 200
        assert av_res.json()["available_quantity"] == 20.0

        # 2. Create reservation
        payload = {
            "branch_id": str(TEST_BRANCH_ID),
            "product_variant_id": str(TEST_VARIANT_ID),
            "quantity": 10.0,
            "reference_type": "QUOTATION",
            "reference_id": str(uuid.uuid4()),
        }
        res = await client.post("/api/v1/inventory/reservations", json=payload, headers=auth_headers)
        assert res.status_code == 201
        assert res.json()["status"] == "ACTIVE"

        # 3. Release reservation
        rel_res = await client.post(
            f"/api/v1/inventory/reservations/{TEST_RES_ID}/release", headers=auth_headers
        )
        assert rel_res.status_code == 200
        assert rel_res.json()["status"] == "RELEASED"


# ============================================================================
# 4. Physical Stock Counts (Audits)
# ============================================================================
@pytest.mark.asyncio
async def test_physical_stock_count_session(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    fake_count = StockCountOut(
        id=TEST_COUNT_ID,
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        branch_name="Main Central Store",
        status="DRAFT",
        notes="Q4 Inventory Audit",
        created_by=TEST_USER_ID,
        approved_by=None,
        created_at=datetime.now(UTC),
        completed_at=None,
        lines=[
            StockCountLineOut(
                id=uuid.uuid4(),
                stock_count_id=TEST_COUNT_ID,
                product_variant_id=TEST_VARIANT_ID,
                product_name="Paracetamol 500mg",
                variant_name="Box of 100",
                barcode="8801230001",
                expected_qty=Decimal("20.0000"),
                counted_qty=Decimal("0.0000"),
                variance=Decimal("-20.0000"),
                discrepancy_reason=None,
            )
        ],
    )

    fake_scanned = fake_count.model_copy(
        update={
            "status": "IN_PROGRESS",
            "lines": [
                StockCountLineOut(
                    id=uuid.uuid4(),
                    stock_count_id=TEST_COUNT_ID,
                    product_variant_id=TEST_VARIANT_ID,
                    product_name="Paracetamol 500mg",
                    variant_name="Box of 100",
                    barcode="8801230001",
                    expected_qty=Decimal("20.0000"),
                    counted_qty=Decimal("22.0000"),
                    variance=Decimal("2.0000"),
                    discrepancy_reason=None,
                )
            ],
        }
    )

    fake_completed = fake_scanned.model_copy(
        update={"status": "COMPLETED", "completed_at": datetime.now(UTC)}
    )

    with patch.object(
        InventoryService, "create_stock_count", new_callable=AsyncMock
    ) as mock_create, patch.object(
        InventoryService, "scan_stock_count_item", new_callable=AsyncMock
    ) as mock_scan, patch.object(
        InventoryService, "complete_stock_count", new_callable=AsyncMock
    ) as mock_comp:
        mock_create.return_value = fake_count
        mock_scan.return_value = fake_scanned
        mock_comp.return_value = fake_completed

        # 1. Create Count Session
        c_res = await client.post(
            "/api/v1/inventory/counts",
            json={"branch_id": str(TEST_BRANCH_ID), "notes": "Q4 Audit"},
            headers=auth_headers,
        )
        assert c_res.status_code == 201
        assert c_res.json()["status"] == "DRAFT"

        # 2. Barcode scan
        s_res = await client.post(
            f"/api/v1/inventory/counts/{TEST_COUNT_ID}/scan",
            json={"barcode": "8801230001", "increment_qty": 22.0},
            headers=auth_headers,
        )
        assert s_res.status_code == 200
        assert s_res.json()["status"] == "IN_PROGRESS"
        assert s_res.json()["lines"][0]["variance"] == 2.0

        # 3. Complete Count
        comp_res = await client.post(
            f"/api/v1/inventory/counts/{TEST_COUNT_ID}/complete", headers=auth_headers
        )
        assert comp_res.status_code == 200
        assert comp_res.json()["status"] == "COMPLETED"


# ============================================================================
# 5. Reorder Engine & Multi-Tier Valuation
# ============================================================================
@pytest.mark.asyncio
async def test_reorder_and_valuation(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    fake_reorder = [
        ReorderSuggestionOut(
            product_variant_id=TEST_VARIANT_ID,
            product_name="Paracetamol 500mg",
            variant_name="Box of 100",
            sku="MED-PARA-100",
            barcode="8801230001",
            branch_id=TEST_BRANCH_ID,
            branch_name="Main Central Store",
            quantity_on_hand=Decimal("15.0000"),
            active_reservations=Decimal("5.0000"),
            available_quantity=Decimal("10.0000"),
            min_stock_level=Decimal("20.0000"),
            suggested_reorder_qty=Decimal("50.0000"),
            estimated_unit_cost=Decimal("120.0000"),
            estimated_total_cost=Decimal("6000.0000"),
            primary_supplier_id=None,
            primary_supplier_name=None,
        )
    ]

    fake_val = InventoryValuationReportOut(
        business_id=TEST_BIZ_ID,
        branch_id=TEST_BRANCH_ID,
        branch_name="Main Central Store",
        as_of_date=datetime.now(UTC),
        total_variants=1,
        total_quantity_on_hand=Decimal("100.0000"),
        total_fifo_valuation=Decimal("12000.0000"),
        total_wac_valuation=Decimal("12000.0000"),
        total_retail_valuation=Decimal("18000.0000"),
        categories=[
            CategoryValuationOut(
                category_id=uuid.uuid4(),
                category_name="Pharmaceuticals & Health",
                item_count=1,
                total_units=Decimal("100.0000"),
                fifo_valuation=Decimal("12000.0000"),
                wac_valuation=Decimal("12000.0000"),
                retail_valuation=Decimal("18000.0000"),
            )
        ],
    )

    with patch.object(
        InventoryService, "get_reorder_suggestions", new_callable=AsyncMock
    ) as mock_sug, patch.object(
        InventoryService, "get_inventory_valuation", new_callable=AsyncMock
    ) as mock_val:
        mock_sug.return_value = fake_reorder
        mock_val.return_value = fake_val

        # 1. Reorder suggestions
        s_res = await client.get(
            f"/api/v1/inventory/reorder/suggestions?branch_id={TEST_BRANCH_ID}", headers=auth_headers
        )
        assert s_res.status_code == 200
        sugs = s_res.json()
        assert len(sugs) == 1
        assert sugs[0]["suggested_reorder_qty"] == 50.0

        # 2. Valuation
        v_res = await client.get(
            f"/api/v1/inventory/valuation?branch_id={TEST_BRANCH_ID}", headers=auth_headers
        )
        assert v_res.status_code == 200
        val = v_res.json()
        assert Decimal(str(val["total_fifo_valuation"])) == Decimal("12000.0000")
        assert Decimal(str(val["total_retail_valuation"])) == Decimal("18000.0000")
        assert len(val["categories"]) == 1
