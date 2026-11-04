import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_client/core/network/api_provider.dart';
import 'package:pos_client/features/branches/presentation/controllers/branches_controller.dart';
import 'package:pos_client/features/reports/data/reports_api_service.dart';
import 'package:pos_client/features/reports/domain/models/customer_dues_report.dart';
import 'package:pos_client/features/reports/domain/models/dashboard_metrics.dart';
import 'package:pos_client/features/reports/domain/models/payment_method_breakdown.dart';
import 'package:pos_client/features/reports/domain/models/sales_time_series.dart';
import 'package:pos_client/features/reports/domain/models/stock_valuation.dart';
import 'package:pos_client/features/reports/domain/models/top_product.dart';

final reportsApiServiceProvider = Provider<ReportsApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportsApiService(apiClient: apiClient);
});

enum ReportDatePreset {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
}

extension ReportDatePresetExt on ReportDatePreset {
  String get label {
    switch (this) {
      case ReportDatePreset.today:
        return 'Today';
      case ReportDatePreset.yesterday:
        return 'Yesterday';
      case ReportDatePreset.last7Days:
        return 'Last 7 Days';
      case ReportDatePreset.last30Days:
        return 'Last 30 Days';
      case ReportDatePreset.thisMonth:
        return 'This Month';
    }
  }

  (DateTime start, DateTime end) toDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (this) {
      case ReportDatePreset.today:
        return (todayStart, todayEnd);
      case ReportDatePreset.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 1));
        final yEnd = DateTime(yStart.year, yStart.month, yStart.day, 23, 59, 59);
        return (yStart, yEnd);
      case ReportDatePreset.last7Days:
        return (todayStart.subtract(const Duration(days: 6)), todayEnd);
      case ReportDatePreset.last30Days:
        return (todayStart.subtract(const Duration(days: 29)), todayEnd);
      case ReportDatePreset.thisMonth:
        final mStart = DateTime(now.year, now.month, 1);
        return (mStart, todayEnd);
    }
  }
}

final reportDatePresetProvider =
    StateProvider<ReportDatePreset>((ref) => ReportDatePreset.today);

final reportBranchFilterProvider = StateProvider<String?>((ref) {
  // Defaults to active terminal branch if selected, or null for all branches
  final activeBranch = ref.watch(activeBranchProvider);
  return activeBranch?.id;
});

final reportsTabProvider = StateProvider<int>((ref) => 0);

final dashboardMetricsProvider =
    FutureProvider.autoDispose<DashboardMetricsModel>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final preset = ref.watch(reportDatePresetProvider);
  final branchId = ref.watch(reportBranchFilterProvider);
  final (start, end) = preset.toDateRange();

  return api.fetchDashboardMetrics(
    startDate: start,
    endDate: end,
    branchId: branchId,
  );
});

final salesTimeSeriesProvider =
    FutureProvider.autoDispose<SalesTimeSeriesModel>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final preset = ref.watch(reportDatePresetProvider);
  final branchId = ref.watch(reportBranchFilterProvider);
  final (start, end) = preset.toDateRange();

  final interval = (preset == ReportDatePreset.today || preset == ReportDatePreset.yesterday)
      ? 'hourly'
      : 'daily';

  return api.fetchSalesTimeSeries(
    startDate: start,
    endDate: end,
    interval: interval,
    branchId: branchId,
  );
});

final stockValuationProvider =
    FutureProvider.autoDispose<StockValuationModel>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final branchId = ref.watch(reportBranchFilterProvider);

  return api.fetchStockValuation(branchId: branchId);
});

final paymentBreakdownProvider =
    FutureProvider.autoDispose<PaymentMethodBreakdownModel>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final preset = ref.watch(reportDatePresetProvider);
  final branchId = ref.watch(reportBranchFilterProvider);
  final (start, end) = preset.toDateRange();

  return api.fetchPaymentMethods(
    startDate: start,
    endDate: end,
    branchId: branchId,
  );
});

final topProductsProvider =
    FutureProvider.autoDispose<TopProductsModel>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final preset = ref.watch(reportDatePresetProvider);
  final branchId = ref.watch(reportBranchFilterProvider);
  final (start, end) = preset.toDateRange();

  return api.fetchTopProducts(
    startDate: start,
    endDate: end,
    branchId: branchId,
    limit: 15,
  );
});

final customerDuesReportProvider =
    FutureProvider.autoDispose<CustomerDuesReportModel>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  return api.fetchCustomerDuesReport();
});
