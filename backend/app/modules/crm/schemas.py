"""Pydantic schemas for Loyalty, Membership Tiers, Gift Cards, Credit Notes, and CRM."""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


# ---------------------------------------------------------------------------
# Loyalty Program Settings
# ---------------------------------------------------------------------------
class LoyaltySettingsUpdate(BaseModel):
    is_enabled: bool | None = None
    earn_rate: Decimal | None = Field(default=None, ge=0)
    redeem_rate: Decimal | None = Field(default=None, gt=0)
    min_redeem_points: int | None = Field(default=None, ge=1)
    points_expiry_days: int | None = Field(default=None, ge=0)
    max_cart_discount_pct: Decimal | None = Field(default=None, ge=0, le=100)


class LoyaltySettingsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    is_enabled: bool
    earn_rate: Decimal
    redeem_rate: Decimal
    min_redeem_points: int
    points_expiry_days: int
    max_cart_discount_pct: Decimal
    updated_at: datetime


# ---------------------------------------------------------------------------
# Membership Tiers
# ---------------------------------------------------------------------------
class MembershipTierCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    code: str = Field(min_length=1, max_length=30)
    min_spend: Decimal = Field(default=Decimal("0.0000"), ge=0)
    points_multiplier: Decimal = Field(default=Decimal("1.00"), gt=0)
    discount_pct: Decimal = Field(default=Decimal("0.00"), ge=0, le=100)
    badge_color: str = Field(default="#64748B", max_length=20)
    perks_description: str | None = None
    sort_order: int = Field(default=0, ge=0)
    is_active: bool = True


class MembershipTierUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=50)
    min_spend: Decimal | None = Field(default=None, ge=0)
    points_multiplier: Decimal | None = Field(default=None, gt=0)
    discount_pct: Decimal | None = Field(default=None, ge=0, le=100)
    badge_color: str | None = Field(default=None, max_length=20)
    perks_description: str | None = None
    sort_order: int | None = Field(default=None, ge=0)
    is_active: bool | None = None


class MembershipTierOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    name: str
    code: str
    min_spend: Decimal
    points_multiplier: Decimal
    discount_pct: Decimal
    badge_color: str
    perks_description: str | None
    sort_order: int
    is_active: bool
    created_at: datetime


# ---------------------------------------------------------------------------
# Loyalty Transactions & Customer Summary
# ---------------------------------------------------------------------------
class LoyaltyTransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    customer_id: uuid.UUID
    sale_id: uuid.UUID | None
    transaction_type: str
    points: int
    points_balance_after: int
    reason: str | None
    created_at: datetime


class CustomerLoyaltySummaryOut(BaseModel):
    customer_id: uuid.UUID
    customer_name: str
    phone: str | None
    loyalty_points_balance: int
    membership_tier_id: uuid.UUID | None
    membership_tier_name: str | None
    points_multiplier: Decimal
    tier_discount_pct: Decimal
    badge_color: str
    lifetime_spend: Decimal
    store_credit_balance: Decimal
    recent_transactions: list[LoyaltyTransactionOut]


class LoyaltyPointsAdjustRequest(BaseModel):
    points: int = Field(description="Positive for bonus/addition, negative for deduction")
    reason: str = Field(min_length=3, max_length=255)


class PointsRedemptionPreviewRequest(BaseModel):
    customer_id: uuid.UUID
    points_to_redeem: int = Field(gt=0)
    cart_subtotal: Decimal = Field(gt=0)


class PointsRedemptionPreviewOut(BaseModel):
    points_to_redeem: int
    discount_amount: Decimal
    points_balance_remaining: int
    is_valid: bool
    error_message: str | None = None


