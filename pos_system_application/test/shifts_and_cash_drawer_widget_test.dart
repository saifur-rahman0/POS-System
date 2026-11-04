import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/shifts/data/shifts_api_service.dart';
import 'package:pos_client/features/shifts/domain/models/paginated_shifts.dart';
import 'package:pos_client/features/shifts/domain/models/register_shift.dart';
import 'package:pos_client/features/shifts/domain/models/z_report.dart';
import 'package:pos_client/features/shifts/presentation/controllers/shift_controller.dart';
import 'package:pos_client/features/shifts/presentation/widgets/cash_in_out_dialog.dart';
import 'package:pos_client/features/shifts/presentation/widgets/close_shift_dialog.dart';
import 'package:pos_client/features/shifts/presentation/widgets/open_shift_dialog.dart';
import 'package:pos_client/features/shifts/presentation/widgets/shift_status_bar.dart';
import 'package:pos_client/features/shifts/presentation/widgets/z_report_dialog.dart';

class MockShiftsApiService implements ShiftsApiService {
  RegisterShiftModel? mockCurrentShift;
  bool openShiftCalled = false;
  bool cashInCalled = false;
  bool cashOutCalled = false;
  bool closeShiftCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<RegisterShiftModel?> getCurrentShift({String? branchId}) async {
    return mockCurrentShift;
  }

