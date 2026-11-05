import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../checkout/data/checkout_api_service.dart';
import '../../../checkout/domain/models/payment_tender.dart';
import '../../../checkout/domain/models/quotation.dart';
import '../../../checkout/domain/models/sale_receipt.dart';
import '../../../checkout/presentation/controllers/cart_controller.dart';

class QuotationsState {
  final bool isLoading;
  final String? errorMessage;
  final List<QuotationModel> quotations;
  final String? statusFilter;
  final String searchQuery;

  const QuotationsState({
    this.isLoading = false,
    this.errorMessage,
    this.quotations = const [],
    this.statusFilter,
    this.searchQuery = '',
  });

  QuotationsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<QuotationModel>? quotations,
    String? statusFilter,
    String? searchQuery,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return QuotationsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      quotations: quotations ?? this.quotations,
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class QuotationsNotifier extends StateNotifier<QuotationsState> {
  final CheckoutApiService _apiService;

  QuotationsNotifier(this._apiService) : super(const QuotationsState());

  Future<void> loadQuotations({String? branchId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _apiService.listQuotations(
        branchId: branchId,
        status: state.statusFilter,
        search: state.searchQuery,
      );
      state = state.copyWith(isLoading: false, quotations: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setStatusFilter(String? status, {String? branchId}) {
    state = state.copyWith(statusFilter: status, clearStatus: status == null);
    loadQuotations(branchId: branchId);
  }

  void setSearchQuery(String query, {String? branchId}) {
    state = state.copyWith(searchQuery: query);
    loadQuotations(branchId: branchId);
  }

  Future<QuotationModel?> createQuotation(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final created = await _apiService.createQuotation(payload);
      state = state.copyWith(
        isLoading: false,
        quotations: [created, ...state.quotations],
      );
      return created;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<QuotationModel?> createQuotationFromCart(
    CartState cart, {
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    int validityDays = 15,
    String? notes,
    String? branchId,
  }) {
    final payload = {
      if (branchId != null) 'branch_id': branchId,
      'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (customerEmail != null) 'customer_email': customerEmail,
      'validity_days': validityDays,
      if (notes != null) 'notes': notes,
      'items': cart.items.map((i) => i.toJson()).toList(),
      'cart_discount': cart.cartDiscount.toStringAsFixed(4),
      'tax_rate': cart.taxRate.toStringAsFixed(4),
      'delivery_charge': cart.deliveryCharge.toStringAsFixed(4),
    };
    return createQuotation(payload);
  }

  Future<SaleReceiptModel?> convertQuotation(
    String quotationId, {
    required List<PaymentTenderInput> payments,
    String? branchId,
  }) {
    return convertQuotationToSale(quotationId, {
      if (branchId != null) 'branch_id': branchId,
      'payments': payments.map((p) => p.toJson()).toList(),
    });
  }

  Future<SaleReceiptModel?> convertQuotationToSale(
    String quotationId,
    Map<String, dynamic> payload,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final sale = await _apiService.convertQuotation(quotationId, payload);
      await loadQuotations();
      return sale;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final quotationsControllerProvider =
    StateNotifierProvider<QuotationsNotifier, QuotationsState>((ref) {
  final apiService = ref.watch(checkoutApiServiceProvider);
  return QuotationsNotifier(apiService);
});

final quotationsProvider = quotationsControllerProvider;

