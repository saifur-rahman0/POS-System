double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

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
      totalUnits: _toDouble(json['total_units']),
      fifoValuation: _toDouble(json['fifo_valuation']),
      wacValuation: _toDouble(json['wac_valuation']),
      retailValuation: _toDouble(json['retail_valuation']),
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
      totalQuantityOnHand: _toDouble(json['total_quantity_on_hand']),
      totalFifoValuation: _toDouble(json['total_fifo_valuation']),
      totalWacValuation: _toDouble(json['total_wac_valuation']),
      totalRetailValuation: _toDouble(json['total_retail_valuation']),
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => CategoryValuationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

