import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/core/network/api_client.dart';
import 'package:pos_client/features/catalog/data/catalog_api_service.dart';
import 'package:pos_client/features/catalog/domain/models/category.dart';
import 'package:pos_client/features/catalog/domain/services/catalog_code_generator.dart';
import 'package:pos_client/features/catalog/presentation/controllers/catalog_providers.dart';
import 'package:pos_client/features/catalog/presentation/views/product_form_dialog.dart';

void main() {
  const electronicsCat = CategoryModel(
    id: 'cat-elec',
    businessId: 'biz-1',
    name: 'Electronics',
    code: 'ELEC',
    isActive: true,
  );

  const beveragesCat = CategoryModel(
    id: 'cat-bev',
    businessId: 'biz-1',
    name: 'Beverages',
    code: 'BEV',
    isActive: true,
  );

  Widget createDialogWidget({List<CategoryModel> categories = const []}) {
    return ProviderScope(
      overrides: [
        categoryListProvider
            .overrideWith((ref) => TestCategoryNotifier(categories)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const ProductFormDialog(),
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  group('ProductFormDialog Automatic SKU & Barcode Generation UI Tests', () {
    testWidgets(
        'Empty product dialog shows auto-gen banner, and empty submit triggers validation',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createDialogWidget(categories: [electronicsCat]));

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Product'), findsOneWidget);
      expect(find.text('Auto-Generate SKU & Barcode'), findsOneWidget);

      // Attempt submit without typing anything
      await tester.tap(find.text('Create Product'));
      await tester.pumpAndSettle();

      expect(find.text('Product name is required'), findsOneWidget);
      expect(find.text('SKU is required'), findsOneWidget);
      expect(find.text('Price is required'), findsOneWidget);
    });

    testWidgets(
        'Typing product name automatically generates SKU and valid EAN-13 barcode',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
          createDialogWidget(categories: [electronicsCat, beveragesCat]));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter product name
      final nameField = find.widgetWithText(TextFormField, 'Product Name *');
      await tester.enterText(nameField, 'Wireless Gaming Mouse');
      await tester.pumpAndSettle();

      // Verify SKU is generated with GEN prefix (no category selected yet) and WGM initials
      final skuField = find.widgetWithText(TextFormField, 'SKU *');
      final TextFormField skuWidget = tester.widget(skuField);
      expect(skuWidget.controller?.text, startsWith('GEN-WGM-'));

      // Verify Barcode is generated with 13-digit EAN-13
      final barcodeField = find.widgetWithText(TextFormField, 'Barcode / UPC');
      final TextFormField barcodeWidget = tester.widget(barcodeField);
      final generatedBarcode = barcodeWidget.controller?.text ?? '';
      expect(generatedBarcode.length, equals(13));
      expect(generatedBarcode.startsWith('200'), isTrue);
      expect(CatalogCodeGenerator.isValidEan13(generatedBarcode), isTrue);

      // Verify validation badge appears
      expect(find.text('Valid GS1 EAN-13 Checksum'), findsOneWidget);
    });

    testWidgets('Selecting Category dynamically updates SKU prefix',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
          createDialogWidget(categories: [electronicsCat, beveragesCat]));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter product name
      final nameField = find.widgetWithText(TextFormField, 'Product Name *');
      await tester.enterText(nameField, 'Mojo Cola 250ml');
      await tester.pumpAndSettle();

      // Initially GEN-MC250-xxx
      var skuField = find.widgetWithText(TextFormField, 'SKU *');
      var skuWidget = tester.widget<TextFormField>(skuField);
      expect(skuWidget.controller?.text, startsWith('GEN-MC250-'));

      // Select Beverages Category
      final categoryDropdown =
          find.widgetWithText(DropdownButtonFormField<String>, 'Category');
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Beverages').last);
      await tester.pumpAndSettle();

      // SKU should now start with BEV-MC250-xxx
      skuField = find.widgetWithText(TextFormField, 'SKU *');
      skuWidget = tester.widget<TextFormField>(skuField);
      expect(skuWidget.controller?.text, startsWith('BEV-MC250-'));
    });

    testWidgets('Manual editing sets CUSTOM badge and prevents overwriting',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createDialogWidget(categories: [electronicsCat]));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter name
      final nameField = find.widgetWithText(TextFormField, 'Product Name *');
      await tester.enterText(nameField, 'Keyboard');
      await tester.pumpAndSettle();

      // Manually change SKU
      final skuField = find.widgetWithText(TextFormField, 'SKU *');
      await tester.enterText(skuField, 'MY-CUSTOM-SKU-99');
      await tester.pumpAndSettle();

      // CUSTOM badge should appear
      expect(find.text('CUSTOM'), findsWidgets);

      // Now change product name again
      await tester.enterText(nameField, 'RGB Mechanical Keyboard');
      await tester.pumpAndSettle();

      // SKU must still be the manual custom SKU!
      final skuWidget = tester.widget<TextFormField>(skuField);
      expect(skuWidget.controller?.text, equals('MY-CUSTOM-SKU-99'));

      // Tap refresh icon on SKU field to regenerate with new name
      final refreshIcon = find.byTooltip('Regenerate SKU using rule');
      await tester.tap(refreshIcon);
      await tester.pumpAndSettle();

      final updatedSku = tester.widget<TextFormField>(skuField);
      expect(updatedSku.controller?.text, startsWith('GEN-RMK-'));
    });
  });
}

class TestCategoryNotifier extends CategoryListNotifier {
  final List<CategoryModel> initialData;

  TestCategoryNotifier(this.initialData) : super(FakeCatalogApiService()) {
    state = AsyncValue.data(initialData);
  }

  @override
  Future<void> fetchCategories({bool? isActive}) async {
    state = AsyncValue.data(initialData);
  }
}

class FakeCatalogApiService extends CatalogApiService {
  FakeCatalogApiService() : super(apiClient: DummyApiClient());
}

class DummyApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
