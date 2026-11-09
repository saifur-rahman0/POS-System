enum LabelTemplateType {
  shelfEdge, // 60mm x 40mm
  compactSticker, // 40mm x 25mm
  promotional, // 70mm x 45mm
  a4Sheet24, // 3 x 8 = 24 labels on A4
  a4Sheet40, // 4 x 10 = 40 labels on A4
}

class BarcodeLabelConfig {
  final LabelTemplateType templateType;
  final bool showStoreName;
  final bool showPrice;
  final bool showSku;
  final bool showCategory;
  final bool showBarcode;
  final bool showBarcodeText;
  final String? customStoreHeader;
  final double promoDiscountPercent;
  final String? customNote;
  final int defaultCopies;

  const BarcodeLabelConfig({
    this.templateType = LabelTemplateType.shelfEdge,
    this.showStoreName = true,
    this.showPrice = true,
    this.showSku = true,
    this.showCategory = true,
    this.showBarcode = true,
    this.showBarcodeText = true,
    this.customStoreHeader,
    this.promoDiscountPercent = 0.0,
    this.customNote,
    this.defaultCopies = 1,
  });

  BarcodeLabelConfig copyWith({
    LabelTemplateType? templateType,
    bool? showStoreName,
    bool? showPrice,
    bool? showSku,
    bool? showCategory,
    bool? showBarcode,
    bool? showBarcodeText,
    String? customStoreHeader,
    double? promoDiscountPercent,
    String? customNote,
    int? defaultCopies,
  }) {
    return BarcodeLabelConfig(
      templateType: templateType ?? this.templateType,
      showStoreName: showStoreName ?? this.showStoreName,
      showPrice: showPrice ?? this.showPrice,
      showSku: showSku ?? this.showSku,
      showCategory: showCategory ?? this.showCategory,
      showBarcode: showBarcode ?? this.showBarcode,
      showBarcodeText: showBarcodeText ?? this.showBarcodeText,
      customStoreHeader: customStoreHeader ?? this.customStoreHeader,
      promoDiscountPercent: promoDiscountPercent ?? this.promoDiscountPercent,
      customNote: customNote ?? this.customNote,
      defaultCopies: defaultCopies ?? this.defaultCopies,
    );
  }
}
