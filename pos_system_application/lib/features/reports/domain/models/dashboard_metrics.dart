class DashboardMetricsModel {
  final DateTime periodStart;
  final DateTime periodEnd;
  final double grossSales;
  final double netSales;
  final int totalOrders;
  final double totalItemsSold;
  final double averageBasketValue;
  final double grossProfit;
  final double profitMarginPct;
  final double totalTax;
  final double totalDiscount;
  final double totalRefunds;
  final double totalCollected;
  final double totalDueIssued;
  final int lowStockCount;
  final int outOfStockCount;

  const DashboardMetricsModel({
    required this.periodStart,
    required this.periodEnd,
    required this.grossSales,
    required this.netSales,
    required this.totalOrders,
    required this.totalItemsSold,
    required this.averageBasketValue,
    required this.grossProfit,
    required this.profitMarginPct,
    required this.totalTax,
    required this.totalDiscount,
    required this.totalRefunds,
    required this.totalCollected,
    required this.totalDueIssued,
    required this.lowStockCount,
    required this.outOfStockCount,
  });

  factory DashboardMetricsModel.fromJson(Map<String, dynamic> json) {
    return DashboardMetricsModel(
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      grossSales: (num.parse(json['gross_sales'].toString())).toDouble(),
      netSales: (num.parse(json['net_sales'].toString())).toDouble(),
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      totalItemsSold: (num.parse(json['total_items_sold'].toString())).toDouble(),
      averageBasketValue: (num.parse(json['average_basket_value'].toString())).toDouble(),
      grossProfit: (num.parse(json['gross_profit'].toString())).toDouble(),
      profitMarginPct: (num.parse(json['profit_margin_pct'].toString())).toDouble(),
      totalTax: (num.parse(json['total_tax'].toString())).toDouble(),
      totalDiscount: (num.parse(json['total_discount'].toString())).toDouble(),
      totalRefunds: (num.parse(json['total_refunds'].toString())).toDouble(),
      totalCollected: (num.parse(json['total_collected'].toString())).toDouble(),
      totalDueIssued: (num.parse(json['total_due_issued'].toString())).toDouble(),
      lowStockCount: (json['low_stock_count'] as num?)?.toInt() ?? 0,
      outOfStockCount: (json['out_of_stock_count'] as num?)?.toInt() ?? 0,
    );
  }
}

