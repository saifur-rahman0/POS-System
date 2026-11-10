import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/expenses/domain/models/account_transfer.dart';
import 'package:pos_client/features/expenses/domain/models/expense.dart';
import 'package:pos_client/features/expenses/data/expenses_api_service.dart';
import 'package:pos_client/features/expenses/presentation/controllers/expenses_controller.dart';
import 'package:pos_client/features/expenses/presentation/controllers/financial_accounts_controller.dart';
import 'package:pos_client/features/purchasing/data/purchasing_api_service.dart';
import 'package:pos_client/features/purchasing/domain/models/paginated_purchases.dart';
import 'package:pos_client/features/purchasing/domain/models/purchase_item.dart';
import 'package:pos_client/features/purchasing/domain/models/purchase_order.dart';
import 'package:pos_client/features/purchasing/presentation/controllers/purchasing_controller.dart';
import 'package:pos_client/features/sales/domain/models/paginated_sales.dart';
import 'package:pos_client/features/sales/domain/models/pos_transaction.dart';
import 'package:pos_client/features/sales/domain/models/sale_summary.dart';
import 'package:pos_client/features/sales/presentation/controllers/sales_history_controller.dart';
import 'package:pos_client/features/sales/presentation/views/sales_history_screen.dart';
import 'package:pos_client/features/sales/presentation/views/transaction_detail_dialog.dart';
import 'package:pos_client/features/sales/presentation/views/transactions_hub_view.dart';

