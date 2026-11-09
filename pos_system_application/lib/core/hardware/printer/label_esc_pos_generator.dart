import 'dart:convert';
import 'esc_pos_commands.dart';
import '../../../features/catalog/domain/models/barcode_label_template.dart';
import '../../../features/catalog/domain/models/product.dart';
import '../../../features/catalog/domain/models/product_variant.dart';

/// Generates raw hardware command byte streams for Thermal Label & Sticker Printers (ESC/POS & TSPL protocols).
class LabelEscPosGenerator {
  /// Generates ESC/POS thermal command bytes for a single product tag
  static List<int> generateEscPos({
    required ProductModel product,
    ProductVariantModel? variant,
    required BarcodeLabelConfig config,
    String storeName = 'Retail POS',
    int copies = 1,
  }) {
    final bytes = <int>[];
    final activeVariant = variant ?? product.primaryVariant;
    final price = activeVariant?.sellingPrice ?? 0.0;
    final barcodeData =
        (activeVariant?.barcode != null && activeVariant!.barcode!.isNotEmpty)
            ? activeVariant.barcode!
            : (product.sku.isNotEmpty
                ? product.sku
                : 'PROD-${product.id.substring(0, 6)}');

    for (int copy = 0; copy < copies; copy++) {
      // 1. Initialize
      bytes.addAll(EscPosCommands.initialize);

      // 2. Center Align
      bytes.addAll(EscPosCommands.alignCenter);

      // 3. Store Name Header
      if (config.showStoreName) {
        bytes.addAll(EscPosCommands.boldOn);
        bytes.addAll(utf8.encode('${config.customStoreHeader ?? storeName}\n'));
        bytes.addAll(EscPosCommands.boldOff);
      }

      // 4. Product Name
      bytes.addAll(EscPosCommands.boldOn);
      final cleanName = product.name.length > 28
          ? product.name.substring(0, 28)
          : product.name;
      bytes.addAll(utf8.encode('$cleanName\n'));
      bytes.addAll(EscPosCommands.boldOff);

      // 5. SKU & Category
      if (config.showSku) {
        bytes.addAll(utf8.encode('SKU: ${product.sku}\n'));
      }

      // 6. Price (Double Height & Double Width)
      if (config.showPrice) {
        bytes.addAll(EscPosCommands.textDoubleSize);
        bytes.addAll(EscPosCommands.boldOn);
        bytes.addAll(utf8.encode('BDT ${price.toStringAsFixed(2)}\n'));
        bytes.addAll(EscPosCommands.textNormal);
        bytes.addAll(EscPosCommands.boldOff);
      }

      // 7. 1D Barcode (GS k Code 128)
      if (config.showBarcode && barcodeData.isNotEmpty) {
        // Set Barcode Width (GS w 2)
        bytes.addAll([0x1D, 0x77, 0x02]);
        // Set Barcode Height (GS h 50)
        bytes.addAll([0x1D, 0x68, 0x32]);
        // Set Human Readable Text position below barcode (GS H 2)
        if (config.showBarcodeText) {
          bytes.addAll([0x1D, 0x48, 0x02]);
        } else {
          bytes.addAll([0x1D, 0x48, 0x00]);
        }
        // GS k 73 (Code 128) len data
        final dataBytes = utf8.encode(barcodeData);
        bytes.addAll([0x1D, 0x6B, 0x49, dataBytes.length]);
        bytes.addAll(dataBytes);
        bytes.addAll(EscPosCommands.lineFeed);
      }

      // 8. Feed and partial cut between stickers
      bytes.addAll(EscPosCommands.feedLines(2));
      bytes.addAll(EscPosCommands.cutPartial);
    }

    return bytes;
  }

  /// Generates TSPL command bytes (standard for thermal label printers like TSC, Zebra, Xprinter)
  static List<int> generateTspl({
    required ProductModel product,
    ProductVariantModel? variant,
    required BarcodeLabelConfig config,
    String storeName = 'Retail POS',
    int copies = 1,
  }) {
    final activeVariant = variant ?? product.primaryVariant;
    final price = activeVariant?.sellingPrice ?? 0.0;
    final barcodeData =
        (activeVariant?.barcode != null && activeVariant!.barcode!.isNotEmpty)
            ? activeVariant.barcode!
            : (product.sku.isNotEmpty
                ? product.sku
                : 'PROD-${product.id.substring(0, 6)}');

    final sb = StringBuffer();
    sb.writeln('SIZE 60 mm, 40 mm');
    sb.writeln('GAP 2 mm, 0 mm');
    sb.writeln('DIRECTION 1');
    sb.writeln('CLS');

    if (config.showStoreName) {
      sb.writeln(
          'TEXT 20, 15, "2", 0, 1, 1, "${config.customStoreHeader ?? storeName}"');
    }
    sb.writeln(
        'TEXT 20, 50, "3", 0, 1, 1, "${product.name.replaceAll('"', '')}"');
    if (config.showSku) {
      sb.writeln('TEXT 20, 95, "2", 0, 1, 1, "SKU: ${product.sku}"');
    }
    if (config.showPrice) {
      sb.writeln(
          'TEXT 20, 130, "4", 0, 1, 1, "BDT ${price.toStringAsFixed(2)}"');
    }
    if (config.showBarcode) {
      sb.writeln('BARCODE 20, 185, "128", 50, 1, 0, 2, 2, "$barcodeData"');
    }
    sb.writeln('PRINT $copies, 1');

    return utf8.encode(sb.toString());
  }
}
