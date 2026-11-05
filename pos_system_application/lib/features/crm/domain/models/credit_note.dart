class CreditNoteModel {
  final String id;
  final String businessId;
  final String customerId;
  final String? saleReturnId;
  final String noteNumber;
  final double initialAmount;
  final double remainingBalance;
  final String status;
  final String reason;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const CreditNoteModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    this.saleReturnId,
    required this.noteNumber,
    required this.initialAmount,
    required this.remainingBalance,
    required this.status,
    required this.reason,
    this.expiresAt,
    required this.createdAt,
  });

  factory CreditNoteModel.fromJson(Map<String, dynamic> json) {
    return CreditNoteModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      customerId: json['customer_id'] as String,
      saleReturnId: json['sale_return_id'] as String?,
      noteNumber: json['note_number'] as String,
      initialAmount: double.tryParse(json['initial_amount']?.toString() ?? '0') ?? 0.0,
      remainingBalance: double.tryParse(json['remaining_balance']?.toString() ?? '0') ?? 0.0,
      status: json['status'] as String? ?? 'ACTIVE',
      reason: json['reason'] as String? ?? '',
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

