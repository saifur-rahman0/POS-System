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

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final variantsList = (json['variants'] as List<dynamic>?)
            ?.map((v) => ProductVariantModel.fromJson(v as Map<String, dynamic>))
            .toList() ??
        [];

    final primaryVariant = json['primary_variant'] != null
        ? ProductVariantModel.fromJson(
            json['primary_variant'] as Map<String, dynamic>)
        : (variantsList.isNotEmpty ? variantsList.first : null);

    return ProductModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      productType: json['product_type'] as String? ?? 'standard',
      taxRate: _toDouble(json['tax_rate']),
      hasVariants: json['has_variants'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      primaryVariant: primaryVariant,
      variants: variantsList,
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
