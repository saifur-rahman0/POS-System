"""Stateless mathematical calculations for loyalty points and membership tiers."""

import math
from decimal import ROUND_HALF_UP, Decimal

from app.modules.crm.models import MembershipTier


class LoyaltyEngine:
    """Pure domain calculations for points earning, redemption conversion, and tier qualification."""

    @staticmethod
    def calculate_points_earned(
        sale_grand_total: Decimal,
        earn_rate: Decimal,
        points_multiplier: Decimal = Decimal("1.00"),
        is_enabled: bool = True,
    ) -> int:
        """Compute points earned on a completed purchase.

        Formula: floor((sale_grand_total / 100) * earn_rate * points_multiplier)
        """
        if not is_enabled or sale_grand_total <= Decimal("0"):
            return 0

        # earn_rate is points per 100 currency units
        base_points = (sale_grand_total / Decimal("100")) * earn_rate * points_multiplier
        points_int = math.floor(float(base_points))
        return max(0, points_int)

    @staticmethod
    def validate_and_calculate_redemption(
        customer_points: int,
        points_to_redeem: int,
        cart_subtotal: Decimal,
        is_enabled: bool = True,
        min_redeem_points: int = 100,
        redeem_rate: Decimal = Decimal("0.1000"),
        max_cart_discount_pct: Decimal = Decimal("50.00"),
    ) -> Decimal:
        """Validate points redemption and return equivalent monetary discount.

        Raises ValueError if requirements are not met.
        """
        if not is_enabled:
            raise ValueError("Loyalty points program is currently disabled")

        if points_to_redeem <= 0:
            raise ValueError("Points to redeem must be greater than zero")

        if customer_points < points_to_redeem:
            raise ValueError(
                f"Insufficient points: customer has {customer_points} points, requested {points_to_redeem}"
            )

        if points_to_redeem < min_redeem_points:
            raise ValueError(
                f"Minimum redemption threshold is {min_redeem_points} points (requested {points_to_redeem})"
            )

        discount = Decimal(points_to_redeem) * redeem_rate
        discount = discount.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)

        max_allowed_discount = (cart_subtotal * max_cart_discount_pct) / Decimal("100")
        max_allowed_discount = max_allowed_discount.quantize(Decimal("0.0001"), rounding=ROUND_HALF_UP)

        if discount > max_allowed_discount:
            raise ValueError(
                f"Points discount ({discount}) exceeds maximum allowed {max_cart_discount_pct}% of order ({max_allowed_discount})"
            )

        if discount > cart_subtotal:
            discount = cart_subtotal

        return discount

    @staticmethod
    def determine_membership_tier(
        lifetime_spend: Decimal,
        active_tiers: list[MembershipTier],
    ) -> MembershipTier | None:
        """Find the highest qualifying active membership tier based on lifetime spend."""
        if not active_tiers:
            return None

        # Sort descending by min_spend, then sort_order
        sorted_tiers = sorted(
            [t for t in active_tiers if t.is_active],
            key=lambda t: (t.min_spend, t.sort_order),
            reverse=True,
        )

        for tier in sorted_tiers:
            if lifetime_spend >= tier.min_spend:
                return tier

        return None
