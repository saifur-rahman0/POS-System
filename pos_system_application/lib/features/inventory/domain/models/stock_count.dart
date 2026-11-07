import '../../../../core/utils/parsers.dart';

class StockCountLineModel {
  final String id;
  final String stockCountId;
  final String productVariantId;
  final String? productName;
  final String? variantName;
  final String? barcode;
  final double expectedQty;
  final double countedQty;
  final double variance;
  final String? discrepancyReason;

  const StockCountLineModel({
    required this.id,
    required this.stockCountId,
    required this.productVariantId,
    this.productName,
    this.variantName,
    this.barcode,
    required this.expectedQty,
    required this.countedQty,
    required this.variance,
    this.discrepancyReason,
  });

  factory StockCountLineModel.fromJson(Map<String, dynamic> json) {
    return StockCountLineModel(
      id: json['id'] as String,
      stockCountId: json['stock_count_id'] as String,
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String?,
      variantName: json['variant_name'] as String?,
      barcode: json['barcode'] as String?,
      expectedQty: parseDouble(json['expected_qty']),
      countedQty: parseDouble(json['counted_qty']),
      variance: parseDouble(json['variance']),
      discrepancyReason: json['discrepancy_reason'] as String?,
    );
  }
}

class StockCountModel {
  final String id;
  final String businessId;
  final String branchId;
  final String? branchName;
  final String status;
  final String? notes;
  final String createdBy;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<StockCountLineModel> lines;

  const StockCountModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    this.branchName,
    required this.status,
    this.notes,
    required this.createdBy,
    this.approvedBy,
    required this.createdAt,
    this.completedAt,
    required this.lines,
  });

  factory StockCountModel.fromJson(Map<String, dynamic> json) {
    return StockCountModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      branchId: json['branch_id'] as String,
      branchName: json['branch_name'] as String?,
      status: json['status'] as String? ?? 'DRAFT',
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String,
      approvedBy: json['approved_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      lines: (json['lines'] as List<dynamic>?)
              ?.map((e) => StockCountLineModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

