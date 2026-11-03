"""Retail sales, customer, POS checkout items, and payment tender models."""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
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


class Customer(Base):
    """Store customer or retail buyer profile."""

    __tablename__ = "customers"
    __table_args__ = (
        CheckConstraint("credit_limit >= 0", name="chk_customer_credit_limit_non_negative"),
        Index(
            "uq_customers_business_phone",
            "business_id",
            "phone",
            unique=True,
            postgresql_where=text("phone IS NOT NULL"),
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
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True, index=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    credit_limit: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )


class Sale(Base):
    """Authoritative sales receipt and checkout transaction header."""

    __tablename__ = "sales"
    __table_args__ = (
        UniqueConstraint("business_id", "receipt_no", name="uq_sales_business_receipt_no"),
        UniqueConstraint(
            "business_id", "idempotency_key", name="uq_sales_business_idempotency_key"
        ),
        CheckConstraint("subtotal >= 0", name="chk_sale_subtotal_non_negative"),
        CheckConstraint("discount_total >= 0", name="chk_sale_discount_non_negative"),
        CheckConstraint("tax_total >= 0", name="chk_sale_tax_non_negative"),
        CheckConstraint("grand_total >= 0", name="chk_sale_grand_total_non_negative"),
        CheckConstraint("paid_total >= 0", name="chk_sale_paid_total_non_negative"),
        CheckConstraint("due_total >= 0", name="chk_sale_due_total_non_negative"),
        Index("ix_sales_business_branch_date", "business_id", "branch_id", text("created_at DESC")),
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
    receipt_no: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    customer_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("customers.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    cashier_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="COMPLETED",
        server_default="COMPLETED",
    )  # COMPLETED, VOID, REFUNDED, PARTIALLY_REFUNDED
    subtotal: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    discount_total: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    tax_total: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    grand_total: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    paid_total: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    due_total: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    idempotency_key: Mapped[str] = mapped_column(String(255), nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    items: Mapped[list["SaleItem"]] = relationship("SaleItem", back_populates="sale")
    payments: Mapped[list["PaymentTender"]] = relationship("PaymentTender", back_populates="sale")


class SaleItem(Base):
    """Individual line item sold on a sales receipt."""

    __tablename__ = "sale_items"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="chk_sale_item_qty_positive"),
        CheckConstraint("unit_price >= 0", name="chk_sale_item_price_non_negative"),
        CheckConstraint("unit_cost_snapshot >= 0", name="chk_sale_item_cost_snapshot_non_negative"),
        CheckConstraint("discount >= 0", name="chk_sale_item_discount_non_negative"),
        CheckConstraint("line_total >= 0", name="chk_sale_item_total_non_negative"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    sale_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sales.id", ondelete="RESTRICT"),
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
    quantity: Mapped[Decimal] = mapped_column(Numeric(12, 4), nullable=False)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    unit_cost_snapshot: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    discount: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    line_total: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)

    sale: Mapped["Sale"] = relationship("Sale", back_populates="items")


class PaymentTender(Base):
    """Payment allocation against a sale."""

    __tablename__ = "payment_tenders"
    __table_args__ = (CheckConstraint("amount > 0", name="chk_payment_tender_amount_positive"),)

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
    sale_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sales.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    method: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
    )  # CASH, CARD, BKASH, NAGAD, ROCKET, DUE
    amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="CONFIRMED",
        server_default="CONFIRMED",
    )  # CONFIRMED, VOIDED
    received_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )

    sale: Mapped["Sale"] = relationship("Sale", back_populates="payments")
