import '../../../../core/utils/parsers.dart';

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
      quantityOnHand: parseDouble(json['quantity_on_hand']),
      activeReservations: parseDouble(json['active_reservations']),
      availableQuantity: parseDouble(json['available_quantity']),
      minStockLevel: parseDouble(json['min_stock_level']),
      suggestedReorderQty: parseDouble(json['suggested_reorder_qty']),
      estimatedUnitCost: parseDouble(json['estimated_unit_cost']),
      estimatedTotalCost: parseDouble(json['estimated_total_cost']),
      primarySupplierId: json['primary_supplier_id'] as String?,
      primarySupplierName: json['primary_supplier_name'] as String?,
    );
  }
}

