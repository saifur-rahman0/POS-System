"""Health and readiness endpoints."""

from fastapi import APIRouter, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.config import get_settings
from app.database import check_db_health

router = APIRouter(tags=["System"])


class HealthResponse(BaseModel):
    status: str
    version: str
    environment: str
    services: dict[str, str]


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Health check reporting application and database readiness",
)
async def health_check() -> JSONResponse:
    """Verifies that the API service is up and checks database connectivity.

    Zero credentials or connection strings are ever leaked in the response.
    """
    settings = get_settings()
    db_ok = await check_db_health()

    overall_status = "healthy" if db_ok else "degraded"
    status_code = status.HTTP_200_OK if db_ok else status.HTTP_503_SERVICE_UNAVAILABLE

    payload = {
        "status": overall_status,
        "version": "0.1.0",
        "environment": settings.ENVIRONMENT,
        "services": {
            "database": "connected" if db_ok else "disconnected",
        },
    }
    return JSONResponse(status_code=status_code, content=payload)


@router.get("/health/live", summary="Liveness probe for process uptime")
async def liveness() -> dict[str, str]:
    """Simple probe to verify the process is alive."""
    return {"status": "alive"}
