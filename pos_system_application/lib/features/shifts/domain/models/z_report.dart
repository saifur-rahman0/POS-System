class CashReconciliationModel {
  final double openingFloat;
  final double cashSales;
  final double cashIn;
  final double cashRefunds;
  final double cashOut;
  final double expectedInDrawer;
  final double? actualCounted;
  final double? difference;
  final String varianceStatus; // BALANCED, SHORTAGE, OVERAGE, PENDING_CLOSE

  const CashReconciliationModel({
    required this.openingFloat,
    required this.cashSales,
    required this.cashIn,
    required this.cashRefunds,
    required this.cashOut,
    required this.expectedInDrawer,
    this.actualCounted,
    this.difference,
    required this.varianceStatus,
  });

  factory CashReconciliationModel.fromJson(Map<String, dynamic> json) {
    return CashReconciliationModel(
      openingFloat: double.tryParse(json['opening_float']?.toString() ?? '0') ?? 0.0,
      cashSales: double.tryParse(json['cash_sales']?.toString() ?? '0') ?? 0.0,
      cashIn: double.tryParse(json['cash_in']?.toString() ?? '0') ?? 0.0,
      cashRefunds: double.tryParse(json['cash_refunds']?.toString() ?? '0') ?? 0.0,
      cashOut: double.tryParse(json['cash_out']?.toString() ?? '0') ?? 0.0,
      expectedInDrawer: double.tryParse(json['expected_in_drawer']?.toString() ?? '0') ?? 0.0,
      actualCounted: json['actual_counted'] != null
          ? double.tryParse(json['actual_counted'].toString())
          : null,
      difference: json['difference'] != null
          ? double.tryParse(json['difference'].toString())
          : null,
      varianceStatus: json['variance_status'] as String? ?? 'PENDING_CLOSE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opening_float': openingFloat,
      'cash_sales': cashSales,
      'cash_in': cashIn,
      'cash_refunds': cashRefunds,
      'cash_out': cashOut,
      'expected_in_drawer': expectedInDrawer,
      if (actualCounted != null) 'actual_counted': actualCounted,
      if (difference != null) 'difference': difference,
      'variance_status': varianceStatus,
    };
  }
}

class TenderBreakdownModel {
  final String method;
  final int count;
  final double totalAmount;

  const TenderBreakdownModel({
    required this.method,
    required this.count,
    required this.totalAmount,
  });

  factory TenderBreakdownModel.fromJson(Map<String, dynamic> json) {
    return TenderBreakdownModel(
      method: json['method'] as String? ?? 'CASH',
      count: (json['count'] as num?)?.toInt() ?? 0,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'count': count,
      'total_amount': totalAmount,
    };
  }
}

class SalesPerformanceSummaryModel {
  final double grossSales;
  final double discountTotal;
  final double netSales;
  final double taxTotal;
  final int totalTransactions;
  final int completedSales;
  final int voidedSales;
  final int returnsCount;
  final double returnsTotal;

  const SalesPerformanceSummaryModel({
    required this.grossSales,
    required this.discountTotal,
    required this.netSales,
    required this.taxTotal,
    required this.totalTransactions,
    required this.completedSales,
    required this.voidedSales,
    required this.returnsCount,
    required this.returnsTotal,
  });

  factory SalesPerformanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return SalesPerformanceSummaryModel(
      grossSales: double.tryParse(json['gross_sales']?.toString() ?? '0') ?? 0.0,
      discountTotal: double.tryParse(json['discount_total']?.toString() ?? '0') ?? 0.0,
      netSales: double.tryParse(json['net_sales']?.toString() ?? '0') ?? 0.0,
      taxTotal: double.tryParse(json['tax_total']?.toString() ?? '0') ?? 0.0,
      totalTransactions: (json['total_transactions'] as num?)?.toInt() ?? 0,
      completedSales: (json['completed_sales'] as num?)?.toInt() ?? 0,
      voidedSales: (json['voided_sales'] as num?)?.toInt() ?? 0,
      returnsCount: (json['returns_count'] as num?)?.toInt() ?? 0,
      returnsTotal: double.tryParse(json['returns_total']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gross_sales': grossSales,
      'discount_total': discountTotal,
      'net_sales': netSales,
      'tax_total': taxTotal,
      'total_transactions': totalTransactions,
      'completed_sales': completedSales,
      'voided_sales': voidedSales,
      'returns_count': returnsCount,
      'returns_total': returnsTotal,
    };
  }
}

class ZReportModel {
  final String shiftId;
  final String businessName;
  final String branchName;
  final String cashierUsername;
  final String? cashierFullName;
  final String status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int durationMinutes;
  final CashReconciliationModel cashReconciliation;
  final List<TenderBreakdownModel> tendersBreakdown;
  final SalesPerformanceSummaryModel salesSummary;
  final DateTime generatedAt;

  const ZReportModel({
    required this.shiftId,
    required this.businessName,
    required this.branchName,
    required this.cashierUsername,
    this.cashierFullName,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.durationMinutes,
    required this.cashReconciliation,
    required this.tendersBreakdown,
    required this.salesSummary,
    required this.generatedAt,
  });

  factory ZReportModel.fromJson(Map<String, dynamic> json) {
    return ZReportModel(
      shiftId: json['shift_id'] as String,
      businessName: json['business_name'] as String? ?? 'Retail Store',
      branchName: json['branch_name'] as String? ?? 'Main Branch',
      cashierUsername: json['cashier_username'] as String? ?? 'Cashier',
      cashierFullName: json['cashier_full_name'] as String?,
      status: json['status'] as String? ?? 'OPEN',
      openedAt: json['opened_at'] != null
          ? DateTime.parse(json['opened_at'] as String)
          : DateTime.now(),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      cashReconciliation: CashReconciliationModel.fromJson(
        json['cash_reconciliation'] as Map<String, dynamic>? ?? {},
      ),
      tendersBreakdown: (json['tenders_breakdown'] as List<dynamic>? ?? [])
          .map((e) => TenderBreakdownModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      salesSummary: SalesPerformanceSummaryModel.fromJson(
        json['sales_summary'] as Map<String, dynamic>? ?? {},
      ),
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_id': shiftId,
      'business_name': businessName,
      'branch_name': branchName,
      'cashier_username': cashierUsername,
      'cashier_full_name': cashierFullName,
      'status': status,
      'opened_at': openedAt.toIso8601String(),
      if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
      'duration_minutes': durationMinutes,
      'cash_reconciliation': cashReconciliation.toJson(),
      'tenders_breakdown': tendersBreakdown.map((e) => e.toJson()).toList(),
      'sales_summary': salesSummary.toJson(),
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}
