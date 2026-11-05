"""Product catalog, category, brand, variant, and IMEI serialization models."""

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    ForeignKey,
    Index,
    Numeric,
    String,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Category(Base):
    """Hierarchical category classification for products."""

    __tablename__ = "categories"
    __table_args__ = (
        UniqueConstraint(
            "business_id", "parent_id", "name", name="uq_categories_business_parent_name"
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
    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )

    parent: Mapped["Category | None"] = relationship("Category", remote_side="Category.id")


class Brand(Base):
    """Manufacturer or brand classification."""

    __tablename__ = "brands"
    __table_args__ = (UniqueConstraint("business_id", "name", name="uq_brands_business_name"),)

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
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )


class Product(Base):
    """High-level catalog product entity."""

    __tablename__ = "products"
    __table_args__ = (UniqueConstraint("business_id", "sku", name="uq_products_business_sku"),)

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
    sku: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    category_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    brand_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("brands.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    product_type: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="STANDARD",
        server_default="STANDARD",
    )  # STANDARD, SERIALIZED_IMEI, SERVICE
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
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    variants: Mapped[list["ProductVariant"]] = relationship(
        "ProductVariant", back_populates="product"
    )
    category: Mapped["Category | None"] = relationship("Category")
    brand: Mapped["Brand | None"] = relationship("Brand")


class ProductVariant(Base):
    """Sellable and stockable SKU item variant (e.g. size/color/specs)."""

    __tablename__ = "product_variants"
    __table_args__ = (
        CheckConstraint("selling_price >= 0", name="chk_variant_selling_price_non_negative"),
        CheckConstraint("cost_price >= 0", name="chk_variant_cost_price_non_negative"),
        Index(
            "uq_variants_business_barcode",
            "business_id",
            "barcode",
            unique=True,
            postgresql_where=text("barcode IS NOT NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    business_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    barcode: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    attributes_json: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        server_default=text("'{}'::jsonb"),
    )
    selling_price: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    cost_price: Mapped[Decimal] = mapped_column(Numeric(19, 4), nullable=False)
    track_stock: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    has_batch_tracking: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    min_stock_level: Mapped[Decimal] = mapped_column(
        Numeric(12, 4),
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0.0000"),
    )
    reorder_quantity: Mapped[Decimal] = mapped_column(
        Numeric(12, 4),
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
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    product: Mapped["Product"] = relationship("Product", back_populates="variants")


class ImeiDevice(Base):
    """Individually serialized mobile handset or serialized hardware device."""

    __tablename__ = "imei_devices"
    __table_args__ = (
        UniqueConstraint("business_id", "imei1", name="uq_imei_devices_business_imei1"),
        Index(
            "uq_imei_devices_business_imei2",
            "business_id",
            "imei2",
            unique=True,
            postgresql_where=text("imei2 IS NOT NULL"),
        ),
        Index(
            "uq_imei_devices_business_serial",
            "business_id",
            "serial_number",
            unique=True,
            postgresql_where=text("serial_number IS NOT NULL"),
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
    imei1: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    imei2: Mapped[str | None] = mapped_column(String(30), nullable=True, index=True)
    serial_number: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    purchase_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("purchases.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="IN_STOCK",
        server_default="IN_STOCK",
    )  # IN_STOCK, SOLD, RETURNED, DEFECTIVE, IN_TRANSFER
    sold_sale_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey(
            "sale_items.id",
            ondelete="RESTRICT",
            use_alter=True,
            name="fk_imei_devices_sold_sale_item_id",
        ),
        nullable=True,
        index=True,
    )
    warranty_end: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
