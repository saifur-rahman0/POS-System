import 'dart:math';
import '../../../../core/hardware/barcode/ean13_encoder.dart';
import '../models/category.dart';

/// Available SKU generation rule strategies
enum SkuRuleType {
  /// Category Code + Product Initials/Size + 3-Digit Random/Sequence (e.g. BEV-MC250-101)
  categoryInitialsNumber,

  /// Category Code + Clean Name Slug + 3-Digit Sequence (e.g. BEV-MOJO-COLA-101)
  categorySlugNumber,

  /// Standard Prefix + 6-Digit Number (e.g. SKU-104921)
  prefixNumber,
}

/// Available Barcode generation rule strategies
enum BarcodeRuleType {
  /// GS1 In-Store 13-digit EAN-13 with '200' prefix + Modulo 10 Check Digit (e.g. 2001234567897)
  ean13InStore,

  /// Code 128 / UPC Numeric 12-Digit (e.g. 890123456789)
  code128Numeric,

  /// Code 128 Barcode that strictly matches the SKU string
  skuMatch,
}

/// Service that automates the generation of standardized SKUs and Barcodes
/// based on Category, Product Name, and retail industry rules.
class CatalogCodeGenerator {
  static final Random _random = Random();

  /// Generates a standardized SKU according to the chosen [rule].
  /// Returns an empty string if [productName] is empty and no custom prefix is given.
  static String generateSku({
    required String productName,
    CategoryModel? category,
    SkuRuleType rule = SkuRuleType.categoryInitialsNumber,
    String? customPrefix,
    int? sequenceNumber,
  }) {
    final cleanName = productName.trim();
    if (cleanName.isEmpty &&
        (customPrefix == null || customPrefix.trim().isEmpty)) {
      return '';
    }

    final catPrefix = _resolveCategoryPrefix(category, customPrefix);
    final suffixNum = sequenceNumber != null
        ? sequenceNumber.toString().padLeft(3, '0')
        : (_random.nextInt(900) + 100).toString(); // 3-digit random: 100..999

    switch (rule) {
      case SkuRuleType.categoryInitialsNumber:
        final initials = _extractInitials(cleanName);
        if (initials.isEmpty) {
          return '$catPrefix-$suffixNum';
        }
        return '$catPrefix-$initials-$suffixNum';

      case SkuRuleType.categorySlugNumber:
        final slug = _extractSlug(cleanName, maxLength: 10);
        if (slug.isEmpty) {
          return '$catPrefix-$suffixNum';
        }
        return '$catPrefix-$slug-$suffixNum';

      case SkuRuleType.prefixNumber:
        final p = (customPrefix != null && customPrefix.trim().isNotEmpty)
            ? customPrefix.trim().toUpperCase()
            : 'SKU';
        final seq = sequenceNumber != null
            ? sequenceNumber.toString().padLeft(6, '0')
            : (_random.nextInt(900000) + 100000).toString();
        return '$p-$seq';
    }
  }

  /// Generates a scannable Barcode according to the chosen [rule].
  static String generateBarcode({
    BarcodeRuleType rule = BarcodeRuleType.ean13InStore,
    String? sku,
    String? inStorePrefix = '200',
  }) {
    switch (rule) {
      case BarcodeRuleType.ean13InStore:
        // GS1 restricted circulation prefix for in-store items is 200..299
        final prefix = (inStorePrefix != null && inStorePrefix.length == 3)
            ? inStorePrefix
            : '200';
        // Generate 9 random digits to form 12 base digits
        final randPart = (_random.nextInt(900000000) + 100000000).toString();
        final base12 = '$prefix$randPart';
        final checkDigit = Ean13Encoder.calculateCheckDigit(base12);
        return '$base12$checkDigit';

      case BarcodeRuleType.code128Numeric:
        // 12-digit numeric UPC/EAN format
        const prefix = '890'; // Common retail prefix
        final randPart = (_random.nextInt(900000000) + 100000000).toString();
        return '$prefix$randPart';

      case BarcodeRuleType.skuMatch:
        if (sku != null && sku.trim().isNotEmpty) {
          return sku
              .trim()
              .toUpperCase()
              .replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
        }
        // Fallback to numeric if SKU is missing
        return (_random.nextInt(900000000) + 100000000).toString();
    }
  }

