"""Algorithmic RFM (Recency, Frequency, Monetary) segmentation and customer retention calculations."""

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass
class CustomerSalesData:
    customer_id: str
    customer_name: str
    phone: str | None
    last_sale_date: datetime | None
    order_count: int
    total_spent: Decimal


@dataclass
class ScoredCustomer:
    customer_id: str
    customer_name: str
    phone: str | None
    recency_days: int
    frequency_orders: int
    monetary_spent: Decimal
    r_score: int
    f_score: int
    m_score: int
    segment: str


class RfmEngine:
    """Computes customer RFM quintiles, behavioral segments, and retention KPIs."""

    @staticmethod
    def calculate_r_score(recency_days: int) -> int:
        if recency_days <= 14:
            return 5
        elif recency_days <= 45:
            return 4
        elif recency_days <= 90:
            return 3
        elif recency_days <= 180:
            return 2
        return 1

    @staticmethod
    def calculate_f_score(order_count: int) -> int:
        if order_count >= 20:
            return 5
        elif order_count >= 10:
            return 4
        elif order_count >= 5:
            return 3
        elif order_count >= 2:
            return 2
        return 1

    @classmethod
    def calculate_m_score_from_rank(cls, index: int, total_count: int) -> int:
        """Compute 1-5 monetary quintile score from sorted spend position."""
        if total_count <= 1:
            return 3  # Single customer gets median score
        normalized_rank = index / (total_count - 1)  # Range: 0.0 to 1.0
        if normalized_rank >= 0.8:
            return 5
        elif normalized_rank >= 0.6:
            return 4
        elif normalized_rank >= 0.4:
            return 3
        elif normalized_rank >= 0.2:
            return 2
        return 1

    @classmethod
    def classify_segment(cls, r: int, f: int, m: int) -> str:
        """Map (R, F, M) triplet into an actionable marketing cohort."""
        if r >= 4 and f >= 4 and m >= 4:
            return "CHAMPIONS"
        elif r >= 3 and f >= 3 and m >= 3:
            return "LOYAL"
        elif r >= 4 and f <= 2 and m >= 2:
            return "POTENTIAL_LOYALIST"
        elif r >= 4 and f == 1:
            return "NEW_CUSTOMER"
        elif r == 3 and f <= 2:
            return "PROMISING"
        elif r == 3 and f >= 3:
            return "NEED_ATTENTION"
        elif r <= 2 and f >= 3 and m >= 3:
            return "AT_RISK"
        elif r <= 2 and f <= 2 and m >= 3:
            return "HIBERNATING"
        else:
            return "LOST"

    @classmethod
    def score_customers(
        cls,
        customers: list[CustomerSalesData],
        reference_time: datetime | None = None,
    ) -> list[ScoredCustomer]:
        """Process a list of customer sales aggregates and produce scored records."""
        if not customers:
            return []

        if reference_time is None:
            reference_time = datetime.utcnow()

        # Sort positive spends to compute rank-based monetary quintiles
        spends = sorted([c.total_spent for c in customers if c.total_spent > Decimal("0")])
        n_spends = len(spends)

        scored: list[ScoredCustomer] = []
        for c in customers:
            if c.last_sale_date:
                # remove timezone if needed for comparison
                last_dt = c.last_sale_date.replace(tzinfo=None) if c.last_sale_date.tzinfo else c.last_sale_date
                ref_dt = reference_time.replace(tzinfo=None) if reference_time.tzinfo else reference_time
                recency_days = max(0, (ref_dt - last_dt).days)
            else:
                recency_days = 999

            r_score = cls.calculate_r_score(recency_days)
            f_score = cls.calculate_f_score(c.order_count)

            if c.total_spent > Decimal("0") and n_spends > 0:
                spend_idx = spends.index(c.total_spent)
                m_score = cls.calculate_m_score_from_rank(spend_idx, n_spends)
            else:
                m_score = 1

            segment = cls.classify_segment(r_score, f_score, m_score)

            scored.append(
                ScoredCustomer(
                    customer_id=c.customer_id,
                    customer_name=c.customer_name,
                    phone=c.phone,
                    recency_days=recency_days,
                    frequency_orders=c.order_count,
                    monetary_spent=c.total_spent,
                    r_score=r_score,
                    f_score=f_score,
                    m_score=m_score,
                    segment=segment,
                )
            )

        return scored
