"""Authentication, JWT token verification, and permission-based authorization dependencies."""

import uuid
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

import jwt
from fastapi import Depends, Header, status
from pydantic import BaseModel

from app.config import get_settings
from app.shared.exceptions import AppException


class CurrentUser(BaseModel):
    """Authenticated principal extracted from validated JWT token."""

    user_id: uuid.UUID
    business_id: uuid.UUID
    username: str
    permissions: set[str] = set()


def create_access_token(
    user_id: uuid.UUID,
    business_id: uuid.UUID,
    username: str,
    permissions: list[str] | set[str] | None = None,
    expires_delta: timedelta | None = None,
) -> str:
    """Generates a signed JWT access token containing tenant context and permissions."""
    settings = get_settings()
    expire = datetime.now(UTC) + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode = {
        "sub": str(user_id),
        "business_id": str(business_id),
        "username": username,
        "permissions": list(permissions or []),
        "exp": expire,
    }
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


async def get_current_user(
    authorization: str | None = Header(default=None),
) -> CurrentUser:
    """Extracts and verifies JWT token from Authorization header."""
    if not authorization or not authorization.startswith("Bearer "):
        raise AppException(
            message="Missing or invalid Authorization header",
            code="UNAUTHORIZED",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    token = authorization.split(" ", 1)[1].strip()
    settings = get_settings()

    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        user_id_str = payload.get("sub")
        business_id_str = payload.get("business_id")
        username = payload.get("username")
        permissions = set(payload.get("permissions", []))

        if not user_id_str or not business_id_str or not username:
            raise AppException(
                message="Invalid token claims",
                code="UNAUTHORIZED",
                status_code=status.HTTP_401_UNAUTHORIZED,
            )

        return CurrentUser(
            user_id=uuid.UUID(user_id_str),
            business_id=uuid.UUID(business_id_str),
            username=username,
            permissions=permissions,
        )
    except jwt.ExpiredSignatureError as exc:
        raise AppException(
            message="Authentication token has expired",
            code="TOKEN_EXPIRED",
            status_code=status.HTTP_401_UNAUTHORIZED,
        ) from exc
    except (jwt.InvalidTokenError, ValueError) as exc:
        raise AppException(
            message=f"Could not validate credentials: {str(exc)}",
            code="INVALID_TOKEN",
            status_code=status.HTTP_401_UNAUTHORIZED,
        ) from exc


def require_permission(permission_code: str) -> Callable[[CurrentUser], CurrentUser]:
    """Dependency factory checking if current user possesses the required permission."""

    def _permission_checker(
        current_user: CurrentUser = Depends(get_current_user),
    ) -> CurrentUser:
        if (
            permission_code not in current_user.permissions
            and "*" not in current_user.permissions
            and "admin" not in current_user.permissions
        ):
            raise AppException(
                message=f"Access denied: permission '{permission_code}' is required",
                code="PERMISSION_DENIED",
                status_code=status.HTTP_403_FORBIDDEN,
                details={"required_permission": permission_code},
            )
        return current_user

    return _permission_checker
