import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/inventory/data/inventory_api_service.dart';
import 'package:pos_client/features/inventory/domain/models/stock_adjustment.dart';
import 'package:pos_client/features/inventory/domain/models/stock_movement.dart';
import 'package:pos_client/features/inventory/presentation/controllers/inventory_controller.dart';
import 'package:pos_client/features/inventory/presentation/views/stock_adjustment_dialog.dart';
import 'package:pos_client/features/inventory/presentation/views/stock_movements_dialog.dart';
import 'package:pos_client/features/purchasing/data/purchasing_api_service.dart';
import 'package:pos_client/features/purchasing/domain/models/paginated_purchases.dart';
import 'package:pos_client/features/purchasing/domain/models/paginated_suppliers.dart';
import 'package:pos_client/features/purchasing/domain/models/purchase_item.dart';
import 'package:pos_client/features/purchasing/domain/models/purchase_order.dart';
import 'package:pos_client/features/purchasing/domain/models/supplier.dart';
import 'package:pos_client/features/purchasing/presentation/controllers/purchasing_controller.dart';
import 'package:pos_client/features/purchasing/presentation/views/purchasing_screen.dart';
import 'package:pos_client/features/purchasing/presentation/views/supplier_form_dialog.dart';

class MockInventoryApiService implements InventoryApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<StockAdjustmentModel> adjustStock({
    required String productVariantId,
    required String adjustmentType,
    required double quantity,
    required String reason,
    String? branchId,
    String? notes,
  }) async {
    return StockAdjustmentModel(
      movementId: 'mov-adj-1',
      businessId: 'biz-1',
      branchId: branchId ?? 'br-1',
      productVariantId: productVariantId,
      adjustmentType: adjustmentType,
      quantityAdjusted: quantity,
      previousQuantity: 20.0,
      newQuantity: adjustmentType == 'ADJUSTMENT_UP' ? 20.0 + quantity : 20.0 - quantity,
      reason: reason,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<PaginatedStockMovementsModel> getStockMovements({
    String? productVariantId,
    String? branchId,
    String? movementType,
    int page = 1,
    int pageSize = 20,
  }) async {
    return PaginatedStockMovementsModel(
      items: [
        StockMovementModel(
          id: 'mov-1',
          businessId: 'biz-1',
          branchId: 'br-1',
          productVariantId: productVariantId ?? 'v-1',
          productName: 'Rice 5kg Bag',
          variantName: '5kg',
          sku: 'RC-05',
          movementType: 'PURCHASE_RECEIVE',
          quantityDelta: 50.0,
          unitCost: 350.0,
          referenceType: 'PURCHASE',
          referenceId: 'po-1',
          createdBy: 'user-1',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        StockMovementModel(
          id: 'mov-2',
          businessId: 'biz-1',
          branchId: 'br-1',
          productVariantId: productVariantId ?? 'v-1',
          productName: 'Rice 5kg Bag',
          variantName: '5kg',
          sku: 'RC-05',
          movementType: 'SALE',
          quantityDelta: -2.0,
          unitCost: 350.0,
          referenceType: 'SALE',
          referenceId: 'sale-1',
          createdBy: 'user-1',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ],
      total: 2,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    );
  }

  @override
  Future<double> getStockBalance(String productVariantId, {String? branchId}) async {
    return 48.0;
  }

  @override
  Future<Map<String, double>> getAllStockBalances({String? branchId}) async {
    return {'v-1': 48.0};
  }
}

class MockPurchasingApiService implements PurchasingApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<SupplierModel> mockSuppliers = [
    SupplierModel(
      id: 'sup-1',
      businessId: 'biz-1',
      name: 'Pran Foods Ltd',
      contactPerson: 'Mr. Rafiq',
      phone: '01711223344',
      email: 'vendor@pran.com',
      address: 'Dhaka, Bangladesh',
      isActive: true,
      totalPurchasesCount: 5,
      totalPurchasesAmount: 50000.0,
      unpaidBalance: 5000.0,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  final List<PurchaseOrderModel> mockOrders = [
    PurchaseOrderModel(
      id: 'po-1',
      businessId: 'biz-1',
      branchId: 'br-1',
      supplierId: 'sup-1',
      supplierName: 'Pran Foods Ltd',
      referenceNo: 'PO-20261104-0001',
      status: 'ORDERED',
      subtotal: 15000.0,
      discount: 0.0,
      total: 15000.0,
      paidTotal: 5000.0,
      dueBalance: 10000.0,
      notes: null,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      items: const [
        PurchaseItemModel(
          id: 'item-1',
          productVariantId: 'v-1',
          productName: 'Rice 5kg Bag',
          variantName: '5kg',
          sku: 'RC-05',
          quantity: 50.0,
          unitCost: 300.0,
          lineTotal: 15000.0,
        ),
      ],
      payments: [],
    ),
  ];

  @override
  Future<PaginatedSuppliersModel> getSuppliers({
    String? search,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async {
    return PaginatedSuppliersModel(
      items: mockSuppliers,
      total: mockSuppliers.length,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<PaginatedPurchasesModel> getPurchases({
    String? status,
    String? supplierId,
    String? branchId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return PaginatedPurchasesModel(
      items: mockOrders,
      total: mockOrders.length,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<SupplierModel> createSupplier(Map<String, dynamic> data) async {
    return SupplierModel(
      id: 'sup-new',
      businessId: 'biz-1',
      name: data['name'] as String,
      contactPerson: data['contact_person'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      isActive: true,
      totalPurchasesCount: 0,
      totalPurchasesAmount: 0.0,
      unpaidBalance: 0.0,
      createdAt: DateTime.now(),
    );
  }
}

Widget buildTestApp({
  required Widget child,
  MockInventoryApiService? mockInventory,
  MockPurchasingApiService? mockPurchasing,
}) {
  return ProviderScope(
    overrides: [
      if (mockInventory != null)
        inventoryApiServiceProvider.overrideWithValue(mockInventory),
      if (mockPurchasing != null)
        purchasingApiServiceProvider.overrideWithValue(mockPurchasing),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  group('Track 3: Purchasing and Inventory Adjustments UI Tests', () {
    testWidgets('StockAdjustmentDialog displays current stock and calculates projected delta',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));

      await tester.pumpWidget(
        buildTestApp(
          mockInventory: MockInventoryApiService(),
          child: const Scaffold(
            body: StockAdjustmentDialog(
              productVariantId: 'v-1',
              productName: 'Rice 5kg Bag',
              currentStock: 25.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check initial stock badge (both current and projected show 25.00 units before input)
      expect(find.text('Adjust Stock — Rice 5kg Bag'), findsOneWidget);
      expect(find.text('25.00 units'), findsNWidgets(2));

      // Enter quantity to deduct
      final qtyFinder = find.byType(TextFormField).first;
      await tester.enterText(qtyFinder, '5');
      await tester.pumpAndSettle();

      // Projected stock should calculate: 25 - 5 = 20.00 units
      expect(find.text('20.00 units'), findsOneWidget);
      expect(find.text('25.00 units'), findsOneWidget);

      // Switch to addition
      await tester.tap(find.text('Add Stock (+)'));
      await tester.pumpAndSettle();

      // Projected stock should calculate: 25 + 5 = 30.00 units
      expect(find.text('30.00 units'), findsOneWidget);
      expect(find.text('25.00 units'), findsOneWidget);

      // Verify submit button for addition
      expect(find.text('Confirm & Add Stock'), findsOneWidget);
    });

    testWidgets('StockMovementsDialog displays ledger table and audit trail',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));

      await tester.pumpWidget(
        buildTestApp(
          mockInventory: MockInventoryApiService(),
          child: const Scaffold(
            body: StockMovementsDialog(
              productVariantId: 'v-1',
              productName: 'Rice 5kg Bag',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Stock Audit Trail — Rice 5kg Bag'), findsOneWidget);

      // Verify movement entries
      expect(find.text('+50.00'), findsOneWidget);
      expect(find.text('-2.00'), findsOneWidget);
      expect(find.text('PURCHASE_RECEIVE'), findsOneWidget);
      expect(find.text('SALE'), findsOneWidget);
    });

    testWidgets('SupplierFormDialog validates required name and renders fields',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 700));

      await tester.pumpWidget(
        buildTestApp(
          mockPurchasing: MockPurchasingApiService(),
          child: const Scaffold(
            body: SupplierFormDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add New Supplier'), findsOneWidget);
      expect(find.text('Supplier Name *'), findsOneWidget);

      // Tap Save Supplier without entering name
      await tester.tap(find.text('Save Supplier'));
      await tester.pumpAndSettle();

      // Validator error
      expect(find.text('Supplier name is required'), findsOneWidget);
    });

    testWidgets('PurchasingScreen renders PO and Supplier tabs with data tables',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildTestApp(
          mockPurchasing: MockPurchasingApiService(),
          mockInventory: MockInventoryApiService(),
          child: const PurchasingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check Tabs
      expect(find.text('Purchase Orders'), findsOneWidget);
      expect(find.text('Suppliers Directory'), findsOneWidget);

      // PO table checks
      expect(find.text('PO-20261104-0001'), findsOneWidget);
      expect(find.text('ORDERED'), findsOneWidget);

      // Switch to Suppliers Directory Tab
      await tester.tap(find.text('Suppliers Directory'));
      await tester.pumpAndSettle();

      // Supplier table checks
      expect(find.text('Pran Foods Ltd'), findsOneWidget);
      expect(find.text('Mr. Rafiq'), findsOneWidget);
      expect(find.text('01711223344'), findsOneWidget);
    });
  });
}
