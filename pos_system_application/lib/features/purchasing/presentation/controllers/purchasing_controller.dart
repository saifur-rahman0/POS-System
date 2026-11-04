import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/purchasing_api_service.dart';
import '../../domain/models/paginated_purchases.dart';
import '../../domain/models/paginated_suppliers.dart';
import '../../domain/models/purchase_order.dart';
import '../../domain/models/supplier.dart';

final purchasingApiServiceProvider = Provider<PurchasingApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PurchasingApiService(apiClient: apiClient);
});

// --- Suppliers State & Notifier ---

class SuppliersState {
  final bool isLoading;
  final String? errorMessage;
  final PaginatedSuppliersModel? paginated;
  final String searchQuery;
  final int currentPage;

  const SuppliersState({
    this.isLoading = false,
    this.errorMessage,
    this.paginated,
    this.searchQuery = '',
    this.currentPage = 1,
  });

  SuppliersState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    PaginatedSuppliersModel? paginated,
    String? searchQuery,
    int? currentPage,
  }) {
    return SuppliersState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paginated: paginated ?? this.paginated,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class SuppliersNotifier extends StateNotifier<SuppliersState> {
  final PurchasingApiService _apiService;

  SuppliersNotifier(this._apiService) : super(const SuppliersState()) {
    loadSuppliers();
  }

  Future<void> loadSuppliers({String? search, int page = 1}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      searchQuery: search ?? state.searchQuery,
      currentPage: page,
    );

    try {
      final res = await _apiService.getSuppliers(
        search: search ?? (state.searchQuery.isNotEmpty ? state.searchQuery : null),
        page: page,
      );
      state = state.copyWith(isLoading: false, paginated: res);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void search(String query) {
    loadSuppliers(search: query, page: 1);
  }

  void refresh() {
    loadSuppliers(page: state.currentPage);
  }

  Future<SupplierModel> createSupplier({
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      final res = await _apiService.createSupplier({
        'name': name.trim(),
        if (contactPerson != null && contactPerson.trim().isNotEmpty)
          'contact_person': contactPerson.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      });
      refresh();
      return res;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<SupplierModel> updateSupplier(
    String id, {
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    bool? isActive,
  }) async {
    try {
      final res = await _apiService.updateSupplier(id, {
        if (name != null) 'name': name.trim(),
        if (contactPerson != null) 'contact_person': contactPerson.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (email != null) 'email': email.trim(),
        if (address != null) 'address': address.trim(),
        if (isActive != null) 'is_active': isActive,
      });
      refresh();
      return res;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }
}

final suppliersControllerProvider =
    StateNotifierProvider<SuppliersNotifier, SuppliersState>((ref) {
  final api = ref.watch(purchasingApiServiceProvider);
  return SuppliersNotifier(api);
});

// --- Purchases State & Notifier ---

class PurchasesState {
  final bool isLoading;
  final String? errorMessage;
  final PaginatedPurchasesModel? paginated;
  final String? statusFilter;
  final int currentPage;

  const PurchasesState({
    this.isLoading = false,
    this.errorMessage,
    this.paginated,
    this.statusFilter,
    this.currentPage = 1,
  });

  PurchasesState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    PaginatedPurchasesModel? paginated,
    String? statusFilter,
    bool clearStatus = false,
    int? currentPage,
  }) {
    return PurchasesState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paginated: paginated ?? this.paginated,
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PurchasesNotifier extends StateNotifier<PurchasesState> {
  final PurchasingApiService _apiService;

  PurchasesNotifier(this._apiService) : super(const PurchasesState()) {
    loadPurchases();
  }

  Future<void> loadPurchases({String? status, int page = 1}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      statusFilter: status ?? state.statusFilter,
      currentPage: page,
    );

    try {
      final res = await _apiService.getPurchases(
        status: status ?? state.statusFilter,
        page: page,
      );
      state = state.copyWith(isLoading: false, paginated: res);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void filterByStatus(String? status) {
    if (status == null || status.isEmpty) {
      state = state.copyWith(clearStatus: true);
      loadPurchases(status: null, page: 1);
    } else {
      loadPurchases(status: status, page: 1);
    }
  }

  void refresh() {
    loadPurchases(page: state.currentPage);
  }

  Future<PurchaseOrderModel> createPurchaseOrder({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    double discount = 0.0,
    String? referenceNo,
    String? notes,
  }) async {
    try {
      final res = await _apiService.createPurchase({
        'supplier_id': supplierId,
        'discount': discount.toStringAsFixed(4),
        if (referenceNo != null && referenceNo.isNotEmpty) 'reference_no': referenceNo,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      });
      refresh();
      return res;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<PurchaseOrderModel> receivePurchaseOrder(String id) async {
    try {
      final res = await _apiService.receivePurchase(id);
      refresh();
      return res;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<PurchasePaymentModel> addPayment(
    String id, {
    required double amount,
    required String method,
    String? reference,
  }) async {
    try {
      final res = await _apiService.addPurchasePayment(
        id,
        amount: amount,
        method: method,
        reference: reference,
      );
      refresh();
      return res;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }
}

final purchasesControllerProvider =
    StateNotifierProvider<PurchasesNotifier, PurchasesState>((ref) {
  final api = ref.watch(purchasingApiServiceProvider);
  return PurchasesNotifier(api);
});

