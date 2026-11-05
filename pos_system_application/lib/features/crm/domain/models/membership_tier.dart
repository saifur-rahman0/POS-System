class MembershipTierModel {
  final String id;
  final String businessId;
  final String name;
  final String code;
  final double minSpend;
  final double pointsMultiplier;
  final double discountPct;
  final String badgeColor;
  final String? perksDescription;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  const MembershipTierModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.code,
    required this.minSpend,
    required this.pointsMultiplier,
    required this.discountPct,
    required this.badgeColor,
    this.perksDescription,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
  });

  factory MembershipTierModel.fromJson(Map<String, dynamic> json) {
    return MembershipTierModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      minSpend: double.tryParse(json['min_spend']?.toString() ?? '0') ?? 0.0,
      pointsMultiplier: double.tryParse(json['points_multiplier']?.toString() ?? '1') ?? 1.0,
      discountPct: double.tryParse(json['discount_pct']?.toString() ?? '0') ?? 0.0,
      badgeColor: json['badge_color'] as String? ?? '#64748B',
      perksDescription: json['perks_description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'min_spend': minSpend,
      'points_multiplier': pointsMultiplier,
      'discount_pct': discountPct,
      'badge_color': badgeColor,
      'perks_description': perksDescription,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}

