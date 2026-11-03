import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/customers_api_service.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/customer_due_payment.dart';
import '../../domain/models/customer_ledger.dart';
import '../../domain/models/paginated_customers.dart';

final customersApiServiceProvider = Provider<CustomersApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomersApiService(apiClient: apiClient);
});

class CustomersState {
  final bool isLoading;
  final String? errorMessage;
  final PaginatedCustomersModel? paginated;
  final String searchQuery;
  final int currentPage;

  const CustomersState({
    this.isLoading = false,
    this.errorMessage,
    this.paginated,
    this.searchQuery = '',
    this.currentPage = 1,
  });

  CustomersState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    PaginatedCustomersModel? paginated,
    String? searchQuery,
    int? currentPage,
  }) {
    return CustomersState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paginated: paginated ?? this.paginated,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class CustomersNotifier extends StateNotifier<CustomersState> {
  final CustomersApiService _apiService;

  CustomersNotifier(this._apiService) : super(const CustomersState()) {
    loadCustomers();
  }

  Future<void> loadCustomers({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      searchQuery: search ?? state.searchQuery,
      currentPage: page,
    );

    try {
      final res = await _apiService.getCustomers(
        search: search ?? (state.searchQuery.isNotEmpty ? state.searchQuery : null),
        page: page,
        pageSize: pageSize,
      );

      state = state.copyWith(
        isLoading: false,
        paginated: res,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void search(String query) {
    loadCustomers(search: query, page: 1);
  }

  void refresh() {
    loadCustomers(page: state.currentPage);
  }

  Future<CustomerModel?> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    double creditLimit = 0.0,
  }) async {
    try {
      final newCustomer = await _apiService.createCustomer({
        'name': name.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
        'credit_limit': creditLimit.toStringAsFixed(4),
      });

      refresh();
      return newCustomer;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<CustomerModel?> updateCustomer(
    String id, {
    String? name,
    String? phone,
    String? email,
    String? address,
    double? creditLimit,
    bool? isActive,
  }) async {
    try {
      final updated = await _apiService.updateCustomer(id, {
        if (name != null) 'name': name.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (email != null) 'email': email.trim(),
        if (address != null) 'address': address.trim(),
        if (creditLimit != null) 'credit_limit': creditLimit.toStringAsFixed(4),
        if (isActive != null) 'is_active': isActive,
      });

      refresh();
      return updated;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<CustomerDuePaymentModel> collectDuePayment({
    required String customerId,
    required double amount,
    required String paymentMethod,
    String? reference,
    String? notes,
    String? saleId,
  }) async {
    try {
      final payment = await _apiService.collectDuePayment(
        customerId,
        amount: amount,
        paymentMethod: paymentMethod,
        reference: reference,
        notes: notes,
        saleId: saleId,
      );

      refresh();
      return payment;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }
}

final customersControllerProvider =
    StateNotifierProvider<CustomersNotifier, CustomersState>((ref) {
  final api = ref.watch(customersApiServiceProvider);
  return CustomersNotifier(api);
});

final customerLedgerProvider =
    FutureProvider.family<List<CustomerLedgerEntryModel>, String>((ref, customerId) async {
  final api = ref.watch(customersApiServiceProvider);
  return api.getCustomerLedger(customerId);
});

