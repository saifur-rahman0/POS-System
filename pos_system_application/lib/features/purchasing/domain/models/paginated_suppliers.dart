import 'supplier.dart';

class PaginatedSuppliersModel {
  final List<SupplierModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedSuppliersModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedSuppliersModel.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return PaginatedSuppliersModel(
      items: list.map((item) => SupplierModel.fromJson(item as Map<String, dynamic>)).toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}