# ---------------------------------------------------------------------------
# Gift Cards
# ---------------------------------------------------------------------------
class GiftCardCreate(BaseModel):
    card_number: str | None = Field(default=None, max_length=32)
    pin: str = Field(min_length=4, max_length=8, description="4 to 8 digit numeric PIN")
    initial_balance: Decimal = Field(gt=0)
    purchaser_customer_id: uuid.UUID | None = None
    recipient_name: str | None = Field(default=None, max_length=100)
    recipient_phone: str | None = Field(default=None, max_length=50)
    recipient_email: str | None = Field(default=None, max_length=100)
    expires_at: datetime | None = None


class GiftCardOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    card_number: str
    initial_balance: Decimal
    current_balance: Decimal
    status: str
    purchaser_customer_id: uuid.UUID | None
    recipient_name: str | None
    recipient_phone: str | None
    recipient_email: str | None
    expires_at: datetime | None
    created_at: datetime


class GiftCardVerifyRequest(BaseModel):
    card_number: str
    pin: str


class GiftCardVerifyOut(BaseModel):
    is_valid: bool
    card_id: uuid.UUID | None = None
    card_number: str | None = None
    current_balance: Decimal = Decimal("0.0000")
    status: str | None = None
    message: str


class GiftCardReloadRequest(BaseModel):
    amount: Decimal = Field(gt=0)
    reference: str | None = Field(default=None, max_length=100)
    notes: str | None = None


class GiftCardTransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    gift_card_id: uuid.UUID
    sale_id: uuid.UUID | None
    transaction_type: str
    amount: Decimal
    balance_after: Decimal
    reference: str | None
    notes: str | None
    created_at: datetime


# ---------------------------------------------------------------------------
# Credit Notes
# ---------------------------------------------------------------------------
class CreditNoteCreate(BaseModel):
    customer_id: uuid.UUID
    initial_amount: Decimal = Field(gt=0)
    reason: str = Field(min_length=3, max_length=255)
    sale_return_id: uuid.UUID | None = None
    expires_at: datetime | None = None


class CreditNoteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    customer_id: uuid.UUID
    sale_return_id: uuid.UUID | None
    note_number: str
    initial_amount: Decimal
    remaining_balance: Decimal
    status: str
    reason: str
    expires_at: datetime | None
    created_at: datetime


# ---------------------------------------------------------------------------
# RFM & Retention Analytics
# ---------------------------------------------------------------------------
class CustomerRfmScoreOut(BaseModel):
    customer_id: uuid.UUID
    customer_name: str
    phone: str | None
    recency_days: int
    frequency_orders: int
    monetary_spent: Decimal
    r_score: int
    f_score: int
    m_score: int
    segment: str


class RfmSegmentSummaryOut(BaseModel):
    segment: str
    count: int
    percentage: float
    total_monetary: Decimal
    avg_recency_days: float


class RetentionKpisOut(BaseModel):
    total_active_customers: int
    repeat_purchase_rate: float
    churn_rate_90d: float
    avg_clv: Decimal
    revenue_at_risk: Decimal
    segments: list[RfmSegmentSummaryOut]


# ---------------------------------------------------------------------------
# Promotional Campaigns
# ---------------------------------------------------------------------------
class PromotionalCampaignCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    target_segment: str = Field(default="ALL")
    target_group_id: uuid.UUID | None = None
    channel: str = Field(default="SMS")
    message_template: str = Field(min_length=1)
    promotion_id: uuid.UUID | None = None
    scheduled_at: datetime | None = None


class PromotionalCampaignUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=120)
    target_segment: str | None = None
    target_group_id: uuid.UUID | None = None
    channel: str | None = None
    message_template: str | None = None
    promotion_id: uuid.UUID | None = None
    status: str | None = None
    scheduled_at: datetime | None = None


class PromotionalCampaignOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    business_id: uuid.UUID
    title: str
    target_segment: str
    target_group_id: uuid.UUID | None
    channel: str
    message_template: str
    promotion_id: uuid.UUID | None
    audience_count: int
    status: str
    scheduled_at: datetime | None
    sent_at: datetime | None
    created_at: datetime


class AudiencePreviewOut(BaseModel):
    total_recipients: int
    sample_recipients: list[dict[str, Any]]

