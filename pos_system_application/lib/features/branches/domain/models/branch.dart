import '../../../../core/utils/parsers.dart';

class BranchModel {
  final String id;
  final String businessId;
  final String name;
  final String? code;
  final String? address;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalVariantsInStock;
  final double totalStockQuantity;
  final bool hasActiveShift;

  const BranchModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.code,
    this.address,
    this.phone,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.totalVariantsInStock = 0,
    this.totalStockQuantity = 0.0,
    this.hasActiveShift = false,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      totalVariantsInStock: parseInt(json['total_variants_in_stock']),
      totalStockQuantity: parseDouble(json['total_stock_quantity']),
      hasActiveShift: json['has_active_shift'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

