"""add_advanced_inventory

Revision ID: e50f31a1b4d3
Revises: d49e20f5b3c2
Create Date: 2026-11-05 10:00:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'e50f31a1b4d3'
down_revision: str | None = 'd49e20f5b3c2'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Alter branches: add branch_type
    op.add_column(
        'branches',
        sa.Column(
            'branch_type',
            sa.String(length=32),
            server_default=sa.text("'RETAIL_STORE'"),
            nullable=False,
        ),
    )

    # 2. Alter product_variants: add batch and reorder columns
    op.add_column(
        'product_variants',
        sa.Column(
            'has_batch_tracking',
            sa.Boolean(),
            server_default=sa.text('false'),
            nullable=False,
        ),
    )
    op.add_column(
        'product_variants',
        sa.Column(
            'min_stock_level',
            sa.Numeric(precision=12, scale=4),
            server_default=sa.text('0.0000'),
            nullable=False,
        ),
    )
    op.add_column(
        'product_variants',
        sa.Column(
            'reorder_quantity',
            sa.Numeric(precision=12, scale=4),
            server_default=sa.text('0.0000'),
            nullable=False,
        ),
    )

    # 3. Create inventory_batches table
    op.create_table(
        'inventory_batches',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('business_id', sa.UUID(), nullable=False),
        sa.Column('branch_id', sa.UUID(), nullable=False),
        sa.Column('product_variant_id', sa.UUID(), nullable=False),
        sa.Column('batch_number', sa.String(length=100), nullable=False),
        sa.Column('manufacturing_date', sa.Date(), nullable=True),
        sa.Column('expiry_date', sa.Date(), nullable=True),
        sa.Column('quantity_received', sa.Numeric(precision=12, scale=4), nullable=False),
        sa.Column('quantity_on_hand', sa.Numeric(precision=12, scale=4), nullable=False),
        sa.Column(
            'cost_price',
            sa.Numeric(precision=19, scale=4),
            server_default=sa.text('0.0000'),
            nullable=False,
        ),
        sa.Column('supplier_id', sa.UUID(), nullable=True),
        sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.CheckConstraint('quantity_received > 0', name='chk_batch_qty_received_positive'),
        sa.CheckConstraint('quantity_on_hand >= 0', name='chk_batch_qty_on_hand_non_negative'),
        sa.CheckConstraint('cost_price >= 0', name='chk_batch_cost_price_non_negative'),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['business_id'], ['businesses.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['product_variant_id'], ['product_variants.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['supplier_id'], ['suppliers.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'business_id',
            'branch_id',
            'product_variant_id',
            'batch_number',
            name='uq_batches_biz_branch_variant_batch',
        ),
    )
    op.create_index(op.f('ix_inventory_batches_business_id'), 'inventory_batches', ['business_id'], unique=False)
    op.create_index(op.f('ix_inventory_batches_branch_id'), 'inventory_batches', ['branch_id'], unique=False)
    op.create_index(op.f('ix_inventory_batches_product_variant_id'), 'inventory_batches', ['product_variant_id'], unique=False)
    op.create_index(op.f('ix_inventory_batches_supplier_id'), 'inventory_batches', ['supplier_id'], unique=False)
    op.create_index('ix_inventory_batches_expiry', 'inventory_batches', ['business_id', 'branch_id', 'expiry_date'], unique=False)
    op.create_index('ix_inventory_batches_variant', 'inventory_batches', ['product_variant_id', 'is_active'], unique=False)

    # 4. Alter stock_movements: add batch_id
    op.add_column('stock_movements', sa.Column('batch_id', sa.UUID(), nullable=True))
    op.create_index(op.f('ix_stock_movements_batch_id'), 'stock_movements', ['batch_id'], unique=False)
    op.create_foreign_key('fk_stock_movements_batch_id', 'stock_movements', 'inventory_batches', ['batch_id'], ['id'], ondelete='SET NULL')

    # 5. Create damaged_stock_records table
    op.create_table(
        'damaged_stock_records',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('business_id', sa.UUID(), nullable=False),
        sa.Column('branch_id', sa.UUID(), nullable=False),
        sa.Column('product_variant_id', sa.UUID(), nullable=False),
        sa.Column('batch_id', sa.UUID(), nullable=True),
        sa.Column('voucher_no', sa.String(length=50), nullable=False),
        sa.Column('quantity', sa.Numeric(precision=12, scale=4), nullable=False),
        sa.Column('unit_cost', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('total_loss', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('reason', sa.String(length=50), nullable=False),
        sa.Column('disposal_method', sa.String(length=50), nullable=False),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('reported_by', sa.UUID(), nullable=False),
        sa.Column('approved_by', sa.UUID(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.CheckConstraint('quantity > 0', name='chk_damaged_qty_positive'),
        sa.CheckConstraint('unit_cost >= 0', name='chk_damaged_cost_non_negative'),
        sa.CheckConstraint('total_loss >= 0', name='chk_damaged_loss_non_negative'),
        sa.CheckConstraint(
            "reason IN ('EXPIRED', 'BROKEN', 'TRANSIT_DAMAGE', 'WATER_DAMAGE', 'THEFT', 'OTHER')",
            name='chk_damaged_reason',
        ),
        sa.CheckConstraint(
            "disposal_method IN ('DESTROYED', 'RETURNED_TO_VENDOR', 'SOLD_AT_DISCOUNT', 'WRITTEN_OFF')",
            name='chk_damaged_disposal_method',
        ),
        sa.ForeignKeyConstraint(['approved_by'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['batch_id'], ['inventory_batches.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['business_id'], ['businesses.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['product_variant_id'], ['product_variants.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['reported_by'], ['users.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_damaged_stock_records_business_id'), 'damaged_stock_records', ['business_id'], unique=False)
    op.create_index(op.f('ix_damaged_stock_records_branch_id'), 'damaged_stock_records', ['branch_id'], unique=False)
    op.create_index(op.f('ix_damaged_stock_records_product_variant_id'), 'damaged_stock_records', ['product_variant_id'], unique=False)
    op.create_index(op.f('ix_damaged_stock_records_batch_id'), 'damaged_stock_records', ['batch_id'], unique=False)
    op.create_index(op.f('ix_damaged_stock_records_voucher_no'), 'damaged_stock_records', ['voucher_no'], unique=False)
    op.create_index(op.f('ix_damaged_stock_records_reported_by'), 'damaged_stock_records', ['reported_by'], unique=False)
    op.create_index(op.f('ix_damaged_stock_records_created_at'), 'damaged_stock_records', ['created_at'], unique=False)

    # 6. Create stock_reservations table
    op.create_table(
        'stock_reservations',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('business_id', sa.UUID(), nullable=False),
        sa.Column('branch_id', sa.UUID(), nullable=False),
        sa.Column('product_variant_id', sa.UUID(), nullable=False),
        sa.Column('batch_id', sa.UUID(), nullable=True),
        sa.Column('quantity', sa.Numeric(precision=12, scale=4), nullable=False),
        sa.Column('reference_type', sa.String(length=50), nullable=False),
        sa.Column('reference_id', sa.UUID(), nullable=False),
        sa.Column('status', sa.String(length=32), server_default=sa.text("'ACTIVE'"), nullable=False),
        sa.Column('reserved_until', sa.DateTime(), nullable=False),
        sa.Column('created_by', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.CheckConstraint('quantity > 0', name='chk_reservation_qty_positive'),
        sa.CheckConstraint(
            "reference_type IN ('QUOTATION', 'LAYAWAY', 'SALES_ORDER')",
            name='chk_reservation_ref_type',
        ),
        sa.CheckConstraint(
            "status IN ('ACTIVE', 'FULFILLED', 'RELEASED', 'EXPIRED')",
            name='chk_reservation_status',
        ),
        sa.ForeignKeyConstraint(['batch_id'], ['inventory_batches.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['business_id'], ['businesses.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['product_variant_id'], ['product_variants.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_stock_reservations_business_id'), 'stock_reservations', ['business_id'], unique=False)
    op.create_index(op.f('ix_stock_reservations_branch_id'), 'stock_reservations', ['branch_id'], unique=False)
    op.create_index(op.f('ix_stock_reservations_product_variant_id'), 'stock_reservations', ['product_variant_id'], unique=False)
    op.create_index(op.f('ix_stock_reservations_batch_id'), 'stock_reservations', ['batch_id'], unique=False)
    op.create_index(op.f('ix_stock_reservations_reference_id'), 'stock_reservations', ['reference_id'], unique=False)
    op.create_index(op.f('ix_stock_reservations_created_by'), 'stock_reservations', ['created_by'], unique=False)
    op.create_index(op.f('ix_stock_reservations_created_at'), 'stock_reservations', ['created_at'], unique=False)
    op.create_index(
        'ix_stock_reservations_lookup',
        'stock_reservations',
        ['business_id', 'branch_id', 'product_variant_id', 'status'],
        unique=False,
    )


def downgrade() -> None:
    # 6. Drop stock_reservations
    op.drop_index('ix_stock_reservations_lookup', table_name='stock_reservations')
    op.drop_index(op.f('ix_stock_reservations_created_at'), table_name='stock_reservations')
    op.drop_index(op.f('ix_stock_reservations_created_by'), table_name='stock_reservations')
    op.drop_index(op.f('ix_stock_reservations_reference_id'), table_name='stock_reservations')
    op.drop_index(op.f('ix_stock_reservations_batch_id'), table_name='stock_reservations')
    op.drop_index(op.f('ix_stock_reservations_product_variant_id'), table_name='stock_reservations')
    op.drop_index(op.f('ix_stock_reservations_branch_id'), table_name='stock_reservations')
    op.drop_index(op.f('ix_stock_reservations_business_id'), table_name='stock_reservations')
    op.drop_table('stock_reservations')

    # 5. Drop damaged_stock_records
    op.drop_index(op.f('ix_damaged_stock_records_created_at'), table_name='damaged_stock_records')
    op.drop_index(op.f('ix_damaged_stock_records_reported_by'), table_name='damaged_stock_records')
    op.drop_index(op.f('ix_damaged_stock_records_voucher_no'), table_name='damaged_stock_records')
    op.drop_index(op.f('ix_damaged_stock_records_batch_id'), table_name='damaged_stock_records')
    op.drop_index(op.f('ix_damaged_stock_records_product_variant_id'), table_name='damaged_stock_records')
    op.drop_index(op.f('ix_damaged_stock_records_branch_id'), table_name='damaged_stock_records')
    op.drop_index(op.f('ix_damaged_stock_records_business_id'), table_name='damaged_stock_records')
    op.drop_table('damaged_stock_records')

    # 4. Revert stock_movements batch_id
    op.drop_constraint('fk_stock_movements_batch_id', 'stock_movements', type_='foreignkey')
    op.drop_index(op.f('ix_stock_movements_batch_id'), table_name='stock_movements')
    op.drop_column('stock_movements', 'batch_id')

    # 3. Drop inventory_batches
    op.drop_index('ix_inventory_batches_variant', table_name='inventory_batches')
    op.drop_index('ix_inventory_batches_expiry', table_name='inventory_batches')
    op.drop_index(op.f('ix_inventory_batches_supplier_id'), table_name='inventory_batches')
    op.drop_index(op.f('ix_inventory_batches_product_variant_id'), table_name='inventory_batches')
    op.drop_index(op.f('ix_inventory_batches_branch_id'), table_name='inventory_batches')
    op.drop_index(op.f('ix_inventory_batches_business_id'), table_name='inventory_batches')
    op.drop_table('inventory_batches')

    # 2. Revert product_variants columns
    op.drop_column('product_variants', 'reorder_quantity')
    op.drop_column('product_variants', 'min_stock_level')
    op.drop_column('product_variants', 'has_batch_tracking')

    # 1. Revert branches branch_type
    op.drop_column('branches', 'branch_type')

