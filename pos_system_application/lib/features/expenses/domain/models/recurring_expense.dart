class RecurringExpenseModel {
  final String id;
  final String businessId;
  final String? branchId;
  final String categoryId;
  final String? paymentAccountId;
  final String title;
  final double amount;
  final String frequency; // DAILY, WEEKLY, MONTHLY, QUARTERLY, ANNUAL
  final DateTime nextDueDate;
  final DateTime? lastGeneratedAt;
  final bool autoPost;
  final bool isActive;
  final DateTime createdAt;
  final String? categoryName;
  final String? paymentAccountName;

  RecurringExpenseModel({
    required this.id,
    required this.businessId,
    this.branchId,
    required this.categoryId,
    this.paymentAccountId,
    required this.title,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    this.lastGeneratedAt,
    required this.autoPost,
    required this.isActive,
    required this.createdAt,
    this.categoryName,
    this.paymentAccountName,
  });

  factory RecurringExpenseModel.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String?,
      categoryId: json['category_id'] as String,
      paymentAccountId: json['payment_account_id'] as String?,
      title: json['title'] as String,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      frequency: json['frequency'] as String,
      nextDueDate: DateTime.parse(json['next_due_date'] as String),
      lastGeneratedAt: json['last_generated_at'] != null
          ? DateTime.parse(json['last_generated_at'] as String)
          : null,
      autoPost: json['auto_post'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      categoryName: json['category_name'] as String?,
      paymentAccountName: json['payment_account_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'branch_id': branchId,
      'category_id': categoryId,
      'payment_account_id': paymentAccountId,
      'title': title,
      'amount': amount,
      'frequency': frequency,
      'next_due_date': nextDueDate.toIso8601String().substring(0, 10),
      'last_generated_at': lastGeneratedAt?.toIso8601String(),
      'auto_post': autoPost,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'category_name': categoryName,
      'payment_account_name': paymentAccountName,
    };
  }

  bool get isDueTodayOrOverdue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.isBefore(today) || due.isAtSameMomentAs(today);
  }
}

