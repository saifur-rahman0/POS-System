class CategoryModel {
  final String id;
  final String businessId;
  final String name;
  final String? code;
  final String? parentId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CategoryModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.code,
    this.parentId,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      parentId: json['parent_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      if (code != null) 'code': code,
      if (parentId != null) 'parent_id': parentId,
      'is_active': isActive,
    };
  }
}
