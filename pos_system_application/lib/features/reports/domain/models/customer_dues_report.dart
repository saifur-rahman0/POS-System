class TopDebtorModel {
  final String customerId;
  final String name;
  final String? phone;
  final double dueBalance;
  final double creditLimit;
  final double utilizationPct;

  const TopDebtorModel({
    required this.customerId,
    required this.name,
    this.phone,
    required this.dueBalance,
    required this.creditLimit,
    required this.utilizationPct,
  });

  factory TopDebtorModel.fromJson(Map<String, dynamic> json) {
    return TopDebtorModel(
      customerId: json['customer_id'] as String,
      name: json['name'] as String? ?? 'Unnamed',
      phone: json['phone'] as String?,
      dueBalance: (num.parse(json['due_balance'].toString())).toDouble(),
      creditLimit: (num.parse(json['credit_limit'].toString())).toDouble(),
      utilizationPct: (num.parse(json['utilization_pct'].toString())).toDouble(),
    );
  }
}

class CustomerDuesReportModel {
  final int totalCustomersWithDue;
  final double totalOutstandingDue;
  final double totalCreditLimit;
  final double overallCreditUtilizationPct;
  final List<TopDebtorModel> topDebtors;

  const CustomerDuesReportModel({
    required this.totalCustomersWithDue,
    required this.totalOutstandingDue,
    required this.totalCreditLimit,
    required this.overallCreditUtilizationPct,
    required this.topDebtors,
  });

  factory CustomerDuesReportModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['top_debtors'] as List<dynamic>? ?? [];
    return CustomerDuesReportModel(
      totalCustomersWithDue: (json['total_customers_with_due'] as num?)?.toInt() ?? 0,
      totalOutstandingDue: (num.parse(json['total_outstanding_due'].toString())).toDouble(),
      totalCreditLimit: (num.parse(json['total_credit_limit'].toString())).toDouble(),
      overallCreditUtilizationPct:
          (num.parse(json['overall_credit_utilization_pct'].toString())).toDouble(),
      topDebtors: rawList
          .map((d) => TopDebtorModel.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

