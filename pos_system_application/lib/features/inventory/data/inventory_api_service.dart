import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/parsers.dart';
import '../domain/models/stock_adjustment.dart';
import '../domain/models/stock_movement.dart';

class InventoryApiService {
  final ApiClient _apiClient;

  InventoryApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<StockAdjustmentModel> adjustStock({
    required String productVariantId,
    required String adjustmentType,
    required double quantity,
    required String reason,
    String? branchId,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/inventory/adjustments',
        data: {
          'product_variant_id': productVariantId,
          'adjustment_type': adjustmentType,
          'quantity': quantity.toStringAsFixed(4),
          'reason': reason,
          if (branchId != null) 'branch_id': branchId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return StockAdjustmentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<double> getStockBalance(String productVariantId, {String? branchId}) async {
    try {
      final response = await _apiClient.dio.get(
        '/inventory/balances/$productVariantId',
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return parseDouble(data['quantity_on_hand']);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<Map<String, double>> getAllStockBalances({String? branchId}) async {
    try {
      final response = await _apiClient.dio.get(
        '/inventory/balances',
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );
      final list = response.data as List<dynamic>;
      final map = <String, double>{};
      for (final item in list) {
        if (item is Map) {
          final vId = item['product_variant_id']?.toString();
          final qty = parseDouble(item['quantity_on_hand']);
          if (vId != null) {
            map[vId] = qty;
          }
        }
      }
      return map;
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PaginatedStockMovementsModel> getStockMovements({
    String? productVariantId,
    String? branchId,
    String? movementType,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (productVariantId != null) {
        queryParams['product_variant_id'] = productVariantId;
      }
      if (branchId != null) {
        queryParams['branch_id'] = branchId;
      }
      if (movementType != null) {
        queryParams['movement_type'] = movementType;
      }

      final response = await _apiClient.dio.get(
        '/inventory/movements',
        queryParameters: queryParams,
      );

      return PaginatedStockMovementsModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }
}
