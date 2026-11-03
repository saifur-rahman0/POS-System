import 'product.dart';

class PaginatedProducts {
  final List<ProductModel> items;
  final int total;
  final int page;
  final int limit;
  final int pages;

  const PaginatedProducts({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  factory PaginatedProducts.fromJson(Map<String, dynamic> json) {
    return PaginatedProducts(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      pages: json['pages'] as int? ?? 1,
    );
  }
}
