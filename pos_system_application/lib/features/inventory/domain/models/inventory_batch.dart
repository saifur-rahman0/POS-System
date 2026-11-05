class InventoryBatchModel {
  final String id;
  final String businessId;
  final String branchId;
  final String productVariantId;
  final String? productName;
  final String? variantName;
  final String? sku;
  final String batchNumber;
  final DateTime? manufacturingDate;
  final DateTime? expiryDate;
  final double quantityReceived;
  final double quantityOnHand;
  final double costPrice;
  final String? supplierId;
  final String? supplierName;
  final bool isActive;
  final int? daysToExpiry;
  final String? expiryStatus;
  final DateTime createdAt;

  const InventoryBatchModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.productVariantId,
    this.productName,
    this.variantName,
    this.sku,
    required this.batchNumber,
    this.manufacturingDate,
    this.expiryDate,
    required this.quantityReceived,
    required this.quantityOnHand,
    required this.costPrice,
    this.supplierId,
    this.supplierName,
    required this.isActive,
    this.daysToExpiry,
    this.expiryStatus,
    required this.createdAt,
  });

  factory InventoryBatchModel.fromJson(Map<String, dynamic> json) {
    return InventoryBatchModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String?,
      variantName: json['variant_name'] as String?,
      sku: json['sku'] as String?,
      batchNumber: json['batch_number'] as String,
      manufacturingDate: json['manufacturing_date'] != null
          ? DateTime.parse(json['manufacturing_date'] as String)
          : null,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      quantityReceived: (json['quantity_received'] as num?)?.toDouble() ?? 0.0,
      quantityOnHand: (json['quantity_on_hand'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      supplierId: json['supplier_id'] as String?,
      supplierName: json['supplier_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      daysToExpiry: json['days_to_expiry'] as int?,
      expiryStatus: json['expiry_status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ExpiryAlertModel {
  final String batchId;
  final String batchNumber;
  final String productVariantId;
  final String productName;
  final String variantName;
  final String branchId;
  final String? branchName;
  final double quantityOnHand;
  final DateTime expiryDate;
  final int daysRemaining;
  final String urgency;

  const ExpiryAlertModel({
    required this.batchId,
    required this.batchNumber,
    required this.productVariantId,
    required this.productName,
    required this.variantName,
    required this.branchId,
    this.branchName,
    required this.quantityOnHand,
    required this.expiryDate,
    required this.daysRemaining,
    required this.urgency,
  });

  factory ExpiryAlertModel.fromJson(Map<String, dynamic> json) {
    return ExpiryAlertModel(
      batchId: json['batch_id'] as String,
      batchNumber: json['batch_number'] as String,
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String? ?? 'Unknown Product',
      variantName: json['variant_name'] as String? ?? 'Standard',
      branchId: json['branch_id'] as String,
      branchName: json['branch_name'] as String?,
      quantityOnHand: (json['quantity_on_hand'] as num?)?.toDouble() ?? 0.0,
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      daysRemaining: json['days_remaining'] as int? ?? 0,
      urgency: json['urgency'] as String? ?? 'LOW_60_DAYS',
    );
  }
}

