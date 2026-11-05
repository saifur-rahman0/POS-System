class GiftCardModel {
  final String id;
  final String businessId;
  final String cardNumber;
  final double initialBalance;
  final double currentBalance;
  final String status;
  final String? purchaserCustomerId;
  final String? recipientName;
  final String? recipientPhone;
  final String? recipientEmail;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const GiftCardModel({
    required this.id,
    required this.businessId,
    required this.cardNumber,
    required this.initialBalance,
    required this.currentBalance,
    required this.status,
    this.purchaserCustomerId,
    this.recipientName,
    this.recipientPhone,
    this.recipientEmail,
    this.expiresAt,
    required this.createdAt,
  });

  factory GiftCardModel.fromJson(Map<String, dynamic> json) {
    return GiftCardModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      cardNumber: json['card_number'] as String,
      initialBalance: double.tryParse(json['initial_balance']?.toString() ?? '0') ?? 0.0,
      currentBalance: double.tryParse(json['current_balance']?.toString() ?? '0') ?? 0.0,
      status: json['status'] as String? ?? 'ACTIVE',
      purchaserCustomerId: json['purchaser_customer_id'] as String?,
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
      recipientEmail: json['recipient_email'] as String?,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

class GiftCardVerifyResult {
  final bool isValid;
  final String? cardId;
  final String? cardNumber;
  final double currentBalance;
  final String? status;
  final String message;

  const GiftCardVerifyResult({
    required this.isValid,
    this.cardId,
    this.cardNumber,
    required this.currentBalance,
    this.status,
    required this.message,
  });

  factory GiftCardVerifyResult.fromJson(Map<String, dynamic> json) {
    return GiftCardVerifyResult(
      isValid: json['is_valid'] as bool? ?? false,
      cardId: json['card_id'] as String?,
      cardNumber: json['card_number'] as String?,
      currentBalance: double.tryParse(json['current_balance']?.toString() ?? '0') ?? 0.0,
      status: json['status'] as String?,
      message: json['message'] as String? ?? '',
    );
  }
}

