class StockValuationItemModel {
  final String variantId;
  final String productName;
  final String variantName;
  final String sku;
  final String? barcode;
  final double quantityOnHand;
  final double costPrice;
  final double sellingPrice;
  final double stockCostValue;
  final double stockRetailValue;
  final bool isLowStock;
  final bool isOutOfStock;

  const StockValuationItemModel({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.sku,
    this.barcode,
    required this.quantityOnHand,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockCostValue,
    required this.stockRetailValue,
    required this.isLowStock,
    required this.isOutOfStock,
  });

  factory StockValuationItemModel.fromJson(Map<String, dynamic> json) {
    return StockValuationItemModel(
      variantId: json['variant_id'] as String,
      productName: json['product_name'] as String? ?? '',
      variantName: json['variant_name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      barcode: json['barcode'] as String?,
      quantityOnHand: (num.parse(json['quantity_on_hand'].toString())).toDouble(),
      costPrice: (num.parse(json['cost_price'].toString())).toDouble(),
      sellingPrice: (num.parse(json['selling_price'].toString())).toDouble(),
      stockCostValue: (num.parse(json['stock_cost_value'].toString())).toDouble(),
      stockRetailValue: (num.parse(json['stock_retail_value'].toString())).toDouble(),
      isLowStock: json['is_low_stock'] as bool? ?? false,
      isOutOfStock: json['is_out_of_stock'] as bool? ?? false,
    );
  }
}

class StockValuationModel {
  final int totalVariantsStocked;
  final double totalUnitsOnHand;
  final double totalCostValue;
  final double totalRetailValue;
  final double potentialGrossProfit;
  final int lowStockCount;
  final int outOfStockCount;
  final List<StockValuationItemModel> lowStockItems;

  const StockValuationModel({
    required this.totalVariantsStocked,
    required this.totalUnitsOnHand,
    required this.totalCostValue,
    required this.totalRetailValue,
    required this.potentialGrossProfit,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.lowStockItems,
  });

  factory StockValuationModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['low_stock_items'] as List<dynamic>? ?? [];
    return StockValuationModel(
      totalVariantsStocked: (json['total_variants_stocked'] as num?)?.toInt() ?? 0,
      totalUnitsOnHand: (num.parse(json['total_units_on_hand'].toString())).toDouble(),
      totalCostValue: (num.parse(json['total_cost_value'].toString())).toDouble(),
      totalRetailValue: (num.parse(json['total_retail_value'].toString())).toDouble(),
      potentialGrossProfit: (num.parse(json['potential_gross_profit'].toString())).toDouble(),
      lowStockCount: (json['low_stock_count'] as num?)?.toInt() ?? 0,
      outOfStockCount: (json['out_of_stock_count'] as num?)?.toInt() ?? 0,
      lowStockItems: rawList
          .map((i) => StockValuationItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

