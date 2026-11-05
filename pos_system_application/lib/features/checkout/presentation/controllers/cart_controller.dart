import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_provider.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../../catalog/domain/models/product.dart';
import '../../../catalog/domain/models/product_variant.dart';
import '../../data/checkout_api_service.dart';
import '../../domain/models/cart_item.dart';
import '../../domain/models/checkout_request.dart';
import '../../domain/models/payment_tender.dart';
import '../../domain/models/sale_receipt.dart';

final checkoutApiServiceProvider = Provider<CheckoutApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CheckoutApiService(apiClient: apiClient);
});

class CartState {
  final List<CartItemModel> items;
  final double cartDiscount;
  final double taxRate;
  final double deliveryCharge;
  final String? notes;
  final String? customerId;
  final String? customerName;
  final String? heldCartId;

  const CartState({
    this.items = const [],
    this.cartDiscount = 0.0,
    this.taxRate = 5.0, // Default 5% VAT
    this.deliveryCharge = 0.0,
    this.notes,
    this.customerId,
    this.customerName,
    this.heldCartId,
  });

  double get subtotal =>
      items.fold(0.0, (acc, item) => acc + (item.quantity * item.unitPrice));

  double get itemDiscounts =>
      items.fold(0.0, (acc, item) => acc + item.lineDiscount);

  double get discountTotal => itemDiscounts + cartDiscount;

  double get discountedSubtotal {
    final diff = subtotal - discountTotal;
    return diff > 0 ? diff : 0.0;
  }

  double get taxTotal {
    if (taxRate <= 0) return 0.0;
    final rawTax = discountedSubtotal * (taxRate / 100.0);
    return double.parse(rawTax.toStringAsFixed(4));
  }

  double get grandTotal {
    final total = discountedSubtotal + taxTotal + deliveryCharge;
    return double.parse(total.toStringAsFixed(4));
  }

