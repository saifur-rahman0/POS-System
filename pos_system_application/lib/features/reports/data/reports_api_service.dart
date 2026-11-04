import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/customer_dues_report.dart';
import '../domain/models/dashboard_metrics.dart';
import '../domain/models/payment_method_breakdown.dart';
import '../domain/models/sales_time_series.dart';
import '../domain/models/stock_valuation.dart';
import '../domain/models/top_product.dart';

class ReportsApiService {
  final ApiClient apiClient;

  ReportsApiService({required this.apiClient});

  Future<DashboardMetricsModel> fetchDashboardMetrics({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (startDate != null) params['start_date'] = startDate.toIso8601String();
      if (endDate != null) params['end_date'] = endDate.toIso8601String();
      if (branchId != null) params['branch_id'] = branchId;

      final res = await apiClient.dio.get('/reports/dashboard', queryParameters: params);
      return DashboardMetricsModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<SalesTimeSeriesModel> fetchSalesTimeSeries({
    DateTime? startDate,
    DateTime? endDate,
    String interval = 'daily',
    String? branchId,
  }) async {
    try {
      final params = <String, dynamic>{'interval': interval};
      if (startDate != null) params['start_date'] = startDate.toIso8601String();
      if (endDate != null) params['end_date'] = endDate.toIso8601String();
      if (branchId != null) params['branch_id'] = branchId;

      final res = await apiClient.dio.get('/reports/sales', queryParameters: params);
      return SalesTimeSeriesModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<StockValuationModel> fetchStockValuation({String? branchId}) async {
    try {
      final params = <String, dynamic>{};
      if (branchId != null) params['branch_id'] = branchId;

      final res = await apiClient.dio.get('/reports/stock', queryParameters: params);
      return StockValuationModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<PaymentMethodBreakdownModel> fetchPaymentMethods({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (startDate != null) params['start_date'] = startDate.toIso8601String();
      if (endDate != null) params['end_date'] = endDate.toIso8601String();
      if (branchId != null) params['branch_id'] = branchId;

      final res = await apiClient.dio.get('/reports/payment-methods', queryParameters: params);
      return PaymentMethodBreakdownModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<TopProductsModel> fetchTopProducts({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
    int limit = 10,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (startDate != null) params['start_date'] = startDate.toIso8601String();
      if (endDate != null) params['end_date'] = endDate.toIso8601String();
      if (branchId != null) params['branch_id'] = branchId;

      final res = await apiClient.dio.get('/reports/top-products', queryParameters: params);
      return TopProductsModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<CustomerDuesReportModel> fetchCustomerDuesReport() async {
    try {
      final res = await apiClient.dio.get('/reports/customer-dues');
      return CustomerDuesReportModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<String> downloadReportCsv({
    required String reportType,
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  }) async {
    try {
      final params = <String, dynamic>{'report_type': reportType};
      if (startDate != null) params['start_date'] = startDate.toIso8601String();
      if (endDate != null) params['end_date'] = endDate.toIso8601String();
      if (branchId != null) params['branch_id'] = branchId;

      final res = await apiClient.dio.get(
        '/reports/export',
        queryParameters: params,
        options: Options(responseType: ResponseType.plain),
      );
      return res.data.toString();
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }
}

