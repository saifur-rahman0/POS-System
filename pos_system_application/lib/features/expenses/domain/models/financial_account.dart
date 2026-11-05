class FinancialAccountModel {
  final String id;
  final String businessId;
  final String? branchId;
  final String accountName;
  final String accountType; // CASH_DRAWER, SAFE, BANK, MOBILE_WALLET, PETTY_CASH
  final String? accountNumber;
  final String? bankName;
  final double openingBalance;
  final double currentBalance;
  final bool isActive;
  final DateTime createdAt;

  FinancialAccountModel({
    required this.id,
    required this.businessId,
    this.branchId,
    required this.accountName,
    required this.accountType,
    this.accountNumber,
    this.bankName,
    required this.openingBalance,
    required this.currentBalance,
    required this.isActive,
    required this.createdAt,
  });

  factory FinancialAccountModel.fromJson(Map<String, dynamic> json) {
    return FinancialAccountModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String?,
      accountName: json['account_name'] as String,
      accountType: json['account_type'] as String,
      accountNumber: json['account_number'] as String?,
      bankName: json['bank_name'] as String?,
      openingBalance: double.tryParse(json['opening_balance']?.toString() ?? '0') ?? 0.0,
      currentBalance: double.tryParse(json['current_balance']?.toString() ?? '0') ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'branch_id': branchId,
      'account_name': accountName,
      'account_type': accountType,
      'account_number': accountNumber,
      'bank_name': bankName,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get typeDisplayName {
    switch (accountType) {
      case 'CASH_DRAWER':
        return 'Cash Drawer';
      case 'SAFE':
        return 'Store Safe';
      case 'BANK':
        return 'Bank Account';
      case 'MOBILE_WALLET':
        return 'Mobile Wallet';
      case 'PETTY_CASH':
        return 'Petty Cash';
      default:
        return accountType;
    }
  }
}

