import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/checkout/domain/models/sale_receipt.dart';
import 'package:pos_client/features/sales/data/sales_api_service.dart';
import 'package:pos_client/features/sales/domain/models/paginated_sales.dart';
import 'package:pos_client/features/sales/domain/models/sale_return.dart';
import 'package:pos_client/features/sales/domain/models/sale_returnable_item.dart';
import 'package:pos_client/features/sales/domain/models/sale_summary.dart';
import 'package:pos_client/features/sales/presentation/controllers/sales_history_controller.dart';
import 'package:pos_client/features/sales/presentation/views/return_dialog.dart';
import 'package:pos_client/features/sales/presentation/views/sale_detail_drawer.dart';
import 'package:pos_client/features/sales/presentation/views/sales_history_screen.dart';

class MockSalesApiService implements SalesApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<SaleReturnableItemModel>> getReturnableItems(String saleId) async {
    return const [
      SaleReturnableItemModel(
        saleItemId: 'item-1',
        productVariantId: 'var-1',
        productName: 'Mechanical Keyboard',
        sku: 'KB-01',
        quantitySold: 2.0,
        quantityReturned: 0.0,
        quantityReturnable: 2.0,
        unitPrice: 150.0,
        lineTotal: 300.0,
      ),
    ];
  }

  @override
  Future<SaleReceiptModel> getSaleDetail(String saleId) async {
    return SaleReceiptModel(
      id: saleId,
      receiptNo: 'REC-20261103-MAIN-0001',
      status: 'COMPLETED',
      cashierId: 'user-0001',
      customerName: 'Alice Walk-in',
      financials: const SaleFinancialsModel(
        subtotal: 300.0,
        discountTotal: 0.0,
        taxTotal: 15.0,
        grandTotal: 315.0,
        paidTotal: 315.0,
        dueTotal: 0.0,
        changeAmount: 0.0,
      ),
      items: const [
        SaleReceiptItemModel(
          id: 'item-1',
          productVariantId: 'var-1',
          productName: 'Mechanical Keyboard',
          sku: 'KB-01',
          quantity: 2.0,
          unitPrice: 150.0,
          discount: 0.0,
          lineTotal: 300.0,
        ),
      ],
      payments: const [
        SaleReceiptPaymentModel(
          id: 'pay-1',
          method: 'CASH',
          amount: 315.0,
          status: 'CONFIRMED',
        ),
      ],
      createdAt: DateTime(2026, 11, 3, 14, 30),
    );
  }

  @override
  Future<List<SaleReturnModel>> getSaleReturns(String saleId) async {
    return [];
  }

  @override
  Future<SaleReturnModel> createReturn(
    String saleId, {
    required List<Map<String, dynamic>> items,
    String? reason,
    String refundMethod = 'CASH',
  }) async {
    return SaleReturnModel(
      id: 'ret-001',
      businessId: 'biz-001',
      branchId: 'branch-001',
      originalSaleId: saleId,
      returnNo: 'RET-20261103-MAIN-0001',
      status: 'COMPLETED',
      refundTotal: 150.0,
      reason: reason,
      createdBy: 'user-001',
      createdAt: DateTime.now(),
      items: const [
        SaleReturnItemModel(
          id: 'ri-1',
          returnId: 'ret-001',
          originalSaleItemId: 'item-1',
          productVariantId: 'var-1',
          productName: 'Mechanical Keyboard',
          sku: 'KB-01',
          quantity: 1.0,
          refundAmount: 150.0,
          restockStatus: 'RESTOCKED',
        ),
      ],
    );
  }
}

void main() {
  final sampleSaleSummary = SaleSummaryModel(
    id: 'sale-001',
    receiptNo: 'REC-20261103-MAIN-0001',
    status: 'COMPLETED',
    cashierId: 'user-0001',
    customerName: 'Alice Walk-in',
    subtotal: 300.0,
    discountTotal: 0.0,
    taxTotal: 15.0,
    grandTotal: 315.0,
    paidTotal: 315.0,
    dueTotal: 0.0,
    itemsCount: 2,
    createdAt: DateTime(2026, 11, 3, 14, 30),
  );

  final samplePaginatedSales = PaginatedSalesModel(
    items: [sampleSaleSummary],
    total: 1,
    page: 1,
    pageSize: 15,
    totalPages: 1,
  );

  testWidgets('SalesHistoryScreen renders sales table with receipt details',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesListProvider.overrideWith((ref) => samplePaginatedSales),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SalesHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Receipt Details
    expect(find.text('Sales History & Receipts'), findsOneWidget);
    expect(find.text('REC-20261103-MAIN-0001'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('৳ 315.00'), findsOneWidget);
    expect(find.text('Alice Walk-in'), findsOneWidget);

    // Verify filter buttons exist
    expect(find.text('All Time'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Last 7 Days'), findsOneWidget);
  });

  testWidgets('ReturnDialog increments return quantity and calculates refund total',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final mockApi = MockSalesApiService();
    var returnSuccessCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesApiServiceProvider.overrideWithValue(mockApi),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ReturnDialog(
              saleId: 'sale-001',
              receiptNo: 'REC-20261103-MAIN-0001',
              onReturnSuccess: () {
                returnSuccessCalled = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify loaded item
    expect(find.text('Process Customer Return'), findsOneWidget);
    expect(find.text('Mechanical Keyboard'), findsOneWidget);
    expect(find.text('Returnable: 2 (Sold: 2)'), findsOneWidget);
    expect(find.text('৳ 0.00'), findsOneWidget); // Initial total refund

    // Tap + to return 1 item
    final addBtn = find.byIcon(Icons.add);
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Verify quantity changed to 1 and refund is ৳ 150.00
    expect(find.text('1'), findsOneWidget);
    expect(find.text('৳ 150.00'), findsOneWidget);

    // Tap Complete Refund
    final submitBtn = find.text('Complete Refund');
    expect(submitBtn, findsOneWidget);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(returnSuccessCalled, isTrue);
  });

  testWidgets('SaleDetailDrawer renders breakdown and action buttons',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final mockApi = MockSalesApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesApiServiceProvider.overrideWithValue(mockApi),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SaleDetailDrawer(
              saleId: 'sale-001',
              onStateChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify receipt details in drawer
    expect(find.text('REC-20261103-MAIN-0001'), findsOneWidget);
    expect(find.text('Customer: Alice Walk-in'), findsOneWidget);
    expect(find.text('Mechanical Keyboard'), findsOneWidget);
    expect(find.text('Grand Total'), findsOneWidget);
    expect(find.text('Reprint Receipt'), findsOneWidget);
    expect(find.text('Return / Refund'), findsOneWidget);
  });
}
