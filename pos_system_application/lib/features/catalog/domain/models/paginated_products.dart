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

  factory PaginatedProducts.fromJson(Map<dynamic, dynamic> json) {
    return PaginatedProducts(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => ProductModel.fromJson(item as Map<dynamic, dynamic>))
              .toList() ??
          [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}
