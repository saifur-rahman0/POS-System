class PurchaseItemModel {
  final String id;
  final String productVariantId;
  final String? productName;
  final String? variantName;
  final String? sku;
  final double quantity;
  final double unitCost;
  final double lineTotal;

  const PurchaseItemModel({
    required this.id,
    required this.productVariantId,
    this.productName,
    this.variantName,
    this.sku,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
  });

  factory PurchaseItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseItemModel(
      id: json['id'] as String,
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String?,
      variantName: json['variant_name'] as String?,
      sku: json['sku'] as String?,
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      unitCost: double.tryParse(json['unit_cost']?.toString() ?? '0') ?? 0.0,
      lineTotal: double.tryParse(json['line_total']?.toString() ?? '0') ?? 0.0,
    );
  }

  double get subtotal => lineTotal;
}
