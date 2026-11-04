import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/branches/data/branches_api_service.dart';
import 'package:pos_client/features/branches/domain/models/branch.dart';
import 'package:pos_client/features/branches/presentation/controllers/branches_controller.dart';
import 'package:pos_client/features/branches/presentation/views/branch_form_dialog.dart';
import 'package:pos_client/features/branches/presentation/views/branches_screen.dart';
import 'package:pos_client/features/catalog/domain/models/paginated_products.dart';
import 'package:pos_client/features/catalog/presentation/controllers/catalog_providers.dart';
import 'package:pos_client/features/inventory/data/transfers_api_service.dart';
import 'package:pos_client/features/inventory/domain/models/stock_transfer.dart';
import 'package:pos_client/features/inventory/presentation/controllers/transfers_controller.dart';
import 'package:pos_client/features/inventory/presentation/views/create_transfer_dialog.dart';
import 'package:pos_client/features/inventory/presentation/views/cross_branch_stock_dialog.dart';

class MockBranchesApiService implements BranchesApiService {
  List<BranchModel> mockBranches = [];
  bool createBranchCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<BranchModel>> getBranches({bool? isActive}) async {
    return mockBranches;
  }

  @override
  Future<BranchModel> createBranch({
    required String name,
    String? code,
    String? address,
    String? phone,
    bool isActive = true,
  }) async {
    createBranchCalled = true;
    final b = BranchModel(
      id: 'branch-new-1',
      businessId: 'biz-1',
      name: name,
      code: code,
      address: address,
      phone: phone,
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    mockBranches.add(b);
    return b;
  }
}

class MockTransfersApiService implements TransfersApiService {
  List<StockTransferModel> mockTransfers = [];
  List<CrossBranchStockItemModel> mockCrossStock = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<StockTransferModel>> listTransfers({
    String? sourceBranchId,
    String? destinationBranchId,
    String? status,
  }) async {
    return mockTransfers;
  }

  @override
  Future<List<CrossBranchStockItemModel>> getCrossBranchStock(
      String productVariantId) async {
    return mockCrossStock;
  }
}

void main() {
  late MockBranchesApiService mockBranchesApi;
  late MockTransfersApiService mockTransfersApi;

  final sampleBranch1 = BranchModel(
    id: 'branch-1',
    businessId: 'biz-1',
    name: 'Main Store Flagship',
    code: 'MAIN',
    address: '123 Commercial Ave, Zone 1',
    phone: '+8801700112233',
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleBranch2 = BranchModel(
    id: 'branch-2',
    businessId: 'biz-1',
    name: 'Downtown Express',
    code: 'DT-01',
    address: '45 Lake View Road',
    phone: '+8801811223344',
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleTransfer = StockTransferModel(
    id: 'transfer-1',
    businessId: 'biz-1',
    transferNo: 'TRF-20261104-0001',
    sourceBranchId: 'branch-1',
    sourceBranchName: 'Main Store Flagship',
    destinationBranchId: 'branch-2',
    destinationBranchName: 'Downtown Express',
    status: 'IN_TRANSIT',
    createdBy: 'user-1',
    createdAt: DateTime.now(),
    totalItemsCount: 1,
    totalQuantity: 25.0,
    items: [
      const StockTransferItemModel(
        id: 'ti-1',
        transferId: 'transfer-1',
        productVariantId: 'var-1',
        productName: 'Hammer',
        quantity: 25.0,
      ),
    ],
  );

  setUp(() {
    mockBranchesApi = MockBranchesApiService();
    mockTransfersApi = MockTransfersApiService();
    mockBranchesApi.mockBranches = [sampleBranch1, sampleBranch2];
    mockTransfersApi.mockTransfers = [sampleTransfer];
  });

  Widget buildTestableWidget(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        branchesApiServiceProvider.overrideWithValue(mockBranchesApi),
        transfersApiServiceProvider.overrideWithValue(mockTransfersApi),
        paginatedProductsProvider.overrideWith(
          (ref) async => const PaginatedProducts(
            items: [],
            total: 0,
            page: 1,
            limit: 15,
            pages: 1,
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  testWidgets('BranchesScreen renders branches list and active terminal',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      buildTestableWidget(
        const BranchesScreen(),
        overrides: [
          activeBranchProvider.overrideWith((ref) => sampleBranch1),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Verify Tab Headers
    expect(find.text('Retail Branches'), findsOneWidget);
    expect(find.text('Stock Transfers'), findsOneWidget);

    // Verify Branches tab content
    expect(find.text('Store Locations'), findsOneWidget);
    expect(find.text('Main Store Flagship'), findsOneWidget);
    expect(find.text('Downtown Express'), findsOneWidget);
    expect(find.text('MAIN'), findsOneWidget);
    expect(find.text('DT-01'), findsOneWidget);
    expect(find.text('ACTIVE TERMINAL'), findsOneWidget);
    expect(find.text('Set as Active Store'), findsOneWidget);
  });

  testWidgets('BranchFormDialog validates name and calls createBranch',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));

    await tester.pumpWidget(
      buildTestableWidget(
        const BranchFormDialog(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add New Branch'), findsOneWidget);
    expect(find.text('Branch Name *'), findsOneWidget);

    // Tap submit without entering name -> shows validation error
    await tester.tap(find.text('Create Branch'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);

    // Enter branch details
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Branch Name *'), 'Uttara Hub');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Store Code'), 'UTR-01');
    await tester.tap(find.text('Create Branch'));
    await tester.pumpAndSettle();

    expect(mockBranchesApi.createBranchCalled, isTrue);
  });

  testWidgets('CreateTransferDialog renders branch selectors and validation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));

    await tester.pumpWidget(
      buildTestableWidget(
        CreateTransferDialog(
          branches: [sampleBranch1, sampleBranch2],
          initialSourceBranchId: sampleBranch1.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Stock Transfer'), findsOneWidget);
    expect(find.text('Transfer Quantity *'), findsOneWidget);
    expect(find.text('Create Draft Order'), findsOneWidget);
  });

  testWidgets('CrossBranchStockDialog displays network availability',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));

    mockTransfersApi.mockCrossStock = [
      const CrossBranchStockItemModel(
        branchId: 'branch-1',
        branchName: 'Main Store Flagship',
        branchCode: 'MAIN',
        quantityOnHand: 45.0,
        isActive: true,
      ),
      const CrossBranchStockItemModel(
        branchId: 'branch-2',
        branchName: 'Downtown Express',
        branchCode: 'DT-01',
        quantityOnHand: 3.0,
        isActive: true,
      ),
    ];

    await tester.pumpWidget(
      buildTestableWidget(
        const CrossBranchStockDialog(
          productVariantId: 'var-1',
          productName: 'Ergonomic Keyboard',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cross-Store Inventory'), findsOneWidget);
    expect(find.text('Ergonomic Keyboard'), findsOneWidget);
    expect(find.text('Total Network Stock:'), findsOneWidget);
    expect(find.text('48.0 units'), findsOneWidget);
    expect(find.text('45.0 in stock'), findsOneWidget);
    expect(find.text('3.0 in stock'), findsOneWidget);
  });
}
