"""Pure unit tests for Track 13 Customer Loyalty and CRM domain engines."""

from datetime import datetime, timedelta
from decimal import Decimal

import pytest

from app.modules.crm.gift_card_service import GiftCardService
from app.modules.crm.loyalty_engine import LoyaltyEngine
from app.modules.crm.models import MembershipTier
from app.modules.crm.rfm_engine import CustomerSalesData, RfmEngine


class TestLoyaltyEngine:
    def test_calculate_points_earned_basic(self) -> None:
        # 1000 spend at 1 pt per 100 with 1.0x multiplier = 10 pts
        pts = LoyaltyEngine.calculate_points_earned(
            sale_grand_total=Decimal("1000.00"),
            earn_rate=Decimal("1.0000"),
            points_multiplier=Decimal("1.00"),
            is_enabled=True,
        )
        assert pts == 10

    def test_calculate_points_earned_with_tier_multiplier(self) -> None:
        # 1000 spend at 1 pt per 100 with 1.5x multiplier = 15 pts
        pts = LoyaltyEngine.calculate_points_earned(
            sale_grand_total=Decimal("1000.00"),
            earn_rate=Decimal("1.0000"),
            points_multiplier=Decimal("1.50"),
            is_enabled=True,
        )
        assert pts == 15

    def test_calculate_points_earned_disabled_or_zero(self) -> None:
        pts1 = LoyaltyEngine.calculate_points_earned(
            sale_grand_total=Decimal("1000.00"),
            earn_rate=Decimal("1.0000"),
            is_enabled=False,
        )
        assert pts1 == 0

        pts2 = LoyaltyEngine.calculate_points_earned(
            sale_grand_total=Decimal("0.00"),
            earn_rate=Decimal("1.0000"),
            is_enabled=True,
        )
        assert pts2 == 0

    def test_validate_and_calculate_redemption_success(self) -> None:
        # 200 points at 0.10 BDT/pt = 20 BDT discount on 100 BDT cart (max 50% = 50 BDT)
        discount = LoyaltyEngine.validate_and_calculate_redemption(
            customer_points=500,
            points_to_redeem=200,
            cart_subtotal=Decimal("100.00"),
            is_enabled=True,
            min_redeem_points=100,
            redeem_rate=Decimal("0.1000"),
            max_cart_discount_pct=Decimal("50.00"),
        )
        assert discount == Decimal("20.0000")

    def test_validate_redemption_insufficient_points(self) -> None:
        with pytest.raises(ValueError, match="Insufficient points"):
            LoyaltyEngine.validate_and_calculate_redemption(
                customer_points=50,
                points_to_redeem=100,
                cart_subtotal=Decimal("100.00"),
                is_enabled=True,
            )

    def test_validate_redemption_below_minimum(self) -> None:
        with pytest.raises(ValueError, match="Minimum redemption threshold"):
            LoyaltyEngine.validate_and_calculate_redemption(
                customer_points=500,
                points_to_redeem=50,
                cart_subtotal=Decimal("100.00"),
                min_redeem_points=100,
            )

    def test_validate_redemption_exceeds_max_cart_pct(self) -> None:
        # 400 points = 40 BDT discount on 50 BDT cart with 50% max allowed (25 BDT)
        with pytest.raises(ValueError, match="exceeds maximum allowed"):
            LoyaltyEngine.validate_and_calculate_redemption(
                customer_points=500,
                points_to_redeem=400,
                cart_subtotal=Decimal("50.00"),
                min_redeem_points=100,
                redeem_rate=Decimal("0.1000"),
                max_cart_discount_pct=Decimal("50.00"),
            )

    def test_determine_membership_tier(self) -> None:
        bronze = MembershipTier(name="Bronze", code="BRONZE", min_spend=Decimal("0"), sort_order=1, is_active=True)
        silver = MembershipTier(name="Silver", code="SILVER", min_spend=Decimal("10000"), sort_order=2, is_active=True)
        gold = MembershipTier(name="Gold", code="GOLD", min_spend=Decimal("50000"), sort_order=3, is_active=True)
        tiers = [bronze, silver, gold]

        assert LoyaltyEngine.determine_membership_tier(Decimal("500"), tiers) == bronze
        assert LoyaltyEngine.determine_membership_tier(Decimal("15000"), tiers) == silver
        assert LoyaltyEngine.determine_membership_tier(Decimal("60000"), tiers) == gold


class TestGiftCardService:
    def test_generate_card_number_format(self) -> None:
        card_num = GiftCardService.generate_card_number("GC")
        assert card_num.startswith("GC-")
        parts = card_num.split("-")
        assert len(parts) == 4
        for p in parts[1:]:
            assert len(p) == 4

    def test_generate_credit_note_number_format(self) -> None:
        cn_num = GiftCardService.generate_credit_note_number("CN")
        assert cn_num.startswith("CN-")
        parts = cn_num.split("-")
        assert len(parts) == 3

    def test_hash_pin_and_verify(self) -> None:
        raw_pin = "4829"
        pin_hash = GiftCardService.hash_pin(raw_pin)
        assert "$" in pin_hash

        # Verify correct PIN
        assert GiftCardService.verify_pin(pin_hash, "4829") is True

        # Verify incorrect PIN
        assert GiftCardService.verify_pin(pin_hash, "0000") is False
        assert GiftCardService.verify_pin(pin_hash, "4828") is False


class TestRfmEngine:
    def test_score_recency(self) -> None:
        assert RfmEngine.calculate_r_score(5) == 5
        assert RfmEngine.calculate_r_score(25) == 4
        assert RfmEngine.calculate_r_score(60) == 3
        assert RfmEngine.calculate_r_score(120) == 2
        assert RfmEngine.calculate_r_score(250) == 1

    def test_score_frequency(self) -> None:
        assert RfmEngine.calculate_f_score(25) == 5
        assert RfmEngine.calculate_f_score(15) == 4
        assert RfmEngine.calculate_f_score(7) == 3
        assert RfmEngine.calculate_f_score(3) == 2
        assert RfmEngine.calculate_f_score(1) == 1

    def test_classify_segment(self) -> None:
        assert RfmEngine.classify_segment(5, 5, 5) == "CHAMPIONS"
        assert RfmEngine.classify_segment(4, 4, 4) == "CHAMPIONS"
        assert RfmEngine.classify_segment(3, 3, 3) == "LOYAL"
        assert RfmEngine.classify_segment(1, 4, 4) == "AT_RISK"
        assert RfmEngine.classify_segment(1, 1, 1) == "LOST"

    def test_score_customers_batch(self) -> None:
        now = datetime.utcnow()
        customers = [
            CustomerSalesData(
                customer_id="c1",
                customer_name="Alice Champion",
                phone="01711111111",
                last_sale_date=now - timedelta(days=5),
                order_count=22,
                total_spent=Decimal("50000.00"),
            ),
            CustomerSalesData(
                customer_id="c2",
                customer_name="Bob Lost",
                phone="01722222222",
                last_sale_date=now - timedelta(days=200),
                order_count=1,
                total_spent=Decimal("500.00"),
            ),
        ]

        scored = RfmEngine.score_customers(customers, reference_time=now)
        assert len(scored) == 2

        alice = next(s for s in scored if s.customer_id == "c1")
        assert alice.segment == "CHAMPIONS"
        assert alice.r_score == 5
        assert alice.f_score == 5

        bob = next(s for s in scored if s.customer_id == "c2")
        assert bob.segment == "LOST"
        assert bob.r_score == 1
        assert bob.f_score == 1