  @override
  Future<RegisterShiftModel> openShift({
    required double openingCash,
    String? notes,
    String? deviceId,
    String? branchId,
  }) async {
    openShiftCalled = true;
    final shift = RegisterShiftModel(
      id: 'shift-12345678',
      businessId: 'biz-1',
      branchId: 'branch-1',
      branchName: 'Main Store',
      userId: 'user-1',
      cashierName: 'Rahim Cashier',
      status: 'OPEN',
      openedAt: DateTime.now(),
      openingCash: openingCash,
      openingNotes: notes,
      totals: ShiftSummaryTotalsModel(
        openingCash: openingCash,
        cashSales: 0.0,
        cashIn: 0.0,
        cashRefunds: 0.0,
        cashOut: 0.0,
        expectedCash: openingCash,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    mockCurrentShift = shift;
    return shift;
  }

  @override
  Future<ShiftCashTransactionModel> recordCashIn({
    required String shiftId,
    required double amount,
    required String reason,
    String? notes,
  }) async {
    cashInCalled = true;
    return ShiftCashTransactionModel(
      id: 'tx-in-1',
      businessId: 'biz-1',
      branchId: 'branch-1',
      accountId: 'MAIN_CASH_DRAWER',
      direction: 'IN',
      amount: amount,
      referenceType: 'SHIFT_CASH_IN',
      referenceId: shiftId,
      note: notes,
      createdBy: 'user-1',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<ShiftCashTransactionModel> recordCashOut({
    required String shiftId,
    required double amount,
    required String reason,
    String? notes,
  }) async {
    cashOutCalled = true;
    return ShiftCashTransactionModel(
      id: 'tx-out-1',
      businessId: 'biz-1',
      branchId: 'branch-1',
      accountId: 'MAIN_CASH_DRAWER',
      direction: 'OUT',
      amount: amount,
      referenceType: 'SHIFT_CASH_OUT',
      referenceId: shiftId,
      note: notes,
      createdBy: 'user-1',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<RegisterShiftModel> closeShift({
    required String shiftId,
    required double closingCashCounted,
    String? notes,
    Map<String, int> denominations = const {},
  }) async {
    closeShiftCalled = true;
    return RegisterShiftModel(
      id: shiftId,
      businessId: 'biz-1',
      branchId: 'branch-1',
      userId: 'user-1',
      status: 'CLOSED',
      openedAt: DateTime.now().subtract(const Duration(hours: 8)),
      closedAt: DateTime.now(),
      openingCash: 1000.0,
      closingCashCounted: closingCashCounted,
      closingCashExpected: 1500.0,
      cashDifference: closingCashCounted - 1500.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ZReportModel> getZReport({required String shiftId}) async {
    return ZReportModel(
      shiftId: shiftId,
      businessName: 'Metro Superstore Ltd',
      branchName: 'Gulshan Branch',
      cashierUsername: 'cashier_rahim',
      cashierFullName: 'Abdur Rahim',
      status: 'CLOSED',
      openedAt: DateTime(2026, 11, 4, 9, 0),
      closedAt: DateTime(2026, 11, 4, 18, 0),
      durationMinutes: 540,
      cashReconciliation: const CashReconciliationModel(
        openingFloat: 1000.0,
        cashSales: 3500.0,
        cashIn: 500.0,
        cashRefunds: 200.0,
        cashOut: 300.0,
        expectedInDrawer: 4500.0,
        actualCounted: 4500.0,
        difference: 0.0,
        varianceStatus: 'BALANCED',
      ),
      tendersBreakdown: const [
        TenderBreakdownModel(method: 'CASH', count: 18, totalAmount: 3500.0),
        TenderBreakdownModel(method: 'CARD', count: 10, totalAmount: 2200.0),
        TenderBreakdownModel(method: 'BKASH', count: 6, totalAmount: 1100.0),
      ],
      salesSummary: const SalesPerformanceSummaryModel(
        grossSales: 6800.0,
        discountTotal: 200.0,
        netSales: 6600.0,
        taxTotal: 330.0,
        totalTransactions: 34,
        completedSales: 33,
        voidedSales: 1,
        returnsCount: 2,
        returnsTotal: 200.0,
      ),
      generatedAt: DateTime(2026, 11, 4, 18, 5),
    );
  }

  @override
  Future<PaginatedShiftsModel> listShifts({
    String? branchId,
    String? userId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PaginatedShiftsModel(
      items: [],
      total: 0,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    );
  }
}

Widget createTestApp({
  required Widget child,
  required MockShiftsApiService mockService,
  RegisterShiftModel? initialShift,
}) {
  return ProviderScope(
    overrides: [
      shiftsApiServiceProvider.overrideWithValue(mockService),
      if (initialShift != null)
        currentShiftProvider.overrideWith((ref) => CurrentShiftNotifier(mockService, initialShift)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late MockShiftsApiService mockService;

  setUp(() {
    mockService = MockShiftsApiService();
  });

  testWidgets('OpenShiftDialog renders starting float and quick chips', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 700));

    await tester.pumpWidget(
      createTestApp(
        child: const OpenShiftDialog(),
        mockService: mockService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Register Shift'), findsOneWidget);
    expect(find.text('Starting Cash Float (৳) *'), findsOneWidget);
    expect(find.text('1000.00'), findsOneWidget);
    expect(find.text('+৳500'), findsOneWidget);
    expect(find.text('+৳2000'), findsOneWidget);

    // Tap quick chip +৳2000
    await tester.tap(find.text('+৳2000'));
    await tester.pumpAndSettle();
    expect(find.text('2000.00'), findsOneWidget);

    // Tap Start Shift
    await tester.tap(find.text('Start Shift'));
    await tester.pumpAndSettle();

    expect(mockService.openShiftCalled, isTrue);
  });

  testWidgets('CashInOutDialog toggles Cash In and Cash Out with drawer checking', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));

    final openShift = RegisterShiftModel(
      id: 'shift-open-1',
      businessId: 'biz-1',
      branchId: 'branch-1',
      userId: 'user-1',
      status: 'OPEN',
      openedAt: DateTime.now(),
      openingCash: 1000.0,
      totals: const ShiftSummaryTotalsModel(
        openingCash: 1000.0,
        cashSales: 500.0,
        cashIn: 0.0,
        cashRefunds: 0.0,
        cashOut: 0.0,
        expectedCash: 1500.0,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    mockService.mockCurrentShift = openShift;

    await tester.pumpWidget(
      createTestApp(
        child: CashInOutDialog(shift: openShift, initialType: CashMovementType.cashIn),
        mockService: mockService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cash In (Deposit)'), findsOneWidget);
    expect(find.text('Live Expected Drawer Cash:'), findsOneWidget);
    expect(find.text('৳1500.00'), findsOneWidget);

    // Toggle to Cash Out
    await tester.tap(find.text('Cash Out (-)'));
    await tester.pumpAndSettle();
    expect(find.text('Cash Out (Drop / Expense)'), findsOneWidget);
    expect(find.text('Confirm Cash Out'), findsOneWidget);

    // Enter excessive amount: 9999.00
    await tester.enterText(find.byType(TextFormField).first, '9999.00');
    await tester.pumpAndSettle();

    // Tap Confirm Cash Out -> Should show drawer warning
    await tester.tap(find.text('Confirm Cash Out'));
    await tester.pumpAndSettle();

    expect(find.textContaining('exceeds drawer cash on hand'), findsOneWidget);
    expect(mockService.cashOutCalled, isFalse);

    // Enter valid amount: 300.00
    await tester.enterText(find.byType(TextFormField).first, '300.00');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Cash Out'));
    await tester.pumpAndSettle();

    expect(mockService.cashOutCalled, isTrue);
  });

  testWidgets('CloseShiftDialog denomination counter computes variance correctly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));

    final openShift = RegisterShiftModel(
      id: 'shift-open-2',
      businessId: 'biz-1',
      branchId: 'branch-1',
      userId: 'user-1',
      status: 'OPEN',
      openedAt: DateTime.now(),
      openingCash: 500.0,
      totals: const ShiftSummaryTotalsModel(
        openingCash: 500.0,
        cashSales: 1000.0,
        cashIn: 0.0,
        cashRefunds: 0.0,
        cashOut: 0.0,
        expectedCash: 1500.0,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    mockService.mockCurrentShift = openShift;

    await tester.pumpWidget(
      createTestApp(
        child: CloseShiftDialog(shift: openShift),
        mockService: mockService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Close Register Shift'), findsOneWidget);
    expect(find.text('Expected Cash'), findsOneWidget);
    expect(find.text('৳1500.00'), findsOneWidget);
    expect(find.text('Count Bills / Notes (৳)'), findsOneWidget);

    // Initially with 0 notes, counted = 0, variance = -1500 (SHORTAGE)
    expect(find.text('SHORTAGE'), findsOneWidget);

    // Enter note counts: 1 x ৳1000 and 1 x ৳500 = ৳1500
    // Denomination fields: 1000 is first, 500 is second
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '1'); // 1000 x 1
    await tester.enterText(textFields.at(1), '1'); // 500 x 1
    await tester.pumpAndSettle();

    // Now counted = 1500, variance = 0 -> BALANCED
    expect(find.text('BALANCED'), findsOneWidget);
    expect(find.text('Physical Count: ৳1500.00'), findsOneWidget);

    // Submit shift close
    await tester.tap(find.text('Reconcile & Close Shift'));
    await tester.pumpAndSettle();

    expect(mockService.closeShiftCalled, isTrue);
  });

  testWidgets('ZReportDialog renders 80mm thermal receipt layout and sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 850));

    await tester.pumpWidget(
      createTestApp(
        child: const ZReportDialog(shiftId: 'shift-closed-99'),
        mockService: mockService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shift Z-Report'), findsOneWidget);
    expect(find.text('METRO SUPERSTORE LTD'), findsOneWidget);
    expect(find.text('Gulshan Branch'), findsOneWidget);
    expect(find.text('DRAWER RECONCILIATION'), findsOneWidget);
    expect(find.text('TENDER BREAKDOWN'), findsOneWidget);
    expect(find.text('SALES PERFORMANCE'), findsOneWidget);
    expect(find.text('Print Receipt'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Check specific line items
    expect(find.text('Opening Float'), findsOneWidget);
    expect(find.text('৳1000.00'), findsOneWidget);
    expect(find.text('Expected Drawer Cash'), findsOneWidget);
    expect(find.text('৳4500.00'), findsWidgets);
    expect(find.text('Variance (BALANCED)'), findsOneWidget);

    // Check tenders
    expect(find.text('CASH (18)'), findsOneWidget);
    expect(find.text('CARD (10)'), findsOneWidget);
    expect(find.text('BKASH (6)'), findsOneWidget);

    // Check sales performance
    expect(find.text('Gross Sales'), findsOneWidget);
    expect(find.text('৳6800.00'), findsOneWidget);
    expect(find.text('Net Sales'), findsOneWidget);
    expect(find.text('৳6600.00'), findsOneWidget);

    // Test print button feedback
    await tester.tap(find.text('Print Receipt'));
    await tester.pump();
    expect(find.text('Sent to 80mm ESC/POS Thermal Printer'), findsOneWidget);
  });

  testWidgets('ShiftStatusBar displays active shift and opens drawer action dialogs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 700));

    final openShift = RegisterShiftModel(
      id: 'shift-open-active-9',
      businessId: 'biz-1',
      branchId: 'branch-1',
      userId: 'user-1',
      cashierName: 'Rahim Cashier',
      status: 'OPEN',
      openedAt: DateTime(2026, 11, 4, 8, 30),
      openingCash: 2000.0,
      totals: const ShiftSummaryTotalsModel(
        openingCash: 2000.0,
        cashSales: 1200.0,
        cashIn: 0.0,
        cashRefunds: 0.0,
        cashOut: 0.0,
        expectedCash: 3200.0,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    mockService.mockCurrentShift = openShift;

    await tester.pumpWidget(
      createTestApp(
        child: const ShiftStatusBar(),
        mockService: mockService,
        initialShift: openShift,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Shift #SHIFT-'), findsOneWidget);
    expect(find.text('Rahim Cashier'), findsOneWidget);
    expect(find.text('Drawer: ৳3200.00'), findsOneWidget);
    expect(find.text('Cash In'), findsOneWidget);
    expect(find.text('Cash Out'), findsOneWidget);
    expect(find.text('Close Shift'), findsOneWidget);

    // Tap Cash In -> opens CashInOutDialog
    await tester.tap(find.text('Cash In'));
    await tester.pumpAndSettle();
    expect(find.text('Cash In (Deposit)'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Tap Close Shift -> opens CloseShiftDialog
    await tester.tap(find.text('Close Shift'));
    await tester.pumpAndSettle();
    expect(find.text('Close Register Shift'), findsOneWidget);
  });
}