  /// Validates whether a barcode string is a valid GS1 EAN-13 code with matching checksum.
  static bool isValidEan13(String barcode) {
    final clean = barcode.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length != 13) return false;
    final expectedCheck =
        Ean13Encoder.calculateCheckDigit(clean.substring(0, 12));
    final actualCheck = int.tryParse(clean[12]);
    return expectedCheck == actualCheck;
  }

  static const Map<String, String> _knownCategoryCodes = {
    'BEVERAGES': 'BEV',
    'BEVERAGE': 'BEV',
    'ELECTRONICS': 'ELEC',
    'ELECTRONIC': 'ELEC',
    'APPAREL': 'APP',
    'FASHION': 'APP',
    'PERSONAL CARE': 'PC',
    'DAIRY': 'DAIRY',
    'BAKERY': 'BAK',
    'SNACKS': 'SNK',
    'CONFECTIONERY': 'CONF',
    'GROCERY': 'GROC',
    'HOUSEHOLD': 'HOUSE',
    'CLEANING': 'CLEAN',
    'PHARMACY': 'PHARM',
    'MEDICINE': 'MED',
    'STATIONERY': 'STAT',
    'COSMETICS': 'COSM',
  };

  /// Extracts category prefix:
  /// 1. category.code (if set)
  /// 2. Known category mapping
  /// 3. First 3-4 alphanumeric letters of category.name
  /// 4. Fallback to 'GEN'
  static String _resolveCategoryPrefix(
      CategoryModel? category, String? customPrefix) {
    if (customPrefix != null && customPrefix.trim().isNotEmpty) {
      return customPrefix
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    }

    if (category == null) {
      return 'GEN';
    }

    if (category.code != null && category.code!.trim().isNotEmpty) {
      final code = category.code!
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (code.isNotEmpty) return code;
    }

    final rawName = category.name.trim().toUpperCase();
    if (_knownCategoryCodes.containsKey(rawName)) {
      return _knownCategoryCodes[rawName]!;
    }

    final catName = rawName.replaceAll(RegExp(r'[^A-Z0-9\s]'), '');
    final words =
        catName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) return 'GEN';

    // Check if first word is known (e.g. "Beverages & Drinks" -> "BEV")
    if (_knownCategoryCodes.containsKey(words.first)) {
      return _knownCategoryCodes[words.first]!;
    }

    if (words.length == 1) {
      return words.first.length >= 3
          ? words.first.substring(0, min(4, words.first.length))
          : words.first;
    } else {
      // e.g. "Dairy & Bakery" -> "DB" or "DAIRY" -> take first word if >= 3, or initials
      final first = words.first;
      if (first.length >= 3 && first.length <= 4) {
        return first;
      }
      final initials = words.map((w) => w[0]).take(4).join();
      return initials.isNotEmpty ? initials : 'CAT';
    }
  }

  /// Extracts product initials and embedded numbers:
  /// e.g. "Mojo Cola 250ml" -> "MC250"
  /// e.g. "Wireless Ergonomic Mouse" -> "WEM"
  /// e.g. "KitKat" -> "KITKAT"
  static String _extractInitials(String productName) {
    final clean =
        productName.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s]'), '');
    final words =
        clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) return '';

    if (words.length == 1) {
      final word = words.first;
      return word.length <= 6 ? word : word.substring(0, 5);
    }

    final buffer = StringBuffer();
    String? sizePart;

    for (final w in words) {
      // Check if word contains numbers (e.g. 250ML, 400G, 1L, 4F)
      final numMatch = RegExp(r'\d+').firstMatch(w);
      if (numMatch != null && sizePart == null) {
        sizePart = numMatch.group(0);
      } else if (w.isNotEmpty) {
        buffer.write(w[0]);
      }
    }

    var result = buffer.toString();
    if (result.length > 4) {
      result = result.substring(0, 4);
    }

    if (sizePart != null && sizePart.isNotEmpty) {
      result = '$result$sizePart';
    }

    return result;
  }

  /// Extracts clean uppercase slug:
  /// e.g. "Wireless Mouse" -> "WIRELESS-M"
  static String _extractSlug(String productName, {int maxLength = 10}) {
    final clean =
        productName.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s]'), '');
    final words =
        clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) return '';

    final slug = words.join('-');
    if (slug.length <= maxLength) {
      return slug;
    }
    return slug.substring(0, maxLength).replaceAll(RegExp(r'\-+$'), '');
  }
}
