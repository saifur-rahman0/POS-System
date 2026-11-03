class SaleSummaryModel {
  final String id;
  final String receiptNo;
  final String status;
  final String cashierId;
  final String? customerId;
  final String? customerName;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double grandTotal;
  final double paidTotal;
  final double dueTotal;
  final int itemsCount;
  final DateTime createdAt;

  const SaleSummaryModel({
    required this.id,
    required this.receiptNo,
    required this.status,
    required this.cashierId,
    this.customerId,
    this.customerName,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.paidTotal,
    required this.dueTotal,
    required this.itemsCount,
    required this.createdAt,
  });

  factory SaleSummaryModel.fromJson(Map<dynamic, dynamic> json) {
    return SaleSummaryModel(
      id: json['id']?.toString() ?? '',
      receiptNo: json['receipt_no']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      cashierId: json['cashier_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString(),
      subtotal: _toDouble(json['subtotal']),
      discountTotal: _toDouble(json['discount_total']),
      taxTotal: _toDouble(json['tax_total']),
      grandTotal: _toDouble(json['grand_total']),
      paidTotal: _toDouble(json['paid_total']),
      dueTotal: _toDouble(json['due_total']),
      itemsCount: json['items_count'] is num ? (json['items_count'] as num).toInt() : 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

