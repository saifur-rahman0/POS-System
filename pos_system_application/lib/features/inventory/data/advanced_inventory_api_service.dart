import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/damaged_stock.dart';
import '../domain/models/inventory_batch.dart';
import '../domain/models/inventory_valuation.dart';
import '../domain/models/reorder_suggestion.dart';
import '../domain/models/stock_count.dart';
import '../domain/models/stock_reservation.dart';

class AdvancedInventoryApiService {
  final ApiClient _apiClient;

  AdvancedInventoryApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  // =========================================================================
  // 1. Batches & Expiry Management
  // =========================================================================
  Future<InventoryBatchModel> createBatch({
    String? branchId,
    required String productVariantId,
    required String batchNumber,
    DateTime? manufacturingDate,
    DateTime? expiryDate,
    required double quantityReceived,
    double costPrice = 0.0,
    String? supplierId,
  }) async {
    try {
      final data = {
        if (branchId != null) 'branch_id': branchId,
        'product_variant_id': productVariantId,
        'batch_number': batchNumber,
        if (manufacturingDate != null)
          'manufacturing_date': manufacturingDate.toIso8601String().substring(0, 10),
        if (expiryDate != null)
          'expiry_date': expiryDate.toIso8601String().substring(0, 10),
        'quantity_received': quantityReceived,
        'cost_price': costPrice,
        if (supplierId != null) 'supplier_id': supplierId,
      };
      final res = await _apiClient.dio.post('/inventory/batches', data: data);
      return InventoryBatchModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<List<InventoryBatchModel>> getBatches({
    String? branchId,
    String? productVariantId,
    bool? isActive,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (branchId != null) qp['branch_id'] = branchId;
      if (productVariantId != null) qp['product_variant_id'] = productVariantId;
      if (isActive != null) qp['is_active'] = isActive;

      final res = await _apiClient.dio.get('/inventory/batches', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => InventoryBatchModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<List<ExpiryAlertModel>> getExpiryAlerts({
    String? branchId,
    int daysThreshold = 60,
  }) async {
    try {
      final qp = <String, dynamic>{'days_threshold': daysThreshold};
      if (branchId != null) qp['branch_id'] = branchId;

      final res = await _apiClient.dio.get('/inventory/batches/alerts', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => ExpiryAlertModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // =========================================================================
  // 2. Damaged Stock & Write-offs
  // =========================================================================
  Future<DamagedStockModel> recordDamagedStock({
    String? branchId,
    required String productVariantId,
    String? batchId,
    required double quantity,
    double? unitCost,
    required String reason,
    required String disposalMethod,
    String? notes,
  }) async {
    try {
      final data = {
        if (branchId != null) 'branch_id': branchId,
        'product_variant_id': productVariantId,
        if (batchId != null) 'batch_id': batchId,
        'quantity': quantity,
        if (unitCost != null) 'unit_cost': unitCost,
        'reason': reason,
        'disposal_method': disposalMethod,
        if (notes != null) 'notes': notes,
      };
      final res = await _apiClient.dio.post('/inventory/damaged', data: data);
      return DamagedStockModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<List<DamagedStockModel>> getDamagedRecords({
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (branchId != null) qp['branch_id'] = branchId;
      if (startDate != null) qp['start_date'] = startDate.toIso8601String();
      if (endDate != null) qp['end_date'] = endDate.toIso8601String();

      final res = await _apiClient.dio.get('/inventory/damaged', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => DamagedStockModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // =========================================================================
  // 3. Stock Reservations
  // =========================================================================
  Future<AvailableStockModel> getAvailableStock({
    required String productVariantId,
    required String branchId,
  }) async {
    try {
      final res = await _apiClient.dio.get(
        '/inventory/available/$productVariantId',
        queryParameters: {'branch_id': branchId},
      );
      return AvailableStockModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<StockReservationModel> createReservation({
    String? branchId,
    required String productVariantId,
    String? batchId,
    required double quantity,
    required String referenceType,
    required String referenceId,
    int durationHours = 24,
  }) async {
    try {
      final data = {
        if (branchId != null) 'branch_id': branchId,
        'product_variant_id': productVariantId,
        if (batchId != null) 'batch_id': batchId,
        'quantity': quantity,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'duration_hours': durationHours,
      };
      final res = await _apiClient.dio.post('/inventory/reservations', data: data);
      return StockReservationModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<StockReservationModel> releaseReservation({
    required String reservationId,
    String statusAction = 'RELEASED',
  }) async {
    try {
      final res = await _apiClient.dio.post(
        '/inventory/reservations/$reservationId/release',
        queryParameters: {'status_action': statusAction},
      );
      return StockReservationModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<List<StockReservationModel>> getReservations({
    String? branchId,
    String? productVariantId,
    String? status,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (branchId != null) qp['branch_id'] = branchId;
      if (productVariantId != null) qp['product_variant_id'] = productVariantId;
      if (status != null) qp['status'] = status;

      final res = await _apiClient.dio.get('/inventory/reservations', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => StockReservationModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // =========================================================================
  // 4. Physical Stock Counts (Audits)
  // =========================================================================
  Future<StockCountModel> createStockCount({
    String? branchId,
    String? notes,
  }) async {
    try {
      final data = {
        if (branchId != null) 'branch_id': branchId,
        if (notes != null) 'notes': notes,
        'lines': [],
      };
      final res = await _apiClient.dio.post('/inventory/counts', data: data);
      return StockCountModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<List<StockCountModel>> getStockCounts({
    String? branchId,
    String? status,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (branchId != null) qp['branch_id'] = branchId;
      if (status != null) qp['status'] = status;

      final res = await _apiClient.dio.get('/inventory/counts', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => StockCountModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<StockCountModel> getStockCount(String countId) async {
    try {
      final res = await _apiClient.dio.get('/inventory/counts/$countId');
      return StockCountModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<StockCountModel> scanStockCountItem({
    required String countId,
    required String barcode,
    double incrementQty = 1.0,
  }) async {
    try {
      final data = {
        'barcode': barcode,
        'increment_qty': incrementQty,
      };
      final res = await _apiClient.dio.post('/inventory/counts/$countId/scan', data: data);
      return StockCountModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<StockCountModel> completeStockCount(String countId) async {
    try {
      final res = await _apiClient.dio.post('/inventory/counts/$countId/complete');
      return StockCountModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // =========================================================================
  // 5. Reorder Suggestions & Thresholds
  // =========================================================================
  Future<List<ReorderSuggestionModel>> getReorderSuggestions({String? branchId}) async {
    try {
      final qp = <String, dynamic>{};
      if (branchId != null) qp['branch_id'] = branchId;

      final res = await _apiClient.dio.get('/inventory/reorder/suggestions', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => ReorderSuggestionModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> updateVariantThresholds({
    required String variantId,
    required double minStockLevel,
    required double reorderQuantity,
    bool? hasBatchTracking,
  }) async {
    try {
      final data = {
        'min_stock_level': minStockLevel,
        'reorder_quantity': reorderQuantity,
        if (hasBatchTracking != null) 'has_batch_tracking': hasBatchTracking,
      };
      final res = await _apiClient.dio.patch('/inventory/variants/$variantId/thresholds', data: data);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // =========================================================================
  // 6. Multi-tier Valuation
  // =========================================================================
  Future<InventoryValuationReportModel> getInventoryValuation({String? branchId}) async {
    try {
      final qp = <String, dynamic>{};
      if (branchId != null) qp['branch_id'] = branchId;

      final res = await _apiClient.dio.get('/inventory/valuation', queryParameters: qp);
      return InventoryValuationReportModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }
}

