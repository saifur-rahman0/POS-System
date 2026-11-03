class SupplierModel {
  final String id;
  final String businessId;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final bool isActive;
  final int totalPurchasesCount;
  final double totalPurchasesAmount;
  final double unpaidBalance;
  final DateTime createdAt;

  const SupplierModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    required this.isActive,
    required this.totalPurchasesCount,
    required this.totalPurchasesAmount,
    required this.unpaidBalance,
    required this.createdAt,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      totalPurchasesCount: (json['total_purchases_count'] as num?)?.toInt() ?? 0,
      totalPurchasesAmount:
          double.tryParse(json['total_purchases_amount']?.toString() ?? '0') ?? 0.0,
      unpaidBalance:
          double.tryParse(json['unpaid_balance']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  double get totalPurchased => totalPurchasesAmount;
  double get totalPaid => (totalPurchasesAmount - unpaidBalance).clamp(0.0, double.infinity);
  double get outstandingBalance => unpaidBalance;
}
