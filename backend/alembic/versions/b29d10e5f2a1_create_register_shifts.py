"""create register_shifts table

Revision ID: b29d10e5f2a1
Revises: ad56b6eabc03
Create Date: 2026-11-04 10:20:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b29d10e5f2a1"
down_revision: str | None = "ad56b6eabc03"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "register_shifts",
        sa.Column("id", sa.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("business_id", sa.UUID(), nullable=False),
        sa.Column("branch_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("device_id", sa.UUID(), nullable=True),
        sa.Column("status", sa.String(length=32), server_default="OPEN", nullable=False),
        sa.Column("opened_at", sa.DateTime(), server_default=sa.text("now()"), nullable=False),
        sa.Column("closed_at", sa.DateTime(), nullable=True),
        sa.Column("opening_cash", sa.Numeric(precision=19, scale=4), server_default=sa.text("0.0000"), nullable=False),
        sa.Column("closing_cash_counted", sa.Numeric(precision=19, scale=4), nullable=True),
        sa.Column("closing_cash_expected", sa.Numeric(precision=19, scale=4), nullable=True),
        sa.Column("cash_difference", sa.Numeric(precision=19, scale=4), nullable=True),
        sa.Column("opening_notes", sa.Text(), nullable=True),
        sa.Column("closing_notes", sa.Text(), nullable=True),
        sa.Column("denominations_json", postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("opening_cash >= 0", name="chk_shift_opening_cash_non_negative"),
        sa.ForeignKeyConstraint(["branch_id"], ["branches.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["business_id"], ["businesses.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["device_id"], ["devices.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_shifts_business_branch_status", "register_shifts", ["business_id", "branch_id", "status"])
    op.create_index("ix_shifts_user_status", "register_shifts", ["user_id", "status"])
    op.create_index("ix_shifts_business_branch_date", "register_shifts", ["business_id", "branch_id", sa.text("opened_at DESC")])
    op.create_index(op.f("ix_register_shifts_business_id"), "register_shifts", ["business_id"])
    op.create_index(op.f("ix_register_shifts_branch_id"), "register_shifts", ["branch_id"])
    op.create_index(op.f("ix_register_shifts_user_id"), "register_shifts", ["user_id"])
    op.create_index(op.f("ix_register_shifts_device_id"), "register_shifts", ["device_id"])
    op.create_index(op.f("ix_register_shifts_opened_at"), "register_shifts", ["opened_at"])


def downgrade() -> None:
    op.drop_index(op.f("ix_register_shifts_opened_at"), table_name="register_shifts")
    op.drop_index(op.f("ix_register_shifts_device_id"), table_name="register_shifts")
    op.drop_index(op.f("ix_register_shifts_user_id"), table_name="register_shifts")
    op.drop_index(op.f("ix_register_shifts_branch_id"), table_name="register_shifts")
    op.drop_index(op.f("ix_register_shifts_business_id"), table_name="register_shifts")
    op.drop_index("ix_shifts_business_branch_date", table_name="register_shifts")
    op.drop_index("ix_shifts_user_status", table_name="register_shifts")
    op.drop_index("ix_shifts_business_branch_status", table_name="register_shifts")
    op.drop_table("register_shifts")

