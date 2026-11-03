import 'sale_summary.dart';

class PaginatedSalesModel {
  final List<SaleSummaryModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedSalesModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedSalesModel.fromJson(Map<dynamic, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PaginatedSalesModel(
      items: rawItems
          .map((i) => SaleSummaryModel.fromJson(i is Map ? i : {}))
          .toList(),
      total: json['total'] is num ? (json['total'] as num).toInt() : 0,
      page: json['page'] is num ? (json['page'] as num).toInt() : 1,
      pageSize: json['page_size'] is num ? (json['page_size'] as num).toInt() : 20,
      totalPages: json['total_pages'] is num ? (json['total_pages'] as num).toInt() : 1,
    );
  }
}

