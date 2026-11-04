import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class SyncPullResult {
  final DateTime serverTime;
  final int branchesCount;
  final int categoriesCount;
  final int productsCount;
  final int customersCount;
  final int stockBalancesCount;

  const SyncPullResult({
    required this.serverTime,
    required this.branchesCount,
    required this.categoriesCount,
    required this.productsCount,
    required this.customersCount,
    required this.stockBalancesCount,
  });
}

class SyncPushResult {
  final int totalSuccessful;
  final int totalFailed;

  const SyncPushResult({
    required this.totalSuccessful,
    required this.totalFailed,
  });
}

class SyncApiService {
  final ApiClient apiClient;

  SyncApiService({required this.apiClient});

  Future<SyncPullResult> pullDeltas({DateTime? since, String? branchId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (since != null) queryParams['since'] = since.toIso8601String();
      if (branchId != null) queryParams['branch_id'] = branchId;

      final response = await apiClient.dio.get(
        '/sync/pull',
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      return SyncPullResult(
        serverTime: DateTime.parse(data['server_time'] as String),
        branchesCount: (data['branches'] as List?)?.length ?? 0,
        categoriesCount: (data['categories'] as List?)?.length ?? 0,
        productsCount: (data['products'] as List?)?.length ?? 0,
        customersCount: (data['customers'] as List?)?.length ?? 0,
        stockBalancesCount: (data['stock_balances'] as List?)?.length ?? 0,
      );
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<SyncPushResult> pushOfflineSales(
      List<Map<String, dynamic>> sales) async {
    try {
      final response = await apiClient.dio.post(
        '/sync/push',
        data: {
          'client_terminal_id': 'FLUTTER-DESKTOP-POS',
          'sales': sales,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return SyncPushResult(
        totalSuccessful: data['total_successful'] as int? ?? 0,
        totalFailed: data['total_failed'] as int? ?? 0,
      );
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }
}

