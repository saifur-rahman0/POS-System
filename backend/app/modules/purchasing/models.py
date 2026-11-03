"""Supplier purchasing, invoice line items, and supplier payment models."""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
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


class Supplier(Base):
    """Vendor or wholesale distributor supplying products."""

    __tablename__ = "suppliers"
    __table_args__ = (UniqueConstraint("business_id", "name", name="uq_suppliers_business_name"),)

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
    contact_person: Mapped[str | None] = mapped_column(String(255), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
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


class Purchase(Base):
    """Purchase order / received supplier invoice header."""

    __tablename__ = "purchases"
    __table_args__ = (
        UniqueConstraint("business_id", "reference_no", name="uq_purchases_business_reference_no"),
        CheckConstraint("subtotal >= 0", name="chk_purchase_subtotal_non_negative"),
        CheckConstraint("discount >= 0", name="chk_purchase_discount_non_negative"),
        CheckConstraint("total >= 0", name="chk_purchase_total_non_negative"),
        CheckConstraint("paid_total >= 0", name="chk_purchase_paid_total_non_negative"),
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
    supplier_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("suppliers.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    reference_no: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="ORDERED",
        server_default="ORDERED",
    )  # ORDERED, RECEIVED, PARTIAL, CANCELLED
    subtotal: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    discount: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    total: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    paid_total: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
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

    items: Mapped[list["PurchaseItem"]] = relationship("PurchaseItem", back_populates="purchase")
    payments: Mapped[list["PurchasePayment"]] = relationship(
        "PurchasePayment", back_populates="purchase"
    )


class PurchaseItem(Base):
    """Line item on a supplier purchase order/invoice."""

    __tablename__ = "purchase_items"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="chk_purchase_item_qty_positive"),
        CheckConstraint("unit_cost >= 0", name="chk_purchase_item_cost_non_negative"),
        CheckConstraint("line_total >= 0", name="chk_purchase_item_total_non_negative"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    purchase_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("purchases.id", ondelete="RESTRICT"),
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
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    line_total: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)

    purchase: Mapped["Purchase"] = relationship("Purchase", back_populates="items")


class PurchasePayment(Base):
    """Disbursement or payment applied against a purchase order."""

    __tablename__ = "purchase_payments"
    __table_args__ = (CheckConstraint("amount > 0", name="chk_purchase_payment_amount_positive"),)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    purchase_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("purchases.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    method: Mapped[str] = mapped_column(
        String(32), nullable=False
    )  # CASH, BANK, BKASH, NAGAD, CHEQUE
    reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    paid_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )

    purchase: Mapped["Purchase"] = relationship("Purchase", back_populates="payments")
