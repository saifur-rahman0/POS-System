class CustomerLedgerEntryModel {
  final DateTime date;
  final String entryType;
  final String? receiptNo;
  final String description;
  final double debit;
  final double credit;
  final double balance;

  const CustomerLedgerEntryModel({
    required this.date,
    required this.entryType,
    this.receiptNo,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory CustomerLedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return CustomerLedgerEntryModel(
      date: DateTime.parse(json['date'] as String),
      entryType: json['entry_type'] as String,
      receiptNo: json['receipt_no'] as String?,
      description: json['description'] as String,
      debit: double.tryParse(json['debit']?.toString() ?? '0') ?? 0.0,
      credit: double.tryParse(json['credit']?.toString() ?? '0') ?? 0.0,
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
    );
  }
}
