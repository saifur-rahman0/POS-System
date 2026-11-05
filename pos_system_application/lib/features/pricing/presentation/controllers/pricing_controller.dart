import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/pricing_api_service.dart';
import '../../domain/models/branch_price_override.dart';
import '../../domain/models/bulk_import_result.dart';
import '../../domain/models/customer_group.dart';
import '../../domain/models/price_list.dart';
import '../../domain/models/product_bundle.dart';
import '../../domain/models/promotion.dart';

final pricingApiServiceProvider = Provider<PricingApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PricingApiService(apiClient: apiClient);
});

// ---------------------------------------------------------------------------
// Read Providers
// ---------------------------------------------------------------------------
final customerGroupsProvider = FutureProvider.autoDispose<List<CustomerGroupModel>>((ref) async {
  final api = ref.watch(pricingApiServiceProvider);
  return api.getCustomerGroups();
});

final priceListsProvider = FutureProvider.autoDispose<List<PriceListModel>>((ref) async {
  final api = ref.watch(pricingApiServiceProvider);
  return api.getPriceLists();
});

final selectedPriceListIdProvider = StateProvider<String?>((ref) => null);

final selectedPriceListDetailProvider = FutureProvider.autoDispose<PriceListModel?>((ref) async {
  final selectedId = ref.watch(selectedPriceListIdProvider);
  if (selectedId == null) return null;
  final api = ref.watch(pricingApiServiceProvider);
  return api.getPriceList(selectedId);
});

final branchOverridesProvider = FutureProvider.autoDispose<List<BranchPriceOverrideModel>>((ref) async {
  final api = ref.watch(pricingApiServiceProvider);
  return api.getBranchOverrides();
});

final productBundlesProvider = FutureProvider.autoDispose<List<ProductBundleModel>>((ref) async {
  final api = ref.watch(pricingApiServiceProvider);
  return api.getBundles();
});

final promotionsProvider = FutureProvider.autoDispose<List<PromotionModel>>((ref) async {
  final api = ref.watch(pricingApiServiceProvider);
  return api.getPromotions();
});

// ---------------------------------------------------------------------------
// Controller for actions
// ---------------------------------------------------------------------------
class PricingState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const PricingState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  PricingState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return PricingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class PricingController extends StateNotifier<PricingState> {
  final PricingApiService _api;
  final Ref _ref;

  PricingController(this._api, this._ref) : super(const PricingState());

  // Customer Groups
  Future<bool> createCustomerGroup(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.createCustomerGroup(data);
      _ref.invalidate(customerGroupsProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Customer group created');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // Price Lists
  Future<bool> createPriceList(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final created = await _api.createPriceList(data);
      _ref.invalidate(priceListsProvider);
      _ref.read(selectedPriceListIdProvider.notifier).state = created.id;
      state = state.copyWith(isLoading: false, successMessage: 'Price list created');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> addOrUpdatePriceListItem(String priceListId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.addOrUpdatePriceListItem(priceListId, data);
      _ref.invalidate(priceListsProvider);
      _ref.invalidate(selectedPriceListDetailProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Price list item saved');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deletePriceListItem(String priceListId, String itemId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.deletePriceListItem(priceListId, itemId);
      _ref.invalidate(priceListsProvider);
      _ref.invalidate(selectedPriceListDetailProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Item removed from price list');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // Branch Overrides
  Future<bool> upsertBranchOverride(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.upsertBranchOverride(data);
      _ref.invalidate(branchOverridesProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Branch override saved');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteBranchOverride(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.deleteBranchOverride(id);
      _ref.invalidate(branchOverridesProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Override deleted');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // Bundles
  Future<bool> createBundle(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.createBundle(data);
      _ref.invalidate(productBundlesProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Product bundle created');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // Promotions
  Future<bool> createPromotion(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.createPromotion(data);
      _ref.invalidate(promotionsProvider);
      state = state.copyWith(isLoading: false, successMessage: 'Promotion created');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // Bulk Import
  Future<BulkImportResultModel?> bulkImport(List<int> bytes) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.bulkImportCsv(bytes);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Imported: ${res.createdCount} created, ${res.updatedCount} updated',
      );
      return res;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final pricingControllerProvider = StateNotifierProvider<PricingController, PricingState>((ref) {
  final api = ref.watch(pricingApiServiceProvider);
  return PricingController(api, ref);
});
