class StockAdjustmentModel {
  final String movementId;
  final String businessId;
  final String branchId;
  final String productVariantId;
  final String? productName;
  final String? variantName;
  final String adjustmentType; // ADJUSTMENT_UP, ADJUSTMENT_DOWN
  final double quantityAdjusted;
  final double previousQuantity;
  final double newQuantity;
  final String reason;
  final String? notes;
  final DateTime createdAt;

  const StockAdjustmentModel({
    required this.movementId,
    required this.businessId,
    required this.branchId,
    required this.productVariantId,
    this.productName,
    this.variantName,
    required this.adjustmentType,
    required this.quantityAdjusted,
    required this.previousQuantity,
    required this.newQuantity,
    required this.reason,
    this.notes,
    required this.createdAt,
  });

  factory StockAdjustmentModel.fromJson(Map<String, dynamic> json) {
    return StockAdjustmentModel(
      movementId: json['movement_id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String?,
      variantName: json['variant_name'] as String?,
      adjustmentType: json['adjustment_type'] as String,
      quantityAdjusted:
          double.tryParse(json['quantity_adjusted']?.toString() ?? '0') ?? 0.0,
      previousQuantity:
          double.tryParse(json['previous_quantity']?.toString() ?? '0') ?? 0.0,
      newQuantity: double.tryParse(json['new_quantity']?.toString() ?? '0') ?? 0.0,
      reason: json['reason'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
