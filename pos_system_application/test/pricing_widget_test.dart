import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_client/features/pricing/data/pricing_api_service.dart';
import 'package:pos_client/features/pricing/domain/models/branch_price_override.dart';
import 'package:pos_client/features/pricing/domain/models/customer_group.dart';
import 'package:pos_client/features/pricing/domain/models/price_list.dart';
import 'package:pos_client/features/pricing/domain/models/product_bundle.dart';
import 'package:pos_client/features/pricing/domain/models/promotion.dart';
import 'package:pos_client/features/pricing/presentation/controllers/pricing_controller.dart';
import 'package:pos_client/features/pricing/presentation/views/dialogs/customer_group_dialog.dart';
import 'package:pos_client/features/pricing/presentation/views/pricing_screen.dart';

final dummyGroup = CustomerGroupModel(
  id: 'group-1',
  businessId: 'biz-1',
  name: 'Wholesale Tier 1',
  description: 'Major bulk buyers',
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  memberCount: 8,
);

final dummyPriceListItem = PriceListItemModel(
  id: 'item-1',
  priceListId: 'list-1',
  productVariantId: 'var-1',
  minQuantity: 5.0,
  price: 450.0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  variantName: 'USB Flash Drive 64GB',
);

final dummyPriceList = PriceListModel(
  id: 'list-1',
  businessId: 'biz-1',
  name: 'B2B Wholesale Schedule',
  description: 'Special wholesale rates',
  currency: 'BDT',
  isDefault: true,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  items: [dummyPriceListItem],
);

final dummyOverride = BranchPriceOverrideModel(
  id: 'override-1',
  businessId: 'biz-1',
  branchId: 'branch-1',
  productVariantId: 'var-1',
  sellingPrice: 520.0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  branchName: 'Dhanmondi Branch',
  variantName: 'USB Flash Drive 64GB',
);

final dummyBundle = ProductBundleModel(
  id: 'bundle-1',
  businessId: 'biz-1',
  productId: 'prod-1',
  name: 'Workstation Starter Kit',
  bundlePrice: 2500.0,
  isKit: false,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  items: const [
    ProductBundleItemModel(
      id: 'b-item-1',
      bundleId: 'bundle-1',
      componentVariantId: 'comp-1',
      quantity: 1.0,
      componentName: 'Optical Mouse',
    ),
    ProductBundleItemModel(
      id: 'b-item-2',
      bundleId: 'bundle-1',
      componentVariantId: 'comp-2',
      quantity: 1.0,
      componentName: 'Mechanical Keyboard',
    ),
  ],
);

final dummyPromotion = PromotionModel(
  id: 'promo-1',
  businessId: 'biz-1',
  name: 'Flash Sale 15% Off',
  code: 'FLASH15',
  discountType: 'PERCENTAGE',
  discountValue: 15.0,
  minSpend: 500.0,
  maxDiscountCap: 300.0,
  usageLimit: 50,
  timesUsed: 12,
  validFrom: DateTime(2026, 1, 1),
  validUntil: DateTime(2026, 12, 31),
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class MockPricingApiService extends Fake implements PricingApiService {
  @override
  Future<List<CustomerGroupModel>> getCustomerGroups({bool? isActive}) async => [dummyGroup];

  @override
  Future<List<PriceListModel>> getPriceLists({bool? isActive}) async => [dummyPriceList];

  @override
  Future<PriceListModel> getPriceList(String id) async => dummyPriceList;

  @override
  Future<List<BranchPriceOverrideModel>> getBranchOverrides({String? branchId}) async => [dummyOverride];

  @override
  Future<List<ProductBundleModel>> getBundles({bool? isActive}) async => [dummyBundle];

  @override
  Future<List<PromotionModel>> getPromotions({bool? isActive}) async => [dummyPromotion];
}

Widget createTestWidget({required Widget child}) {
  return ProviderScope(
    overrides: [
      pricingApiServiceProvider.overrideWithValue(MockPricingApiService()),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('PricingScreen renders all 5 tabs and Bulk Import button', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(child: const PricingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Price Lists'), findsOneWidget);
    expect(find.text('Customer Groups'), findsOneWidget);
    expect(find.text('Branch Overrides'), findsOneWidget);
    expect(find.text('Bundles & Kits'), findsOneWidget);
    expect(find.text('Promotions & Coupons'), findsOneWidget);
    expect(find.text('Bulk CSV Import'), findsOneWidget);
  });

  testWidgets('Price Lists tab shows loaded schedules and default chip', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(child: const PricingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('B2B Wholesale Schedule'), findsOneWidget);
    expect(find.text('DEFAULT'), findsOneWidget);
  });

  testWidgets('Customer Groups tab renders groups table', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(child: const PricingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Customer Groups'));
    await tester.pumpAndSettle();

    expect(find.text('Customer Groups & Tiers'), findsOneWidget);
    expect(find.text('Wholesale Tier 1'), findsOneWidget);
    expect(find.text('Major bulk buyers'), findsOneWidget);
    expect(find.text('8 members'), findsOneWidget);
  });

  testWidgets('Branch Overrides tab renders overrides data', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(child: const PricingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Branch Overrides'));
    await tester.pumpAndSettle();

    expect(find.text('Branch-Specific Price Overrides'), findsOneWidget);
    expect(find.text('Dhanmondi Branch'), findsOneWidget);
    expect(find.text('USB Flash Drive 64GB'), findsOneWidget);
    expect(find.text('৳520.00'), findsOneWidget);
  });

  testWidgets('Bundles tab renders bundles and expands component details', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(child: const PricingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bundles & Kits'));
    await tester.pumpAndSettle();

    expect(find.text('Product Bundles & Composite Kits'), findsOneWidget);
    expect(find.text('Workstation Starter Kit'), findsOneWidget);

    await tester.tap(find.text('Workstation Starter Kit'));
    await tester.pumpAndSettle();

    expect(find.text('Included Items:'), findsOneWidget);
    expect(find.text('Optical Mouse × 1.0'), findsOneWidget);
    expect(find.text('Mechanical Keyboard × 1.0'), findsOneWidget);
  });

  testWidgets('Promotions tab renders promotions table with discount chip', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(child: const PricingScreen()));
    await tester.pumpAndSettle();

    final promoTab = find.text('Promotions & Coupons');
    await tester.ensureVisible(promoTab);
    await tester.tap(promoTab, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Active Promotions & Coupons'), findsOneWidget);
    expect(find.text('Flash Sale 15% Off'), findsOneWidget);
    expect(find.text('FLASH15'), findsOneWidget);
    expect(find.text('15% Off'), findsOneWidget);
  });

  testWidgets('CustomerGroupDialog form validation and cancel', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: CustomerGroupDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Customer Group'), findsOneWidget);
    expect(find.text('Create Group'), findsOneWidget);

    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
  });
}
