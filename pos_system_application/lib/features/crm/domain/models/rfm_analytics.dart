class RfmSegmentSummary {
  final String segment;
  final int count;
  final double percentage;
  final double totalMonetary;
  final double avgRecencyDays;

  const RfmSegmentSummary({
    required this.segment,
    required this.count,
    required this.percentage,
    required this.totalMonetary,
    required this.avgRecencyDays,
  });

  factory RfmSegmentSummary.fromJson(Map<String, dynamic> json) {
    return RfmSegmentSummary(
      segment: json['segment'] as String,
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: double.tryParse(json['percentage']?.toString() ?? '0') ?? 0.0,
      totalMonetary: double.tryParse(json['total_monetary']?.toString() ?? '0') ?? 0.0,
      avgRecencyDays: double.tryParse(json['avg_recency_days']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class RetentionKpisModel {
  final int totalActiveCustomers;
  final double repeatPurchaseRate;
  final double churnRate90d;
  final double avgClv;
  final double revenueAtRisk;
  final List<RfmSegmentSummary> segments;

  const RetentionKpisModel({
    required this.totalActiveCustomers,
    required this.repeatPurchaseRate,
    required this.churnRate90d,
    required this.avgClv,
    required this.revenueAtRisk,
    required this.segments,
  });

  factory RetentionKpisModel.fromJson(Map<String, dynamic> json) {
    return RetentionKpisModel(
      totalActiveCustomers: (json['total_active_customers'] as num?)?.toInt() ?? 0,
      repeatPurchaseRate: double.tryParse(json['repeat_purchase_rate']?.toString() ?? '0') ?? 0.0,
      churnRate90d: double.tryParse(json['churn_rate_90d']?.toString() ?? '0') ?? 0.0,
      avgClv: double.tryParse(json['avg_clv']?.toString() ?? '0') ?? 0.0,
      revenueAtRisk: double.tryParse(json['revenue_at_risk']?.toString() ?? '0') ?? 0.0,
      segments: (json['segments'] as List<dynamic>?)
              ?.map((s) => RfmSegmentSummary.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

