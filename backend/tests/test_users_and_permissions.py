"""Tests for staff user accounts, role-based authorization, and permissions management."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_roles_and_permissions_meta(client: AsyncClient):
    response = await client.get("/api/v1/users/meta/roles")
    assert response.status_code == 200
    data = response.json()
    assert "ADMIN" in data["roles"]
    assert "MANAGER" in data["roles"]
    assert "CASHIER" in data["roles"]
    assert "STOCK_KEEPER" in data["roles"]
    assert "*" in data["roles"]["ADMIN"]
    assert "pos" in data["roles"]["CASHIER"]
    assert "labels" in data
    assert data["labels"]["ADMIN"] == "Stall Owner (Admin)"


@pytest.mark.asyncio
async def test_role_based_logins(client: AsyncClient):
    # 1. Admin login
    admin_res = await client.post(
        "/api/v1/auth/login",
        json={"username": "admin", "password": "password"},
    )
    assert admin_res.status_code == 200
    admin_data = admin_res.json()
    assert admin_data["user"]["role"] == "ADMIN"
    assert "*" in admin_data["user"]["permissions"]

    # 2. Manager login
    mgr_res = await client.post(
        "/api/v1/auth/login",
        json={"username": "manager", "password": "password"},
    )
    assert mgr_res.status_code == 200
    mgr_data = mgr_res.json()
    assert mgr_data["user"]["role"] == "MANAGER"
    assert "reports:read" in mgr_data["user"]["permissions"]

    # 3. Cashier login
    cashier_res = await client.post(
        "/api/v1/auth/login",
        json={"username": "dev_cashier", "password": "password"},
    )
    assert cashier_res.status_code == 200
    cashier_data = cashier_res.json()
    assert cashier_data["user"]["role"] == "CASHIER"
    assert "pos" in cashier_data["user"]["permissions"]
    assert "users:manage" not in cashier_data["user"]["permissions"]

    # 4. Stock keeper login
    stock_res = await client.post(
        "/api/v1/auth/login",
        json={"username": "stock_keeper", "password": "password"},
    )
    assert stock_res.status_code == 200
    stock_data = stock_res.json()
    assert stock_data["user"]["role"] == "STOCK_KEEPER"
    assert "inventory:read" in stock_data["user"]["permissions"]
    assert "pos" not in stock_data["user"]["permissions"]


@pytest.mark.asyncio
async def test_admin_staff_crud_lifecycle(client: AsyncClient):
    # Log in as admin
    login_res = await client.post(
        "/api/v1/auth/login",
        json={"username": "admin", "password": "password"},
    )
    assert login_res.status_code == 200
    admin_token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {admin_token}"}

    # List users
    list_res = await client.get("/api/v1/users", headers=headers)
    assert list_res.status_code == 200
    users = list_res.json()
    assert len(users) >= 4

    # Create new staff cashier
    import uuid
    random_suffix = uuid.uuid4().hex[:6]
    new_username = f"cashier_{random_suffix}"
    create_res = await client.post(
        "/api/v1/users",
        headers=headers,
        json={
            "username": new_username,
            "password": "Password123!",
            "display_name": f"New Cashier {random_suffix}",
            "email": f"{new_username}@pos.local",
            "role": "CASHIER",
        },
    )
    assert create_res.status_code == 201
    created_user = create_res.json()
    assert created_user["username"] == new_username
    assert created_user["role"] == "CASHIER"
    user_id = created_user["id"]

    # Test login with newly created cashier
    new_login_res = await client.post(
        "/api/v1/auth/login",
        json={"username": new_username, "password": "Password123!"},
    )
    assert new_login_res.status_code == 200
    assert new_login_res.json()["user"]["role"] == "CASHIER"

    # Update user role to MANAGER
    update_res = await client.put(
        f"/api/v1/users/{user_id}",
        headers=headers,
        json={
            "display_name": f"Promoted Manager {random_suffix}",
            "role": "MANAGER",
        },
    )
    assert update_res.status_code == 200
    assert update_res.json()["role"] == "MANAGER"

    # Deactivate user
    del_res = await client.delete(f"/api/v1/users/{user_id}", headers=headers)
    assert del_res.status_code == 200
    assert del_res.json()["is_active"] is False