  int get totalQuantity =>
      items.fold(0, (acc, item) => acc + item.quantity.round());

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItemModel>? items,
    double? cartDiscount,
    double? taxRate,
    double? deliveryCharge,
    String? notes,
    String? customerId,
    String? customerName,
    String? heldCartId,
    bool clearCustomer = false,
    bool clearHeldCart = false,
  }) {
    return CartState(
      items: items ?? this.items,
      cartDiscount: cartDiscount ?? this.cartDiscount,
      taxRate: taxRate ?? this.taxRate,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      notes: notes ?? this.notes,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      heldCartId: clearHeldCart ? null : (heldCartId ?? this.heldCartId),
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addItem(ProductModel product, [ProductVariantModel? variant]) {
    final targetVariant = variant ??
        product.primaryVariant ??
        (product.variants.isNotEmpty ? product.variants.first : null);

    if (targetVariant == null) return;

    final existingIndex = state.items.indexWhere(
      (item) => item.variantId == targetVariant.id,
    );

    if (existingIndex >= 0) {
      final current = state.items[existingIndex];
      final updatedList = List<CartItemModel>.from(state.items);
      updatedList[existingIndex] = current.copyWith(
        quantity: current.quantity + 1.0,
      );
      state = state.copyWith(items: updatedList);
    } else {
      final newItem = CartItemModel(
        variantId: targetVariant.id,
        productId: product.id,
        productName: product.name,
        variantName: targetVariant.name == 'Standard' ? null : targetVariant.name,
        sku: targetVariant.sku ?? product.sku,
        barcode: targetVariant.barcode,
        unitPrice: targetVariant.sellingPrice,
        unitCost: targetVariant.costPrice,
        quantity: 1.0,
        discount: 0.0,
        discountType: 'FIXED',
        trackStock: targetVariant.trackStock,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  bool addByBarcode(String query, List<ProductModel> catalog) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return false;

    for (final product in catalog) {
      for (final v in product.variants) {
        if (v.barcode?.toLowerCase() == cleanQuery ||
            v.sku?.toLowerCase() == cleanQuery) {
          addItem(product, v);
          return true;
        }
      }
      if (product.sku.toLowerCase() == cleanQuery) {
        addItem(product);
        return true;
      }
    }
    return false;
  }

  void updateQuantity(String variantId, double quantity) {
    if (quantity <= 0) {
      removeItem(variantId);
      return;
    }

    final updated = state.items.map((item) {
      if (item.variantId == variantId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
  }

  void incrementQuantity(String variantId) {
    final item = state.items.firstWhere((i) => i.variantId == variantId);
    updateQuantity(variantId, item.quantity + 1.0);
  }

  void decrementQuantity(String variantId) {
    final item = state.items.firstWhere((i) => i.variantId == variantId);
    updateQuantity(variantId, item.quantity - 1.0);
  }

  void removeItem(String variantId) {
    state = state.copyWith(
      items: state.items.where((i) => i.variantId != variantId).toList(),
    );
  }

  void updateItemDiscount(
    String variantId,
    double discount, {
    String discountType = 'FIXED',
    String? discountReason,
  }) {
    final updated = state.items.map((item) {
      if (item.variantId == variantId) {
        return item.copyWith(
          discount: max(0.0, discount),
          discountType: discountType,
          discountReason: discountReason,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
  }

  void setCartDiscount(double discount) {
    state = state.copyWith(cartDiscount: max(0.0, discount));
  }

  void setTaxRate(double rate) {
    state = state.copyWith(taxRate: max(0.0, rate));
  }

  void setDeliveryCharge(double charge) {
    state = state.copyWith(deliveryCharge: max(0.0, charge));
  }

  void setCustomer(String? id, String? name) {
    if (id == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(customerId: id, customerName: name);
    }
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  void setHeldCartId(String? id) {
    if (id == null) {
      state = state.copyWith(clearHeldCart: true);
    } else {
      state = state.copyWith(heldCartId: id);
    }
  }

  void restoreCart({
    required List<CartItemModel> items,
    double cartDiscount = 0.0,
    double taxRate = 5.0,
    double deliveryCharge = 0.0,
    String? customerId,
    String? customerName,
    String? notes,
    String? heldCartId,
  }) {
    state = CartState(
      items: items,
      cartDiscount: cartDiscount,
      taxRate: taxRate,
      deliveryCharge: deliveryCharge,
      customerId: customerId,
      customerName: customerName,
      notes: notes,
      heldCartId: heldCartId,
    );
  }

  void clearCart() {
    state = const CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

// Checkout Action Controller
class CheckoutState {
  final bool isLoading;
  final String? errorMessage;
  final SaleReceiptModel? completedSale;

  const CheckoutState({
    this.isLoading = false,
    this.errorMessage,
    this.completedSale,
  });
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final CheckoutApiService _apiService;
  final Ref _ref;

  CheckoutNotifier(this._apiService, this._ref) : super(const CheckoutState());

  Future<SaleReceiptModel?> processCheckout({
    required List<PaymentTenderInput> payments,
    String? branchId,
    String? idempotencyKey,
    String? managerApprovedBy,
  }) async {
    final cart = _ref.read(cartProvider);
    if (cart.isEmpty) {
      state = const CheckoutState(errorMessage: 'Cannot checkout an empty cart');
      return null;
    }

    state = const CheckoutState(isLoading: true);

    try {
      final key = idempotencyKey ?? generateUuidV4();
      final request = CheckoutRequestModel(
        idempotencyKey: key,
        branchId: branchId,
        customerId: cart.customerId,
        items: cart.items.map((item) {
          return CheckoutRequestItemModel(
            productVariantId: item.variantId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            discount: item.discount,
            discountType: item.discountType,
            discountReason: item.discountReason,
          );
        }).toList(),
        cartDiscount: cart.cartDiscount,
        taxRate: cart.taxRate,
        deliveryCharge: cart.deliveryCharge,
        heldCartId: cart.heldCartId,
        managerApprovedBy: managerApprovedBy,
        payments: payments,
        notes: cart.notes,
      );

      final sale = await _apiService.checkout(request);

      // Successfully completed: clear cart and update state
      _ref.read(cartProvider.notifier).clearCart();
      state = CheckoutState(isLoading: false, completedSale: sale);
      return sale;
    } catch (e) {
      state = CheckoutState(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  void reset() {
    state = const CheckoutState();
  }
}

final checkoutControllerProvider =
    StateNotifierProvider<CheckoutNotifier, CheckoutState>((ref) {
  final apiService = ref.watch(checkoutApiServiceProvider);
  return CheckoutNotifier(apiService, ref);
});
