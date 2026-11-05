class APAgeingBucketModel {
  final String bucketName;
  final double totalAmount;
  final int count;

  APAgeingBucketModel({
    required this.bucketName,
    required this.totalAmount,
    required this.count,
  });

  factory APAgeingBucketModel.fromJson(Map<String, dynamic> json) {
    return APAgeingBucketModel(
      bucketName: json['bucket_name'] as String,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class APAgeingReportModel {
  final DateTime asOfDate;
  final double totalPayable;
  final List<APAgeingBucketModel> buckets;

  APAgeingReportModel({
    required this.asOfDate,
    required this.totalPayable,
    required this.buckets,
  });

  factory APAgeingReportModel.fromJson(Map<String, dynamic> json) {
    final rawBuckets = json['buckets'] as List<dynamic>? ?? [];
    return APAgeingReportModel(
      asOfDate: DateTime.parse(json['as_of_date'] as String),
      totalPayable: double.tryParse(json['total_payable']?.toString() ?? '0') ?? 0.0,
      buckets: rawBuckets.map((e) => APAgeingBucketModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

