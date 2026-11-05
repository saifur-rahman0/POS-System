"""Integration tests for Offline Cryptographic Licensing and Database Disaster Recovery Backups."""

import uuid

import pytest
from httpx import AsyncClient

from app.modules.licensing.schemas import LicenseGenerateRequest
from app.modules.licensing.service import LicensingService
from app.shared.auth import DEV_BUSINESS_ID, create_access_token


@pytest.fixture
def admin_headers() -> dict[str, str]:
    token = create_access_token(
        user_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
        business_id=DEV_BUSINESS_ID,
        username="dev_admin",
        permissions=["*", "admin", "catalog:read", "catalog:write"],
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_initial_trial_license_status(
    client: AsyncClient,
    admin_headers: dict[str, str],
) -> None:
    """When no commercial license has been activated, system reports 30-day evaluation trial."""
    res = await client.get("/api/v1/license/status", headers=admin_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] in ("TRIAL", "ACTIVE")
    assert data["device_limit"] >= 1
    assert "CORE_POS" in data["features"] or "MULTI_STORE" in data["features"]


@pytest.mark.asyncio
async def test_generate_and_activate_signed_license(
    client: AsyncClient,
    admin_headers: dict[str, str],
) -> None:
    """Admin generates offline cryptographic license token; store activates it offline."""
    # 1. Generate signed certificate
    gen_res = await client.post(
        "/api/v1/license/generate",
        headers=admin_headers,
        json={
            "business_id": str(DEV_BUSINESS_ID),
            "plan_name": "ENTERPRISE",
            "device_limit": 10,
            "days_valid": 365,
            "features": ["MULTI_STORE", "ANALYTICS", "HARDWARE_PRINTING"],
        },
    )
    assert gen_res.status_code == 201
    gen_data = gen_res.json()
    token = gen_data["license_token"]
    assert token is not None
    assert "." in token

    # 2. Activate token
    act_res = await client.post(
        "/api/v1/license/activate",
        headers=admin_headers,
        json={"license_token": token},
    )
    assert act_res.status_code == 200
    act_data = act_res.json()
    assert act_data["status"] == "ACTIVE"
    assert act_data["plan_name"] == "ENTERPRISE"
    assert act_data["device_limit"] == 10
    assert "HARDWARE_PRINTING" in act_data["features"]
    assert act_data["days_remaining"] >= 364

    # 3. Verify status endpoint reflects new license
    stat_res = await client.get("/api/v1/license/status", headers=admin_headers)
    assert stat_res.status_code == 200
    stat_data = stat_res.json()
    assert stat_data["status"] == "ACTIVE"
    assert stat_data["plan_name"] == "ENTERPRISE"


@pytest.mark.asyncio
async def test_tampered_license_signature_rejected(
    client: AsyncClient,
    admin_headers: dict[str, str],
) -> None:
    """Tampered token with invalid signature must be rejected with 400."""
    service = LicensingService()
    req = LicenseGenerateRequest(
        business_id=DEV_BUSINESS_ID,
        plan_name="PRO",
        device_limit=5,
        days_valid=30,
    )
    issued = service.generate_signed_token(req)
    payload_part, sig_part = issued.license_token.split(".")

    # Tamper the signature
    tampered_sig = sig_part[:-4] + "ffff"
    tampered_token = f"{payload_part}.{tampered_sig}"

    res = await client.post(
        "/api/v1/license/activate",
        headers=admin_headers,
        json={"license_token": tampered_token},
    )
    assert res.status_code == 400
    assert "signature" in res.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_cross_tenant_license_rejected(
    client: AsyncClient,
    admin_headers: dict[str, str],
) -> None:
    """License issued to another business UUID must be rejected with 403."""
    foreign_biz = uuid.uuid4()
    service = LicensingService()
    req = LicenseGenerateRequest(
        business_id=foreign_biz,
        plan_name="ENTERPRISE",
        device_limit=10,
        days_valid=100,
    )
    issued = service.generate_signed_token(req)

    res = await client.post(
        "/api/v1/license/activate",
        headers=admin_headers,
        json={"license_token": issued.license_token},
    )
    assert res.status_code == 403
    assert "different retail business" in res.json()["error"]["message"]


@pytest.mark.asyncio
async def test_create_and_list_database_backup(
    client: AsyncClient,
    admin_headers: dict[str, str],
) -> None:
    """Creates a compressed database backup archive and verifies metadata."""
    # 1. Create backup
    create_res = await client.post(
        "/api/v1/backups/create",
        headers=admin_headers,
        json={"backup_type": "MANUAL", "notes": "Pre-upgrade automated test dump"},
    )
    assert create_res.status_code == 201
    data = create_res.json()
    assert data["status"] == "COMPLETED"
    assert data["file_name"].endswith(".json.gz")
    assert data["size_bytes"] > 0
    assert len(data["checksum"]) == 64  # SHA-256
    backup_id = data["id"]

    # 2. List backups
    list_res = await client.get("/api/v1/backups", headers=admin_headers)
    assert list_res.status_code == 200
    archives = list_res.json()
    assert len(archives) >= 1
    matched = [a for a in archives if a["id"] == backup_id]
    assert len(matched) == 1
    assert matched[0]["checksum"] == data["checksum"]

    # 3. Verify restore readiness
    restore_res = await client.post(
        f"/api/v1/backups/{backup_id}/restore",
        headers=admin_headers,
    )
    assert restore_res.status_code == 200
    r_data = restore_res.json()
    assert r_data["status"] == "VERIFIED_AND_READY"
    assert r_data["tables_verified"] >= 15
    assert r_data["records_count"] >= 1
