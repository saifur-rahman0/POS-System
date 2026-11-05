class CustomerModel {
  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double creditLimit;
  final double dueBalance;
  final double availableCredit;
  final int totalSalesCount;
  final double totalSpent;
  final bool isActive;
  final int loyaltyPointsBalance;
  final double storeCreditBalance;
  final String? membershipTierId;
  final String? rfmSegment;
  final DateTime createdAt;

  const CustomerModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.creditLimit,
    required this.dueBalance,
    required this.availableCredit,
    required this.totalSalesCount,
    required this.totalSpent,
    required this.isActive,
    this.loyaltyPointsBalance = 0,
    this.storeCreditBalance = 0.0,
    this.membershipTierId,
    this.rfmSegment,
    required this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      creditLimit: double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0.0,
      dueBalance: double.tryParse(json['due_balance']?.toString() ?? '0') ?? 0.0,
      availableCredit: double.tryParse(json['available_credit']?.toString() ?? '0') ?? 0.0,
      totalSalesCount: (json['total_sales_count'] as num?)?.toInt() ?? 0,
      totalSpent: double.tryParse(json['total_spent']?.toString() ?? '0') ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      loyaltyPointsBalance: (json['loyalty_points_balance'] as num?)?.toInt() ?? 0,
      storeCreditBalance: double.tryParse(json['store_credit_balance']?.toString() ?? '0') ?? 0.0,
      membershipTierId: json['membership_tier_id'] as String?,
      rfmSegment: json['rfm_segment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'credit_limit': creditLimit,
      'due_balance': dueBalance,
      'available_credit': availableCredit,
      'total_sales_count': totalSalesCount,
      'total_spent': totalSpent,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

