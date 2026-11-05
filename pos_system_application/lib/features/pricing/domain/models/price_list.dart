class PriceListItemModel {
  final String id;
  final String priceListId;
  final String productVariantId;
  final double minQuantity;
  final double price;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final String? variantName;
  final String? variantSku;

  const PriceListItemModel({
    required this.id,
    required this.priceListId,
    required this.productVariantId,
    required this.minQuantity,
    required this.price,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.createdAt,
    this.variantName,
    this.variantSku,
  });

  factory PriceListItemModel.fromJson(Map<String, dynamic> json) {
    return PriceListItemModel(
      id: json['id']?.toString() ?? '',
      priceListId: json['price_list_id']?.toString() ?? '',
      productVariantId: json['product_variant_id']?.toString() ?? '',
      minQuantity: _toDouble(json['min_quantity'], 1.0),
      price: _toDouble(json['price'], 0.0),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString())
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      variantName: json['variant_name']?.toString(),
      variantSku: json['variant_sku']?.toString(),
    );
  }

  static double _toDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  Map<String, dynamic> toJson() {
    return {
      'product_variant_id': productVariantId,
      'min_quantity': minQuantity,
      'price': price,
      if (startDate != null) 'start_date': startDate!.toIso8601String().substring(0, 10),
      if (endDate != null) 'end_date': endDate!.toIso8601String().substring(0, 10),
      'is_active': isActive,
    };
  }
}

class PriceListModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String currency;
  final bool isDefault;
  final bool isActive;
  final String? customerGroupId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PriceListItemModel> items;

  const PriceListModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.currency = 'BDT',
    required this.isDefault,
    required this.isActive,
    this.customerGroupId,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory PriceListModel.fromJson(Map<String, dynamic> json) {
    return PriceListModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      currency: json['currency']?.toString() ?? 'BDT',
      isDefault: json['is_default'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      customerGroupId: json['customer_group_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PriceListItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'currency': currency,
      'is_default': isDefault,
      'is_active': isActive,
      if (customerGroupId != null) 'customer_group_id': customerGroupId,
    };
  }
}

