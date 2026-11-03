import 'payment_tender.dart';

class CheckoutRequestModel {
  final String idempotencyKey;
  final String? branchId;
  final String? customerId;
  final List<CheckoutRequestItemModel> items;
  final double cartDiscount;
  final double taxRate;
  final List<PaymentTenderInput> payments;
  final String? notes;

  const CheckoutRequestModel({
    required this.idempotencyKey,
    this.branchId,
    this.customerId,
    required this.items,
    this.cartDiscount = 0.0,
    this.taxRate = 0.0,
    required this.payments,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'idempotency_key': idempotencyKey,
      if (branchId != null) 'branch_id': branchId,
      if (customerId != null) 'customer_id': customerId,
      'items': items.map((i) => i.toJson()).toList(),
      'cart_discount': cartDiscount.toStringAsFixed(4),
      'tax_rate': taxRate.toStringAsFixed(4),
      'payments': payments.map((p) => p.toJson()).toList(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}

class CheckoutRequestItemModel {
  final String productVariantId;
  final double quantity;
  final double? unitPrice;
  final double discount;

  const CheckoutRequestItemModel({
    required this.productVariantId,
    required this.quantity,
    this.unitPrice,
    this.discount = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_variant_id': productVariantId,
      'quantity': quantity.toStringAsFixed(4),
      if (unitPrice != null) 'unit_price': unitPrice!.toStringAsFixed(4),
      'discount': discount.toStringAsFixed(4),
    };
  }
}

