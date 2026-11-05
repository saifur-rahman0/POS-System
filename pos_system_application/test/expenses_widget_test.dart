import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_client/features/expenses/data/expenses_api_service.dart';
import 'package:pos_client/features/expenses/domain/models/account_transfer.dart';
import 'package:pos_client/features/expenses/domain/models/ap_aging_report.dart';
import 'package:pos_client/features/expenses/domain/models/cash_flow_report.dart';
import 'package:pos_client/features/expenses/domain/models/expense.dart';
import 'package:pos_client/features/expenses/domain/models/expense_category.dart';
import 'package:pos_client/features/expenses/domain/models/financial_account.dart';
import 'package:pos_client/features/expenses/domain/models/recurring_expense.dart';
import 'package:pos_client/features/expenses/presentation/controllers/expenses_controller.dart';
import 'package:pos_client/features/expenses/presentation/views/account_transfer_dialog.dart';
import 'package:pos_client/features/expenses/presentation/views/expense_form_dialog.dart';
import 'package:pos_client/features/expenses/presentation/views/expenses_screen.dart';
import 'package:pos_client/features/expenses/presentation/views/financial_accounts_screen.dart';

final dummyCategory = ExpenseCategoryModel(
  id: 'cat-1',
  businessId: 'biz-1',
  name: 'Office Rent & Tenancy',
  code: 'RENT',
  description: 'Monthly store rental',
  monthlyBudget: 50000.0,
  currentMonthSpent: 45000.0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

final dummyAccount = FinancialAccountModel(
  id: 'acc-1',
  businessId: 'biz-1',
  accountName: 'Main Store Safe',
  accountType: 'SAFE',
  openingBalance: 30000.0,
  currentBalance: 75000.0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

final dummyBank = FinancialAccountModel(
  id: 'acc-2',
  businessId: 'biz-1',
  accountName: 'Corporate Current Account',
  accountType: 'BANK',
  bankName: 'City Bank PLC',
  accountNumber: '1102938475',
  openingBalance: 100000.0,
  currentBalance: 150000.0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

final dummyExpense = ExpenseModel(
  id: 'exp-1',
  businessId: 'biz-1',
  branchId: 'branch-1',
  voucherNo: 'EXP-20261105-MAIN-0001',
  category: 'Office Rent & Tenancy',
  categoryId: 'cat-1',
  paymentAccountId: 'acc-2',
  paymentMethod: 'BANK',
  payee: 'Commercial Landlord',
  taxDeductible: true,
  amount: 35000.0,
  approvalStatus: 'PENDING_APPROVAL',
  createdBy: 'user-1',
  createdAt: DateTime.now(),
);

final dummyRecurring = RecurringExpenseModel(
  id: 'rec-1',
  businessId: 'biz-1',
  categoryId: 'cat-1',
  title: 'High-Speed Fiber Internet',
  amount: 3500.0,
  frequency: 'MONTHLY',
  nextDueDate: DateTime.now(),
  autoPost: true,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

final dummyApAging = APAgeingReportModel(
  asOfDate: DateTime.now(),
  totalPayable: 45000.0,
  buckets: [
    APAgeingBucketModel(bucketName: '0-30 Days', totalAmount: 15000.0, count: 2),
    APAgeingBucketModel(bucketName: '31-60 Days', totalAmount: 30000.0, count: 1),
    APAgeingBucketModel(bucketName: '61-90 Days', totalAmount: 0.0, count: 0),
    APAgeingBucketModel(bucketName: '90+ Days', totalAmount: 0.0, count: 0),
  ],
);

final dummyCashFlow = CashFlowReportModel(
  startDate: DateTime.now().subtract(const Duration(days: 30)),
  endDate: DateTime.now(),
  totalCashIn: 85000.0,
  totalCashOut: 45000.0,
  netCashFlow: 40000.0,
  inflowBreakdown: {'Sales: CASH': 50000.0, 'Sales: BKASH': 35000.0},
  outflowBreakdown: {'Expense: RENT': 35000.0, 'Supplier Payment: BANK': 10000.0},
);

class MockExpensesApiService implements ExpensesApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<ExpenseCategoryModel>> getCategories({bool? isActive}) async => [dummyCategory];

  @override
  Future<List<FinancialAccountModel>> getFinancialAccounts({String? branchId, bool? isActive}) async =>
      [dummyAccount, dummyBank];

  @override
  Future<List<ExpenseModel>> getExpenses({
    String? branchId,
    String? categoryId,
    String? paymentAccountId,
    String? approvalStatus,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async =>
      [dummyExpense];

  @override
  Future<List<RecurringExpenseModel>> getRecurringExpenses({String? branchId, bool? isActive}) async =>
      [dummyRecurring];

  @override
  Future<List<AccountTransferModel>> getTransfers({String? accountId, int limit = 50}) async => [];

  @override
  Future<APAgeingReportModel> getAPAgeingReport({DateTime? asOfDate}) async => dummyApAging;

  @override
  Future<CashFlowReportModel> getCashFlowReport({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  }) async =>
      dummyCashFlow;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track 10: Expense Domain Model Tests', () {
    test('ExpenseCategoryModel computes budget utilization and over-budget flag', () {
      expect(dummyCategory.budgetUtilization, 0.9); // 45000 / 50000
      expect(dummyCategory.isOverBudget, isFalse);

      final overCategory = ExpenseCategoryModel(
        id: 'cat-2',
        businessId: 'biz-1',
        name: 'Entertainment',
        code: 'ENT',
        monthlyBudget: 10000.0,
        currentMonthSpent: 12500.0,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(overCategory.budgetUtilization, 1.25);
      expect(overCategory.isOverBudget, isTrue);
    });

    test('FinancialAccountModel displays human-readable type', () {
      expect(dummyAccount.typeDisplayName, 'Store Safe');
      expect(dummyBank.typeDisplayName, 'Bank Account');
    });

    test('RecurringExpenseModel correctly identifies due today or overdue', () {
      expect(dummyRecurring.isDueTodayOrOverdue, isTrue);

      final futureRecurring = RecurringExpenseModel(
        id: 'rec-2',
        businessId: 'biz-1',
        categoryId: 'cat-1',
        title: 'Annual Trade License',
        amount: 15000.0,
        frequency: 'ANNUAL',
        nextDueDate: DateTime.now().add(const Duration(days: 90)),
        autoPost: false,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(futureRecurring.isDueTodayOrOverdue, isFalse);
    });

    test('ExpenseModel approval status getters evaluate accurately', () {
      expect(dummyExpense.isPendingApproval, isTrue);
      expect(dummyExpense.isApproved, isFalse);
    });
  });

  group('Track 10: Widget Tests for Dialogs and Screens', () {
    testWidgets('ExpenseFormDialog renders fields and shows manager approval warning when amount > 5000',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expensesApiServiceProvider.overrideWithValue(MockExpensesApiService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExpenseFormDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Record Expense Voucher'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);

      // Enter amount 2500 -> no warning
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (BDT) *'), '2500');
      await tester.pumpAndSettle();
      expect(find.textContaining('Payouts over ৳ 5,000 require manager approval'), findsNothing);

      // Enter amount 12000 -> shows manager approval banner
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount (BDT) *'), '12000');
      await tester.pumpAndSettle();
      expect(find.textContaining('Payouts over ৳ 5,000 require manager approval'), findsOneWidget);
    });

    testWidgets('AccountTransferDialog renders source, destination, and amount fields', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expensesApiServiceProvider.overrideWithValue(MockExpensesApiService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AccountTransferDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inter-Account Transfer'), findsOneWidget);
      expect(find.text('Execute Transfer'), findsOneWidget);
    });

    testWidgets('FinancialAccountsScreen renders treasury cards and AP aging breakdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expensesApiServiceProvider.overrideWithValue(MockExpensesApiService()),
          ],
          child: const MaterialApp(
            home: FinancialAccountsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Financial Accounts & Treasury'), findsOneWidget);
      expect(find.text('Total Liquid Capital'), findsOneWidget);
      expect(find.text('Accounts Payable (AP) Aging Breakdown'), findsOneWidget);
      expect(find.text('30-Day Cash Flow Summary'), findsOneWidget);
      expect(find.text('0-30 Days'), findsOneWidget);
      expect(find.text('31-60 Days'), findsOneWidget);
    });

    testWidgets('ExpensesScreen renders tabs, vouchers, and budget progress', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expensesApiServiceProvider.overrideWithValue(MockExpensesApiService()),
          ],
          child: const MaterialApp(
            home: ExpensesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expense Management'), findsOneWidget);
      expect(find.text('Expense Vouchers'), findsOneWidget);
      expect(find.text('Category Budgets'), findsOneWidget);
      expect(find.text('Recurring Schedules'), findsOneWidget);
      expect(find.text(dummyExpense.voucherNo!), findsOneWidget);
      expect(find.text('PENDING_APPROVAL'), findsOneWidget);

      // Switch to Category Budgets Tab
      await tester.tap(find.text('Category Budgets'));
      await tester.pumpAndSettle();

      expect(find.text(dummyCategory.name), findsOneWidget);
      expect(find.text('90.0% utilized'), findsOneWidget);

      // Switch to Recurring Schedules Tab
      await tester.tap(find.text('Recurring Schedules'));
      await tester.pumpAndSettle();

      expect(find.text(dummyRecurring.title), findsOneWidget);
    });
  });
}
