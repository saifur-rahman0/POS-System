import 'register_shift.dart';

class PaginatedShiftsModel {
  final List<RegisterShiftModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedShiftsModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedShiftsModel.fromJson(Map<String, dynamic> json) {
    return PaginatedShiftsModel(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => RegisterShiftModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'total': total,
      'page': page,
      'page_size': pageSize,
      'total_pages': totalPages,
    };
  }
}

