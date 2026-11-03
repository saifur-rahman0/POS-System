class ProductVariantModel {
  final String id;
  final String productId;
  final String sku;
  final String name;
  final String? barcode;
  final double costPrice;
  final double sellingPrice;
  final bool trackStock;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductVariantModel({
    required this.id,
    required this.productId,
    required this.sku,
    required this.name,
    this.barcode,
    required this.costPrice,
    required this.sellingPrice,
    required this.trackStock,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      barcode: json['barcode'] as String?,
      costPrice: _toDouble(json['cost_price']),
      sellingPrice: _toDouble(json['selling_price']),
      trackStock: json['track_stock'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'sku': sku,
      'name': name,
      if (barcode != null) 'barcode': barcode,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'track_stock': trackStock,
      'is_active': isActive,
    };
  }
}

