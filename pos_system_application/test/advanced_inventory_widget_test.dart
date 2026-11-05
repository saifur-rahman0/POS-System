import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_client/features/catalog/domain/models/paginated_products.dart';
import 'package:pos_client/features/catalog/domain/models/product.dart';
import 'package:pos_client/features/catalog/domain/models/product_variant.dart';
import 'package:pos_client/features/catalog/presentation/controllers/catalog_providers.dart';
import 'package:pos_client/features/inventory/data/advanced_inventory_api_service.dart';
import 'package:pos_client/features/inventory/domain/models/damaged_stock.dart';
import 'package:pos_client/features/inventory/domain/models/inventory_batch.dart';
import 'package:pos_client/features/inventory/domain/models/inventory_valuation.dart';
import 'package:pos_client/features/inventory/domain/models/reorder_suggestion.dart';
import 'package:pos_client/features/inventory/domain/models/stock_count.dart';
import 'package:pos_client/features/inventory/domain/models/stock_reservation.dart';
import 'package:pos_client/features/inventory/presentation/controllers/advanced_inventory_controller.dart';
import 'package:pos_client/features/inventory/presentation/views/advanced_inventory_screen.dart';
import 'package:pos_client/features/inventory/presentation/views/batch_inward_dialog.dart';
import 'package:pos_client/features/inventory/presentation/views/damaged_stock_dialog.dart';
import 'package:pos_client/features/inventory/presentation/views/stock_count_session_dialog.dart';
import 'package:pos_client/features/inventory/presentation/views/stock_reservation_dialog.dart';

final dummyBatch = InventoryBatchModel(
  id: 'batch-1',
  businessId: 'biz-1',
  branchId: 'branch-1',
  productVariantId: 'var-1',
  productName: 'Paracetamol 500mg',
  variantName: 'Box of 100',
  sku: 'MED-001',
  batchNumber: 'LOT-2026-X1',
  manufacturingDate: DateTime(2026, 1, 1),
  expiryDate: DateTime(2026, 12, 31),
  quantityReceived: 100.0,
  quantityOnHand: 85.0,
  costPrice: 120.0,
  isActive: true,
  daysToExpiry: 240,
  expiryStatus: 'GOOD',
  createdAt: DateTime(2026, 1, 1),
);

final dummyAlert = ExpiryAlertModel(
  batchId: 'batch-2',
  batchNumber: 'LOT-EXP-1',
  productVariantId: 'var-2',
  productName: 'Eye Drops 10ml',
  variantName: 'Standard',
  branchId: 'branch-1',
  branchName: 'Main Store',
  quantityOnHand: 15.0,
  expiryDate: DateTime.now().add(const Duration(days: 5)),
  daysRemaining: 5,
  urgency: 'HIGH_7_DAYS',
);

final dummyDamaged = DamagedStockModel(
  id: 'dmg-1',
  businessId: 'biz-1',
  branchId: 'branch-1',
  productVariantId: 'var-1',
  productName: 'Paracetamol 500mg',
  variantName: 'Box of 100',
  batchNumber: 'LOT-2026-X1',
  voucherNo: 'DAM-20261105-0001',
  quantity: 5.0,
  unitCost: 120.0,
  totalLoss: 600.0,
  reason: 'WATER_DAMAGE',
  disposalMethod: 'DESTROYED',
  notes: 'Storeroom leak',
  reportedBy: 'user-1',
  createdAt: DateTime(2026, 11, 5),
);

final dummyReservation = StockReservationModel(
  id: 'res-1',
  businessId: 'biz-1',
  branchId: 'branch-1',
  productVariantId: 'var-1',
  productName: 'Paracetamol 500mg',
  variantName: 'Box of 100',
  quantity: 10.0,
  referenceType: 'QUOTATION',
  referenceId: 'quote-123',
  status: 'ACTIVE',
  reservedUntil: DateTime.now().add(const Duration(hours: 48)),
  createdBy: 'user-1',
  createdAt: DateTime(2026, 11, 5),
);

