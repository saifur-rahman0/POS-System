import 'purchase_order.dart';

class PaginatedPurchasesModel {
  final List<PurchaseOrderModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedPurchasesModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedPurchasesModel.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return PaginatedPurchasesModel(
      items: list
          .map((item) => PurchaseOrderModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}

