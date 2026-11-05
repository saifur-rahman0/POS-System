class LoyaltyTransactionModel {
  final String id;
  final String businessId;
  final String customerId;
  final String? saleId;
  final String transactionType;
  final int points;
  final int pointsBalanceAfter;
  final String? reason;
  final DateTime createdAt;

  const LoyaltyTransactionModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    this.saleId,
    required this.transactionType,
    required this.points,
    required this.pointsBalanceAfter,
    this.reason,
    required this.createdAt,
  });

  factory LoyaltyTransactionModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransactionModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      customerId: json['customer_id'] as String,
      saleId: json['sale_id'] as String?,
      transactionType: json['transaction_type'] as String,
      points: (json['points'] as num?)?.toInt() ?? 0,
      pointsBalanceAfter: (json['points_balance_after'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

