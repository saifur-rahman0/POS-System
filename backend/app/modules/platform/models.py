"""Platform foundation models: audit logging, HTTP idempotency, licensing, backups, and outbox."""

import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AuditLog(Base):
    """Immutable audit trail of security, configuration, and data-modifying events."""

    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("ix_audit_logs_business_entity", "business_id", "entity_type", "entity_id"),
        Index("ix_audit_logs_business_date", "business_id", text("created_at DESC")),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    branch_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    actor_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(100), nullable=False)
    entity_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    before_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    after_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
        index=True,
    )


class IdempotencyRecord(Base):
    """HTTP API idempotency ledger preventing duplicate mutations on client retries."""

    __tablename__ = "idempotency_records"
    __table_args__ = (
        UniqueConstraint(
            "business_id",
            "endpoint",
            "idempotency_key",
            name="uq_idempotency_business_endpoint_key",
        ),
        Index("ix_idempotency_created_at", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    endpoint: Mapped[str] = mapped_column(String(255), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(255), nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    response_json: Mapped[dict] = mapped_column(JSONB, nullable=False)
    status_code: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )


class LicenseRecord(Base):
    """Locally verifiable perpetual or term license certificates."""

    __tablename__ = "license_records"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    license_key_id: Mapped[str] = mapped_column(String(100), nullable=False)
    license_payload: Mapped[str] = mapped_column(Text, nullable=False)
    signature: Mapped[str] = mapped_column(Text, nullable=False)
    device_limit: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        server_default=text("1"),
    )
    activated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )
    expires_at: Mapped[datetime | None] = mapped_column(nullable=True)
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="ACTIVE",
        server_default="ACTIVE",
    )  # ACTIVE, EXPIRED, REVOKED


class BackupRecord(Base):
    """Database dump and disaster recovery metadata archive."""

    __tablename__ = "backup_records"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    backup_type: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
    )  # MANUAL, SCHEDULED, AUTO_PRE_UPGRADE
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    checksum: Mapped[str] = mapped_column(String(64), nullable=False)  # SHA-256
    status: Mapped[str] = mapped_column(String(32), nullable=False)  # PENDING, COMPLETED, FAILED
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )


class SyncOutbox(Base):
    """Transactional outbox queue for future multi-branch synchronization."""

    __tablename__ = "sync_outbox"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        unique=True,
        nullable=False,
        index=True,
    )
    aggregate_type: Mapped[str] = mapped_column(String(100), nullable=False)
    aggregate_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
    payload_json: Mapped[dict] = mapped_column(JSONB, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
        index=True,
    )
    synced_at: Mapped[datetime | None] = mapped_column(nullable=True, index=True)

