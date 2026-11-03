class AllocatedSalePaymentModel {
  final String saleId;
  final String receiptNo;
  final double allocatedAmount;
  final double remainingSaleDue;

  const AllocatedSalePaymentModel({
    required this.saleId,
    required this.receiptNo,
    required this.allocatedAmount,
    required this.remainingSaleDue,
  });

  factory AllocatedSalePaymentModel.fromJson(Map<String, dynamic> json) {
    return AllocatedSalePaymentModel(
      saleId: json['sale_id'] as String,
      receiptNo: json['receipt_no'] as String,
      allocatedAmount: double.tryParse(json['allocated_amount']?.toString() ?? '0') ?? 0.0,
      remainingSaleDue: double.tryParse(json['remaining_sale_due']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CustomerDuePaymentModel {
  final String customerId;
  final String customerName;
  final double amountPaid;
  final double previousDue;
  final double remainingDue;
  final String paymentMethod;
  final String? reference;
  final List<AllocatedSalePaymentModel> allocatedSales;
  final DateTime createdAt;

  const CustomerDuePaymentModel({
    required this.customerId,
    required this.customerName,
    required this.amountPaid,
    required this.previousDue,
    required this.remainingDue,
    required this.paymentMethod,
    this.reference,
    required this.allocatedSales,
    required this.createdAt,
  });

  factory CustomerDuePaymentModel.fromJson(Map<String, dynamic> json) {
    final list = json['allocated_sales'] as List<dynamic>? ?? [];
    return CustomerDuePaymentModel(
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      amountPaid: double.tryParse(json['amount_paid']?.toString() ?? '0') ?? 0.0,
      previousDue: double.tryParse(json['previous_due']?.toString() ?? '0') ?? 0.0,
      remainingDue: double.tryParse(json['remaining_due']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['payment_method'] as String,
      reference: json['reference'] as String?,
      allocatedSales: list
          .map((item) => AllocatedSalePaymentModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
