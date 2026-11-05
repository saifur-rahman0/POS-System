class CategoryValuationModel {
  final String? categoryId;
  final String categoryName;
  final int itemCount;
  final double totalUnits;
  final double fifoValuation;
  final double wacValuation;
  final double retailValuation;

  const CategoryValuationModel({
    this.categoryId,
    required this.categoryName,
    required this.itemCount,
    required this.totalUnits,
    required this.fifoValuation,
    required this.wacValuation,
    required this.retailValuation,
  });

  factory CategoryValuationModel.fromJson(Map<String, dynamic> json) {
    return CategoryValuationModel(
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String? ?? 'Uncategorized',
      itemCount: json['item_count'] as int? ?? 0,
      totalUnits: (json['total_units'] as num?)?.toDouble() ?? 0.0,
      fifoValuation: (json['fifo_valuation'] as num?)?.toDouble() ?? 0.0,
      wacValuation: (json['wac_valuation'] as num?)?.toDouble() ?? 0.0,
      retailValuation: (json['retail_valuation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class InventoryValuationReportModel {
  final String businessId;
  final String? branchId;
  final String? branchName;
  final DateTime asOfDate;
  final int totalVariants;
  final double totalQuantityOnHand;
  final double totalFifoValuation;
  final double totalWacValuation;
  final double totalRetailValuation;
  final List<CategoryValuationModel> categories;

  const InventoryValuationReportModel({
    required this.businessId,
    this.branchId,
    this.branchName,
    required this.asOfDate,
    required this.totalVariants,
    required this.totalQuantityOnHand,
    required this.totalFifoValuation,
    required this.totalWacValuation,
    required this.totalRetailValuation,
    required this.categories,
  });

  factory InventoryValuationReportModel.fromJson(Map<String, dynamic> json) {
    return InventoryValuationReportModel(
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String?,
      branchName: json['branch_name'] as String?,
      asOfDate: DateTime.parse(json['as_of_date'] as String),
      totalVariants: json['total_variants'] as int? ?? 0,
      totalQuantityOnHand: (json['total_quantity_on_hand'] as num?)?.toDouble() ?? 0.0,
      totalFifoValuation: (json['total_fifo_valuation'] as num?)?.toDouble() ?? 0.0,
      totalWacValuation: (json['total_wac_valuation'] as num?)?.toDouble() ?? 0.0,
      totalRetailValuation: (json['total_retail_valuation'] as num?)?.toDouble() ?? 0.0,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => CategoryValuationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

