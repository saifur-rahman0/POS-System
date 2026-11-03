import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/core/network/api_client.dart';
import 'package:pos_client/features/catalog/data/catalog_api_service.dart';
import 'package:pos_client/features/catalog/domain/models/category.dart';
import 'package:pos_client/features/catalog/domain/models/product.dart';
import 'package:pos_client/features/catalog/domain/models/product_variant.dart';
import 'package:pos_client/features/catalog/presentation/controllers/catalog_providers.dart';
import 'package:pos_client/features/checkout/domain/models/sale_receipt.dart';
import 'package:pos_client/features/checkout/presentation/controllers/cart_controller.dart';
import 'package:pos_client/features/checkout/presentation/views/pos_register_screen.dart';
import 'package:pos_client/features/checkout/presentation/views/receipt_dialog.dart';

void main() {
  const sampleVariant = ProductVariantModel(
    id: 'var-test-1',
    productId: 'prod-test-1',
    sku: 'SKU-MOUSE-01',
    name: 'Standard',
    barcode: '880123456789',
    costPrice: 50.0,
    sellingPrice: 100.0,
    trackStock: true,
    isActive: true,
  );

  const sampleProduct = ProductModel(
    id: 'prod-test-1',
    businessId: 'biz-test-1',
    sku: 'SKU-MOUSE-01',
    name: 'Ergonomic Optical Mouse',
    categoryId: 'cat-test-1',
    categoryName: 'Peripherals',
    productType: 'standard',
    taxRate: 5.0,
    hasVariants: false,
    isActive: true,
    primaryVariant: sampleVariant,
    variants: [sampleVariant],
  );

  final sampleReceipt = SaleReceiptModel(
    id: 'sale-test-1',
    receiptNo: 'REC-20261103-MAIN-0042',
    status: 'COMPLETED',
    cashierId: 'user-cashier-1',
    customerName: 'John Doe',
    financials: const SaleFinancialsModel(
      subtotal: 200.0,
      discountTotal: 10.0,
      taxTotal: 9.5,
      grandTotal: 199.5,
      paidTotal: 200.0,
      dueTotal: 0.0,
      changeAmount: 0.5,
    ),
    items: const [
      SaleReceiptItemModel(
        id: 'item-1',
        productVariantId: 'var-test-1',
        productName: 'Ergonomic Optical Mouse',
        sku: 'SKU-MOUSE-01',
        barcode: '880123456789',
        quantity: 2.0,
        unitPrice: 100.0,
        discount: 10.0,
        lineTotal: 190.0,
      ),
    ],
    payments: const [
      SaleReceiptPaymentModel(
        id: 'pay-1',
        method: 'CASH',
        amount: 200.0,
        reference: null,
        status: 'CONFIRMED',
      ),
    ],
    notes: 'Test sale',
    createdAt: DateTime(2026, 11, 3, 21, 45),
  );

  Widget createTestWidget({
    List<Override> overrides = const [],
    required Widget child,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('CartNotifier Unit Tests', () {
    test('Calculates subtotal, discounts, tax, and grand total accurately', () {
      final container = ProviderContainer();
      final notifier = container.read(cartProvider.notifier);

      expect(container.read(cartProvider).isEmpty, isTrue);

      // Add product
      notifier.addItem(sampleProduct);
      var state = container.read(cartProvider);
      expect(state.items.length, 1);
      expect(state.items.first.quantity, 1.0);
      expect(state.subtotal, 100.0);
      expect(state.discountTotal, 0.0);
      expect(state.taxTotal, 5.0); // 5% of 100
      expect(state.grandTotal, 105.0);

      // Increment quantity
      notifier.incrementQuantity('var-test-1');
      state = container.read(cartProvider);
      expect(state.items.first.quantity, 2.0);
      expect(state.subtotal, 200.0);
      expect(state.taxTotal, 10.0);
      expect(state.grandTotal, 210.0);

      // Set cart discount
      notifier.setCartDiscount(20.0);
      state = container.read(cartProvider);
      expect(state.discountTotal, 20.0);
      expect(state.discountedSubtotal, 180.0);
      expect(state.taxTotal, 9.0); // 5% of 180 = 9.0
      expect(state.grandTotal, 189.0);

      // Clear cart
      notifier.clearCart();
      state = container.read(cartProvider);
      expect(state.isEmpty, isTrue);
      expect(state.grandTotal, 0.0);
    });

    test('addByBarcode matches barcode or SKU', () {
      final container = ProviderContainer();
      final notifier = container.read(cartProvider.notifier);

      final found = notifier.addByBarcode('880123456789', [sampleProduct]);
      expect(found, isTrue);
      expect(container.read(cartProvider).items.length, 1);

      final notFound = notifier.addByBarcode('999999999999', [sampleProduct]);
      expect(notFound, isFalse);
    });
  });

  group('POS Register Screen Widget Tests', () {
    testWidgets('Renders empty cart and catalog items, adds product on click',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            posProductsProvider.overrideWith((ref) async => [sampleProduct]),
            categoryListProvider.overrideWith((ref) => CategoryListNotifierMock([
                  const CategoryModel(
                    id: 'cat-test-1',
                    businessId: 'biz-1',
                    name: 'Peripherals',
                    isActive: true,
                  ),
                ])),
          ],
          child: const PosRegisterScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify empty cart state
      expect(find.text('Cart is empty'), findsOneWidget);
      expect(find.text('Order'), findsOneWidget);

      // Verify product card is visible in catalog grid
      expect(find.text('Ergonomic Optical Mouse'), findsOneWidget);
      expect(find.text('SKU-MOUSE-01'), findsOneWidget);
      expect(find.text('৳ 100.00'), findsWidgets);

      // Tap product card to add to cart
      await tester.tap(find.text('Ergonomic Optical Mouse'));
      await tester.pumpAndSettle();

      // Verify cart now contains the item
      expect(find.text('Cart is empty'), findsNothing);
      expect(find.text('1 items'), findsOneWidget);
      expect(find.text('Grand Total'), findsOneWidget);
      expect(find.text('Pay ৳ 105.00 (F4)'), findsOneWidget);

      // Tap '+' stepper to increase quantity
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();

      // Verify 2 items in cart
      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('Pay ৳ 210.00 (F4)'), findsOneWidget);
    });

    testWidgets('Tapping Pay button opens PaymentDialog',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      final container = ProviderContainer(
        overrides: [
          posProductsProvider.overrideWith((ref) async => [sampleProduct]),
          categoryListProvider.overrideWith((ref) => CategoryListNotifierMock([
                const CategoryModel(
                  id: 'cat-test-1',
                  businessId: 'biz-1',
                  name: 'Peripherals',
                  isActive: true,
                ),
              ])),
        ],
      );

      // Pre-add item to cart
      container.read(cartProvider.notifier).addItem(sampleProduct);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: PosRegisterScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Pay button
      await tester.tap(find.text('Pay ৳ 105.00 (F4)'));
      await tester.pumpAndSettle();

      // Verify PaymentDialog is shown
      expect(find.text('Complete Payment'), findsOneWidget);
      expect(find.text('TOTAL PAYABLE'), findsOneWidget);
      expect(find.text('৳ 105.00'), findsWidgets);
      expect(find.text('Quick Cash:'), findsOneWidget);
      expect(find.text('Exact'), findsOneWidget);
    });
  });

  group('Receipt Dialog Widget Tests', () {
    testWidgets('Renders receipt details, line items, and print button',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ReceiptDialog(sale: sampleReceipt),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Payment Successful'), findsOneWidget);
      expect(find.text('RETAIL POS STORE'), findsOneWidget);
      expect(find.text('REC-20261103-MAIN-0042'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Ergonomic Optical Mouse'), findsOneWidget);
      expect(find.text('GRAND TOTAL'), findsOneWidget);
      expect(find.text('৳ 199.50'), findsOneWidget);
      expect(find.text('Print Receipt'), findsOneWidget);
      expect(find.text('New Sale'), findsOneWidget);
    });
  });
}

class CategoryListNotifierMock extends CategoryListNotifier {
  final List<CategoryModel> initialData;

  CategoryListNotifierMock(this.initialData) : super(FakeCatalogApiService()) {
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
