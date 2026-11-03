import 'customer.dart';

class PaginatedCustomersModel {
  final List<CustomerModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final double totalOutstandingDues;

  const PaginatedCustomersModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.totalOutstandingDues,
  });

  factory PaginatedCustomersModel.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return PaginatedCustomersModel(
      items: list.map((item) => CustomerModel.fromJson(item as Map<String, dynamic>)).toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
      totalOutstandingDues:
          double.tryParse(json['total_outstanding_dues']?.toString() ?? '0') ?? 0.0,
    );
  }
}
