class SaleReturnableItemModel {
  final String saleItemId;
  final String productVariantId;
  final String productName;
  final String sku;
  final double quantitySold;
  final double quantityReturned;
  final double quantityReturnable;
  final double unitPrice;
  final double lineTotal;

  const SaleReturnableItemModel({
    required this.saleItemId,
    required this.productVariantId,
    required this.productName,
    required this.sku,
    required this.quantitySold,
    required this.quantityReturned,
    required this.quantityReturnable,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory SaleReturnableItemModel.fromJson(Map<dynamic, dynamic> json) {
    return SaleReturnableItemModel(
      saleItemId: json['sale_item_id']?.toString() ?? '',
      productVariantId: json['product_variant_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Product',
      sku: json['sku']?.toString() ?? '',
      quantitySold: _toDouble(json['quantity_sold']),
      quantityReturned: _toDouble(json['quantity_returned']),
      quantityReturnable: _toDouble(json['quantity_returnable']),
      unitPrice: _toDouble(json['unit_price']),
      lineTotal: _toDouble(json['line_total']),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}
