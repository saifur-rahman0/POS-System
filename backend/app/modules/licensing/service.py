"""Licensing domain service: offline cryptographic signature issuance, token validation, and status tracking."""

import base64
import hashlib
import hmac
import json
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.modules.platform.models import LicenseRecord
from app.shared.exceptions import AppException

from .schemas import (
    LicenseGenerateRequest,
    LicenseGenerateResponse,
    LicenseStatusOut,
)


class LicensingService:
    """Manages offline cryptographic licensing and hardware entitlement validation."""

    def __init__(self) -> None:
        self.settings = get_settings()

    def _get_signing_key(self) -> bytes:
        return self.settings.JWT_SECRET_KEY.encode("utf-8")

    def generate_signed_token(
        self,
        payload: LicenseGenerateRequest,
    ) -> LicenseGenerateResponse:
        """Vendor utility: generates an offline cryptographic license token."""
        now_utc = datetime.now(UTC)
        key_id = f"LIC-{now_utc.strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"

        expires_at = (
            now_utc + timedelta(days=payload.days_valid)
            if payload.days_valid is not None
            else None
        )

        claims = {
            "license_key_id": key_id,
            "business_id": str(payload.business_id),
            "plan_name": payload.plan_name,
            "device_limit": payload.device_limit,
            "features": payload.features,
            "issued_at": now_utc.isoformat(),
            "expires_at": expires_at.isoformat() if expires_at else None,
        }

        payload_json = json.dumps(claims, sort_keys=True)
        payload_b64 = base64.urlsafe_b64encode(payload_json.encode("utf-8")).decode("utf-8").rstrip("=")

        signature = hmac.new(
            self._get_signing_key(),
            payload_b64.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

        token = f"{payload_b64}.{signature}"

        return LicenseGenerateResponse(
            license_key_id=key_id,
            license_token=token,
            plan_name=payload.plan_name,
            device_limit=payload.device_limit,
            expires_at=expires_at,
        )

    def verify_token(
        self,
        token: str,
        expected_business_id: uuid.UUID,
    ) -> tuple[dict, str]:
        """Cryptographically verifies a signed license token. Returns (claims, signature)."""
        parts = token.strip().split(".")
        if len(parts) != 2:
            raise AppException(
                message="Malformed license token format",
                code="INVALID_LICENSE_FORMAT",
                status_code=400,
            )

        payload_b64, signature = parts[0], parts[1]

        # Verify HMAC signature
        expected_signature = hmac.new(
            self._get_signing_key(),
            payload_b64.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

        if not hmac.compare_digest(signature, expected_signature):
            raise AppException(
                message="Invalid cryptographic signature on license certificate",
                code="INVALID_LICENSE_SIGNATURE",
                status_code=400,
            )

        # Decode claims
        padding = "=" * ((4 - len(payload_b64) % 4) % 4)
        try:
            payload_json = base64.urlsafe_b64decode(payload_b64 + padding).decode("utf-8")
            claims = json.loads(payload_json)
        except Exception as exc:
            raise AppException(
                message=f"Failed to decode license claims: {exc}",
                code="INVALID_LICENSE_CLAIMS",
                status_code=400,
            ) from exc

        # Check tenant matching
        token_biz_id = claims.get("business_id")
        if not token_biz_id or uuid.UUID(token_biz_id) != expected_business_id:
            raise AppException(
                message="This license certificate was issued to a different retail business",
                code="LICENSE_TENANT_MISMATCH",
                status_code=403,
                details={"expected_business_id": str(expected_business_id), "token_business_id": token_biz_id},
            )

        # Check expiration
        expires_at_str = claims.get("expires_at")
        if expires_at_str:
            exp_dt = datetime.fromisoformat(expires_at_str)
            if exp_dt.tzinfo is None:
                exp_dt = exp_dt.replace(tzinfo=UTC)
            if exp_dt < datetime.now(UTC):
                raise AppException(
                    message=f"This license has expired (expired on {exp_dt.strftime('%Y-%m-%d')})",
                    code="LICENSE_EXPIRED",
                    status_code=400,
                    details={"expired_at": exp_dt.isoformat()},
                )

        return claims, signature

    async def get_license_status(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
    ) -> LicenseStatusOut:
        """Retrieves active license entitlements or reports trial status."""
        stmt = (
            select(LicenseRecord)
            .where(
                LicenseRecord.business_id == business_id,
                LicenseRecord.status == "ACTIVE",
            )
            .order_by(LicenseRecord.activated_at.desc())
            .limit(1)
        )
        res = await session.execute(stmt)
        record = res.scalars().first()

        now_utc = datetime.now(UTC)

        if not record:
            # Default to offline trial
            return LicenseStatusOut(
                business_id=business_id,
                license_key_id="TRIAL-MODE",
                status="TRIAL",
                plan_name="TRIAL",
                device_limit=2,
                features=["CORE_POS", "LOCAL_REPORTS"],
                days_remaining=30,
                is_perpetual=False,
                activated_at=None,
                expires_at=now_utc + timedelta(days=30),
                message="Operating in 30-Day Evaluation Trial Mode. Activate a commercial license for full features.",
            )

        # Parse stored payload
        try:
            claims = json.loads(record.license_payload)
        except Exception:
            claims = {}

        plan = claims.get("plan_name", "COMMERCIAL")
        features = claims.get("features", [])
        is_perpetual = record.expires_at is None

        # Check if expired
        days_remaining = None
        status = "ACTIVE"
        msg = f"Valid {plan} license active."

        if record.expires_at is not None:
            exp_dt = record.expires_at
            if exp_dt.tzinfo is None:
                exp_dt = exp_dt.replace(tzinfo=UTC)

            remaining_delta = exp_dt - now_utc
            days_remaining = max(0, remaining_delta.days)

            if remaining_delta.total_seconds() <= 0:
                status = "EXPIRED"
                msg = f"License expired on {exp_dt.strftime('%Y-%m-%d')}. Please renew."
            elif days_remaining <= 14:
                status = "EXPIRING_SOON"
                msg = f"License expires in {days_remaining} days on {exp_dt.strftime('%Y-%m-%d')}."

        return LicenseStatusOut(
            business_id=business_id,
            license_key_id=record.license_key_id,
            status=status,
            plan_name=plan,
            device_limit=record.device_limit,
            features=features,
            days_remaining=days_remaining,
            is_perpetual=is_perpetual,
            activated_at=record.activated_at,
            expires_at=record.expires_at,
            message=msg,
        )

    async def activate_license(
        self,
        session: AsyncSession,
        business_id: uuid.UUID,
        license_token: str,
    ) -> LicenseStatusOut:
        """Validates signed token, deactivates previous licenses, and records active license."""
        claims, signature = self.verify_token(license_token, business_id)

        # Deactivate existing active licenses
        existing_stmt = select(LicenseRecord).where(
            LicenseRecord.business_id == business_id,
            LicenseRecord.status == "ACTIVE",
        )
        existing_res = await session.execute(existing_stmt)
        for prev in existing_res.scalars().all():
            prev.status = "REVOKED"

        expires_at = None
        if claims.get("expires_at"):
            exp_dt = datetime.fromisoformat(claims["expires_at"])
            expires_at = exp_dt.astimezone(UTC).replace(tzinfo=None)

        now_naive = datetime.now(UTC).replace(tzinfo=None)

        record = LicenseRecord(
            id=uuid.uuid4(),
            business_id=business_id,
            license_key_id=claims["license_key_id"],
            license_payload=json.dumps(claims, sort_keys=True),
            signature=signature,
            device_limit=claims.get("device_limit", 1),
            activated_at=now_naive,
            expires_at=expires_at,
            status="ACTIVE",
        )
        session.add(record)
        await session.commit()

        return await self.get_license_status(session, business_id)
