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
    this.trackStock = true,
  });

  double get lineTotal {
    final sub = quantity * unitPrice;
    final total = sub - discount;
    return total > 0 ? total : 0.0;
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
      trackStock: trackStock ?? this.trackStock,
    );
  }
}

