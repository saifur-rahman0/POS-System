class BranchPriceOverrideModel {
  final String id;
  final String businessId;
  final String branchId;
  final String productVariantId;
  final double sellingPrice;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? variantName;
  final String? variantSku;
  final String? branchName;

  const BranchPriceOverrideModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.productVariantId,
    required this.sellingPrice,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.variantName,
    this.variantSku,
    this.branchName,
  });

  factory BranchPriceOverrideModel.fromJson(Map<String, dynamic> json) {
    return BranchPriceOverrideModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      productVariantId: json['product_variant_id']?.toString() ?? '',
      sellingPrice: _toDouble(json['selling_price']),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      variantName: json['variant_name']?.toString(),
      variantSku: json['variant_sku']?.toString(),
      branchName: json['branch_name']?.toString(),
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
      'branch_id': branchId,
      'product_variant_id': productVariantId,
      'selling_price': sellingPrice,
      'is_active': isActive,
    };
  }
}
