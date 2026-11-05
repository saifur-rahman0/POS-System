"""Pricing, price lists, customer groups, bundles, and promotions models."""

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class CustomerGroup(Base):
    """Customer classification tier for pricing and loyalty segmentation."""

    __tablename__ = "customer_groups"
    __table_args__ = (
        UniqueConstraint("business_id", "name", name="uq_customer_groups_business_name"),
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
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    members: Mapped[list["CustomerGroupMember"]] = relationship(
        "CustomerGroupMember", back_populates="customer_group", cascade="all, delete-orphan"
    )


class CustomerGroupMember(Base):
    """Join entity between customer groups and individual customers."""

    __tablename__ = "customer_group_members"
    __table_args__ = (
        UniqueConstraint(
            "customer_group_id", "customer_id", name="uq_customer_group_members_group_customer"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    customer_group_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("customer_groups.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("customers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    customer_group: Mapped["CustomerGroup"] = relationship("CustomerGroup", back_populates="members")


class PriceList(Base):
    """Named pricing schedule (e.g. Retail, Wholesale, VIP)."""

    __tablename__ = "price_lists"
    __table_args__ = (
        UniqueConstraint("business_id", "name", name="uq_price_lists_business_name"),
        Index(
            "uq_price_lists_business_default",
            "business_id",
            unique=True,
            postgresql_where=text("is_default = true"),
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
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    currency: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        default="BDT",
        server_default=text("'BDT'"),
    )
    is_default: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    customer_group_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("customer_groups.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    items: Mapped[list["PriceListItem"]] = relationship(
        "PriceListItem", back_populates="price_list", cascade="all, delete-orphan"
    )
    customer_group: Mapped["CustomerGroup | None"] = relationship("CustomerGroup")


class PriceListItem(Base):
    """Specific variant price in a price list with quantity break and scheduling."""

    __tablename__ = "price_list_items"
    __table_args__ = (
        UniqueConstraint(
            "price_list_id",
            "product_variant_id",
            "min_quantity",
            name="uq_price_list_items_list_var_minqty",
        ),
        CheckConstraint("min_quantity > 0", name="chk_price_list_items_min_qty_pos"),
        CheckConstraint("price >= 0", name="chk_price_list_items_price_non_neg"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    price_list_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("price_lists.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("product_variants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    min_quantity: Mapped[Decimal] = mapped_column(
        Numeric(12, 4),
        nullable=False,
        default=Decimal("1.0000"),
        server_default=text("1.0000"),
    )
    price: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    price_list: Mapped["PriceList"] = relationship("PriceList", back_populates="items")


class BranchPriceOverride(Base):
    """Branch-specific price override for a product variant (highest priority)."""

    __tablename__ = "branch_price_overrides"
    __table_args__ = (
        UniqueConstraint("branch_id", "product_variant_id", name="uq_branch_overrides_branch_variant"),
        CheckConstraint("selling_price >= 0", name="chk_branch_overrides_price_non_neg"),
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
        ForeignKey("branches.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("product_variants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    selling_price: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class ProductBundle(Base):
    """Parent bundle or kit linked to a composite product."""

    __tablename__ = "product_bundles"
    __table_args__ = (
        UniqueConstraint("business_id", "product_id", name="uq_product_bundles_business_product"),
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
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    bundle_price: Mapped[Decimal | None] = mapped_column(Numeric(19, 4), nullable=True)
    is_kit: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    items: Mapped[list["ProductBundleItem"]] = relationship(
        "ProductBundleItem", back_populates="bundle", cascade="all, delete-orphan"
    )


class ProductBundleItem(Base):
    """Component variant required for a bundle."""

    __tablename__ = "product_bundle_items"
    __table_args__ = (
        UniqueConstraint("bundle_id", "component_variant_id", name="uq_product_bundle_items_bundle_component"),
        CheckConstraint("quantity > 0", name="chk_product_bundle_items_qty_pos"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    bundle_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("product_bundles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    component_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("product_variants.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    quantity: Mapped[Decimal] = mapped_column(Numeric(12, 4), nullable=False)
    is_optional: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )

    bundle: Mapped["ProductBundle"] = relationship("ProductBundle", back_populates="items")


class Promotion(Base):
    """Promotional campaign or coupon code."""

    __tablename__ = "promotions"
    __table_args__ = (
        Index(
            "uq_promotions_business_code",
            "business_id",
            "code",
            unique=True,
            postgresql_where=text("code IS NOT NULL"),
        ),
        CheckConstraint("discount_value > 0", name="chk_promotions_discount_value_pos"),
        CheckConstraint("min_spend >= 0", name="chk_promotions_min_spend_non_neg"),
        CheckConstraint("times_used >= 0", name="chk_promotions_times_used_non_neg"),
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
    code: Mapped[str | None] = mapped_column(String(50), nullable=True)
    discount_type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )  # PERCENTAGE | FIXED_AMOUNT
    discount_value: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    min_spend: Mapped[Decimal] = mapped_column(
        Numeric(19, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    max_discount_cap: Mapped[Decimal | None] = mapped_column(Numeric(19, 4), nullable=True)
    usage_limit: Mapped[int | None] = mapped_column(Integer, nullable=True)
    times_used: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default=text("0"),
    )
    valid_from: Mapped[date] = mapped_column(Date, nullable=False)
    valid_until: Mapped[date] = mapped_column(Date, nullable=False)
    applies_to: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="ALL",
        server_default=text("'ALL'"),
    )  # ALL | CATEGORY | PRODUCT
    scope_ids: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        default=list,
        server_default=text("'[]'::jsonb"),
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    usages: Mapped[list["PromotionUsage"]] = relationship(
        "PromotionUsage", back_populates="promotion"
    )


class PromotionUsage(Base):
    """Audit log of promotion / coupon redemptions."""

    __tablename__ = "promotion_usages"
    __table_args__ = (
        UniqueConstraint("promotion_id", "sale_id", name="uq_promotion_usages_promo_sale"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    promotion_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("promotions.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    sale_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sales.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    discount_applied: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    used_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    promotion: Mapped["Promotion"] = relationship("Promotion", back_populates="usages")
