import 'loyalty_transaction.dart';

class CustomerLoyaltySummaryModel {
  final String customerId;
  final String customerName;
  final String? phone;
  final int loyaltyPointsBalance;
  final String? membershipTierId;
  final String? membershipTierName;
  final double pointsMultiplier;
  final double tierDiscountPct;
  final String badgeColor;
  final double lifetimeSpend;
  final double storeCreditBalance;
  final List<LoyaltyTransactionModel> recentTransactions;

  const CustomerLoyaltySummaryModel({
    required this.customerId,
    required this.customerName,
    this.phone,
    required this.loyaltyPointsBalance,
    this.membershipTierId,
    this.membershipTierName,
    required this.pointsMultiplier,
    required this.tierDiscountPct,
    required this.badgeColor,
    required this.lifetimeSpend,
    required this.storeCreditBalance,
    required this.recentTransactions,
  });

  factory CustomerLoyaltySummaryModel.fromJson(Map<String, dynamic> json) {
    return CustomerLoyaltySummaryModel(
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      phone: json['phone'] as String?,
      loyaltyPointsBalance: (json['loyalty_points_balance'] as num?)?.toInt() ?? 0,
      membershipTierId: json['membership_tier_id'] as String?,
      membershipTierName: json['membership_tier_name'] as String?,
      pointsMultiplier: double.tryParse(json['points_multiplier']?.toString() ?? '1') ?? 1.0,
      tierDiscountPct: double.tryParse(json['tier_discount_pct']?.toString() ?? '0') ?? 0.0,
      badgeColor: json['badge_color'] as String? ?? '#64748B',
      lifetimeSpend: double.tryParse(json['lifetime_spend']?.toString() ?? '0') ?? 0.0,
      storeCreditBalance: double.tryParse(json['store_credit_balance']?.toString() ?? '0') ?? 0.0,
      recentTransactions: (json['recent_transactions'] as List<dynamic>?)
              ?.map((t) => LoyaltyTransactionModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

