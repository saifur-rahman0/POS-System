"""Tests for health and readiness endpoints."""

from unittest.mock import patch

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_live(client: AsyncClient) -> None:
    """Verifies the simple liveness probe."""
    response = await client.get("/health/live")
    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


@pytest.mark.asyncio
async def test_health_endpoint_healthy_when_db_connected(client: AsyncClient) -> None:
    """Verifies /health when the database connection succeeds."""
    with patch("app.api.v1.health.check_db_health", return_value=True):
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["version"] == "0.1.0"
        assert data["services"]["database"] == "connected"


@pytest.mark.asyncio
async def test_health_endpoint_degraded_when_db_disconnected(client: AsyncClient) -> None:
    """Verifies /health reports degraded (HTTP 503) without crashing when the DB is unavailable."""
    with patch("app.api.v1.health.check_db_health", return_value=False):
        response = await client.get("/health")
        assert response.status_code == 503
        data = response.json()
        assert data["status"] == "degraded"
        assert data["services"]["database"] == "disconnected"


@pytest.mark.asyncio
async def test_health_no_credentials_leaked(client: AsyncClient) -> None:
    """Ensures no database credentials, URLs, or secrets are exposed in the health response."""
    with patch("app.api.v1.health.check_db_health", return_value=False):
        response = await client.get("/health")
        content = response.text.lower()

        # Sensitive keywords that must NEVER appear in the response payload
        assert "password" not in content
        assert "secret" not in content
        assert "pos_user" not in content
        assert "postgresql://" not in content
        assert "postgresql+asyncpg://" not in content


@pytest.mark.asyncio
async def test_api_v1_health_route(client: AsyncClient) -> None:
    """Verifies that the versioned route /api/v1/health works identically."""
    with patch("app.api.v1.health.check_db_health", return_value=True):
        response = await client.get("/api/v1/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
