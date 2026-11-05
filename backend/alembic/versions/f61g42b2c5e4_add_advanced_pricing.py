"""add_advanced_pricing

Revision ID: f61g42b2c5e4
Revises: e50f31a1b4d3
Create Date: 2026-11-05 11:30:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'f61g42b2c5e4'
down_revision: str | None = 'e50f31a1b4d3'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. customer_groups
    op.create_table(
        'customer_groups',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('business_id', 'name', name='uq_customer_groups_business_name'),
    )
    op.create_index('ix_customer_groups_business', 'customer_groups', ['business_id'])

    # 2. customer_group_members
    op.create_table(
        'customer_group_members',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('customer_group_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customer_groups.id', ondelete='CASCADE'), nullable=False),
        sa.Column('customer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customers.id', ondelete='CASCADE'), nullable=False),
        sa.Column('assigned_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('customer_group_id', 'customer_id', name='uq_customer_group_members_group_customer'),
    )
    op.create_index('ix_customer_group_members_group', 'customer_group_members', ['customer_group_id'])
    op.create_index('ix_customer_group_members_customer', 'customer_group_members', ['customer_id'])

    # 3. price_lists
    op.create_table(
        'price_lists',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('currency', sa.String(length=10), nullable=False, server_default=sa.text("'BDT'")),
        sa.Column('is_default', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('customer_group_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customer_groups.id', ondelete='SET NULL'), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now(), nullable=False),
        sa.UniqueConstraint('business_id', 'name', name='uq_price_lists_business_name'),
    )
    op.create_index('ix_price_lists_business', 'price_lists', ['business_id'])
    op.create_index(
        'uq_price_lists_business_default',
        'price_lists',
        ['business_id'],
        unique=True,
        postgresql_where=sa.text('is_default = true'),
    )

    # 4. price_list_items
    op.create_table(
        'price_list_items',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('price_list_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('price_lists.id', ondelete='CASCADE'), nullable=False),
        sa.Column('product_variant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('product_variants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('min_quantity', sa.Numeric(precision=12, scale=4), nullable=False, server_default=sa.text('1.0000')),
        sa.Column('price', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('start_date', sa.Date(), nullable=True),
        sa.Column('end_date', sa.Date(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('price_list_id', 'product_variant_id', 'min_quantity', name='uq_price_list_items_list_var_minqty'),
        sa.CheckConstraint('min_quantity > 0', name='chk_price_list_items_min_qty_pos'),
        sa.CheckConstraint('price >= 0', name='chk_price_list_items_price_non_neg'),
    )
    op.create_index('ix_price_list_items_variant', 'price_list_items', ['product_variant_id'])
    op.create_index('ix_price_list_items_list', 'price_list_items', ['price_list_id'])

    # 5. branch_price_overrides
    op.create_table(
        'branch_price_overrides',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('branch_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('branches.id', ondelete='CASCADE'), nullable=False),
        sa.Column('product_variant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('product_variants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('selling_price', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now(), nullable=False),
        sa.UniqueConstraint('branch_id', 'product_variant_id', name='uq_branch_overrides_branch_variant'),
        sa.CheckConstraint('selling_price >= 0', name='chk_branch_overrides_price_non_neg'),
    )
    op.create_index('ix_branch_overrides_business', 'branch_price_overrides', ['business_id'])
    op.create_index('ix_branch_overrides_branch', 'branch_price_overrides', ['branch_id'])
    op.create_index('ix_branch_overrides_variant', 'branch_price_overrides', ['product_variant_id'])

    # 6. product_bundles
    op.create_table(
        'product_bundles',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('product_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('products.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('bundle_price', sa.Numeric(precision=19, scale=4), nullable=True),
        sa.Column('is_kit', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('business_id', 'product_id', name='uq_product_bundles_business_product'),
    )
    op.create_index('ix_product_bundles_business', 'product_bundles', ['business_id'])

    # 7. product_bundle_items
    op.create_table(
        'product_bundle_items',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('bundle_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('product_bundles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('component_variant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('product_variants.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('quantity', sa.Numeric(precision=12, scale=4), nullable=False),
        sa.Column('is_optional', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.UniqueConstraint('bundle_id', 'component_variant_id', name='uq_product_bundle_items_bundle_component'),
        sa.CheckConstraint('quantity > 0', name='chk_product_bundle_items_qty_pos'),
    )
    op.create_index('ix_product_bundle_items_bundle', 'product_bundle_items', ['bundle_id'])
    op.create_index('ix_product_bundle_items_component', 'product_bundle_items', ['component_variant_id'])

    # 8. promotions
    op.create_table(
        'promotions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('code', sa.String(length=50), nullable=True),
        sa.Column('discount_type', sa.String(length=20), nullable=False),
        sa.Column('discount_value', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('min_spend', sa.Numeric(precision=19, scale=4), nullable=False, server_default=sa.text('0.0000')),
        sa.Column('max_discount_cap', sa.Numeric(precision=19, scale=4), nullable=True),
        sa.Column('usage_limit', sa.Integer(), nullable=True),
        sa.Column('times_used', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('valid_from', sa.Date(), nullable=False),
        sa.Column('valid_until', sa.Date(), nullable=False),
        sa.Column('applies_to', sa.String(length=20), nullable=False, server_default=sa.text("'ALL'")),
        sa.Column('scope_ids', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'[]'::jsonb")),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now(), nullable=False),
        sa.CheckConstraint('discount_value > 0', name='chk_promotions_discount_value_pos'),
        sa.CheckConstraint('min_spend >= 0', name='chk_promotions_min_spend_non_neg'),
        sa.CheckConstraint('times_used >= 0', name='chk_promotions_times_used_non_neg'),
    )
    op.create_index('ix_promotions_business', 'promotions', ['business_id'])
    op.create_index(
        'uq_promotions_business_code',
        'promotions',
        ['business_id', 'code'],
        unique=True,
        postgresql_where=sa.text('code IS NOT NULL'),
    )

    # 9. promotion_usages
    op.create_table(
        'promotion_usages',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('promotion_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('promotions.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('sale_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('sales.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('discount_applied', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('used_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('promotion_id', 'sale_id', name='uq_promotion_usages_promo_sale'),
    )
    op.create_index('ix_promotion_usages_promo', 'promotion_usages', ['promotion_id'])
    op.create_index('ix_promotion_usages_sale', 'promotion_usages', ['sale_id'])

    # 10. alter customers: add primary_group_id
    op.add_column(
        'customers',
        sa.Column('primary_group_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customer_groups.id', ondelete='SET NULL'), nullable=True),
    )
    op.create_index('ix_customers_primary_group', 'customers', ['primary_group_id'])

    # 11. alter sales: add promotion and price list columns
    op.add_column(
        'sales',
        sa.Column('promotion_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('promotions.id', ondelete='SET NULL'), nullable=True),
    )
    op.add_column(
        'sales',
        sa.Column('promotion_code', sa.String(length=50), nullable=True),
    )
    op.add_column(
        'sales',
        sa.Column('promotion_discount', sa.Numeric(precision=19, scale=4), nullable=False, server_default=sa.text('0.0000')),
    )
    op.add_column(
        'sales',
        sa.Column('price_list_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('price_lists.id', ondelete='SET NULL'), nullable=True),
    )
    op.create_index('ix_sales_promotion_id', 'sales', ['promotion_id'])
    op.create_index('ix_sales_price_list_id', 'sales', ['price_list_id'])


def downgrade() -> None:
    op.drop_index('ix_sales_price_list_id', table_name='sales')
    op.drop_index('ix_sales_promotion_id', table_name='sales')
    op.drop_column('sales', 'price_list_id')
    op.drop_column('sales', 'promotion_discount')
    op.drop_column('sales', 'promotion_code')
    op.drop_column('sales', 'promotion_id')

    op.drop_index('ix_customers_primary_group', table_name='customers')
    op.drop_column('customers', 'primary_group_id')

    op.drop_table('promotion_usages')
    op.drop_table('promotions')
    op.drop_table('product_bundle_items')
    op.drop_table('product_bundles')
    op.drop_table('branch_price_overrides')
    op.drop_table('price_list_items')
    op.drop_table('price_lists')
    op.drop_table('customer_group_members')
    op.drop_table('customer_groups')
