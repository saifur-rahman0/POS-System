class QuotationItemModel {
  final String id;
  final String productVariantId;
  final String productName;
  final String sku;
  final double quantity;
  final double unitPrice;
  final double discount;
  final String discountType;
  final double lineTotal;

  const QuotationItemModel({
    required this.id,
    required this.productVariantId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    this.discountType = 'FIXED',
    required this.lineTotal,
  });

  factory QuotationItemModel.fromJson(Map<String, dynamic> json) {
    return QuotationItemModel(
      id: json['id'].toString(),
      productVariantId: json['product_variant_id'].toString(),
      productName: (json['product_name'] ?? 'Item').toString(),
      sku: (json['sku'] ?? '').toString(),
      quantity: double.tryParse((json['quantity'] ?? 0).toString()) ?? 0.0,
      unitPrice: double.tryParse((json['unit_price'] ?? 0).toString()) ?? 0.0,
      discount: double.tryParse((json['discount'] ?? 0).toString()) ?? 0.0,
      discountType: (json['discount_type'] ?? 'FIXED').toString(),
      lineTotal: double.tryParse((json['line_total'] ?? 0).toString()) ?? 0.0,
    );
  }
}

class QuotationModel {
  final String id;
  final String businessId;
  final String branchId;
  final String quotationNo;
  final String? customerId;
  final String? customerName;
  final String status;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double deliveryCharge;
  final double grandTotal;
  final DateTime? validUntil;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final String? convertedSaleId;
  final List<QuotationItemModel> items;

  String get quotationNumber => quotationNo;
  bool get isExpired => validUntil != null && validUntil!.isBefore(DateTime.now());
  double get discountedSubtotal => (subtotal - discountTotal).clamp(0.0, subtotal);

  const QuotationModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.quotationNo,
    this.customerId,
    this.customerName,
    required this.status,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.deliveryCharge,
    required this.grandTotal,
    this.validUntil,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    this.convertedSaleId,
    this.items = const [],
  });

  factory QuotationModel.fromJson(Map<String, dynamic> json) {
    List<QuotationItemModel> parsedItems = [];
    final rawItems = json['items'];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((i) => i is Map ? QuotationItemModel.fromJson(Map<String, dynamic>.from(i)) : null)
          .whereType<QuotationItemModel>()
          .toList();
    }

    return QuotationModel(
      id: json['id'].toString(),
      businessId: json['business_id'].toString(),
      branchId: json['branch_id'].toString(),
      quotationNo: json['quotation_no'].toString(),
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString(),
      status: (json['status'] ?? 'DRAFT').toString(),
      subtotal: double.tryParse((json['subtotal'] ?? 0).toString()) ?? 0.0,
      discountTotal: double.tryParse((json['discount_total'] ?? 0).toString()) ?? 0.0,
      taxTotal: double.tryParse((json['tax_total'] ?? 0).toString()) ?? 0.0,
      deliveryCharge: double.tryParse((json['delivery_charge'] ?? 0).toString()) ?? 0.0,
      grandTotal: double.tryParse((json['grand_total'] ?? 0).toString()) ?? 0.0,
      validUntil: json['valid_until'] != null ? DateTime.tryParse(json['valid_until'].toString()) : null,
      notes: json['notes']?.toString(),
      createdBy: json['created_by'].toString(),
      createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      convertedSaleId: json['converted_sale_id']?.toString(),
      items: parsedItems,
    );
  }
}

