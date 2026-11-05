class DamagedStockModel {
  final String id;
  final String businessId;
  final String branchId;
  final String productVariantId;
  final String? productName;
  final String? variantName;
  final String? batchId;
  final String? batchNumber;
  final String voucherNo;
  final double quantity;
  final double unitCost;
  final double totalLoss;
  final String reason;
  final String disposalMethod;
  final String? notes;
  final String reportedBy;
  final String? reporterName;
  final DateTime createdAt;

  const DamagedStockModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.productVariantId,
    this.productName,
    this.variantName,
    this.batchId,
    this.batchNumber,
    required this.voucherNo,
    required this.quantity,
    required this.unitCost,
    required this.totalLoss,
    required this.reason,
    required this.disposalMethod,
    this.notes,
    required this.reportedBy,
    this.reporterName,
    required this.createdAt,
  });

  factory DamagedStockModel.fromJson(Map<String, dynamic> json) {
    return DamagedStockModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String?,
      variantName: json['variant_name'] as String?,
      batchId: json['batch_id'] as String?,
      batchNumber: json['batch_number'] as String?,
      voucherNo: json['voucher_no'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      totalLoss: (json['total_loss'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? 'OTHER',
      disposalMethod: json['disposal_method'] as String? ?? 'WRITTEN_OFF',
      notes: json['notes'] as String?,
      reportedBy: json['reported_by'] as String,
      reporterName: json['reporter_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

