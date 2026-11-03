class StockMovementModel {
  final String id;
  final String businessId;
  final String branchId;
  final String productVariantId;
  final String? productName;
  final String? variantName;
  final String? sku;
  final String movementType;
  final double quantityDelta;
  final double unitCost;
  final String referenceType;
  final String referenceId;
  final String createdBy;
  final DateTime createdAt;

  const StockMovementModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.productVariantId,
    this.productName,
    this.variantName,
    this.sku,
    required this.movementType,
    required this.quantityDelta,
    required this.unitCost,
    required this.referenceType,
    required this.referenceId,
    required this.createdBy,
    required this.createdAt,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> json) {
    return StockMovementModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String?,
      variantName: json['variant_name'] as String?,
      sku: json['sku'] as String?,
      movementType: json['movement_type'] as String,
      quantityDelta:
          double.tryParse(json['quantity_delta']?.toString() ?? '0') ?? 0.0,
      unitCost: double.tryParse(json['unit_cost']?.toString() ?? '0') ?? 0.0,
      referenceType: json['reference_type'] as String,
      referenceId: json['reference_id'] as String,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PaginatedStockMovementsModel {
  final List<StockMovementModel> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedStockMovementsModel({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedStockMovementsModel.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return PaginatedStockMovementsModel(
      items: list
          .map((item) => StockMovementModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}
