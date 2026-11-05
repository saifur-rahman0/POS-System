import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/advanced_inventory_api_service.dart';
import '../../domain/models/damaged_stock.dart';
import '../../domain/models/inventory_batch.dart';
import '../../domain/models/inventory_valuation.dart';
import '../../domain/models/reorder_suggestion.dart';
import '../../domain/models/stock_count.dart';
import '../../domain/models/stock_reservation.dart';

final advancedInventoryApiServiceProvider = Provider<AdvancedInventoryApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdvancedInventoryApiService(apiClient: apiClient);
});

// ============================================================================
// 1. Batches Controller
// ============================================================================
class BatchesListNotifier extends StateNotifier<AsyncValue<List<InventoryBatchModel>>> {
  final AdvancedInventoryApiService _apiService;
  String? _branchId;
  String? _variantId;

  BatchesListNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadBatches();
  }

  Future<void> loadBatches({String? branchId, String? variantId}) async {
    if (branchId != null) _branchId = branchId;
    if (variantId != null) _variantId = variantId;
    state = const AsyncValue.loading();
    try {
      final batches = await _apiService.getBatches(
        branchId: _branchId,
        productVariantId: _variantId,
      );
      state = AsyncValue.data(batches);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

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
    final newBatch = await _apiService.createBatch(
      branchId: branchId ?? _branchId,
      productVariantId: productVariantId,
      batchNumber: batchNumber,
      manufacturingDate: manufacturingDate,
      expiryDate: expiryDate,
      quantityReceived: quantityReceived,
      costPrice: costPrice,
      supplierId: supplierId,
    );
    await loadBatches();
    return newBatch;
  }
}

final batchesListProvider =
    StateNotifierProvider<BatchesListNotifier, AsyncValue<List<InventoryBatchModel>> >((ref) {
  final api = ref.watch(advancedInventoryApiServiceProvider);
  return BatchesListNotifier(api);
});

final expiryAlertsProvider = FutureProvider<List<ExpiryAlertModel>>((ref) async {
  final api = ref.watch(advancedInventoryApiServiceProvider);
  return api.getExpiryAlerts();
});

// ============================================================================
// 2. Damaged Stock Controller
// ============================================================================
class DamagedStockNotifier extends StateNotifier<AsyncValue<List<DamagedStockModel>>> {
  final AdvancedInventoryApiService _apiService;
  String? _branchId;

  DamagedStockNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadDamagedRecords();
  }

  Future<void> loadDamagedRecords({String? branchId}) async {
    if (branchId != null) _branchId = branchId;
    state = const AsyncValue.loading();
    try {
      final records = await _apiService.getDamagedRecords(branchId: _branchId);
      state = AsyncValue.data(records);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

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
    final record = await _apiService.recordDamagedStock(
      branchId: branchId ?? _branchId,
      productVariantId: productVariantId,
      batchId: batchId,
      quantity: quantity,
      unitCost: unitCost,
      reason: reason,
      disposalMethod: disposalMethod,
      notes: notes,
    );
    await loadDamagedRecords();
    return record;
  }
}

final damagedStockListProvider =
    StateNotifierProvider<DamagedStockNotifier, AsyncValue<List<DamagedStockModel>> >((ref) {
  final api = ref.watch(advancedInventoryApiServiceProvider);
  return DamagedStockNotifier(api);
});

// ============================================================================
// 3. Stock Reservations Controller
// ============================================================================
class StockReservationsNotifier extends StateNotifier<AsyncValue<List<StockReservationModel>> > {
  final AdvancedInventoryApiService _apiService;
  String? _branchId;
  String? _status;

  StockReservationsNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadReservations();
  }

  Future<void> loadReservations({String? branchId, String? status}) async {
    if (branchId != null) _branchId = branchId;
    if (status != null) _status = status;
    state = const AsyncValue.loading();
    try {
      final reservations = await _apiService.getReservations(
        branchId: _branchId,
        status: _status,
      );
      state = AsyncValue.data(reservations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
    final res = await _apiService.createReservation(
      branchId: branchId ?? _branchId,
      productVariantId: productVariantId,
      batchId: batchId,
      quantity: quantity,
      referenceType: referenceType,
      referenceId: referenceId,
      durationHours: durationHours,
    );
    await loadReservations();
    return res;
  }

  Future<StockReservationModel> releaseReservation(String reservationId) async {
    final res = await _apiService.releaseReservation(reservationId: reservationId);
    await loadReservations();
    return res;
  }
}

final stockReservationsListProvider =
    StateNotifierProvider<StockReservationsNotifier, AsyncValue<List<StockReservationModel>> >((ref) {
  final api = ref.watch(advancedInventoryApiServiceProvider);
  return StockReservationsNotifier(api);
});

// ============================================================================
// 4. Physical Stock Counts (Audits) Controller
// ============================================================================
class StockCountsNotifier extends StateNotifier<AsyncValue<List<StockCountModel>> > {
  final AdvancedInventoryApiService _apiService;
  String? _branchId;

  StockCountsNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadCounts();
  }

  Future<void> loadCounts({String? branchId, String? status}) async {
    if (branchId != null) _branchId = branchId;
    state = const AsyncValue.loading();
    try {
      final counts = await _apiService.getStockCounts(
        branchId: _branchId,
        status: status,
      );
      state = AsyncValue.data(counts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<StockCountModel> createCount({
    String? branchId,
    String? notes,
  }) async {
    final count = await _apiService.createStockCount(
      branchId: branchId ?? _branchId,
      notes: notes,
    );
    await loadCounts();
    return count;
  }

  Future<StockCountModel> scanItem({
    required String countId,
    required String barcode,
    double incrementQty = 1.0,
  }) async {
    final updated = await _apiService.scanStockCountItem(
      countId: countId,
      barcode: barcode,
      incrementQty: incrementQty,
    );
    await loadCounts();
    return updated;
  }

  Future<StockCountModel> completeCount(String countId) async {
    final completed = await _apiService.completeStockCount(countId);
    await loadCounts();
    return completed;
  }
}

final stockCountsListProvider =
    StateNotifierProvider<StockCountsNotifier, AsyncValue<List<StockCountModel>> >((ref) {
  final api = ref.watch(advancedInventoryApiServiceProvider);
  return StockCountsNotifier(api);
});

// ============================================================================
// 5. Reorder Engine & Valuation Providers
// ============================================================================
final reorderSuggestionsProvider = FutureProvider<List<ReorderSuggestionModel>>((ref) async {
  final api = ref.watch(advancedInventoryApiServiceProvider);
  return api.getReorderSuggestions();
});

final inventoryValuationProvider = FutureProvider<InventoryValuationReportModel>((ref) async {
  final api = ref.watch(advancedInventoryApiServiceProvider);
  return api.getInventoryValuation();
});
