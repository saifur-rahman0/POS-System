"""add_loyalty_and_crm

Revision ID: a72h53c3d6f5
Revises: f61g42b2c5e4
Create Date: 2026-11-05 12:00:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'a72h53c3d6f5'
down_revision: str | None = 'f61g42b2c5e4'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. loyalty_settings
    op.create_table(
        'loyalty_settings',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='CASCADE'), nullable=False),
        sa.Column('is_enabled', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('earn_rate', sa.Numeric(10, 4), nullable=False, server_default=sa.text('1.0000')),
        sa.Column('redeem_rate', sa.Numeric(10, 4), nullable=False, server_default=sa.text('0.1000')),
        sa.Column('min_redeem_points', sa.Integer(), nullable=False, server_default=sa.text('100')),
        sa.Column('points_expiry_days', sa.Integer(), nullable=False, server_default=sa.text('365')),
        sa.Column('max_cart_discount_pct', sa.Numeric(5, 2), nullable=False, server_default=sa.text('50.00')),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('business_id', name='uq_loyalty_settings_business'),
    )
    op.create_index('ix_loyalty_settings_business', 'loyalty_settings', ['business_id'])

    # 2. membership_tiers
    op.create_table(
        'membership_tiers',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(length=50), nullable=False),
        sa.Column('code', sa.String(length=30), nullable=False),
        sa.Column('min_spend', sa.Numeric(19, 4), nullable=False, server_default=sa.text('0.0000')),
        sa.Column('points_multiplier', sa.Numeric(5, 2), nullable=False, server_default=sa.text('1.00')),
        sa.Column('discount_pct', sa.Numeric(5, 2), nullable=False, server_default=sa.text('0.00')),
        sa.Column('badge_color', sa.String(length=20), nullable=False, server_default=sa.text("'#64748B'")),
        sa.Column('perks_description', sa.Text(), nullable=True),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('business_id', 'code', name='uq_membership_tiers_business_code'),
        sa.CheckConstraint('min_spend >= 0', name='chk_tier_min_spend_non_negative'),
        sa.CheckConstraint('points_multiplier > 0', name='chk_tier_multiplier_positive'),
    )
    op.create_index('ix_membership_tiers_business', 'membership_tiers', ['business_id'])

    # 3. loyalty_transactions
    op.create_table(
        'loyalty_transactions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='CASCADE'), nullable=False),
        sa.Column('customer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customers.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('sale_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('sales.id', ondelete='SET NULL'), nullable=True),
        sa.Column('transaction_type', sa.String(length=20), nullable=False),
        sa.Column('points', sa.Integer(), nullable=False),
        sa.Column('points_balance_after', sa.Integer(), nullable=False),
        sa.Column('reason', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint('points_balance_after >= 0', name='chk_loyalty_balance_non_negative'),
    )
    op.create_index('ix_loyalty_tx_business', 'loyalty_transactions', ['business_id'])
    op.create_index('ix_loyalty_tx_customer', 'loyalty_transactions', ['customer_id', 'created_at'])
    op.create_index('ix_loyalty_tx_sale', 'loyalty_transactions', ['sale_id'])

    # 4. gift_cards
    op.create_table(
        'gift_cards',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='CASCADE'), nullable=False),
        sa.Column('card_number', sa.String(length=32), nullable=False),
        sa.Column('pin_hash', sa.String(length=128), nullable=False),
        sa.Column('initial_balance', sa.Numeric(19, 4), nullable=False),
        sa.Column('current_balance', sa.Numeric(19, 4), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, server_default=sa.text("'ACTIVE'")),
        sa.Column('purchaser_customer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customers.id', ondelete='SET NULL'), nullable=True),
        sa.Column('recipient_name', sa.String(length=100), nullable=True),
        sa.Column('recipient_phone', sa.String(length=50), nullable=True),
        sa.Column('recipient_email', sa.String(length=100), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('business_id', 'card_number', name='uq_gift_cards_business_number'),
        sa.CheckConstraint('current_balance >= 0', name='chk_gift_card_balance_non_negative'),
        sa.CheckConstraint('initial_balance >= 0', name='chk_gift_card_initial_non_negative'),
    )
    op.create_index('ix_gift_cards_business', 'gift_cards', ['business_id'])
    op.create_index('ix_gift_cards_number', 'gift_cards', ['card_number'])

    # 5. gift_card_transactions
    op.create_table(
        'gift_card_transactions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='CASCADE'), nullable=False),
        sa.Column('gift_card_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('gift_cards.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('sale_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('sales.id', ondelete='SET NULL'), nullable=True),
        sa.Column('transaction_type', sa.String(length=20), nullable=False),
        sa.Column('amount', sa.Numeric(19, 4), nullable=False),
        sa.Column('balance_after', sa.Numeric(19, 4), nullable=False),
        sa.Column('reference', sa.String(length=100), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint('balance_after >= 0', name='chk_gift_card_tx_balance_non_negative'),
    )
    op.create_index('ix_gift_card_tx_business', 'gift_card_transactions', ['business_id'])
    op.create_index('ix_gift_card_tx_card', 'gift_card_transactions', ['gift_card_id', 'created_at'])

    # 6. credit_notes
    op.create_table(
        'credit_notes',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='CASCADE'), nullable=False),
        sa.Column('customer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customers.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('sale_return_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('returns.id', ondelete='SET NULL'), nullable=True),
        sa.Column('note_number', sa.String(length=50), nullable=False),
        sa.Column('initial_amount', sa.Numeric(19, 4), nullable=False),
        sa.Column('remaining_balance', sa.Numeric(19, 4), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, server_default=sa.text("'ACTIVE'")),
        sa.Column('reason', sa.String(length=255), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('business_id', 'note_number', name='uq_credit_notes_business_number'),
        sa.CheckConstraint('remaining_balance >= 0', name='chk_credit_note_balance_non_negative'),
        sa.CheckConstraint('initial_amount >= 0', name='chk_credit_note_initial_non_negative'),
    )
    op.create_index('ix_credit_notes_business', 'credit_notes', ['business_id'])
    op.create_index('ix_credit_notes_customer', 'credit_notes', ['customer_id'])

    # 7. promotional_campaigns
    op.create_table(
        'promotional_campaigns',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('business_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('businesses.id', ondelete='CASCADE'), nullable=False),
        sa.Column('title', sa.String(length=120), nullable=False),
        sa.Column('target_segment', sa.String(length=50), nullable=False, server_default=sa.text("'ALL'")),
        sa.Column('target_group_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('customer_groups.id', ondelete='SET NULL'), nullable=True),
        sa.Column('channel', sa.String(length=20), nullable=False, server_default=sa.text("'SMS'")),
        sa.Column('message_template', sa.Text(), nullable=False),
        sa.Column('promotion_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('promotions.id', ondelete='SET NULL'), nullable=True),
        sa.Column('audience_count', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('status', sa.String(length=20), nullable=False, server_default=sa.text("'DRAFT'")),
        sa.Column('scheduled_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('sent_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index('ix_promotional_campaigns_business', 'promotional_campaigns', ['business_id'])

    # 8. Alter customers table
    op.add_column('customers', sa.Column('loyalty_points_balance', sa.Integer(), nullable=False, server_default=sa.text('0')))
    op.add_column('customers', sa.Column('membership_tier_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('membership_tiers.id', ondelete='SET NULL'), nullable=True))
    op.add_column('customers', sa.Column('store_credit_balance', sa.Numeric(19, 4), nullable=False, server_default=sa.text('0.0000')))
    op.add_column('customers', sa.Column('lifetime_spend', sa.Numeric(19, 4), nullable=False, server_default=sa.text('0.0000')))
    op.add_column('customers', sa.Column('rfm_segment', sa.String(length=50), nullable=True, server_default=sa.text("'NEW_CUSTOMER'")))
    op.create_check_constraint('chk_customer_points_non_negative', 'customers', 'loyalty_points_balance >= 0')
    op.create_check_constraint('chk_customer_store_credit_non_negative', 'customers', 'store_credit_balance >= 0')
    op.create_check_constraint('chk_customer_lifetime_spend_non_negative', 'customers', 'lifetime_spend >= 0')

    # 9. Alter sales table
    op.add_column('sales', sa.Column('loyalty_points_earned', sa.Integer(), nullable=False, server_default=sa.text('0')))
    op.add_column('sales', sa.Column('loyalty_points_redeemed', sa.Integer(), nullable=False, server_default=sa.text('0')))
    op.add_column('sales', sa.Column('loyalty_discount', sa.Numeric(19, 4), nullable=False, server_default=sa.text('0.0000')))
    op.add_column('sales', sa.Column('gift_card_discount', sa.Numeric(19, 4), nullable=False, server_default=sa.text('0.0000')))
    op.add_column('sales', sa.Column('store_credit_discount', sa.Numeric(19, 4), nullable=False, server_default=sa.text('0.0000')))


def downgrade() -> None:
    # Sales columns
    op.drop_column('sales', 'store_credit_discount')
    op.drop_column('sales', 'gift_card_discount')
    op.drop_column('sales', 'loyalty_discount')
    op.drop_column('sales', 'loyalty_points_redeemed')
    op.drop_column('sales', 'loyalty_points_earned')

    # Customers columns & constraints
    op.drop_constraint('chk_customer_lifetime_spend_non_negative', 'customers', type_='check')
    op.drop_constraint('chk_customer_store_credit_non_negative', 'customers', type_='check')
    op.drop_constraint('chk_customer_points_non_negative', 'customers', type_='check')
    op.drop_column('customers', 'rfm_segment')
    op.drop_column('customers', 'lifetime_spend')
    op.drop_column('customers', 'store_credit_balance')
    op.drop_column('customers', 'membership_tier_id')
    op.drop_column('customers', 'loyalty_points_balance')

    # Drop CRM tables
    op.drop_table('promotional_campaigns')
    op.drop_table('credit_notes')
    op.drop_table('gift_card_transactions')
    op.drop_table('gift_cards')
    op.drop_table('loyalty_transactions')
    op.drop_table('membership_tiers')
    op.drop_table('loyalty_settings')

