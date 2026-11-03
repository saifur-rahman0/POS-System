class PaymentTenderInput {
  final String method; // 'CASH', 'CARD', 'BKASH', 'NAGAD', 'ROCKET', 'DUE'
  final double amount;
  final String? reference;

  const PaymentTenderInput({
    required this.method,
    required this.amount,
    this.reference,
  });

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'amount': amount.toStringAsFixed(4),
      if (reference != null && reference!.trim().isNotEmpty)
        'reference': reference!.trim(),
    };
  }
}

