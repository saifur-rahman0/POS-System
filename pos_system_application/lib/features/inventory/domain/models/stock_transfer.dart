class StockTransferItemModel {
  final String id;
  final String transferId;
  final String productVariantId;
  final String? productName;
  final String? variantName;
  final String? sku;
  final double quantity;
  final double unitCost;

  const StockTransferItemModel({
    required this.id,
    required this.transferId,
    required this.productVariantId,
    this.productName,
    this.variantName,
    this.sku,
    required this.quantity,
    this.unitCost = 0.0,
  });

  factory StockTransferItemModel.fromJson(Map<String, dynamic> json) {
    return StockTransferItemModel(
      id: json['id'] as String,
      transferId: json['transfer_id'] as String,
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String?,
      variantName: json['variant_name'] as String?,
      sku: json['sku'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_variant_id': productVariantId,
      'quantity': quantity,
    };
  }
}

class StockTransferModel {
  final String id;
  final String businessId;
  final String transferNo;
  final String sourceBranchId;
  final String? sourceBranchName;
  final String destinationBranchId;
  final String? destinationBranchName;
  final String status; // DRAFT, IN_TRANSIT, RECEIVED, CANCELLED
  final String createdBy;
  final String? receivedBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? receivedAt;
  final int totalItemsCount;
  final double totalQuantity;
  final List<StockTransferItemModel> items;

  const StockTransferModel({
    required this.id,
    required this.businessId,
    required this.transferNo,
    required this.sourceBranchId,
    this.sourceBranchName,
    required this.destinationBranchId,
    this.destinationBranchName,
    required this.status,
    required this.createdBy,
    this.receivedBy,
    this.notes,
    required this.createdAt,
    this.sentAt,
    this.receivedAt,
    this.totalItemsCount = 0,
    this.totalQuantity = 0.0,
    this.items = const [],
  });

  factory StockTransferModel.fromJson(Map<String, dynamic> json) {
    return StockTransferModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      transferNo: json['transfer_no'] as String,
      sourceBranchId: json['source_branch_id'] as String,
      sourceBranchName: json['source_branch_name'] as String?,
      destinationBranchId: json['destination_branch_id'] as String,
      destinationBranchName: json['destination_branch_name'] as String?,
      status: json['status'] as String,
      createdBy: json['created_by'] as String,
      receivedBy: json['received_by'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      receivedAt: json['received_at'] != null
          ? DateTime.parse(json['received_at'] as String)
          : null,
      totalItemsCount: (json['total_items_count'] as num?)?.toInt() ?? 0,
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0.0,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((i) =>
                  StockTransferItemModel.fromJson(i as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }
}

class CrossBranchStockItemModel {
  final String branchId;
  final String branchName;
  final String? branchCode;
  final double quantityOnHand;
  final bool isActive;

  const CrossBranchStockItemModel({
    required this.branchId,
    required this.branchName,
    this.branchCode,
    required this.quantityOnHand,
    required this.isActive,
  });

  factory CrossBranchStockItemModel.fromJson(Map<String, dynamic> json) {
    return CrossBranchStockItemModel(
      branchId: json['branch_id'] as String,
      branchName: json['branch_name'] as String,
      branchCode: json['branch_code'] as String?,
      quantityOnHand: (json['quantity_on_hand'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

