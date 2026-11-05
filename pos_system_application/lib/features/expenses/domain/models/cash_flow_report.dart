class CashFlowReportModel {
  final DateTime startDate;
  final DateTime endDate;
  final double totalCashIn;
  final double totalCashOut;
  final double netCashFlow;
  final Map<String, double> inflowBreakdown;
  final Map<String, double> outflowBreakdown;

  CashFlowReportModel({
    required this.startDate,
    required this.endDate,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.netCashFlow,
    required this.inflowBreakdown,
    required this.outflowBreakdown,
  });

  factory CashFlowReportModel.fromJson(Map<String, dynamic> json) {
    final rawInflows = json['inflow_breakdown'] as Map<String, dynamic>? ?? {};
    final rawOutflows = json['outflow_breakdown'] as Map<String, dynamic>? ?? {};

    final inflows = rawInflows.map((k, v) => MapEntry(k, double.tryParse(v.toString()) ?? 0.0));
    final outflows = rawOutflows.map((k, v) => MapEntry(k, double.tryParse(v.toString()) ?? 0.0));

    return CashFlowReportModel(
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalCashIn: double.tryParse(json['total_cash_in']?.toString() ?? '0') ?? 0.0,
      totalCashOut: double.tryParse(json['total_cash_out']?.toString() ?? '0') ?? 0.0,
      netCashFlow: double.tryParse(json['net_cash_flow']?.toString() ?? '0') ?? 0.0,
      inflowBreakdown: inflows,
      outflowBreakdown: outflows,
    );
  }
}

