class ShiftSummaryTotalsModel {
  final double openingCash;
  final double cashSales;
  final double cashIn;
  final double cashRefunds;
  final double cashOut;
  final double expectedCash;
  final double? actualCashCounted;
  final double? cashDifference;

  const ShiftSummaryTotalsModel({
    required this.openingCash,
    required this.cashSales,
    required this.cashIn,
    required this.cashRefunds,
    required this.cashOut,
    required this.expectedCash,
    this.actualCashCounted,
    this.cashDifference,
  });

  factory ShiftSummaryTotalsModel.fromJson(Map<String, dynamic> json) {
    return ShiftSummaryTotalsModel(
      openingCash: double.tryParse(json['opening_cash']?.toString() ?? '0') ?? 0.0,
      cashSales: double.tryParse(json['cash_sales']?.toString() ?? '0') ?? 0.0,
      cashIn: double.tryParse(json['cash_in']?.toString() ?? '0') ?? 0.0,
      cashRefunds: double.tryParse(json['cash_refunds']?.toString() ?? '0') ?? 0.0,
      cashOut: double.tryParse(json['cash_out']?.toString() ?? '0') ?? 0.0,
      expectedCash: double.tryParse(json['expected_cash']?.toString() ?? '0') ?? 0.0,
      actualCashCounted: json['actual_cash_counted'] != null
          ? double.tryParse(json['actual_cash_counted'].toString())
          : null,
      cashDifference: json['cash_difference'] != null
          ? double.tryParse(json['cash_difference'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opening_cash': openingCash,
      'cash_sales': cashSales,
      'cash_in': cashIn,
      'cash_refunds': cashRefunds,
      'cash_out': cashOut,
      'expected_cash': expectedCash,
      if (actualCashCounted != null) 'actual_cash_counted': actualCashCounted,
      if (cashDifference != null) 'cash_difference': cashDifference,
    };
  }
}

class RegisterShiftModel {
  final String id;
  final String businessId;
  final String branchId;
  final String? branchName;
  final String userId;
  final String? cashierName;
  final String? deviceId;
  final String status; // OPEN, CLOSED
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingCash;
  final double? closingCashCounted;
  final double? closingCashExpected;
  final double? cashDifference;
  final String? openingNotes;
  final String? closingNotes;
  final Map<String, dynamic> denominations;
  final ShiftSummaryTotalsModel? totals;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RegisterShiftModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    this.branchName,
    required this.userId,
    this.cashierName,
    this.deviceId,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.openingCash,
    this.closingCashCounted,
    this.closingCashExpected,
    this.cashDifference,
    this.openingNotes,
    this.closingNotes,
    this.denominations = const {},
    this.totals,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == 'OPEN';
  bool get isClosed => status == 'CLOSED';

  factory RegisterShiftModel.fromJson(Map<String, dynamic> json) {
    return RegisterShiftModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      branchName: json['branch_name'] as String?,
      userId: json['user_id'] as String,
      cashierName: json['cashier_name'] as String?,
      deviceId: json['device_id'] as String?,
      status: json['status'] as String? ?? 'OPEN',
      openedAt: json['opened_at'] != null
          ? DateTime.parse(json['opened_at'] as String)
          : DateTime.now(),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      openingCash: double.tryParse(json['opening_cash']?.toString() ?? '0') ?? 0.0,
      closingCashCounted: json['closing_cash_counted'] != null
          ? double.tryParse(json['closing_cash_counted'].toString())
          : null,
      closingCashExpected: json['closing_cash_expected'] != null
          ? double.tryParse(json['closing_cash_expected'].toString())
          : null,
      cashDifference: json['cash_difference'] != null
          ? double.tryParse(json['cash_difference'].toString())
          : null,
      openingNotes: json['opening_notes'] as String?,
      closingNotes: json['closing_notes'] as String?,
      denominations: (json['denominations_json'] as Map<String, dynamic>?) ?? {},
      totals: json['totals'] != null
          ? ShiftSummaryTotalsModel.fromJson(json['totals'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'branch_id': branchId,
      'branch_name': branchName,
      'user_id': userId,
      'cashier_name': cashierName,
      'device_id': deviceId,
      'status': status,
      'opened_at': openedAt.toIso8601String(),
      if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
      'opening_cash': openingCash,
      if (closingCashCounted != null) 'closing_cash_counted': closingCashCounted,
      if (closingCashExpected != null) 'closing_cash_expected': closingCashExpected,
      if (cashDifference != null) 'cash_difference': cashDifference,
      'opening_notes': openingNotes,
      'closing_notes': closingNotes,
      'denominations_json': denominations,
      if (totals != null) 'totals': totals!.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ShiftCashTransactionModel {
  final String id;
  final String businessId;
  final String branchId;
  final String accountId;
  final String direction; // IN, OUT
  final double amount;
  final String referenceType;
  final String referenceId;
  final String? note;
  final String createdBy;
  final DateTime createdAt;

  const ShiftCashTransactionModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.accountId,
    required this.direction,
    required this.amount,
    required this.referenceType,
    required this.referenceId,
    this.note,
    required this.createdBy,
    required this.createdAt,
  });

  factory ShiftCashTransactionModel.fromJson(Map<String, dynamic> json) {
    return ShiftCashTransactionModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      accountId: json['account_id'] as String? ?? 'MAIN_CASH_DRAWER',
      direction: json['direction'] as String,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      referenceType: json['reference_type'] as String,
      referenceId: json['reference_id'] as String,
      note: json['note'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
