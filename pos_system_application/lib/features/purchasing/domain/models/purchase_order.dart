import 'purchase_item.dart';

class PurchasePaymentModel {
  final String id;
  final String purchaseId;
  final double amount;
  final String method;
  final String? reference;
  final DateTime paidAt;

  const PurchasePaymentModel({
    required this.id,
    required this.purchaseId,
    required this.amount,
    required this.method,
    this.reference,
    required this.paidAt,
  });

  factory PurchasePaymentModel.fromJson(Map<String, dynamic> json) {
    return PurchasePaymentModel(
      id: json['id'] as String,
      purchaseId: json['purchase_id'] as String,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      method: json['method'] as String,
      reference: json['reference'] as String?,
      paidAt: DateTime.parse(json['paid_at'] as String),
    );
  }
}

class PurchaseOrderModel {
  final String id;
  final String businessId;
  final String branchId;
  final String supplierId;
  final String? supplierName;
  final String referenceNo;
  final String status; // ORDERED, RECEIVED, CANCELLED
  final double subtotal;
  final double discount;
  final double total;
  final double paidTotal;
  final double dueBalance;
  final String? notes;
  final DateTime createdAt;
  final List<PurchaseItemModel> items;
  final List<PurchasePaymentModel> payments;

  const PurchaseOrderModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.supplierId,
    this.supplierName,
    required this.referenceNo,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paidTotal,
    required this.dueBalance,
    this.notes,
    required this.createdAt,
    required this.items,
    required this.payments,
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    final paymentsList = json['payments'] as List<dynamic>? ?? [];

    return PurchaseOrderModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      supplierId: json['supplier_id'] as String,
      supplierName: json['supplier_name'] as String?,
      referenceNo: json['reference_no'] as String,
      status: json['status'] as String,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      paidTotal: double.tryParse(json['paid_total']?.toString() ?? '0') ?? 0.0,
      dueBalance: double.tryParse(json['due_balance']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: itemsList
          .map((item) => PurchaseItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      payments: paymentsList
          .map((item) => PurchasePaymentModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  double get totalAmount => total;
  double get paidAmount => paidTotal;
  double get dueAmount => dueBalance;

  PurchaseOrderModel copyWith({
    String? status,
    double? total,
    double? paidTotal,
    double? dueBalance,
    List<PurchasePaymentModel>? payments,
  }) {
    return PurchaseOrderModel(
      id: id,
      businessId: businessId,
      branchId: branchId,
      supplierId: supplierId,
      supplierName: supplierName,
      referenceNo: referenceNo,
      status: status ?? this.status,
      subtotal: subtotal,
      discount: discount,
      total: total ?? this.total,
      paidTotal: paidTotal ?? this.paidTotal,
      dueBalance: dueBalance ?? this.dueBalance,
      notes: notes,
      createdAt: createdAt,
      items: items,
      payments: payments ?? this.payments,
    );
  }
}
