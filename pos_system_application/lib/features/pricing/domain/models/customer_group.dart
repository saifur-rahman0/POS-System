class CustomerGroupModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final int memberCount;

  const CustomerGroupModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    required this.isActive,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory CustomerGroupModel.fromJson(Map<String, dynamic> json) {
    return CustomerGroupModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      memberCount: json['member_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'is_active': isActive,
    };
  }
}
