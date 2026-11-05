class SaleReceiptModel {
  final String id;
  final String receiptNo;
  final String status;
  final String cashierId;
  final String? customerId;
  final String? customerName;
  final SaleFinancialsModel financials;
  final List<SaleReceiptItemModel> items;
  final List<SaleReceiptPaymentModel> payments;
  final String? notes;
  final DateTime createdAt;

  double get grandTotal => financials.grandTotal;
  double get subtotal => financials.subtotal;

  const SaleReceiptModel({
    required this.id,
    required this.receiptNo,
    required this.status,
    required this.cashierId,
    this.customerId,
    this.customerName,
    required this.financials,
    required this.items,
    required this.payments,
    this.notes,
    required this.createdAt,
  });

  factory SaleReceiptModel.fromJson(Map<dynamic, dynamic> json) {
    final finMap = json['financials'] is Map ? json['financials'] as Map : {};
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final rawPayments = json['payments'] as List<dynamic>? ?? [];

    return SaleReceiptModel(
      id: json['id']?.toString() ?? '',
      receiptNo: json['receipt_no']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      cashierId: json['cashier_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString(),
      financials: SaleFinancialsModel.fromJson(finMap),
      items: rawItems
          .map((i) => SaleReceiptItemModel.fromJson(i is Map ? i : {}))
          .toList(),
      payments: rawPayments
          .map((p) => SaleReceiptPaymentModel.fromJson(p is Map ? p : {}))
          .toList(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SaleFinancialsModel {
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double grandTotal;
  final double paidTotal;
  final double dueTotal;
  final double changeAmount;

  const SaleFinancialsModel({
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.paidTotal,
    required this.dueTotal,
    required this.changeAmount,
  });

  factory SaleFinancialsModel.fromJson(Map<dynamic, dynamic> json) {
    return SaleFinancialsModel(
      subtotal: _toDouble(json['subtotal']),
      discountTotal: _toDouble(json['discount_total']),
      taxTotal: _toDouble(json['tax_total']),
      grandTotal: _toDouble(json['grand_total']),
      paidTotal: _toDouble(json['paid_total']),
      dueTotal: _toDouble(json['due_total']),
      changeAmount: _toDouble(json['change_amount']),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

class SaleReceiptItemModel {
  final String id;
  final String productVariantId;
  final String productName;
  final String? sku;
  final String? barcode;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double lineTotal;

  const SaleReceiptItemModel({
    required this.id,
    required this.productVariantId,
    required this.productName,
    this.sku,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
  });

  factory SaleReceiptItemModel.fromJson(Map<dynamic, dynamic> json) {
    return SaleReceiptItemModel(
      id: json['id']?.toString() ?? '',
      productVariantId: json['product_variant_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Product',
      sku: json['sku']?.toString(),
      barcode: json['barcode']?.toString(),
      quantity: _toDouble(json['quantity']),
      unitPrice: _toDouble(json['unit_price']),
      discount: _toDouble(json['discount']),
      lineTotal: _toDouble(json['line_total']),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

class SaleReceiptPaymentModel {
  final String id;
  final String method;
  final double amount;
  final String? reference;
  final String status;

  const SaleReceiptPaymentModel({
    required this.id,
    required this.method,
    required this.amount,
    this.reference,
    required this.status,
  });

  factory SaleReceiptPaymentModel.fromJson(Map<dynamic, dynamic> json) {
    return SaleReceiptPaymentModel(
      id: json['id']?.toString() ?? '',
      method: json['method']?.toString() ?? 'CASH',
      amount: _toDouble(json['amount']),
      reference: json['reference']?.toString(),
      status: json['status']?.toString() ?? 'CONFIRMED',
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

