class PaymentMethodBreakdownItemModel {
  final String method;
  final double totalAmount;
  final int transactionCount;
  final double percentage;

  const PaymentMethodBreakdownItemModel({
    required this.method,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });

  factory PaymentMethodBreakdownItemModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodBreakdownItemModel(
      method: json['method'] as String? ?? 'UNKNOWN',
      totalAmount: (num.parse(json['total_amount'].toString())).toDouble(),
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      percentage: (num.parse(json['percentage'].toString())).toDouble(),
    );
  }
}

class PaymentMethodBreakdownModel {
  final double totalCollected;
  final List<PaymentMethodBreakdownItemModel> methods;

  const PaymentMethodBreakdownModel({
    required this.totalCollected,
    required this.methods,
  });

  factory PaymentMethodBreakdownModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['methods'] as List<dynamic>? ?? [];
    return PaymentMethodBreakdownModel(
      totalCollected: (num.parse(json['total_collected'].toString())).toDouble(),
      methods: rawList
          .map((m) => PaymentMethodBreakdownItemModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

