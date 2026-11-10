import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/features/catalog/domain/models/category.dart';
import 'package:pos_client/features/catalog/domain/services/catalog_code_generator.dart';

void main() {
  group('CatalogCodeGenerator SKU Tests', () {
    const electronicsCat = CategoryModel(
      id: 'cat-1',
      businessId: 'biz-1',
      name: 'Electronics',
      code: 'ELEC',
      isActive: true,
    );

    const beveragesCat = CategoryModel(
      id: 'cat-2',
      businessId: 'biz-1',
      name: 'Beverages',
      isActive: true,
    );

    test('Returns empty string when product name is empty', () {
      final sku = CatalogCodeGenerator.generateSku(
        productName: '',
        category: electronicsCat,
      );
      expect(sku, isEmpty);
    });

    test('Generates categoryInitialsNumber SKU with category code and sequence',
        () {
      final sku = CatalogCodeGenerator.generateSku(
        productName: 'Wireless Ergonomic Mouse',
        category: electronicsCat,
        rule: SkuRuleType.categoryInitialsNumber,
        sequenceNumber: 101,
      );

      // Category code ELEC, initials WEM, sequence 101
      expect(sku, equals('ELEC-WEM-101'));
    });

    test('Extracts embedded quantity/volume in initials', () {
      final sku = CatalogCodeGenerator.generateSku(
        productName: 'Mojo Cola 250ml',
        category: beveragesCat,
        rule: SkuRuleType.categoryInitialsNumber,
        sequenceNumber: 42,
      );

      // Category BEVERAGES (known code BEV), initials MC250, sequence 042
      expect(sku, startsWith('BEV-MC250-042'));
    });

    test('Falls back to GEN prefix when category is null', () {
      final sku = CatalogCodeGenerator.generateSku(
        productName: 'Universal Power Adapter',
        category: null,
        sequenceNumber: 5,
      );

      expect(sku, equals('GEN-UPA-005'));
    });

    test('Generates categorySlugNumber SKU', () {
      final sku = CatalogCodeGenerator.generateSku(
        productName: 'Organic Green Tea',
        category: beveragesCat,
        rule: SkuRuleType.categorySlugNumber,
        sequenceNumber: 12,
      );

      expect(sku, startsWith('BEV-ORGANIC-GR-012'));
    });

    test('Generates prefixNumber SKU', () {
      final sku = CatalogCodeGenerator.generateSku(
        productName: 'Any Product',
        customPrefix: 'ITEM',
        rule: SkuRuleType.prefixNumber,
        sequenceNumber: 789,
      );

      expect(sku, equals('ITEM-000789'));
    });

    test('Generates random 3-digit number when sequence is omitted', () {
      final sku = CatalogCodeGenerator.generateSku(
        productName: 'Dettol Soap',
        category: null,
      );

      expect(sku, matches(RegExp(r'^GEN-DS-\d{3}$')));
    });
  });

  group('CatalogCodeGenerator Barcode Tests', () {
    test('Generates valid 13-digit GS1 EAN-13 in-store barcode with checksum',
        () {
      final barcode = CatalogCodeGenerator.generateBarcode(
        rule: BarcodeRuleType.ean13InStore,
      );

      expect(barcode.length, equals(13));
      expect(barcode.startsWith('200'), isTrue);
      // Validates mathematical Modulo 10 check digit
      expect(CatalogCodeGenerator.isValidEan13(barcode), isTrue);
    });

    test('Generates 12-digit numeric Code 128 barcode', () {
      final barcode = CatalogCodeGenerator.generateBarcode(
        rule: BarcodeRuleType.code128Numeric,
      );

      expect(barcode.length, equals(12));
      expect(barcode, matches(RegExp(r'^\d{12}$')));
    });

    test('Generates SKU-match barcode', () {
      final barcode = CatalogCodeGenerator.generateBarcode(
        rule: BarcodeRuleType.skuMatch,
        sku: 'ELEC-WEM-101',
      );

      expect(barcode, equals('ELEC-WEM-101'));
    });

    test('isValidEan13 correctly distinguishes valid and invalid checksums',
        () {
      // Known valid EAN-13: 8901030383458
      expect(CatalogCodeGenerator.isValidEan13('8901030383458'), isTrue);
      // Tampered last digit: 8901030383459
      expect(CatalogCodeGenerator.isValidEan13('8901030383459'), isFalse);
      // Invalid length
      expect(CatalogCodeGenerator.isValidEan13('12345'), isFalse);
    });
  });
}
