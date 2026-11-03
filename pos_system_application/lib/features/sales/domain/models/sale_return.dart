class SaleReturnItemModel {
  final String id;
  final String returnId;
  final String originalSaleItemId;
  final String productVariantId;
  final String productName;
  final String sku;
  final double quantity;
  final double refundAmount;
  final String restockStatus;

  const SaleReturnItemModel({
    required this.id,
    required this.returnId,
    required this.originalSaleItemId,
    required this.productVariantId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.refundAmount,
    required this.restockStatus,
  });

  factory SaleReturnItemModel.fromJson(Map<dynamic, dynamic> json) {
    return SaleReturnItemModel(
      id: json['id']?.toString() ?? '',
      returnId: json['return_id']?.toString() ?? '',
      originalSaleItemId: json['original_sale_item_id']?.toString() ?? '',
      productVariantId: json['product_variant_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Product',
      sku: json['sku']?.toString() ?? '',
      quantity: _toDouble(json['quantity']),
      refundAmount: _toDouble(json['refund_amount']),
      restockStatus: json['restock_status']?.toString() ?? 'RESTOCKED',
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

class SaleReturnModel {
  final String id;
  final String businessId;
  final String branchId;
  final String originalSaleId;
  final String returnNo;
  final String status;
  final double refundTotal;
  final String? reason;
  final String createdBy;
  final DateTime createdAt;
  final List<SaleReturnItemModel> items;

  const SaleReturnModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.originalSaleId,
    required this.returnNo,
    required this.status,
    required this.refundTotal,
    this.reason,
    required this.createdBy,
    required this.createdAt,
    required this.items,
  });

  factory SaleReturnModel.fromJson(Map<dynamic, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return SaleReturnModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      originalSaleId: json['original_sale_id']?.toString() ?? '',
      returnNo: json['return_no']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      refundTotal: _toDouble(json['refund_total']),
      reason: json['reason']?.toString(),
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: rawItems
          .map((i) => SaleReturnItemModel.fromJson(i is Map ? i : {}))
          .toList(),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

