class TopProductModel {
  final String productVariantId;
  final String productName;
  final String variantName;
  final String sku;
  final double unitsSold;
  final double grossRevenue;
  final double cogs;
  final double profit;
  final double marginPct;

  const TopProductModel({
    required this.productVariantId,
    required this.productName,
    required this.variantName,
    required this.sku,
    required this.unitsSold,
    required this.grossRevenue,
    required this.cogs,
    required this.profit,
    required this.marginPct,
  });

  factory TopProductModel.fromJson(Map<String, dynamic> json) {
    return TopProductModel(
      productVariantId: json['product_variant_id'] as String,
      productName: json['product_name'] as String? ?? '',
      variantName: json['variant_name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      unitsSold: (num.parse(json['units_sold'].toString())).toDouble(),
      grossRevenue: (num.parse(json['gross_revenue'].toString())).toDouble(),
      cogs: (num.parse(json['cogs'].toString())).toDouble(),
      profit: (num.parse(json['profit'].toString())).toDouble(),
      marginPct: (num.parse(json['margin_pct'].toString())).toDouble(),
    );
  }
}

class TopProductsModel {
  final List<TopProductModel> items;

  const TopProductsModel({required this.items});

  factory TopProductsModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['items'] as List<dynamic>? ?? [];
    return TopProductsModel(
      items: rawList
          .map((i) => TopProductModel.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

