class ProductBundleItemModel {
  final String id;
  final String bundleId;
  final String componentVariantId;
  final double quantity;
  final bool isOptional;
  final String? componentName;
  final String? componentSku;

  const ProductBundleItemModel({
    required this.id,
    required this.bundleId,
    required this.componentVariantId,
    required this.quantity,
    this.isOptional = false,
    this.componentName,
    this.componentSku,
  });

  factory ProductBundleItemModel.fromJson(Map<String, dynamic> json) {
    return ProductBundleItemModel(
      id: json['id']?.toString() ?? '',
      bundleId: json['bundle_id']?.toString() ?? '',
      componentVariantId: json['component_variant_id']?.toString() ?? '',
      quantity: _toDouble(json['quantity'], 1.0),
      isOptional: json['is_optional'] as bool? ?? false,
      componentName: json['component_name']?.toString(),
      componentSku: json['component_sku']?.toString(),
    );
  }

  static double _toDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  Map<String, dynamic> toJson() {
    return {
      'component_variant_id': componentVariantId,
      'quantity': quantity,
      'is_optional': isOptional,
    };
  }
}

class ProductBundleModel {
  final String id;
  final String businessId;
  final String productId;
  final String name;
  final double? bundlePrice;
  final bool isKit;
  final bool isActive;
  final DateTime createdAt;
  final List<ProductBundleItemModel> items;

  const ProductBundleModel({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.name,
    this.bundlePrice,
    this.isKit = false,
    required this.isActive,
    required this.createdAt,
    this.items = const [],
  });

  factory ProductBundleModel.fromJson(Map<String, dynamic> json) {
    return ProductBundleModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      bundlePrice: json['bundle_price'] != null ? _toDouble(json['bundle_price']) : null,
      isKit: json['is_kit'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ProductBundleItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
      'product_id': productId,
      'name': name,
      if (bundlePrice != null) 'bundle_price': bundlePrice,
      'is_kit': isKit,
      'is_active': isActive,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

