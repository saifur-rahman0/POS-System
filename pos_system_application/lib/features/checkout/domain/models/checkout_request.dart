import 'payment_tender.dart';

class CheckoutRequestModel {
  final String idempotencyKey;
  final String? branchId;
  final String? customerId;
  final List<CheckoutRequestItemModel> items;
  final double cartDiscount;
  final double taxRate;
  final double deliveryCharge;
  final String saleType;
  final String? managerApprovedBy;
  final String? exchangeReturnId;
  final String? heldCartId;
  final List<PaymentTenderInput> payments;
  final String? notes;

  const CheckoutRequestModel({
    required this.idempotencyKey,
    this.branchId,
    this.customerId,
    required this.items,
    this.cartDiscount = 0.0,
    this.taxRate = 0.0,
    this.deliveryCharge = 0.0,
    this.saleType = 'RETAIL',
    this.managerApprovedBy,
    this.exchangeReturnId,
    this.heldCartId,
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
      'delivery_charge': deliveryCharge.toStringAsFixed(4),
      'sale_type': saleType,
      if (managerApprovedBy != null) 'manager_approved_by': managerApprovedBy,
      if (exchangeReturnId != null) 'exchange_return_id': exchangeReturnId,
      if (heldCartId != null) 'held_cart_id': heldCartId,
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
  final String discountType;
  final String? discountReason;

  const CheckoutRequestItemModel({
    required this.productVariantId,
    required this.quantity,
    this.unitPrice,
    this.discount = 0.0,
    this.discountType = 'FIXED',
    this.discountReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_variant_id': productVariantId,
      'quantity': quantity.toStringAsFixed(4),
      if (unitPrice != null) 'unit_price': unitPrice!.toStringAsFixed(4),
      'discount': discount.toStringAsFixed(4),
      'discount_type': discountType,
      if (discountReason != null) 'discount_reason': discountReason,
    };
  }
}
