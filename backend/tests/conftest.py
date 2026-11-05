"""Pytest fixtures for FastAPI testing."""

import os
from collections.abc import AsyncGenerator

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

# Ensure test environment settings
os.environ["ENVIRONMENT"] = "testing"
os.environ["DEBUG"] = "true"
os.environ["JWT_SECRET_KEY"] = "test_secret_key_minimum_32_characters_for_pytest"

from app.config import get_settings

get_settings.cache_clear()

from app.main import app  # noqa: E402


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Provides an asynchronous HTTP test client bound directly to the FastAPI app."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac
