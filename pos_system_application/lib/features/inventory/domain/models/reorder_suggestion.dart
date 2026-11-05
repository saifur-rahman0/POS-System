class ReorderSuggestionModel {
  final String productVariantId;
  final String productName;
  final String variantName;
  final String? sku;
  final String? barcode;
  final String branchId;
  final String? branchName;
  final double quantityOnHand;
  final double activeReservations;
  final double availableQuantity;
  final double minStockLevel;
  final double suggestedReorderQty;
  final double estimatedUnitCost;
  final double estimatedTotalCost;
  final String? primarySupplierId;
  final String? primarySupplierName;

  const ReorderSuggestionModel({
    required this.productVariantId,
    required this.productName,
    required this.variantName,
    this.sku,
    this.barcode,
    required this.branchId,
    this.branchName,
    required this.quantityOnHand,
    required this.activeReservations,
    required this.availableQuantity,
    required this.minStockLevel,
    required this.suggestedReorderQty,
    required this.estimatedUnitCost,
    required this.estimatedTotalCost,
    this.primarySupplierId,
    this.primarySupplierName,
  });

  factory ReorderSuggestionModel.fromJson(Map<String, dynamic> json) {
    return ReorderSuggestionModel(
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String? ?? 'Unknown Product',
      variantName: json['variant_name'] as String? ?? 'Standard',
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      branchId: json['branch_id'] as String,
      branchName: json['branch_name'] as String?,
      quantityOnHand: (json['quantity_on_hand'] as num?)?.toDouble() ?? 0.0,
      activeReservations: (json['active_reservations'] as num?)?.toDouble() ?? 0.0,
      availableQuantity: (json['available_quantity'] as num?)?.toDouble() ?? 0.0,
      minStockLevel: (json['min_stock_level'] as num?)?.toDouble() ?? 0.0,
      suggestedReorderQty: (json['suggested_reorder_qty'] as num?)?.toDouble() ?? 0.0,
      estimatedUnitCost: (json['estimated_unit_cost'] as num?)?.toDouble() ?? 0.0,
      estimatedTotalCost: (json['estimated_total_cost'] as num?)?.toDouble() ?? 0.0,
      primarySupplierId: json['primary_supplier_id'] as String?,
      primarySupplierName: json['primary_supplier_name'] as String?,
    );
  }
}

