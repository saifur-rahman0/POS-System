"""Inventory ledger (stock movements), physical balances, and stock count models."""

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
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class StockMovement(Base):
    """Immutable, append-only inventory ledger record."""

    __tablename__ = "stock_movements"
    __table_args__ = (
        CheckConstraint("unit_cost >= 0", name="chk_stock_movement_cost_non_negative"),
        Index(
            "ix_stock_movements_business_branch_date",
            "business_id",
            "branch_id",
            text("created_at DESC"),
        ),
        Index(
            "ix_stock_movements_business_variant",
            "business_id",
            "product_variant_id",
        ),
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
    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("product_variants.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    imei_device_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("imei_devices.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    movement_type: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
    )  # PURCHASE_RECEIVE, SALE, SALE_RETURN, PURCHASE_RETURN, ADJUSTMENT_UP, ADJUSTMENT_DOWN, TRANSFER_IN, TRANSFER_OUT
    quantity_delta: Mapped[Decimal] = mapped_column(
        Numeric(12, 4),
        nullable=False,
    )  # Positive for additions, negative for deductions
    unit_cost: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
    )
    reference_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )  # SALE, PURCHASE, RETURN, STOCK_COUNT, TRANSFER
    reference_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
        index=True,
    )


class StockBalance(Base):
    """Authoritative fast operational quantity on hand per variant and branch."""

    __tablename__ = "stock_balances"
    __table_args__ = (
        CheckConstraint("quantity_on_hand >= 0", name="chk_stock_balance_non_negative"),
        Index("ix_stock_balances_branch_qty", "business_id", "branch_id", "quantity_on_hand"),
    )

    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        primary_key=True,
    )
    branch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", ondelete="RESTRICT"),
        primary_key=True,
    )
    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("product_variants.id", ondelete="RESTRICT"),
        primary_key=True,
    )
    quantity_on_hand: Mapped[Decimal] = mapped_column(
        Numeric(12, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class StockCount(Base):
    """Periodic physical inventory audit and count session."""

    __tablename__ = "stock_counts"

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
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="DRAFT",
        server_default="DRAFT",
    )  # DRAFT, IN_PROGRESS, COMPLETED, CANCELLED
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    approved_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )
    completed_at: Mapped[datetime | None] = mapped_column(nullable=True)

    lines: Mapped[list["StockCountLine"]] = relationship(
        "StockCountLine",
        back_populates="stock_count",
        cascade="all, delete-orphan",
    )


class StockCountLine(Base):
    """Individual variant tally inside a stock count session."""

    __tablename__ = "stock_count_lines"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    stock_count_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("stock_counts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("product_variants.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    expected_qty: Mapped[Decimal] = mapped_column(Numeric(12, 4), nullable=False)
    counted_qty: Mapped[Decimal] = mapped_column(Numeric(12, 4), nullable=False)
    discrepancy_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    stock_count: Mapped["StockCount"] = relationship("StockCount", back_populates="lines")


class StockTransfer(Base):
    """Inter-branch stock transfer shipment."""

    __tablename__ = "stock_transfers"
    __table_args__ = (
        UniqueConstraint("business_id", "transfer_no", name="uq_stock_transfers_business_no"),
        CheckConstraint(
            "source_branch_id != destination_branch_id",
            name="chk_stock_transfer_distinct_branches",
        ),
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
    transfer_no: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
    )
    source_branch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    destination_branch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="DRAFT",
        server_default="DRAFT",
    )  # DRAFT, IN_TRANSIT, RECEIVED, CANCELLED
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    received_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )
    sent_at: Mapped[datetime | None] = mapped_column(nullable=True)
    received_at: Mapped[datetime | None] = mapped_column(nullable=True)

    items: Mapped[list["StockTransferItem"]] = relationship(
        "StockTransferItem",
        back_populates="transfer",
        cascade="all, delete-orphan",
    )


class StockTransferItem(Base):
    """Line item within an inter-branch transfer."""

    __tablename__ = "stock_transfer_items"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="chk_stock_transfer_item_qty_positive"),
        CheckConstraint("unit_cost >= 0", name="chk_stock_transfer_item_cost_non_negative"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    transfer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("stock_transfers.id", ondelete="CASCADE"),
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
    unit_cost: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )

    transfer: Mapped["StockTransfer"] = relationship("StockTransfer", back_populates="items")
