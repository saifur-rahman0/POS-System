"""Sales return, credit memo, and restocked item models."""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Return(Base):
    """Customer return / credit note header."""

    __tablename__ = "returns"
    __table_args__ = (
        UniqueConstraint("business_id", "return_no", name="uq_returns_business_return_no"),
        CheckConstraint("refund_total >= 0", name="chk_return_refund_total_non_negative"),
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
    original_sale_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sales.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    return_no: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="COMPLETED",
        server_default="COMPLETED",
    )  # COMPLETED, CANCELLED
    refund_total: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )

    items: Mapped[list["ReturnItem"]] = relationship("ReturnItem", back_populates="return_order")


class ReturnItem(Base):
    """Individual product returned from a sale item."""

    __tablename__ = "return_items"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="chk_return_item_qty_positive"),
        CheckConstraint("refund_amount >= 0", name="chk_return_item_refund_non_negative"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    return_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("returns.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    original_sale_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sale_items.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("product_variants.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    quantity: Mapped[Decimal] = mapped_column(Numeric(12, 4), nullable=False)
    refund_amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    restock_status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="RESTOCKED",
        server_default="RESTOCKED",
    )  # RESTOCKED, DEFECTIVE, SCRAPPED

    return_order: Mapped["Return"] = relationship("Return", back_populates="items")
