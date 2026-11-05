class ExpenseModel {
  final String id;
  final String businessId;
  final String branchId;
  final String? voucherNo;
  final String category;
  final String? categoryId;
  final String? paymentAccountId;
  final String paymentMethod;
  final String? payee;
  final String? receiptReference;
  final bool taxDeductible;
  final double amount;
  final String? note;
  final String approvalStatus; // APPROVED, PENDING_APPROVAL, REJECTED
  final String? approvedBy;
  final DateTime? approvedAt;
  final String createdBy;
  final DateTime createdAt;
  final String? categoryName;
  final String? paymentAccountName;

  ExpenseModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    this.voucherNo,
    required this.category,
    this.categoryId,
    this.paymentAccountId,
    required this.paymentMethod,
    this.payee,
    this.receiptReference,
    required this.taxDeductible,
    required this.amount,
    this.note,
    required this.approvalStatus,
    this.approvedBy,
    this.approvedAt,
    required this.createdBy,
    required this.createdAt,
    this.categoryName,
    this.paymentAccountName,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      voucherNo: json['voucher_no'] as String?,
      category: json['category'] as String,
      categoryId: json['category_id'] as String?,
      paymentAccountId: json['payment_account_id'] as String?,
      paymentMethod: json['payment_method'] as String? ?? 'CASH',
      payee: json['payee'] as String?,
      receiptReference: json['receipt_reference'] as String?,
      taxDeductible: json['tax_deductible'] as bool? ?? true,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      note: json['note'] as String?,
      approvalStatus: json['approval_status'] as String? ?? 'APPROVED',
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      categoryName: json['category_name'] as String?,
      paymentAccountName: json['payment_account_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'branch_id': branchId,
      'voucher_no': voucherNo,
      'category': category,
      'category_id': categoryId,
      'payment_account_id': paymentAccountId,
      'payment_method': paymentMethod,
      'payee': payee,
      'receipt_reference': receiptReference,
      'tax_deductible': taxDeductible,
      'amount': amount,
      'note': note,
      'approval_status': approvalStatus,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'category_name': categoryName,
      'payment_account_name': paymentAccountName,
    };
  }

  bool get isPendingApproval => approvalStatus == 'PENDING_APPROVAL';
  bool get isApproved => approvalStatus == 'APPROVED';
  bool get isRejected => approvalStatus == 'REJECTED';
}

