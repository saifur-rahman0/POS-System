"""API endpoints for analytics dashboard and financial reports."""

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.modules.reports.schemas import (
    CustomerDuesSummaryOut,
    DashboardMetricsOut,
    PaymentMethodBreakdownOut,
    SalesTimeSeriesOut,
    StockValuationOut,
    TopProductsOut,
)
from app.modules.reports.service import ReportsService
from app.shared.auth import CurrentUser, get_current_user

router = APIRouter(prefix="/reports", tags=["Reports & Analytics"])
reports_service = ReportsService()


@router.get(
    "/dashboard",
    response_model=DashboardMetricsOut,
    status_code=status.HTTP_200_OK,
    summary="Get executive dashboard KPI metrics",
)
async def get_dashboard(
    start_date: datetime | None = Query(
        default=None, description="Start timestamp (UTC or ISO-8601)"
    ),
    end_date: datetime | None = Query(default=None, description="End timestamp (UTC or ISO-8601)"),
    branch_id: uuid.UUID | None = Query(default=None, description="Optional branch filter"),
    current_user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DashboardMetricsOut:
    """Computes gross sales, net sales, orders, margin %, refunds, and inventory alert counts."""
    return await reports_service.get_dashboard_metrics(
        session=session,
        business_id=current_user.business_id,
        start_date=start_date,
        end_date=end_date,
        branch_id=branch_id,
    )


@router.get(
    "/sales",
    response_model=SalesTimeSeriesOut,
    status_code=status.HTTP_200_OK,
    summary="Get time-series sales velocity and trend data",
)
async def get_sales_time_series(
    start_date: datetime | None = Query(default=None, description="Start timestamp"),
    end_date: datetime | None = Query(default=None, description="End timestamp"),
    interval: str = Query(default="daily", description="Interval: 'hourly' or 'daily'"),
    branch_id: uuid.UUID | None = Query(default=None, description="Optional branch filter"),
    current_user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SalesTimeSeriesOut:
    """Returns time-bucketed sales points for trend visualization."""
    return await reports_service.get_sales_time_series(
        session=session,
        business_id=current_user.business_id,
        start_date=start_date,
        end_date=end_date,
        interval=interval,
        branch_id=branch_id,
    )


@router.get(
    "/stock",
    response_model=StockValuationOut,
    status_code=status.HTTP_200_OK,
    summary="Get stock asset valuation and inventory alerts",
)
async def get_stock_valuation(
    branch_id: uuid.UUID | None = Query(default=None, description="Optional branch filter"),
    current_user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> StockValuationOut:
    """Returns invested capital at cost basis, potential retail revenue, and low-stock alerts."""
    return await reports_service.get_stock_valuation(
        session=session,
        business_id=current_user.business_id,
        branch_id=branch_id,
    )


@router.get(
    "/payment-methods",
    response_model=PaymentMethodBreakdownOut,
    status_code=status.HTTP_200_OK,
    summary="Get payment method distribution",
)
async def get_payment_methods(
    start_date: datetime | None = Query(default=None, description="Start timestamp"),
    end_date: datetime | None = Query(default=None, description="End timestamp"),
    branch_id: uuid.UUID | None = Query(default=None, description="Optional branch filter"),
    current_user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaymentMethodBreakdownOut:
    """Returns volume and ratio breakdown across Cash, Card, bKash, Nagad, Rocket, and Due."""
    return await reports_service.get_payment_methods(
        session=session,
        business_id=current_user.business_id,
        start_date=start_date,
        end_date=end_date,
        branch_id=branch_id,
    )


@router.get(
    "/top-products",
    response_model=TopProductsOut,
    status_code=status.HTTP_200_OK,
    summary="Get best-selling products ranked by revenue",
)
async def get_top_products(
    start_date: datetime | None = Query(default=None, description="Start timestamp"),
    end_date: datetime | None = Query(default=None, description="End timestamp"),
    branch_id: uuid.UUID | None = Query(default=None, description="Optional branch filter"),
    limit: int = Query(default=10, ge=1, le=100, description="Max products to return"),
    current_user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> TopProductsOut:
    """Returns top ranked products by volume and gross revenue."""
    return await reports_service.get_top_products(
        session=session,
        business_id=current_user.business_id,
        start_date=start_date,
        end_date=end_date,
        branch_id=branch_id,
        limit=limit,
    )


@router.get(
    "/customer-dues",
    response_model=CustomerDuesSummaryOut,
    status_code=status.HTTP_200_OK,
    summary="Get customer dues and credit liability report",
)
async def get_customer_dues(
    current_user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> CustomerDuesSummaryOut:
    """Returns outstanding accounts receivable summary and top debtor exposure."""
    return await reports_service.get_customer_dues_report(
        session=session,
        business_id=current_user.business_id,
    )


@router.get(
    "/export",
    status_code=status.HTTP_200_OK,
    summary="Export report dataset as CSV download",
)
async def export_report(
    report_type: str = Query(
        default="summary",
        description="Type: 'summary', 'top_products', 'stock_valuation', 'payment_methods', 'customer_dues'",
    ),
    start_date: datetime | None = Query(default=None),
    end_date: datetime | None = Query(default=None),
    branch_id: uuid.UUID | None = Query(default=None),
    current_user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Response:
    """Generates and streams a downloadable CSV document."""
    csv_content = await reports_service.export_report_csv(
        session=session,
        business_id=current_user.business_id,
        report_type=report_type,
        start_date=start_date,
        end_date=end_date,
        branch_id=branch_id,
    )
    today_str = datetime.now(UTC).strftime("%Y%m%d_%H%M")
    filename = f"pos_report_{report_type}_{today_str}.csv"

    return Response(
        content=csv_content,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
