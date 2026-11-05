class LoyaltySettingsModel {
  final String id;
  final String businessId;
  final bool isEnabled;
  final double earnRate;
  final double redeemRate;
  final int minRedeemPoints;
  final int pointsExpiryDays;
  final double maxCartDiscountPct;
  final DateTime updatedAt;

  const LoyaltySettingsModel({
    required this.id,
    required this.businessId,
    required this.isEnabled,
    required this.earnRate,
    required this.redeemRate,
    required this.minRedeemPoints,
    required this.pointsExpiryDays,
    required this.maxCartDiscountPct,
    required this.updatedAt,
  });

  factory LoyaltySettingsModel.fromJson(Map<String, dynamic> json) {
    return LoyaltySettingsModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      isEnabled: json['is_enabled'] as bool? ?? true,
      earnRate: double.tryParse(json['earn_rate']?.toString() ?? '1') ?? 1.0,
      redeemRate: double.tryParse(json['redeem_rate']?.toString() ?? '0.1') ?? 0.1,
      minRedeemPoints: (json['min_redeem_points'] as num?)?.toInt() ?? 100,
      pointsExpiryDays: (json['points_expiry_days'] as num?)?.toInt() ?? 365,
      maxCartDiscountPct: double.tryParse(json['max_cart_discount_pct']?.toString() ?? '50') ?? 50.0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_enabled': isEnabled,
      'earn_rate': earnRate,
      'redeem_rate': redeemRate,
      'min_redeem_points': minRedeemPoints,
      'points_expiry_days': pointsExpiryDays,
      'max_cart_discount_pct': maxCartDiscountPct,
    };
  }
}

