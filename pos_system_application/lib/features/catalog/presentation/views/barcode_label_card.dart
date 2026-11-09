import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/hardware/barcode/barcode_widget.dart';
import '../../domain/models/barcode_label_template.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_variant.dart';

/// Renders a single WYSIWYG barcode label or shelf edge tag matching the configured template.
class BarcodeLabelCard extends StatelessWidget {
  final ProductModel product;
  final ProductVariantModel? variant;
  final BarcodeLabelConfig config;
  final String storeName;
  final double scale;

  const BarcodeLabelCard({
    super.key,
    required this.product,
    this.variant,
    required this.config,
    this.storeName = 'Retail POS Terminal',
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final activeVariant = variant ?? product.primaryVariant;
    final price = activeVariant?.sellingPrice ?? 0.0;
    final barcodeData =
        (activeVariant?.barcode != null && activeVariant!.barcode!.isNotEmpty)
            ? activeVariant.barcode!
            : (product.sku.isNotEmpty
                ? product.sku
                : 'PROD-${product.id.substring(0, 6)}');

    Widget content;
    switch (config.templateType) {
      case LabelTemplateType.compactSticker:
        content = _buildCompactSticker(barcodeData, price, currencyFmt);
        break;
      case LabelTemplateType.promotional:
        content = _buildPromotionalTag(barcodeData, price, currencyFmt);
        break;
      case LabelTemplateType.a4Sheet24:
      case LabelTemplateType.a4Sheet40:
      case LabelTemplateType.shelfEdge:
        content = _buildShelfEdgeTag(barcodeData, price, currencyFmt);
        break;
    }

    if (scale == 1.0) return content;
    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: content,
    );
  }

  /// 60mm x 40mm Retail Shelf Edge Tag
  Widget _buildShelfEdgeTag(
      String barcodeData, double price, NumberFormat currencyFmt) {
    return Container(
      width: 260,
      height: 165,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black87, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Store Name / Header
          if (config.showStoreName) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    config.customStoreHeader ?? storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
                if (product.categoryName != null && config.showCategory)
                  Text(
                    product.categoryName!,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const Divider(height: 6, thickness: 0.8),
          ],

          // Product Name & Variant
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              height: 1.15,
              color: Colors.black87,
            ),
          ),
          if (variant != null &&
              variant!.name.isNotEmpty &&
              variant!.name != 'Standard')
            Text(
              'Variant: ${variant!.name}',
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700),
            ),

          // Price Row (Large and prominent)
          if (config.showPrice)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (config.showSku)
                  Expanded(
                    child: Text(
                      'SKU: ${product.sku}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                Text(
                  currencyFmt.format(price),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),

          // Barcode Widget
          if (config.showBarcode)
            PosBarcodeWidget(
              data: barcodeData,
              height: 38,
              showText: config.showBarcodeText,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  /// 40mm x 25mm Compact Item / Jewelry / Package Sticker
  Widget _buildCompactSticker(
      String barcodeData, double price, NumberFormat currencyFmt) {
    return Container(
      width: 190,
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black87, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
              if (config.showPrice)
                Text(
                  currencyFmt.format(price),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F766E)),
                ),
            ],
          ),
          if (config.showBarcode)
            PosBarcodeWidget(
              data: barcodeData,
              height: 32,
              showText: config.showBarcodeText,
              textStyle: const TextStyle(
                  fontFamily: 'monospace', fontSize: 8.5, letterSpacing: 0.8),
            ),
          if (config.showSku)
            Center(
              child: Text(
                'SKU: ${product.sku}',
                style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }

  /// 70mm x 45mm High-Impact Promotional Shelf Talker
  Widget _buildPromotionalTag(
      String barcodeData, double price, NumberFormat currencyFmt) {
    final discount =
        config.promoDiscountPercent > 0 ? config.promoDiscountPercent : 15.0;
    final discountedPrice = price * (1.0 - (discount / 100.0));

    return Container(
      width: 290,
      height: 185,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE11D48), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Red Header Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: const Color(0xFFE11D48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    '★ SPECIAL OFFER / প্রচার মূল্য ★',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3)),
                  child: Text(
                    '-${discount.toStringAsFixed(0)}% OFF',
                    style: const TextStyle(
                        color: Color(0xFFE11D48),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

                // Pricing Box
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Regular Price',
                              style:
                                  TextStyle(fontSize: 8.5, color: Colors.grey)),
                          Text(
                            currencyFmt.format(price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('OFFER PRICE',
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE11D48))),
                        Text(
                          currencyFmt.format(discountedPrice),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Barcode
                if (config.showBarcode)
                  PosBarcodeWidget(
                    data: barcodeData,
                    height: 38,
                    showText: config.showBarcodeText,
                    textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        letterSpacing: 1.0),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
