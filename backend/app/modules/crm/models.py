"""SQLAlchemy models for Loyalty, Membership Tiers, Gift Cards, Credit Notes, and CRM."""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class LoyaltySettings(Base):
    """Business-level loyalty program rules and point valuation parameters."""

    __tablename__ = "loyalty_settings"
    __table_args__ = (
        UniqueConstraint("business_id", name="uq_loyalty_settings_business"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    is_enabled: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=text("true")
    )
    earn_rate: Mapped[Decimal] = mapped_column(
        Numeric(10, 4), nullable=False, default=Decimal("1.0000"), server_default=text("1.0000")
    )  # Points earned per 100 currency units spent
    redeem_rate: Mapped[Decimal] = mapped_column(
        Numeric(10, 4), nullable=False, default=Decimal("0.1000"), server_default=text("0.1000")
    )  # Currency value per point (e.g. 1 point = 0.10 BDT)
    min_redeem_points: Mapped[int] = mapped_column(
        Integer, nullable=False, default=100, server_default=text("100")
    )  # Minimum threshold before points can be used as payment
    points_expiry_days: Mapped[int] = mapped_column(
        Integer, nullable=False, default=365, server_default=text("365")
    )  # Days before unredeemed points expire (0 = never)
    max_cart_discount_pct: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), nullable=False, default=Decimal("50.00"), server_default=text("50.00")
    )  # Maximum % of order total that can be settled via points
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("clock_timestamp()"),
        nullable=False,
    )


class MembershipTier(Base):
    """Tiered VIP loyalty level based on customer lifetime spend."""

    __tablename__ = "membership_tiers"
    __table_args__ = (
        UniqueConstraint("business_id", "code", name="uq_membership_tiers_business_code"),
        CheckConstraint("min_spend >= 0", name="chk_tier_min_spend_non_negative"),
        CheckConstraint("points_multiplier > 0", name="chk_tier_multiplier_positive"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    code: Mapped[str] = mapped_column(String(30), nullable=False)
    min_spend: Mapped[Decimal] = mapped_column(
        Numeric(19, 4), nullable=False, default=Decimal("0.0000"), server_default=text("0.0000")
    )
    points_multiplier: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), nullable=False, default=Decimal("1.00"), server_default=text("1.00")
    )
    discount_pct: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), nullable=False, default=Decimal("0.00"), server_default=text("0.00")
    )
    badge_color: Mapped[str] = mapped_column(
        String(20), nullable=False, default="#64748B", server_default=text("'#64748B'")
    )
    perks_description: Mapped[str | None] = mapped_column(Text, nullable=True)
    sort_order: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default=text("0")
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=text("true")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("clock_timestamp()"),
        nullable=False,
    )


class LoyaltyTransaction(Base):
    """Immutable ledger record for loyalty points earned, redeemed, or adjusted."""

    __tablename__ = "loyalty_transactions"
    __table_args__ = (
        CheckConstraint("points_balance_after >= 0", name="chk_loyalty_balance_non_negative"),
        Index("ix_loyalty_tx_customer", "customer_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("customers.id", ondelete="RESTRICT"),
        nullable=False,
    )
    sale_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sales.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    transaction_type: Mapped[str] = mapped_column(
        String(20), nullable=False
    )  # EARN, REDEEM, ADJUSTMENT, EXPIRE, BONUS
    points: Mapped[int] = mapped_column(Integer, nullable=False)
    points_balance_after: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("clock_timestamp()"),
        nullable=False,
    )


class GiftCard(Base):
    """Stored-value gift card authenticated with hashed PIN."""

    __tablename__ = "gift_cards"
    __table_args__ = (
        UniqueConstraint("business_id", "card_number", name="uq_gift_cards_business_number"),
        CheckConstraint("current_balance >= 0", name="chk_gift_card_balance_non_negative"),
        CheckConstraint("initial_balance >= 0", name="chk_gift_card_initial_non_negative"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    card_number: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    pin_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    initial_balance: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    current_balance: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="ACTIVE", server_default=text("'ACTIVE'")
    )  # ACTIVE, DEPLETED, EXPIRED, LOCKED, CANCELLED
    purchaser_customer_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("customers.id", ondelete="SET NULL"),
        nullable=True,
    )
    recipient_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    recipient_phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    recipient_email: Mapped[str | None] = mapped_column(String(100), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("clock_timestamp()"),
        nullable=False,
    )

    transactions: Mapped[list["GiftCardTransaction"]] = relationship(
        "GiftCardTransaction", back_populates="gift_card"
    )


class GiftCardTransaction(Base):
    """Ledger of debits, reloads, and issuances on a gift card."""

    __tablename__ = "gift_card_transactions"
    __table_args__ = (
        CheckConstraint("balance_after >= 0", name="chk_gift_card_tx_balance_non_negative"),
        Index("ix_gift_card_tx_card", "gift_card_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    gift_card_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("gift_cards.id", ondelete="RESTRICT"),
        nullable=False,
    )
    sale_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sales.id", ondelete="SET NULL"),
        nullable=True,
    )
    transaction_type: Mapped[str] = mapped_column(
        String(20), nullable=False
    )  # ISSUE, RELOAD, REDEEM, ADJUSTMENT, VOID
    amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    balance_after: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("clock_timestamp()"),
        nullable=False,
    )

    gift_card: Mapped["GiftCard"] = relationship("GiftCard", back_populates="transactions")


class CreditNote(Base):
    """Non-cash credit voucher issued for sale returns or customer overpayments."""

    __tablename__ = "credit_notes"
    __table_args__ = (
        UniqueConstraint("business_id", "note_number", name="uq_credit_notes_business_number"),
        CheckConstraint("remaining_balance >= 0", name="chk_credit_note_balance_non_negative"),
        CheckConstraint("initial_amount >= 0", name="chk_credit_note_initial_non_negative"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("customers.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    sale_return_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("returns.id", ondelete="SET NULL"),
        nullable=True,
    )
    note_number: Mapped[str] = mapped_column(String(50), nullable=False)
    initial_amount: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    remaining_balance: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="ACTIVE", server_default=text("'ACTIVE'")
    )  # ACTIVE, EXHAUSTED, EXPIRED, VOIDED
    reason: Mapped[str] = mapped_column(String(255), nullable=False)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("clock_timestamp()"),
        nullable=False,
    )


class PromotionalCampaign(Base):
    """Marketing and broadcast campaign directed at specific customer segments."""

    __tablename__ = "promotional_campaigns"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    target_segment: Mapped[str] = mapped_column(
        String(50), nullable=False, default="ALL", server_default=text("'ALL'")
    )  # ALL, CHAMPIONS, LOYAL, POTENTIAL, AT_RISK, LOST, GROUP
    target_group_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("customer_groups.id", ondelete="SET NULL"),
        nullable=True,
    )
    channel: Mapped[str] = mapped_column(
        String(20), nullable=False, default="SMS", server_default=text("'SMS'")
    )  # SMS, EMAIL, WHATSAPP, IN_APP
    message_template: Mapped[str] = mapped_column(Text, nullable=False)
    promotion_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("promotions.id", ondelete="SET NULL"),
        nullable=True,
    )
    audience_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default=text("0")
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="DRAFT", server_default=text("'DRAFT'")
    )  # DRAFT, SCHEDULED, SENT, ARCHIVED
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=text("clock_timestamp()"),
        nullable=False,
    )

