class AccountTransferModel {
  final String id;
  final String businessId;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final String? referenceNo;
  final String? note;
  final DateTime transferDate;
  final String createdBy;
  final DateTime createdAt;
  final String? fromAccountName;
  final String? toAccountName;

  AccountTransferModel({
    required this.id,
    required this.businessId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    this.referenceNo,
    this.note,
    required this.transferDate,
    required this.createdBy,
    required this.createdAt,
    this.fromAccountName,
    this.toAccountName,
  });

  factory AccountTransferModel.fromJson(Map<String, dynamic> json) {
    return AccountTransferModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      fromAccountId: json['from_account_id'] as String,
      toAccountId: json['to_account_id'] as String,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      referenceNo: json['reference_no'] as String?,
      note: json['note'] as String?,
      transferDate: DateTime.parse(json['transfer_date'] as String),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      fromAccountName: json['from_account_name'] as String?,
      toAccountName: json['to_account_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'amount': amount,
      'reference_no': referenceNo,
      'note': note,
      'transfer_date': transferDate.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'from_account_name': fromAccountName,
      'to_account_name': toAccountName,
    };
  }
}

