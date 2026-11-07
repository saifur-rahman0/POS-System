import '../../../../core/utils/parsers.dart';

class StockReservationModel {
  final String id;
  final String businessId;
  final String branchId;
  final String productVariantId;
  final String? productName;
  final String? variantName;
  final String? batchId;
  final double quantity;
  final String referenceType;
  final String referenceId;
  final String status;
  final DateTime reservedUntil;
  final String createdBy;
  final DateTime createdAt;

  const StockReservationModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.productVariantId,
    this.productName,
    this.variantName,
    this.batchId,
    required this.quantity,
    required this.referenceType,
    required this.referenceId,
    required this.status,
    required this.reservedUntil,
    required this.createdBy,
    required this.createdAt,
  });

  factory StockReservationModel.fromJson(Map<String, dynamic> json) {
    return StockReservationModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String?,
      variantName: json['variant_name'] as String?,
      batchId: json['batch_id'] as String?,
      quantity: parseDouble(json['quantity']),
      referenceType: json['reference_type'] as String? ?? 'QUOTATION',
      referenceId: json['reference_id'] as String,
      status: json['status'] as String? ?? 'ACTIVE',
      reservedUntil: DateTime.parse(json['reserved_until'] as String),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AvailableStockModel {
  final String productVariantId;
  final String branchId;
  final double quantityOnHand;
  final double quantityReserved;
  final double availableQuantity;

  const AvailableStockModel({
    required this.productVariantId,
    required this.branchId,
    required this.quantityOnHand,
    required this.quantityReserved,
    required this.availableQuantity,
  });

  factory AvailableStockModel.fromJson(Map<String, dynamic> json) {
    return AvailableStockModel(
      productVariantId: json['product_variant_id'] as String,
      branchId: json['branch_id'] as String,
      quantityOnHand: parseDouble(json['quantity_on_hand']),
      quantityReserved: parseDouble(json['quantity_reserved']),
      availableQuantity: parseDouble(json['available_quantity']),
    );
  }
}

