import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/core/hardware/barcode/barcode_widget.dart';
import 'package:pos_client/core/hardware/barcode/code128_encoder.dart';
import 'package:pos_client/core/hardware/barcode/ean13_encoder.dart';
import 'package:pos_client/core/hardware/printer/label_esc_pos_generator.dart';
import 'package:pos_client/features/catalog/domain/models/barcode_label_template.dart';
import 'package:pos_client/features/catalog/domain/models/product.dart';
import 'package:pos_client/features/catalog/domain/models/product_variant.dart';
import 'package:pos_client/features/catalog/presentation/views/barcode_label_card.dart';
import 'package:pos_client/features/catalog/presentation/views/barcode_print_dialog.dart';

void main() {
  group('Code 128 & EAN-13 Barcode Encoder Tests', () {
    test(
        'Code128Encoder encodes alphanumeric SKU to binary modules with checksum',
        () {
      const sku = 'BEV-MOJO-250';
      final modules = Code128Encoder.encode(sku);

      expect(modules, isNotEmpty);
      // Quiet zones (10 + 10) + (1 start + 12 chars + 1 check + 1 stop) * 11 + 2 extra on stop
      // Total modules should be > 100
      expect(modules.length, greaterThan(100));

      // Quiet zones at both ends are false (spaces)
      for (int i = 0; i < 10; i++) {
        expect(modules[i], isFalse);
      }
      for (int i = modules.length - 10; i < modules.length; i++) {
        expect(modules[i], isFalse);
      }
    });

    test('Ean13Encoder computes correct check digit and guards', () {
      // Test known GS1 12-digit: '890103038345' -> check digit 8
      final check = Ean13Encoder.calculateCheckDigit('890103038345');
      expect(check, 8);

      final modules = Ean13Encoder.encode('8901030383458');
      expect(modules, isNotNull);
      // Total modules: 9 left quiet + 3 start guard + 42 left digits + 5 center guard + 42 right digits + 3 end guard + 9 right quiet = 113 modules
      expect(modules!.length, 113);
    });

    test(
        'LabelEscPosGenerator generates valid ESC/POS byte sequence with barcode command',
        () {
      const prod = ProductModel(
        id: 'p1',
        businessId: 'b1',
        sku: 'SKU-COLA-250',
        name: 'Mojo Cola 250ml',
        productType: 'standard',
        taxRate: 0.0,
        hasVariants: false,
        isActive: true,
        primaryVariant: ProductVariantModel(
          id: 'v1',
          productId: 'p1',
          name: 'Standard',
          costPrice: 15.0,
          sellingPrice: 20.0,
          trackStock: true,
          isActive: true,
        ),
      );

      final bytes = LabelEscPosGenerator.generateEscPos(
        product: prod,
        config: const BarcodeLabelConfig(showBarcode: true, showPrice: true),
        storeName: 'Gulshan Branch',
        copies: 2,
      );

      expect(bytes, isNotEmpty);
      // Contains ESC @ (0x1B, 0x40)
      expect(bytes, containsAllInOrder([0x1B, 0x40]));
      // Contains GS k (0x1D, 0x6B, 0x49) for Code 128
      expect(bytes, containsAllInOrder([0x1D, 0x6B, 0x49]));
    });

    test('LabelEscPosGenerator generates TSPL string commands', () {
      const prod = ProductModel(
        id: 'p1',
        businessId: 'b1',
        sku: 'SKU-PRAN-FROOTO',
        name: 'Pran Frooto Mango 250ml',
        productType: 'standard',
        taxRate: 0.0,
        hasVariants: false,
        isActive: true,
        primaryVariant: ProductVariantModel(
          id: 'v1',
          productId: 'p1',
          name: 'Standard',
          costPrice: 22.0,
          sellingPrice: 30.0,
          trackStock: true,
          isActive: true,
        ),
      );

      final tsplBytes = LabelEscPosGenerator.generateTspl(
        product: prod,
        config: const BarcodeLabelConfig(),
        storeName: 'Gulshan Branch',
        copies: 3,
      );

      final tsplString = String.fromCharCodes(tsplBytes);
      expect(tsplString, contains('SIZE 60 mm, 40 mm'));
      expect(tsplString, contains('BARCODE 20, 185, "128"'));
      expect(tsplString, contains('PRINT 3, 1'));
    });
  });

  group('Barcode & Shelf Tag Widgets Tests', () {
    const testProduct = ProductModel(
      id: 'prod-001',
      businessId: 'biz-001',
      sku: 'APP-POLO-SHIRT',
      name: 'Premium Cotton Polo Shirt',
      productType: 'standard',
      taxRate: 5.0,
      hasVariants: false,
      isActive: true,
      categoryName: 'Apparel',
      primaryVariant: ProductVariantModel(
        id: 'var-001',
        productId: 'prod-001',
        sku: 'APP-POLO-SHIRT',
        barcode: '8901234567890',
        name: 'Large - Navy',
        costPrice: 350.0,
        sellingPrice: 550.0,
        trackStock: true,
        isActive: true,
      ),
    );

    testWidgets(
        'PosBarcodeWidget renders vector canvas and human readable barcode text',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PosBarcodeWidget(
                data: 'APP-POLO-SHIRT',
                height: 48,
                showText: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('APP-POLO-SHIRT'), findsOneWidget);
    });

    testWidgets(
        'BarcodeLabelCard renders Shelf Edge Tag template with store name and price',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BarcodeLabelCard(
              product: testProduct,
              config: BarcodeLabelConfig(
                templateType: LabelTemplateType.shelfEdge,
                showStoreName: true,
                showPrice: true,
                showSku: true,
              ),
              storeName: 'Dhaka Superstore',
            ),
          ),
        ),
      );

      expect(find.text('Dhaka Superstore'), findsOneWidget);
      expect(find.text('Premium Cotton Polo Shirt'), findsOneWidget);
      expect(find.text('৳ 550.00'), findsOneWidget);
      expect(find.text('SKU: APP-POLO-SHIRT'), findsOneWidget);
      expect(find.byType(PosBarcodeWidget), findsOneWidget);
    });

    testWidgets(
        'BarcodeLabelCard renders Promotional Offer Talker with discount badge',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BarcodeLabelCard(
              product: testProduct,
              config: BarcodeLabelConfig(
                templateType: LabelTemplateType.promotional,
                promoDiscountPercent: 20.0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('★ SPECIAL OFFER / প্রচার মূল্য ★'), findsOneWidget);
      expect(find.text('-20% OFF'), findsOneWidget);
      // Original price is 550, 20% off is 440
      expect(find.text('৳ 550.00'), findsOneWidget);
      expect(find.text('৳ 440.00'), findsOneWidget);
    });

    testWidgets(
        'BarcodePrintDialog opens, displays WYSIWYG preview, and allows template toggling',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => BarcodePrintDialog.show(
                    context,
                    product: testProduct,
                  ),
                  child: const Text('Open Studio'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Studio'));
      await tester.pumpAndSettle();

      expect(find.text('Barcode Label & Shelf Tag Printing Studio'),
          findsOneWidget);
      expect(find.text('1. SELECT LABEL TEMPLATE'), findsOneWidget);
      expect(find.text('Premium Cotton Polo Shirt'), findsWidgets);

      // Tap on Promotional template
      await tester.tap(find.text('Promotional Talker'));
      await tester.pumpAndSettle();

      expect(find.text('★ SPECIAL OFFER / প্রচার মূল্য ★'), findsOneWidget);

      // Increment label quantity
      final addButtons = find.byIcon(Icons.add);
      expect(addButtons, findsWidgets);
      await tester.ensureVisible(addButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('2 labels total'), findsOneWidget);

      // Test Sheet Print action
      expect(find.text('Sheet Print (A4)'), findsOneWidget);
      await tester.tap(find.text('Sheet Print (A4)'));
      await tester.pumpAndSettle();

      expect(find.text('Print Label Sheet Preview'), findsOneWidget);
      expect(find.text('Send to Printer'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
