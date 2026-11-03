import 'product_variant.dart';

class ProductModel {
  final String id;
  final String businessId;
  final String sku;
  final String name;
  final String? description;
  final String? categoryId;
  final String? categoryName;
  final String productType;
  final double taxRate;
  final bool hasVariants;
  final bool isActive;
  final ProductVariantModel? primaryVariant;
  final List<ProductVariantModel> variants;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.businessId,
    required this.sku,
    required this.name,
    this.description,
    this.categoryId,
    this.categoryName,
    required this.productType,
    required this.taxRate,
    required this.hasVariants,
    required this.isActive,
    this.primaryVariant,
    this.variants = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromJson(Map<dynamic, dynamic> json) {
    final rawVariants = json['variants'] as List<dynamic>?;
    final variantsList = rawVariants != null
        ? rawVariants.map((v) {
            final map = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
            map['sku'] ??= json['sku']?.toString();
            return ProductVariantModel.fromJson(map);
          }).toList()
        : <ProductVariantModel>[];

    ProductVariantModel? primaryVariant;
    if (json['primary_variant'] != null && json['primary_variant'] is Map) {
      final map = Map<String, dynamic>.from(json['primary_variant'] as Map);
      map['sku'] ??= json['sku']?.toString();
      primaryVariant = ProductVariantModel.fromJson(map);
    } else if (variantsList.isNotEmpty) {
      primaryVariant = variantsList.first;
    }

    return ProductModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      categoryId: json['category_id']?.toString(),
      categoryName: json['category_name']?.toString(),
      productType: json['product_type']?.toString() ?? 'standard',
      taxRate: _toDouble(json['tax_rate']),
      hasVariants: json['has_variants'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      primaryVariant: primaryVariant,
      variants: variantsList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
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
      'business_id': businessId,
      'sku': sku,
      'name': name,
      if (description != null) 'description': description,
      if (categoryId != null) 'category_id': categoryId,
      if (categoryName != null) 'category_name': categoryName,
      'product_type': productType,
      'tax_rate': taxRate,
      'has_variants': hasVariants,
      'is_active': isActive,
      if (primaryVariant != null) 'primary_variant': primaryVariant!.toJson(),
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }
}
