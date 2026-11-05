import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/checkout_api_service.dart';
import '../../domain/models/held_cart.dart';
import 'cart_controller.dart';

class HeldCartsState {
  final bool isLoading;
  final String? errorMessage;
  final List<HeldCartModel> heldCarts;

  const HeldCartsState({
    this.isLoading = false,
    this.errorMessage,
    this.heldCarts = const [],
  });

  HeldCartsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<HeldCartModel>? heldCarts,
    bool clearError = false,
  }) {
    return HeldCartsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      heldCarts: heldCarts ?? this.heldCarts,
    );
  }
}

class HeldCartsNotifier extends StateNotifier<HeldCartsState> {
  final CheckoutApiService _apiService;

  HeldCartsNotifier(this._apiService) : super(const HeldCartsState());

  Future<void> loadHeldCarts({String? branchId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _apiService.listHeldCarts(branchId: branchId);
      state = state.copyWith(isLoading: false, heldCarts: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<HeldCartModel?> holdCart(
    CartState cart, {
    String? label,
    String? notes,
    String? branchId,
  }) {
    return holdCurrentCart(
      branchId: branchId,
      label: label ??
          (notes != null && notes.isNotEmpty ? notes : 'Parked Cart'),
      customerId: cart.customerId,
      customerName: cart.customerName,
      items: cart.items.map((i) => i.toJson()).toList(),
      cartDiscount: cart.cartDiscount,
      taxRate: cart.taxRate,
      deliveryCharge: cart.deliveryCharge,
      notes: notes ?? cart.notes,
    );
  }

  Future<HeldCartModel?> holdCurrentCart({
    required String? branchId,
    required String? label,
    required String? customerId,
    required String? customerName,
    required List<Map<String, dynamic>> items,
    required double cartDiscount,
    required double taxRate,
    required double deliveryCharge,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final payload = {
        if (branchId != null) 'branch_id': branchId,
        if (label != null) 'label': label,
        if (customerId != null) 'customer_id': customerId,
        if (customerName != null) 'customer_name': customerName,
        'items': items,
        'cart_discount': cartDiscount.toStringAsFixed(4),
        'tax_rate': taxRate.toStringAsFixed(4),
        'delivery_charge': deliveryCharge.toStringAsFixed(4),
        if (notes != null) 'notes': notes,
      };
      final created = await _apiService.createHeldCart(payload);
      state = state.copyWith(
        isLoading: false,
        heldCarts: [created, ...state.heldCarts],
      );
      return created;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> discardHeldCart(String heldCartId) async {
    try {
      await _apiService.deleteHeldCart(heldCartId);
      state = state.copyWith(
        heldCarts: state.heldCarts.where((c) => c.id != heldCartId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final heldCartsControllerProvider =
    StateNotifierProvider<HeldCartsNotifier, HeldCartsState>((ref) {
  final apiService = ref.watch(checkoutApiServiceProvider);
  return HeldCartsNotifier(apiService);
});

final heldCartsProvider = heldCartsControllerProvider;

