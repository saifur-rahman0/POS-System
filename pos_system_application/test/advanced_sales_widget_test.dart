import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_client/features/catalog/domain/models/product.dart';
import 'package:pos_client/features/catalog/domain/models/product_variant.dart';
import 'package:pos_client/features/checkout/domain/models/cart_item.dart';
import 'package:pos_client/features/checkout/domain/models/quotation.dart';
import 'package:pos_client/features/checkout/presentation/controllers/cart_controller.dart';
import 'package:pos_client/features/checkout/presentation/views/delivery_charge_dialog.dart';
import 'package:pos_client/features/checkout/presentation/views/line_discount_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyVariant = ProductVariantModel(
    id: 'var-1',
    productId: 'prod-1',
    name: 'Standard',
    sku: 'SKU-001',
    sellingPrice: 100.0,
    costPrice: 60.0,
    trackStock: true,
    isActive: true,
  );

  const dummyProduct = ProductModel(
    id: 'prod-1',
    businessId: 'biz-1',
    name: 'Wireless Mouse',
    sku: 'SKU-001',
    productType: 'SINGLE',
    taxRate: 5.0,
    hasVariants: false,
    isActive: true,
    primaryVariant: dummyVariant,
    variants: [dummyVariant],
  );

  group('Track 9: Cart Domain & Advanced Sales Arithmetic Tests', () {
    test('Cart computes line discount percentages and grand total accurately', () {
      final notifier = CartNotifier();

      // Add 2 items at 100.0 each -> subtotal 200.0
      notifier.addItem(dummyProduct, dummyVariant);
      notifier.incrementQuantity('var-1');

      expect(notifier.state.subtotal, 200.0);
      expect(notifier.state.discountTotal, 0.0);

      // Apply 10% discount on line item
      notifier.updateItemDiscount(
        'var-1',
        10.0,
        discountType: 'PERCENTAGE',
        discountReason: 'Loyalty',
      );

      final item = notifier.state.items.first;
      expect(item.lineDiscount, 20.0); // 10% of (2 * 100) = 20.0
      expect(item.lineTotal, 180.0);
      expect(notifier.state.itemDiscounts, 20.0);
      expect(notifier.state.discountedSubtotal, 180.0);

      // Add delivery charge 60.0
      notifier.setDeliveryCharge(60.0);
      expect(notifier.state.deliveryCharge, 60.0);

      // Tax rate 5% on discounted subtotal (180 * 0.05 = 9.0)
      notifier.setTaxRate(5.0);
      expect(notifier.state.taxTotal, 9.0);

      // Grand total = 180 + 9 + 60 = 249.0
      expect(notifier.state.grandTotal, 249.0);
    });

    test('Cart computes fixed line discounts correctly', () {
      final notifier = CartNotifier();
      notifier.addItem(dummyProduct, dummyVariant); // 1 qty at 100.0

      // Fixed ৳15.00 discount
      notifier.updateItemDiscount(
        'var-1',
        15.0,
        discountType: 'FIXED',
        discountReason: 'Manager Promo',
      );

      final item = notifier.state.items.first;
      expect(item.lineDiscount, 15.0);
      expect(item.lineTotal, 85.0);
      expect(notifier.state.discountTotal, 15.0);
    });

    test('Cart restoreCart sets all state variables including heldCartId', () {
      final notifier = CartNotifier();
      const restoredItem = CartItemModel(
        variantId: 'var-1',
        productId: 'prod-1',
        productName: 'Wireless Mouse',
        sku: 'SKU-001',
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 3.0,
        discount: 10.0,
        discountType: 'PERCENTAGE',
      );

      notifier.restoreCart(
        items: [restoredItem],
        cartDiscount: 5.0,
        taxRate: 5.0,
        deliveryCharge: 120.0,
        customerId: 'cust-123',
        customerName: 'Rahim Traders',
        heldCartId: 'held-789',
        notes: 'Restored parked order',
      );

      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.quantity, 3.0);
      expect(notifier.state.cartDiscount, 5.0);
      expect(notifier.state.deliveryCharge, 120.0);
      expect(notifier.state.customerId, 'cust-123');
      expect(notifier.state.customerName, 'Rahim Traders');
      expect(notifier.state.heldCartId, 'held-789');
      expect(notifier.state.notes, 'Restored parked order');
    });
  });

  group('Track 9: Advanced Sales Widgets UI Tests', () {
    testWidgets('DeliveryChargeDialog applies preset delivery fee',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => DeliveryChargeDialog.show(ctx),
                  child: const Text('Open Delivery Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Delivery Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delivery & Shipping Fee'), findsOneWidget);
      expect(find.text('Inside City (৳ 60.00)'), findsOneWidget);
      expect(find.text('Outside City (৳ 120.00)'), findsOneWidget);

      // Tap 'Inside City' preset chip
      await tester.tap(find.text('Inside City (৳ 60.00)'));
      await tester.pumpAndSettle();

      // Tap 'Apply Fee'
      await tester.tap(find.text('Apply Fee'));
      await tester.pumpAndSettle();

      // Verify cart state updated
      expect(container.read(cartProvider).deliveryCharge, 60.0);
    });

    testWidgets('LineDiscountDialog renders discounts and preview calculations',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seed cart with 1 item
      container.read(cartProvider.notifier).addItem(dummyProduct, dummyVariant);
      final item = container.read(cartProvider).items.first;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => LineDiscountDialog.show(ctx, item),
                  child: const Text('Open Discount Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Discount Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Wireless Mouse'), findsOneWidget);
      expect(find.text('Percentage (%)'), findsOneWidget);
      expect(find.text('Fixed (৳)'), findsOneWidget);
      expect(find.text('Discount Reason'), findsOneWidget);
    });

    test('QuotationModel computes getters correctly', () {
      final quotation = QuotationModel(
        id: 'qt-1',
        businessId: 'biz-1',
        branchId: 'br-1',
        quotationNo: 'QT-20261105-0001',
        status: 'PENDING',
        subtotal: 1000.0,
        discountTotal: 100.0,
        taxTotal: 45.0,
        deliveryCharge: 60.0,
        grandTotal: 1005.0,
        validUntil: DateTime.now().add(const Duration(days: 7)),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(quotation.quotationNumber, 'QT-20261105-0001');
      expect(quotation.discountedSubtotal, 900.0);
      expect(quotation.isExpired, false);
    });
  });
}
