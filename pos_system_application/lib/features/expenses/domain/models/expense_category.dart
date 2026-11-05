class ExpenseCategoryModel {
  final String id;
  final String businessId;
  final String name;
  final String code;
  final String? description;
  final double monthlyBudget;
  final double currentMonthSpent;
  final bool isActive;
  final DateTime createdAt;

  ExpenseCategoryModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.code,
    this.description,
    required this.monthlyBudget,
    this.currentMonthSpent = 0.0,
    required this.isActive,
    required this.createdAt,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      monthlyBudget: double.tryParse(json['monthly_budget']?.toString() ?? '0') ?? 0.0,
      currentMonthSpent: double.tryParse(json['current_month_spent']?.toString() ?? '0') ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'code': code,
      'description': description,
      'monthly_budget': monthlyBudget,
      'current_month_spent': currentMonthSpent,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  double get budgetUtilization => monthlyBudget > 0 ? (currentMonthSpent / monthlyBudget) : 0.0;
  bool get isOverBudget => monthlyBudget > 0 && currentMonthSpent > monthlyBudget;
}