final dummyCount = StockCountModel(
  id: 'count-1',
  businessId: 'biz-1',
  branchId: 'branch-1',
  branchName: 'Main Store',
  status: 'DRAFT',
  notes: 'End of month audit',
  createdBy: 'user-1',
  approvedBy: null,
  createdAt: DateTime(2026, 11, 5),
  completedAt: null,
  lines: [
    const StockCountLineModel(
      id: 'line-1',
      stockCountId: 'count-1',
      productVariantId: 'var-1',
      productName: 'Paracetamol 500mg',
      variantName: 'Box of 100',
      barcode: '880123456789',
      expectedQty: 85.0,
      countedQty: 87.0,
      variance: 2.0,
    ),
  ],
);

const dummySuggestion = ReorderSuggestionModel(
  productVariantId: 'var-1',
  productName: 'Paracetamol 500mg',
  variantName: 'Box of 100',
  sku: 'MED-001',
  barcode: '880123456789',
  branchId: 'branch-1',
  branchName: 'Main Store',
  quantityOnHand: 15.0,
  activeReservations: 5.0,
  availableQuantity: 10.0,
  minStockLevel: 25.0,
  suggestedReorderQty: 50.0,
  estimatedUnitCost: 120.0,
  estimatedTotalCost: 6000.0,
);

final dummyValuation = InventoryValuationReportModel(
  businessId: 'biz-1',
  branchId: 'branch-1',
  branchName: 'Main Store',
  asOfDate: DateTime(2026, 11, 5),
  totalVariants: 1,
  totalQuantityOnHand: 85.0,
  totalFifoValuation: 10200.0,
  totalWacValuation: 10200.0,
  totalRetailValuation: 15300.0,
  categories: [
    const CategoryValuationModel(
      categoryId: 'cat-1',
      categoryName: 'Pharmaceuticals',
      itemCount: 1,
      totalUnits: 85.0,
      fifoValuation: 10200.0,
      wacValuation: 10200.0,
      retailValuation: 15300.0,
    ),
  ],
);

const dummyProduct = ProductModel(
  id: 'prod-1',
  businessId: 'biz-1',
  sku: 'MED-001',
  name: 'Paracetamol 500mg',
  productType: 'STANDARD',
  taxRate: 0.0,
  hasVariants: true,
  isActive: true,
  variants: [
    ProductVariantModel(
      id: 'var-1',
      productId: 'prod-1',
      name: 'Box of 100',
      barcode: '880123456789',
      costPrice: 120.0,
      sellingPrice: 180.0,
      trackStock: true,
      isActive: true,
    ),
  ],
);

const dummyPaginated = PaginatedProducts(
  items: [dummyProduct],
  total: 1,
  page: 1,
  limit: 15,
  pages: 1,
);

class MockAdvancedInventoryApiService implements AdvancedInventoryApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<InventoryBatchModel>> getBatches({String? branchId, String? productVariantId, bool? isActive}) async =>
      [dummyBatch];

  @override
  Future<List<ExpiryAlertModel>> getExpiryAlerts({String? branchId, int daysThreshold = 60}) async =>
      [dummyAlert];

  @override
  Future<List<DamagedStockModel>> getDamagedRecords({String? branchId, DateTime? startDate, DateTime? endDate}) async =>
      [dummyDamaged];

  @override
  Future<List<StockReservationModel>> getReservations({String? branchId, String? productVariantId, String? status}) async =>
      [dummyReservation];

  @override
  Future<List<StockCountModel>> getStockCounts({String? branchId, String? status}) async =>
      [dummyCount];

  @override
  Future<StockCountModel> getStockCount(String countId) async => dummyCount;

  @override
  Future<List<ReorderSuggestionModel>> getReorderSuggestions({String? branchId}) async =>
      [dummySuggestion];

  @override
  Future<InventoryValuationReportModel> getInventoryValuation({String? branchId}) async =>
      dummyValuation;
}

