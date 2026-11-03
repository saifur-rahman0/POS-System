import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/core/network/api_client.dart';
import 'package:pos_client/features/catalog/data/catalog_api_service.dart';
import 'package:pos_client/features/catalog/domain/models/category.dart';
import 'package:pos_client/features/catalog/domain/models/paginated_products.dart';
import 'package:pos_client/features/catalog/domain/models/product.dart';
import 'package:pos_client/features/catalog/domain/models/product_variant.dart';
import 'package:pos_client/features/catalog/presentation/controllers/catalog_providers.dart';
import 'package:pos_client/features/shell/presentation/shell_screen.dart';

void main() {
  const sampleCategory = CategoryModel(
    id: 'cat-1',
    businessId: 'biz-1',
    name: 'Electronics',
    code: 'ELEC',
    isActive: true,
  );

  const sampleProduct = ProductModel(
    id: 'prod-1',
    businessId: 'biz-1',
    sku: 'TEST-SKU-001',
    name: 'Wireless Ergonomic Mouse',
    categoryId: 'cat-1',
    categoryName: 'Electronics',
    productType: 'standard',
    taxRate: 5.0,
    hasVariants: false,
    isActive: true,
    primaryVariant: ProductVariantModel(
      id: 'var-1',
      productId: 'prod-1',
      sku: 'TEST-SKU-001',
      name: 'Default',
      barcode: '123456789012',
      costPrice: 15.00,
      sellingPrice: 29.99,
      trackStock: true,
      isActive: true,
    ),
  );

  Widget createTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ShellScreen(),
      ),
    );
  }

  testWidgets('Navigating to Catalog & Stock tab displays CatalogScreen with Products & Categories',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));

    await tester.pumpWidget(
      createTestWidget(
        overrides: [
          categoryListProvider.overrideWith((ref) => TestCategoryNotifier([sampleCategory])),
          paginatedProductsProvider.overrideWith((ref) async {
            return const PaginatedProducts(
              items: [sampleProduct],
              total: 1,
              page: 1,
              limit: 15,
              pages: 1,
            );
          }),
        ],
      ),
    );

    // Initial shell screen shows POS Register
    expect(find.text('Catalog & Stock'), findsOneWidget);

    // Tap the Catalog & Stock navigation rail destination
    await tester.tap(find.text('Catalog & Stock'));
    await tester.pumpAndSettle();

    // Verify CatalogScreen tabs are visible
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);

    // Verify product from test state is displayed in the table
    expect(find.text('TEST-SKU-001'), findsOneWidget);
    expect(find.text('Wireless Ergonomic Mouse'), findsOneWidget);
    expect(find.text('\$29.99'), findsOneWidget);
    expect(find.text('123456789012'), findsOneWidget);

    // Tap on Categories tab
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    // Verify Categories view is rendered
    expect(find.text('Product Categories'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);
    expect(find.text('ELEC'), findsOneWidget);
  });

  testWidgets('Add Product dialog opens and validates required fields',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));

    await tester.pumpWidget(
      createTestWidget(
        overrides: [
          categoryListProvider.overrideWith((ref) => TestCategoryNotifier([sampleCategory])),
          paginatedProductsProvider.overrideWith((ref) async {
            return const PaginatedProducts(
              items: [],
              total: 0,
              page: 1,
              limit: 15,
              pages: 1,
            );
          }),
        ],
      ),
    );

    // Navigate to Catalog
    await tester.tap(find.text('Catalog & Stock'));
    await tester.pumpAndSettle();

    // Tap Add Product button
    final addBtn = find.byKey(const Key('add_product_button'));
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Dialog title
    expect(find.text('Add New Product'), findsOneWidget);

    // Attempt to submit empty form
    await tester.tap(find.text('Create Product'));
    await tester.pumpAndSettle();

    // Validation errors should appear
    expect(find.text('Product name is required'), findsOneWidget);
    expect(find.text('SKU is required'), findsOneWidget);
    expect(find.text('Price is required'), findsOneWidget);
  });

  testWidgets('Add Category dialog opens and validates required name',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));

    await tester.pumpWidget(
      createTestWidget(
        overrides: [
          categoryListProvider.overrideWith((ref) => TestCategoryNotifier([])),
          paginatedProductsProvider.overrideWith((ref) async {
            return const PaginatedProducts(
              items: [],
              total: 0,
              page: 1,
              limit: 15,
              pages: 1,
            );
          }),
        ],
      ),
    );

    // Navigate to Catalog
    await tester.tap(find.text('Catalog & Stock'));
    await tester.pumpAndSettle();

    // Switch to Categories tab
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    // Tap Add Category (toolbar or empty state)
    final addCategoryBtn = find.byKey(const Key('add_category_button'));
    expect(addCategoryBtn, findsOneWidget);
    await tester.tap(addCategoryBtn);
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Create Category'), findsOneWidget);

    // Tap Create with empty name
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Validation error
    expect(find.text('Category name is required'), findsOneWidget);
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
