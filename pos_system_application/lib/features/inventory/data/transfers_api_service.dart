import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/stock_transfer.dart';

class TransfersApiService {
  final ApiClient apiClient;

  TransfersApiService({required this.apiClient});

  Future<List<StockTransferModel>> listTransfers({
    String? sourceBranchId,
    String? destinationBranchId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sourceBranchId != null) queryParams['source_branch_id'] = sourceBranchId;
      if (destinationBranchId != null) {
        queryParams['destination_branch_id'] = destinationBranchId;
      }
      if (status != null) queryParams['status'] = status;

      final response = await apiClient.dio.get(
        '/transfers',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map((item) =>
                StockTransferModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<StockTransferModel> getTransfer(String transferId) async {
    try {
      final response = await apiClient.dio.get('/transfers/$transferId');
      final data = response.data;
      if (data is Map) {
        return StockTransferModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<StockTransferModel> createTransfer({
    required String sourceBranchId,
    required String destinationBranchId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/transfers',
        data: {
          'source_branch_id': sourceBranchId,
          'destination_branch_id': destinationBranchId,
          'items': items,
          'notes': notes,
        },
      );

      final data = response.data;
      if (data is Map) {
        return StockTransferModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<StockTransferModel> sendTransfer(String transferId) async {
    try {
      final response = await apiClient.dio.post('/transfers/$transferId/send');
      final data = response.data;
      if (data is Map) {
        return StockTransferModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<StockTransferModel> receiveTransfer(String transferId) async {
    try {
      final response =
          await apiClient.dio.post('/transfers/$transferId/receive');
      final data = response.data;
      if (data is Map) {
        return StockTransferModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<StockTransferModel> cancelTransfer(String transferId) async {
    try {
      final response = await apiClient.dio.post('/transfers/$transferId/cancel');
      final data = response.data;
      if (data is Map) {
        return StockTransferModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<List<CrossBranchStockItemModel>> getCrossBranchStock(
      String productVariantId) async {
    try {
      final response =
          await apiClient.dio.get('/transfers/cross-branch-stock/$productVariantId');
      final data = response.data;
      if (data is List) {
        return data
            .map((item) => CrossBranchStockItemModel.fromJson(
                item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }
}