Widget createTestWidget(Widget child) {
  return ProviderScope(
    overrides: [
      advancedInventoryApiServiceProvider.overrideWithValue(MockAdvancedInventoryApiService()),
      paginatedProductsProvider.overrideWith((ref) async => dummyPaginated),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('AdvancedInventoryScreen renders all 5 tabs and active batches', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(const AdvancedInventoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Inventory Management'), findsOneWidget);
    expect(find.text('Batches & Expiry'), findsOneWidget);
    expect(find.text('Physical Audits'), findsOneWidget);
    expect(find.text('Damaged Stock'), findsOneWidget);
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('Reorder & Valuation'), findsOneWidget);

    // Verify batch list
    expect(find.textContaining('Paracetamol 500mg'), findsWidgets);
    expect(find.textContaining('LOT-2026-X1'), findsOneWidget);
    expect(find.text('GOOD'), findsOneWidget);
  });

  testWidgets('AdvancedInventoryScreen displays expiry alert banner', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(const AdvancedInventoryScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Expiry Alert:'), findsOneWidget);
  });

  testWidgets('BatchInwardDialog renders variant selector and inputs', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(const BatchInwardDialog()));
    await tester.pumpAndSettle();

    expect(find.text('Inward Stock Batch / Lot'), findsOneWidget);
    expect(find.text('Batch / Lot Number *'), findsOneWidget);
    expect(find.text('Quantity Received *'), findsOneWidget);
    expect(find.text('Save Batch'), findsOneWidget);
  });

  testWidgets('DamagedStockDialog renders reason dropdown and disposal method', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(const DamagedStockDialog()));
    await tester.pumpAndSettle();

    expect(find.text('Damaged / Spoilage Write-off'), findsOneWidget);
    expect(find.text('Damage Reason *'), findsOneWidget);
    expect(find.text('Disposal Method *'), findsOneWidget);
    expect(find.text('Post Write-Off'), findsOneWidget);
  });

  testWidgets('StockReservationDialog renders hold quantity and duration', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(const StockReservationDialog()));
    await tester.pumpAndSettle();

    expect(find.text('Create Stock Reservation'), findsOneWidget);
    expect(find.text('Hold Quantity *'), findsOneWidget);
    expect(find.text('Duration (Hours) *'), findsOneWidget);
    expect(find.text('Reserve Stock'), findsOneWidget);
  });

  testWidgets('StockCountSessionDialog renders audit session lines and variance', (tester) async {
    tester.view.physicalSize = const Size(1100, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(StockCountSessionDialog(stockCount: dummyCount)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Stock Audit Session: DRAFT'), findsOneWidget);
    expect(find.text('Scan Barcode or Type SKU'), findsOneWidget);
    expect(find.text('Complete Audit'), findsOneWidget);
    expect(find.textContaining('Paracetamol 500mg'), findsOneWidget);
    expect(find.text('+2.00'), findsOneWidget);
  });

  testWidgets('AdvancedInventoryScreen Reorder & Valuation tab displays valuation cards', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(const AdvancedInventoryScreen()));
    await tester.pumpAndSettle();

    // Tap the Reorder & Valuation tab
    await tester.tap(find.text('Reorder & Valuation'));
    await tester.pumpAndSettle();

    expect(find.text('Multi-Tier Inventory Valuation'), findsOneWidget);
    expect(find.text('FIFO Valuation'), findsOneWidget);
    expect(find.text('WAC Valuation'), findsOneWidget);
    expect(find.text('Retail Value'), findsOneWidget);
    expect(find.text('BDT 10200.00'), findsWidgets);
    expect(find.text('BDT 15300.00'), findsOneWidget);
    expect(find.text('Automated Replenishment Suggestions'), findsOneWidget);
    expect(find.textContaining('Order +50.0 units'), findsOneWidget);
  });
}