void main() {
  final now = DateTime.now();

  final sampleSale = SaleSummaryModel(
    id: 'sale-001',
    receiptNo: 'REC-20261103-MAIN-0001',
    status: 'COMPLETED',
    cashierId: 'user-0001',
    customerName: 'Rahim Ahmed',
    subtotal: 1000.0,
    discountTotal: 50.0,
    taxTotal: 50.0,
    grandTotal: 1000.0,
    paidTotal: 1000.0,
    dueTotal: 0.0,
    itemsCount: 3,
    createdAt: now.subtract(const Duration(hours: 1)),
  );

  final samplePurchase = PurchaseOrderModel(
    id: 'po-001',
    businessId: 'biz-01',
    branchId: 'branch-01',
    supplierId: 'sup-01',
    supplierName: 'Akij Food & Beverage Ltd',
    referenceNo: 'PO-2026-0042',
    status: 'RECEIVED',
    subtotal: 5000.0,
    discount: 200.0,
    total: 4800.0,
    paidTotal: 4800.0,
    dueBalance: 0.0,
    createdAt: now.subtract(const Duration(hours: 2)),
    items: const [
      PurchaseItemModel(
        id: 'pi-1',
        productVariantId: 'var-1',
        productName: 'Mojo Cola 250ml',
        sku: 'BEV-MOJO-250',
        quantity: 100.0,
        unitCost: 15.0,
        lineTotal: 1500.0,
      ),
    ],
    payments: [
      PurchasePaymentModel(
        id: 'pay-sup-1',
        purchaseId: 'po-001',
        amount: 4800.0,
        method: 'BANK',
        reference: 'TRX-BANK-9912',
        paidAt: now.subtract(const Duration(hours: 2)),
      ),
    ],
  );

  final sampleExpense = ExpenseModel(
    id: 'exp-001',
    businessId: 'biz-01',
    branchId: 'branch-01',
    voucherNo: 'VCH-2026-015',
    category: 'Utilities & Internet',
    paymentMethod: 'BKASH',
    payee: 'Link3 Technologies Ltd',
    taxDeductible: true,
    amount: 1500.0,
    note: 'Monthly fiber internet bill',
    approvalStatus: 'APPROVED',
    createdBy: 'user-0001',
    createdAt: now.subtract(const Duration(hours: 3)),
  );

  final sampleTransfer = AccountTransferModel(
    id: 'trf-001',
    businessId: 'biz-01',
    fromAccountId: 'acc-safe',
    toAccountId: 'acc-bank',
    amount: 10000.0,
    referenceNo: 'TRF-SAFE-BANK-01',
    note: 'End of week safe cash deposit to Bank',
    transferDate: now.subtract(const Duration(hours: 4)),
    createdBy: 'user-0001',
    createdAt: now.subtract(const Duration(hours: 4)),
    fromAccountName: 'Main Store Safe',
    toAccountName: 'City Bank Corporate',
  );

  group('PosTransactionModel Domain Tests', () {
    test('Constructs from SaleSummaryModel as Inflow', () {
      final txn = PosTransactionModel.fromSaleSummary(sampleSale);

      expect(txn.id, 'sale-001');
      expect(txn.type, PosTransactionType.sale);
      expect(txn.direction, TransactionDirection.inflow);
      expect(txn.referenceNo, 'REC-20261103-MAIN-0001');
      expect(txn.partyName, 'Rahim Ahmed');
      expect(txn.amount, 1000.0);
      expect(txn.status, 'COMPLETED');
      expect(txn.isInflow, isTrue);
      expect(txn.isOutflow, isFalse);
    });

    test('Constructs from PurchaseOrderModel as Outflow with items & payments', () {
      final txn = PosTransactionModel.fromPurchaseOrder(samplePurchase);

      expect(txn.id, 'po-001');
      expect(txn.type, PosTransactionType.purchase);
      expect(txn.direction, TransactionDirection.outflow);
      expect(txn.referenceNo, 'PO-2026-0042');
      expect(txn.partyName, 'Akij Food & Beverage Ltd');
      expect(txn.amount, 4800.0);
      expect(txn.status, 'RECEIVED');
      expect(txn.items.length, 1);
      expect(txn.items.first.productName, 'Mojo Cola 250ml');
      expect(txn.payments.length, 1);
      expect(txn.payments.first.method, 'BANK');
    });

    test('Constructs from ExpenseModel as Outflow', () {
      final txn = PosTransactionModel.fromExpense(sampleExpense);

      expect(txn.id, 'exp-001');
      expect(txn.type, PosTransactionType.expense);
      expect(txn.direction, TransactionDirection.outflow);
      expect(txn.referenceNo, 'VCH-2026-015');
      expect(txn.partyName, 'Link3 Technologies Ltd');
      expect(txn.amount, 1500.0);
      expect(txn.paymentMethod, 'BKASH');
      expect(txn.status, 'APPROVED');
    });

    test('Constructs from AccountTransferModel as Neutral Internal Transfer', () {
      final txn = PosTransactionModel.fromTransfer(sampleTransfer);

      expect(txn.id, 'trf-001');
      expect(txn.type, PosTransactionType.transfer);
      expect(txn.direction, TransactionDirection.neutral);
      expect(txn.partyName, 'Main Store Safe ➔ City Bank Corporate');
      expect(txn.amount, 10000.0);
    });

    test('TransactionKpis calculates Inflow, Outflow, and Net Cash Flow', () {
      final txns = [
        PosTransactionModel.fromSaleSummary(sampleSale),
        PosTransactionModel.fromPurchaseOrder(samplePurchase),
        PosTransactionModel.fromExpense(sampleExpense),
        PosTransactionModel.fromTransfer(sampleTransfer),
      ];

      final kpis = TransactionKpis.fromTransactions(txns);

      expect(kpis.totalInflow, 1000.0);
      expect(kpis.inflowCount, 1);
      expect(kpis.totalOutflow, 4800.0 + 1500.0);
      expect(kpis.outflowCount, 2);
      expect(kpis.netCashFlow, 1000.0 - 6300.0);
      expect(kpis.totalCount, 4);
    });
  });

  group('TransactionsHub UI Widget Tests', () {
    testWidgets('TransactionsHubView renders KPI cards, toolbar and list rows',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 800));

      final sampleSalesPage = PaginatedSalesModel(
        items: [sampleSale],
        total: 1,
        page: 1,
        pageSize: 15,
        totalPages: 1,
      );

      final samplePurchasesPage = PaginatedPurchasesModel(
        items: [samplePurchase],
        total: 1,
        page: 1,
        pageSize: 15,
        totalPages: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesListProvider.overrideWith((ref) => sampleSalesPage),
            purchasesControllerProvider.overrideWith(
              (ref) => PurchasesNotifierMock(samplePurchasesPage),
            ),
            expensesListProvider.overrideWith(
              (ref) => ExpensesListNotifierMock([sampleExpense]),
            ),
            accountTransfersProvider.overrideWith(
              (ref) async => [sampleTransfer],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16.0),
                child: TransactionsHubView(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify KPI Summary Cards
      expect(find.text('Total Inflow (Sales & In)'), findsOneWidget);
      expect(find.text('Total Outflow (Purchases & Exp)'), findsOneWidget);
      expect(find.text('Net Cash Flow Position'), findsOneWidget);
      expect(find.text('Total Ledger Entries'), findsOneWidget);

      // 2. Verify Toolbar elements
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('All Types'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);

      // 3. Verify Transactions List contains records
      expect(find.text('REC-20261103-MAIN-0001'), findsWidgets);
      expect(find.text('PO-2026-0042'), findsOneWidget);
      expect(find.text('VCH-2026-015'), findsOneWidget);
      expect(find.text('Akij Food & Beverage Ltd'), findsOneWidget);
      expect(find.text('Link3 Technologies Ltd'), findsOneWidget);
    });

    testWidgets('TransactionDetailDialog displays line items and financial breakdown',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final txn = PosTransactionModel.fromPurchaseOrder(samplePurchase);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionDetailDialog(transaction: txn),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PO-2026-0042'), findsOneWidget);
      expect(find.text('PURCHASE'), findsOneWidget);
      expect(find.text('RECEIVED'), findsOneWidget);
      expect(find.text('Akij Food & Beverage Ltd'), findsOneWidget);
      expect(find.text('Mojo Cola 250ml'), findsOneWidget);
      expect(find.text('BEV-MOJO-250'), findsOneWidget);
      expect(find.text('Payment Allocations'), findsOneWidget);
      expect(find.text('BANK'), findsWidgets);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('SalesHistoryScreen switches smoothly between Sales Receipts and All Transactions',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 800));

      final sampleSalesPage = PaginatedSalesModel(
        items: [sampleSale],
        total: 1,
        page: 1,
        pageSize: 15,
        totalPages: 1,
      );

      final samplePurchasesPage = PaginatedPurchasesModel(
        items: [samplePurchase],
        total: 1,
        page: 1,
        pageSize: 15,
        totalPages: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesListProvider.overrideWith((ref) => sampleSalesPage),
            purchasesControllerProvider.overrideWith(
              (ref) => PurchasesNotifierMock(samplePurchasesPage),
            ),
            expensesListProvider.overrideWith(
              (ref) => ExpensesListNotifierMock([sampleExpense]),
            ),
            accountTransfersProvider.overrideWith(
              (ref) async => [sampleTransfer],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SalesHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial tab is 0: Sales Receipts
      expect(find.text('Sales History & Receipts'), findsOneWidget);
      expect(find.text('Sales Receipts'), findsOneWidget);
      expect(find.text('All Transactions'), findsOneWidget);

      // Tap 'All Transactions' tab
      await tester.tap(find.text('All Transactions'));
      await tester.pumpAndSettle();

      // Now header switches to All Transactions
      expect(find.text('All Transactions History & Audit Ledger'), findsOneWidget);
      expect(find.text('Total Inflow (Sales & In)'), findsOneWidget);
      expect(find.text('Total Outflow (Purchases & Exp)'), findsOneWidget);
    });
  });
}

// Mock StateNotifiers for testing
class PurchasesNotifierMock extends PurchasesNotifier {
  PurchasesNotifierMock(PaginatedPurchasesModel paginated)
      : super(PurchasingApiServiceMock()) {
    state = state.copyWith(paginated: paginated, isLoading: false);
  }
}

class ExpensesListNotifierMock extends ExpensesListNotifier {
  ExpensesListNotifierMock(List<ExpenseModel> list)
      : super(ExpensesApiServiceMock()) {
    state = AsyncValue.data(list);
  }
}

class PurchasingApiServiceMock implements PurchasingApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ExpensesApiServiceMock implements ExpensesApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
