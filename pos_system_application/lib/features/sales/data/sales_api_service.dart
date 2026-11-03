import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_provider.dart';
import '../../checkout/domain/models/sale_receipt.dart';
import '../domain/models/paginated_sales.dart';
import '../domain/models/sale_return.dart';
import '../domain/models/sale_returnable_item.dart';

final salesApiServiceProvider = Provider<SalesApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SalesApiService(apiClient: apiClient);
});

class SalesApiService {
  final ApiClient apiClient;

  SalesApiService({required this.apiClient});

  Future<PaginatedSalesModel> getSales({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null && status.trim().isNotEmpty && status != 'ALL') {
        queryParams['status'] = status.trim().toUpperCase();
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }

      final response = await apiClient.dio.get(
        '/sales',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is Map) {
        return PaginatedSalesModel.fromJson(data);
      }
      throw 'Invalid response format from server';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<SaleReceiptModel> getSaleDetail(String saleId) async {
    try {
      final response = await apiClient.dio.get('/sales/$saleId');
      final data = response.data;
      if (data is Map) {
        return SaleReceiptModel.fromJson(data);
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<List<SaleReturnableItemModel>> getReturnableItems(String saleId) async {
    try {
      final response = await apiClient.dio.get('/sales/$saleId/returnable-items');
      final data = response.data;
      if (data is List) {
        return data
            .map((item) => SaleReturnableItemModel.fromJson(item is Map ? item : {}))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<List<SaleReturnModel>> getSaleReturns(String saleId) async {
    try {
      final response = await apiClient.dio.get('/sales/$saleId/returns');
      final data = response.data;
      if (data is List) {
        return data
            .map((ret) => SaleReturnModel.fromJson(ret is Map ? ret : {}))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<SaleReturnModel> createReturn(
    String saleId, {
    required List<Map<String, dynamic>> items,
    String? reason,
    String refundMethod = 'CASH',
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/sales/$saleId/returns',
        data: {
          'items': items,
          'reason': reason,
          'refund_method': refundMethod,
        },
      );
      final data = response.data;
      if (data is Map) {
        return SaleReturnModel.fromJson(data);
      }
      throw 'Invalid return response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<SaleReceiptModel> voidSale(String saleId, {required String reason}) async {
    try {
      final response = await apiClient.dio.post(
        '/sales/$saleId/void',
        data: {'reason': reason},
      );
      final data = response.data;
      if (data is Map) {
        return SaleReceiptModel.fromJson(data);
      }
      throw 'Invalid void response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }
}

