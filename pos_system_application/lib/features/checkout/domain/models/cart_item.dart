class CartItemModel {
  final String variantId;
  final String productId;
  final String productName;
  final String? variantName;
  final String? sku;
  final String? barcode;
  final double unitPrice;
  final double unitCost;
  final double quantity;
  final double discount;
  final String discountType; // 'FIXED' or 'PERCENTAGE'
  final String? discountReason;
  final bool trackStock;

  const CartItemModel({
    required this.variantId,
    required this.productId,
    required this.productName,
    this.variantName,
    this.sku,
    this.barcode,
    required this.unitPrice,
    required this.unitCost,
    this.quantity = 1.0,
    this.discount = 0.0,
    this.discountType = 'FIXED',
    this.discountReason,
    this.trackStock = true,
  });

  double get lineDiscount {
    final sub = quantity * unitPrice;
    if (discountType == 'PERCENTAGE') {
      final pct = discount.clamp(0.0, 100.0);
      return double.parse((sub * (pct / 100.0)).toStringAsFixed(4));
    }
    final fixedDisc = discount.clamp(0.0, sub);
    return double.parse(fixedDisc.toStringAsFixed(4));
  }

  double get lineTotal {
    final sub = quantity * unitPrice;
    final total = sub - lineDiscount;
    return total > 0 ? double.parse(total.toStringAsFixed(4)) : 0.0;
  }

  CartItemModel copyWith({
    String? variantId,
    String? productId,
    String? productName,
    String? variantName,
    String? sku,
    String? barcode,
    double? unitPrice,
    double? unitCost,
    double? quantity,
    double? discount,
    String? discountType,
    String? discountReason,
    bool? trackStock,
  }) {
    return CartItemModel(
      variantId: variantId ?? this.variantId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantName: variantName ?? this.variantName,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      discountType: discountType ?? this.discountType,
      discountReason: discountReason ?? this.discountReason,
      trackStock: trackStock ?? this.trackStock,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variant_id': variantId,
      'product_id': productId,
      'product_name': productName,
      'variant_name': variantName,
      'sku': sku,
      'barcode': barcode,
      'unit_price': unitPrice,
      'unit_cost': unitCost,
      'quantity': quantity,
      'discount': discount,
      'discount_type': discountType,
      'discount_reason': discountReason,
      'track_stock': trackStock,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      variantId: (json['variant_id'] ?? json['product_variant_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? json['name'] ?? 'Item').toString(),
      variantName: json['variant_name']?.toString(),
      sku: json['sku']?.toString(),
      barcode: json['barcode']?.toString(),
      unitPrice: double.tryParse((json['unit_price'] ?? 0).toString()) ?? 0.0,
      unitCost: double.tryParse((json['unit_cost'] ?? 0).toString()) ?? 0.0,
      quantity: double.tryParse((json['quantity'] ?? 1).toString()) ?? 1.0,
      discount: double.tryParse((json['discount'] ?? 0).toString()) ?? 0.0,
      discountType: (json['discount_type'] ?? 'FIXED').toString(),
      discountReason: json['discount_reason']?.toString(),
      trackStock: json['track_stock'] == true || json['track_stock'] == 1,
    );
  }
}
