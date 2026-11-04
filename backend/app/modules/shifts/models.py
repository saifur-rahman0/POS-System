"""Register shift sessions, cash drawer control, and reconciliation models."""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RegisterShift(Base):
    """Cashier work session on a register terminal tracking cash float and daily reconciliation."""

    __tablename__ = "register_shifts"
    __table_args__ = (
        CheckConstraint("opening_cash >= 0", name="chk_shift_opening_cash_non_negative"),
        Index("ix_shifts_business_branch_status", "business_id", "branch_id", "status"),
        Index("ix_shifts_user_status", "user_id", "status"),
        Index("ix_shifts_business_branch_date", "business_id", "branch_id", text("opened_at DESC")),
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
    branch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    device_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="OPEN",
        server_default="OPEN",
    )  # OPEN, CLOSED
    opened_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
        index=True,
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        nullable=True,
    )
    opening_cash: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    closing_cash_counted: Mapped[Decimal | None] = mapped_column(
        Numeric(19, 4),
        nullable=True,
    )
    closing_cash_expected: Mapped[Decimal | None] = mapped_column(
        Numeric(19, 4),
        nullable=True,
    )
    cash_difference: Mapped[Decimal | None] = mapped_column(
        Numeric(19, 4),
        nullable=True,
    )  # counted - expected (negative=shortage, positive=overage, 0=balanced)
    opening_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    closing_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    denominations_json: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        server_default=text("'{}'::jsonb"),
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    branch: Mapped["Branch"] = relationship("Branch")  # type: ignore[name-defined] # noqa: F821
    user: Mapped["User"] = relationship("User")  # type: ignore[name-defined] # noqa: F821
