"""API endpoints for Track 13 Customer Loyalty and CRM."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.crm.schemas import (
    AudiencePreviewOut,
    CreditNoteCreate,
    CreditNoteOut,
    CustomerLoyaltySummaryOut,
    GiftCardCreate,
    GiftCardOut,
    GiftCardReloadRequest,
    GiftCardTransactionOut,
    GiftCardVerifyOut,
    GiftCardVerifyRequest,
    LoyaltyPointsAdjustRequest,
    LoyaltySettingsOut,
    LoyaltySettingsUpdate,
    LoyaltyTransactionOut,
    MembershipTierCreate,
    MembershipTierOut,
    MembershipTierUpdate,
    PointsRedemptionPreviewOut,
    PointsRedemptionPreviewRequest,
    PromotionalCampaignCreate,
    PromotionalCampaignOut,
    PromotionalCampaignUpdate,
    RetentionKpisOut,
)
from app.modules.crm.service import CrmService
from app.shared.auth import CurrentUser, require_permission

router = APIRouter(prefix="/crm", tags=["CRM & Loyalty"])


# -----------------------------------------------------------------------------
# Loyalty Program Settings
# -----------------------------------------------------------------------------
@router.get(
    "/settings",
    response_model=LoyaltySettingsOut,
    summary="Get business loyalty program settings",
)
async def get_loyalty_settings(
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> LoyaltySettingsOut:
    service = CrmService(db)
    settings = await service.get_settings(user.business_id)
    return LoyaltySettingsOut.model_validate(settings)


@router.put(
    "/settings",
    response_model=LoyaltySettingsOut,
    summary="Update business loyalty program parameters",
)
async def update_loyalty_settings(
    body: LoyaltySettingsUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> LoyaltySettingsOut:
    service = CrmService(db)
    settings = await service.update_settings(user.business_id, body)
    return LoyaltySettingsOut.model_validate(settings)


# -----------------------------------------------------------------------------
# Membership Tiers
# -----------------------------------------------------------------------------
@router.get(
    "/tiers",
    response_model=list[MembershipTierOut],
    summary="List all membership tiers",
)
async def list_membership_tiers(
    active_only: bool = Query(default=False),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> list[MembershipTierOut]:
    service = CrmService(db)
    tiers = await service.get_tiers(user.business_id, active_only=active_only)
    return [MembershipTierOut.model_validate(t) for t in tiers]


@router.post(
    "/tiers",
    response_model=MembershipTierOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new membership tier",
)
async def create_membership_tier(
    body: MembershipTierCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> MembershipTierOut:
    service = CrmService(db)
    try:
        tier = await service.create_tier(user.business_id, body)
        return MembershipTierOut.model_validate(tier)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.put(
    "/tiers/{tier_id}",
    response_model=MembershipTierOut,
    summary="Update an existing membership tier",
)
async def update_membership_tier(
    tier_id: uuid.UUID,
    body: MembershipTierUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> MembershipTierOut:
    service = CrmService(db)
    try:
        tier = await service.update_tier(user.business_id, tier_id, body)
        return MembershipTierOut.model_validate(tier)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.delete(
    "/tiers/{tier_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a membership tier",
)
async def delete_membership_tier(
    tier_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> None:
    service = CrmService(db)
    try:
        await service.delete_tier(user.business_id, tier_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


# -----------------------------------------------------------------------------
# Customer Loyalty & Points Actions
# -----------------------------------------------------------------------------
@router.get(
    "/customers/{customer_id}/loyalty",
    response_model=CustomerLoyaltySummaryOut,
    summary="Get customer loyalty account summary & recent ledger",
)
async def get_customer_loyalty(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> CustomerLoyaltySummaryOut:
    service = CrmService(db)
    try:
        return await service.get_customer_loyalty_summary(user.business_id, customer_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.post(
    "/customers/{customer_id}/loyalty/adjust",
    response_model=LoyaltyTransactionOut,
    summary="Manually award bonus points or adjust customer points balance",
)
async def adjust_customer_loyalty_points(
    customer_id: uuid.UUID,
    body: LoyaltyPointsAdjustRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> LoyaltyTransactionOut:
    service = CrmService(db)
    try:
        return await service.adjust_customer_points(
            user.business_id, customer_id, body.points, body.reason
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post(
    "/customers/{customer_id}/loyalty/preview",
    response_model=PointsRedemptionPreviewOut,
    summary="Preview monetary discount and remaining balance for point redemption",
)
async def preview_points_redemption(
    customer_id: uuid.UUID,
    body: PointsRedemptionPreviewRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> PointsRedemptionPreviewOut:
    service = CrmService(db)
    return await service.preview_points_redemption(
        user.business_id, customer_id, body.points_to_redeem, body.cart_subtotal
    )


# -----------------------------------------------------------------------------
# Gift Cards
# -----------------------------------------------------------------------------
@router.get(
    "/gift-cards",
    response_model=list[GiftCardOut],
    summary="List gift cards with optional status or search filter",
)
async def list_gift_cards(
    status_filter: str | None = Query(default=None, alias="status"),
    search: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> list[GiftCardOut]:
    service = CrmService(db)
    cards = await service.get_gift_cards(user.business_id, status=status_filter, search=search)
    return [GiftCardOut.model_validate(c) for c in cards]


@router.post(
    "/gift-cards",
    response_model=GiftCardOut,
    status_code=status.HTTP_201_CREATED,
    summary="Issue a new stored-value gift card with PIN",
)
async def issue_gift_card(
    body: GiftCardCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> GiftCardOut:
    service = CrmService(db)
    try:
        card = await service.issue_gift_card(user.business_id, body)
        return GiftCardOut.model_validate(card)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post(
    "/gift-cards/verify",
    response_model=GiftCardVerifyOut,
    summary="Verify gift card balance and PIN credentials for POS redemption",
)
async def verify_gift_card(
    body: GiftCardVerifyRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> GiftCardVerifyOut:
    service = CrmService(db)
    return await service.verify_gift_card(user.business_id, body.card_number, body.pin)


@router.post(
    "/gift-cards/{card_id}/reload",
    response_model=GiftCardTransactionOut,
    summary="Top-up existing gift card balance",
)
async def reload_gift_card(
    card_id: uuid.UUID,
    body: GiftCardReloadRequest,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> GiftCardTransactionOut:
    service = CrmService(db)
    try:
        return await service.reload_gift_card(
            user.business_id, card_id, body.amount, body.reference, body.notes
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


@router.post(
    "/gift-cards/{card_id}/toggle-status",
    response_model=GiftCardOut,
    summary="Lock, unlock, or cancel a gift card",
)
async def toggle_gift_card_status(
    card_id: uuid.UUID,
    new_status: str = Query(...),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> GiftCardOut:
    service = CrmService(db)
    try:
        card = await service.toggle_gift_card_status(user.business_id, card_id, new_status)
        return GiftCardOut.model_validate(card)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


# -----------------------------------------------------------------------------
# Credit Notes
# -----------------------------------------------------------------------------
@router.get(
    "/credit-notes",
    response_model=list[CreditNoteOut],
    summary="List store credit notes",
)
async def list_credit_notes(
    customer_id: uuid.UUID | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    search: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> list[CreditNoteOut]:
    service = CrmService(db)
    notes = await service.get_credit_notes(
        user.business_id, customer_id=customer_id, status=status_filter, search=search
    )
    return [CreditNoteOut.model_validate(n) for n in notes]


@router.post(
    "/credit-notes",
    response_model=CreditNoteOut,
    status_code=status.HTTP_201_CREATED,
    summary="Issue a manual store credit note for customer",
)
async def create_credit_note(
    body: CreditNoteCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> CreditNoteOut:
    service = CrmService(db)
    try:
        note = await service.create_credit_note(
            user.business_id,
            body.customer_id,
            body.initial_amount,
            body.reason,
            body.sale_return_id,
            body.expires_at,
        )
        return CreditNoteOut.model_validate(note)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)) from e


# -----------------------------------------------------------------------------
# RFM & Retention Analytics
# -----------------------------------------------------------------------------
@router.get(
    "/rfm-analytics",
    response_model=RetentionKpisOut,
    summary="Compute 365-day customer RFM segmentation and retention KPIs",
)
async def get_rfm_analytics(
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> RetentionKpisOut:
    service = CrmService(db)
    return await service.get_rfm_analytics(user.business_id)


# -----------------------------------------------------------------------------
# Promotional Campaigns
# -----------------------------------------------------------------------------
@router.get(
    "/campaigns",
    response_model=list[PromotionalCampaignOut],
    summary="List marketing campaigns",
)
async def list_campaigns(
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> list[PromotionalCampaignOut]:
    service = CrmService(db)
    campaigns = await service.get_campaigns(user.business_id)
    return [PromotionalCampaignOut.model_validate(c) for c in campaigns]


@router.post(
    "/campaigns",
    response_model=PromotionalCampaignOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create or schedule a promotional broadcast campaign",
)
async def create_campaign(
    body: PromotionalCampaignCreate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> PromotionalCampaignOut:
    service = CrmService(db)
    campaign = await service.create_campaign(user.business_id, body)
    return PromotionalCampaignOut.model_validate(campaign)


@router.put(
    "/campaigns/{campaign_id}",
    response_model=PromotionalCampaignOut,
    summary="Update a promotional campaign",
)
async def update_campaign(
    campaign_id: uuid.UUID,
    body: PromotionalCampaignUpdate,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:write")),
) -> PromotionalCampaignOut:
    service = CrmService(db)
    try:
        camp = await service.update_campaign(user.business_id, campaign_id, body)
        return PromotionalCampaignOut.model_validate(camp)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.get(
    "/campaigns/{campaign_id}/audience-preview",
    response_model=AudiencePreviewOut,
    summary="Preview audience count and sample customer records for campaign",
)
async def preview_campaign_audience(
    campaign_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> AudiencePreviewOut:
    service = CrmService(db)
    try:
        return await service.preview_campaign_audience(user.business_id, campaign_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.get(
    "/campaigns/{campaign_id}/export-recipients",
    summary="Export campaign recipient contact list as CSV",
)
async def export_campaign_recipients(
    campaign_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: CurrentUser = Depends(require_permission("customers:read")),
) -> Response:
    service = CrmService(db)
    try:
        csv_content = await service.export_campaign_recipients_csv(user.business_id, campaign_id)
        return Response(
            content=csv_content,
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=campaign_{campaign_id}_recipients.csv"},
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
