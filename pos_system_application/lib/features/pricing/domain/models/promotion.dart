class PromotionModel {
  final String id;
  final String businessId;
  final String name;
  final String? code;
  final String discountType; // "PERCENTAGE" | "FIXED_AMOUNT"
  final double discountValue;
  final double minSpend;
  final double? maxDiscountCap;
  final int? usageLimit;
  final int timesUsed;
  final DateTime validFrom;
  final DateTime validUntil;
  final String appliesTo; // "ALL" | "CATEGORY" | "PRODUCT"
  final List<String> scopeIds;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PromotionModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.code,
    required this.discountType,
    required this.discountValue,
    this.minSpend = 0.0,
    this.maxDiscountCap,
    this.usageLimit,
    this.timesUsed = 0,
    required this.validFrom,
    required this.validUntil,
    this.appliesTo = 'ALL',
    this.scopeIds = const [],
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      discountType: json['discount_type']?.toString() ?? 'PERCENTAGE',
      discountValue: _toDouble(json['discount_value']),
      minSpend: _toDouble(json['min_spend']),
      maxDiscountCap: json['max_discount_cap'] != null ? _toDouble(json['max_discount_cap']) : null,
      usageLimit: json['usage_limit'] as int?,
      timesUsed: json['times_used'] as int? ?? 0,
      validFrom: json['valid_from'] != null
          ? DateTime.tryParse(json['valid_from'].toString()) ?? DateTime.now()
          : DateTime.now(),
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'].toString()) ?? DateTime.now()
          : DateTime.now(),
      appliesTo: json['applies_to']?.toString() ?? 'ALL',
      scopeIds: (json['scope_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
      'name': name,
      if (code != null) 'code': code,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_spend': minSpend,
      if (maxDiscountCap != null) 'max_discount_cap': maxDiscountCap,
      if (usageLimit != null) 'usage_limit': usageLimit,
      'valid_from': validFrom.toIso8601String().substring(0, 10),
      'valid_until': validUntil.toIso8601String().substring(0, 10),
      'applies_to': appliesTo,
      'scope_ids': scopeIds,
      'is_active': isActive,
    };
  }
}

class PromotionValidationResult {
  final bool isValid;
  final String? promotionId;
  final String? discountType;
  final double? discountValue;
  final double calculatedDiscount;
  final String message;

  const PromotionValidationResult({
    required this.isValid,
    this.promotionId,
    this.discountType,
    this.discountValue,
    required this.calculatedDiscount,
    required this.message,
  });

  factory PromotionValidationResult.fromJson(Map<String, dynamic> json) {
    return PromotionValidationResult(
      isValid: json['is_valid'] as bool? ?? false,
      promotionId: json['promotion_id']?.toString(),
      discountType: json['discount_type']?.toString(),
      discountValue: json['discount_value'] != null
          ? (json['discount_value'] as num).toDouble()
          : null,
      calculatedDiscount: json['calculated_discount'] != null
          ? (json['calculated_discount'] as num).toDouble()
          : 0.0,
      message: json['message']?.toString() ?? '',
    );
  }
}

