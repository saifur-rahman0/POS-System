import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../../branches/presentation/controllers/branches_controller.dart';
import '../../data/inventory_api_service.dart';
import '../../domain/models/stock_adjustment.dart';
import '../../domain/models/stock_movement.dart';

final inventoryApiServiceProvider = Provider<InventoryApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InventoryApiService(apiClient: apiClient);
});

final stockMovementsProvider =
    FutureProvider.family<PaginatedStockMovementsModel, String>((ref, variantId) async {
  final api = ref.watch(inventoryApiServiceProvider);
  return api.getStockMovements(productVariantId: variantId, page: 1, pageSize: 50);
});

final stockBalancesProvider = FutureProvider<Map<String, double>>((ref) async {
  final api = ref.watch(inventoryApiServiceProvider);
  final activeBranch = ref.watch(activeBranchProvider);
  return api.getAllStockBalances(branchId: activeBranch?.id);
});

class InventoryNotifier {
  final InventoryApiService _apiService;

  InventoryNotifier(this._apiService);

  Future<StockAdjustmentModel> adjustStock({
    required String productVariantId,
    required String adjustmentType,
    required double quantity,
    required String reason,
    String? branchId,
    String? notes,
  }) async {
    return _apiService.adjustStock(
      productVariantId: productVariantId,
      adjustmentType: adjustmentType,
      quantity: quantity,
      reason: reason,
      branchId: branchId,
      notes: notes,
    );
  }
}

final inventoryNotifierProvider = Provider<InventoryNotifier>((ref) {
  final api = ref.watch(inventoryApiServiceProvider);
  return InventoryNotifier(api);
});
