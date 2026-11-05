"""add_expenses_and_financial_accounts

Revision ID: d49e20f5b3c2
Revises: c38f19e4a2b1
Create Date: 2026-11-05 09:30:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'd49e20f5b3c2'
down_revision: str | None = 'c38f19e4a2b1'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Create expense_categories table
    op.create_table(
        'expense_categories',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('business_id', sa.UUID(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('code', sa.String(length=50), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('monthly_budget', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['business_id'], ['businesses.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('business_id', 'code', name='uq_expense_category_biz_code')
    )
    op.create_index(op.f('ix_expense_categories_business_id'), 'expense_categories', ['business_id'], unique=False)

    # 2. Create financial_accounts table
    op.create_table(
        'financial_accounts',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('business_id', sa.UUID(), nullable=False),
        sa.Column('branch_id', sa.UUID(), nullable=True),
        sa.Column('account_name', sa.String(length=100), nullable=False),
        sa.Column('account_type', sa.String(length=32), nullable=False),
        sa.Column('account_number', sa.String(length=100), nullable=True),
        sa.Column('bank_name', sa.String(length=100), nullable=True),
        sa.Column('opening_balance', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('current_balance', sa.Numeric(precision=19, scale=4), server_default=sa.text('0.0000'), nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.CheckConstraint("account_type IN ('CASH_DRAWER', 'SAFE', 'BANK', 'MOBILE_WALLET', 'PETTY_CASH')", name='chk_financial_account_type'),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['business_id'], ['businesses.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_financial_accounts_business_id'), 'financial_accounts', ['business_id'], unique=False)
    op.create_index(op.f('ix_financial_accounts_branch_id'), 'financial_accounts', ['branch_id'], unique=False)

    # 3. Create account_transfers table
    op.create_table(
        'account_transfers',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('business_id', sa.UUID(), nullable=False),
        sa.Column('from_account_id', sa.UUID(), nullable=False),
        sa.Column('to_account_id', sa.UUID(), nullable=False),
        sa.Column('amount', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('reference_no', sa.String(length=100), nullable=True),
        sa.Column('note', sa.Text(), nullable=True),
        sa.Column('transfer_date', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.Column('created_by', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.CheckConstraint('amount > 0', name='chk_transfer_amount_positive'),
        sa.CheckConstraint('from_account_id <> to_account_id', name='chk_transfer_diff_accounts'),
        sa.ForeignKeyConstraint(['business_id'], ['businesses.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['from_account_id'], ['financial_accounts.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['to_account_id'], ['financial_accounts.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_account_transfers_business_id'), 'account_transfers', ['business_id'], unique=False)
    op.create_index(op.f('ix_account_transfers_created_by'), 'account_transfers', ['created_by'], unique=False)
    op.create_index(op.f('ix_account_transfers_from_account_id'), 'account_transfers', ['from_account_id'], unique=False)
    op.create_index(op.f('ix_account_transfers_to_account_id'), 'account_transfers', ['to_account_id'], unique=False)

    # 4. Create recurring_expenses table
    op.create_table(
        'recurring_expenses',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('business_id', sa.UUID(), nullable=False),
        sa.Column('branch_id', sa.UUID(), nullable=True),
        sa.Column('category_id', sa.UUID(), nullable=False),
        sa.Column('payment_account_id', sa.UUID(), nullable=True),
        sa.Column('title', sa.String(length=150), nullable=False),
        sa.Column('amount', sa.Numeric(precision=19, scale=4), nullable=False),
        sa.Column('frequency', sa.String(length=32), nullable=False),
        sa.Column('next_due_date', sa.Date(), nullable=False),
        sa.Column('last_generated_at', sa.DateTime(), nullable=True),
        sa.Column('auto_post', sa.Boolean(), server_default=sa.text('false'), nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.CheckConstraint('amount > 0', name='chk_recurring_amount_positive'),
        sa.CheckConstraint("frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUAL')", name='chk_recurring_frequency'),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['business_id'], ['businesses.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['category_id'], ['expense_categories.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['payment_account_id'], ['financial_accounts.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_recurring_expenses_branch_id'), 'recurring_expenses', ['branch_id'], unique=False)
    op.create_index(op.f('ix_recurring_expenses_business_id'), 'recurring_expenses', ['business_id'], unique=False)
    op.create_index(op.f('ix_recurring_expenses_category_id'), 'recurring_expenses', ['category_id'], unique=False)
    op.create_index(op.f('ix_recurring_expenses_payment_account_id'), 'recurring_expenses', ['payment_account_id'], unique=False)

    # 5. Alter expenses table
    op.add_column('expenses', sa.Column('voucher_no', sa.String(length=50), nullable=True))
    op.create_index(op.f('ix_expenses_voucher_no'), 'expenses', ['voucher_no'], unique=False)

    op.add_column('expenses', sa.Column('category_id', sa.UUID(), nullable=True))
    op.create_foreign_key('fk_expenses_category_id', 'expenses', 'expense_categories', ['category_id'], ['id'], ondelete='SET NULL')
    op.create_index(op.f('ix_expenses_category_id'), 'expenses', ['category_id'], unique=False)

    op.add_column('expenses', sa.Column('payment_account_id', sa.UUID(), nullable=True))
    op.create_foreign_key('fk_expenses_payment_account_id', 'expenses', 'financial_accounts', ['payment_account_id'], ['id'], ondelete='SET NULL')
    op.create_index(op.f('ix_expenses_payment_account_id'), 'expenses', ['payment_account_id'], unique=False)

    op.add_column('expenses', sa.Column('payment_method', sa.String(length=32), server_default=sa.text("'CASH'"), nullable=False))
    op.add_column('expenses', sa.Column('payee', sa.String(length=200), nullable=True))
    op.add_column('expenses', sa.Column('receipt_reference', sa.String(length=100), nullable=True))
    op.add_column('expenses', sa.Column('tax_deductible', sa.Boolean(), server_default=sa.text('true'), nullable=False))
    op.add_column('expenses', sa.Column('approval_status', sa.String(length=32), server_default=sa.text("'APPROVED'"), nullable=False))
    op.add_column('expenses', sa.Column('approved_by', sa.UUID(), nullable=True))
    op.create_foreign_key('fk_expenses_approved_by', 'expenses', 'users', ['approved_by'], ['id'], ondelete='SET NULL')
    op.add_column('expenses', sa.Column('approved_at', sa.DateTime(), nullable=True))

    op.create_check_constraint(
        'chk_expense_approval_status',
        'expenses',
        "approval_status IN ('APPROVED', 'PENDING_APPROVAL', 'REJECTED')"
    )


def downgrade() -> None:
    op.drop_constraint('chk_expense_approval_status', 'expenses', type_='check')
    op.drop_constraint('fk_expenses_approved_by', 'expenses', type_='foreignkey')
    op.drop_column('expenses', 'approved_at')
    op.drop_column('expenses', 'approved_by')
    op.drop_column('expenses', 'approval_status')
    op.drop_column('expenses', 'tax_deductible')
    op.drop_column('expenses', 'receipt_reference')
    op.drop_column('expenses', 'payee')
    op.drop_column('expenses', 'payment_method')
    op.drop_constraint('fk_expenses_payment_account_id', 'expenses', type_='foreignkey')
    op.drop_index(op.f('ix_expenses_payment_account_id'), table_name='expenses')
    op.drop_column('expenses', 'payment_account_id')
    op.drop_constraint('fk_expenses_category_id', 'expenses', type_='foreignkey')
    op.drop_index(op.f('ix_expenses_category_id'), table_name='expenses')
    op.drop_column('expenses', 'category_id')
    op.drop_index(op.f('ix_expenses_voucher_no'), table_name='expenses')
    op.drop_column('expenses', 'voucher_no')

    op.drop_index(op.f('ix_recurring_expenses_payment_account_id'), table_name='recurring_expenses')
    op.drop_index(op.f('ix_recurring_expenses_category_id'), table_name='recurring_expenses')
    op.drop_index(op.f('ix_recurring_expenses_business_id'), table_name='recurring_expenses')
    op.drop_index(op.f('ix_recurring_expenses_branch_id'), table_name='recurring_expenses')
    op.drop_table('recurring_expenses')

    op.drop_index(op.f('ix_account_transfers_to_account_id'), table_name='account_transfers')
    op.drop_index(op.f('ix_account_transfers_from_account_id'), table_name='account_transfers')
    op.drop_index(op.f('ix_account_transfers_created_by'), table_name='account_transfers')
    op.drop_index(op.f('ix_account_transfers_business_id'), table_name='account_transfers')
    op.drop_table('account_transfers')

    op.drop_index(op.f('ix_financial_accounts_branch_id'), table_name='financial_accounts')
    op.drop_index(op.f('ix_financial_accounts_business_id'), table_name='financial_accounts')
    op.drop_table('financial_accounts')

    op.drop_index(op.f('ix_expense_categories_business_id'), table_name='expense_categories')
    op.drop_table('expense_categories')
