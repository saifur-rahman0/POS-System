"""add_held_carts_and_quotations

Revision ID: c38f19e4a2b1
Revises: 254c6db01cfc
Create Date: 2026-11-05 01:00:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'c38f19e4a2b1'
down_revision: str | None = '254c6db01cfc'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Create held_carts table
    op.create_table(
        'held_carts',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('business_id', sa.UUID(), nullable=False),
        sa.Column('branch_id', sa.UUID(), nullable=False),
        sa.Column('cashier_id', sa.UUID(), nullable=False),
        sa.Column('customer_id', sa.UUID(), nullable=True),
        sa.Column('customer_name', sa.String(length=255), nullable=True),
        sa.Column('label', sa.String(length=100), nullable=True),
        sa.Column('cart_items_json', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('cart_discount', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('tax_rate', sa.Numeric(precision=5, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('delivery_charge', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['business_id'], ['businesses.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['cashier_id'], ['users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['customer_id'], ['customers.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_held_carts_business_id'), 'held_carts', ['business_id'], unique=False)
    op.create_index(op.f('ix_held_carts_branch_id'), 'held_carts', ['branch_id'], unique=False)
    op.create_index(op.f('ix_held_carts_cashier_id'), 'held_carts', ['cashier_id'], unique=False)
    op.create_index(op.f('ix_held_carts_customer_id'), 'held_carts', ['customer_id'], unique=False)

    # 2. Create quotations table
    op.create_table(
        'quotations',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('business_id', sa.UUID(), nullable=False),
        sa.Column('branch_id', sa.UUID(), nullable=False),
        sa.Column('quotation_no', sa.String(length=100), nullable=False),
        sa.Column('customer_id', sa.UUID(), nullable=True),
        sa.Column('customer_name', sa.String(length=255), nullable=True),
        sa.Column('status', sa.String(length=32), server_default='DRAFT', nullable=False),
        sa.Column('subtotal', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('discount_total', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('tax_total', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('delivery_charge', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('grand_total', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('valid_until', sa.DateTime(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_by', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.Column('converted_sale_id', sa.UUID(), nullable=True),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['business_id'], ['businesses.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['converted_sale_id'], ['sales.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['customer_id'], ['customers.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('business_id', 'quotation_no', name='uq_quotations_business_no')
    )
    op.create_index(op.f('ix_quotations_business_id'), 'quotations', ['business_id'], unique=False)
    op.create_index(op.f('ix_quotations_branch_id'), 'quotations', ['branch_id'], unique=False)
    op.create_index(op.f('ix_quotations_created_by'), 'quotations', ['created_by'], unique=False)
    op.create_index(op.f('ix_quotations_customer_id'), 'quotations', ['customer_id'], unique=False)
    op.create_index(op.f('ix_quotations_quotation_no'), 'quotations', ['quotation_no'], unique=False)

    # 3. Create quotation_items table
    op.create_table(
        'quotation_items',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('quotation_id', sa.UUID(), nullable=False),
        sa.Column('product_variant_id', sa.UUID(), nullable=False),
        sa.Column('quantity', sa.Numeric(precision=12, scale=4), nullable=False),
        sa.Column('unit_price', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('discount', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('line_total', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.ForeignKeyConstraint(['product_variant_id'], ['product_variants.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['quotation_id'], ['quotations.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_quotation_items_product_variant_id'), 'quotation_items', ['product_variant_id'], unique=False)
    op.create_index(op.f('ix_quotation_items_quotation_id'), 'quotation_items', ['quotation_id'], unique=False)

    # 4. Alter sales table
    op.add_column('sales', sa.Column('delivery_charge', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False))
    op.add_column('sales', sa.Column('sale_type', sa.String(length=32), server_default='RETAIL', nullable=False))
    op.add_column('sales', sa.Column('manager_approved_by', sa.UUID(), nullable=True))
    op.add_column('sales', sa.Column('exchange_return_id', sa.UUID(), nullable=True))
    op.create_foreign_key('fk_sales_manager_approved_by', 'sales', 'users', ['manager_approved_by'], ['id'], ondelete='SET NULL')
    op.create_foreign_key('fk_sales_exchange_return_id', 'sales', 'returns', ['exchange_return_id'], ['id'], ondelete='SET NULL')
    op.create_index(op.f('ix_sales_manager_approved_by'), 'sales', ['manager_approved_by'], unique=False)
    op.create_index(op.f('ix_sales_exchange_return_id'), 'sales', ['exchange_return_id'], unique=False)

    # 5. Alter sale_items table
    op.add_column('sale_items', sa.Column('discount_type', sa.String(length=20), server_default='FIXED', nullable=False))
    op.add_column('sale_items', sa.Column('discount_reason', sa.String(length=100), nullable=True))


def downgrade() -> None:
    # 5. Revert sale_items columns
    op.drop_column('sale_items', 'discount_reason')
    op.drop_column('sale_items', 'discount_type')

    # 4. Revert sales columns
    op.drop_index(op.f('ix_sales_exchange_return_id'), table_name='sales')
    op.drop_index(op.f('ix_sales_manager_approved_by'), table_name='sales')
    op.drop_constraint('fk_sales_exchange_return_id', 'sales', type_='foreignkey')
    op.drop_constraint('fk_sales_manager_approved_by', 'sales', type_='foreignkey')
    op.drop_column('sales', 'exchange_return_id')
    op.drop_column('sales', 'manager_approved_by')
    op.drop_column('sales', 'sale_type')
    op.drop_column('sales', 'delivery_charge')

    # 3. Drop quotation_items table
    op.drop_index(op.f('ix_quotation_items_quotation_id'), table_name='quotation_items')
    op.drop_index(op.f('ix_quotation_items_product_variant_id'), table_name='quotation_items')
    op.drop_table('quotation_items')

    # 2. Drop quotations table
    op.drop_index(op.f('ix_quotations_quotation_no'), table_name='quotations')
    op.drop_index(op.f('ix_quotations_customer_id'), table_name='quotations')
    op.drop_index(op.f('ix_quotations_created_by'), table_name='quotations')
    op.drop_index(op.f('ix_quotations_branch_id'), table_name='quotations')
    op.drop_index(op.f('ix_quotations_business_id'), table_name='quotations')
    op.drop_table('quotations')

    # 1. Drop held_carts table
    op.drop_index(op.f('ix_held_carts_customer_id'), table_name='held_carts')
    op.drop_index(op.f('ix_held_carts_cashier_id'), table_name='held_carts')
    op.drop_index(op.f('ix_held_carts_branch_id'), table_name='held_carts')
    op.drop_index(op.f('ix_held_carts_business_id'), table_name='held_carts')
    op.drop_table('held_carts')
