class SalesTimeSeriesPointModel {
  final String periodLabel;
  final int salesCount;
  final double grossSales;
  final double netSales;
  final double profit;

  const SalesTimeSeriesPointModel({
    required this.periodLabel,
    required this.salesCount,
    required this.grossSales,
    required this.netSales,
    required this.profit,
  });

  factory SalesTimeSeriesPointModel.fromJson(Map<String, dynamic> json) {
    return SalesTimeSeriesPointModel(
      periodLabel: json['period_label'] as String? ?? '',
      salesCount: (json['sales_count'] as num?)?.toInt() ?? 0,
      grossSales: (num.parse(json['gross_sales'].toString())).toDouble(),
      netSales: (num.parse(json['net_sales'].toString())).toDouble(),
      profit: (num.parse(json['profit'].toString())).toDouble(),
    );
  }
}

class SalesTimeSeriesModel {
  final String interval;
  final List<SalesTimeSeriesPointModel> points;

  const SalesTimeSeriesModel({
    required this.interval,
    required this.points,
  });

  factory SalesTimeSeriesModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['points'] as List<dynamic>? ?? [];
    return SalesTimeSeriesModel(
      interval: json['interval'] as String? ?? 'daily',
      points: rawList
          .map((p) => SalesTimeSeriesPointModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

