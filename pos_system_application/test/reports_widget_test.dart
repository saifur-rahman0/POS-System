import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/branches/data/branches_api_service.dart';
import 'package:pos_client/features/branches/domain/models/branch.dart';
import 'package:pos_client/features/branches/presentation/controllers/branches_controller.dart';
import 'package:pos_client/features/reports/domain/models/customer_dues_report.dart';
import 'package:pos_client/features/reports/domain/models/dashboard_metrics.dart';
import 'package:pos_client/features/reports/domain/models/payment_method_breakdown.dart';
import 'package:pos_client/features/reports/domain/models/sales_time_series.dart';
import 'package:pos_client/features/reports/domain/models/stock_valuation.dart';
import 'package:pos_client/features/reports/domain/models/top_product.dart';
import 'package:pos_client/features/reports/presentation/controllers/reports_controller.dart';
import 'package:pos_client/features/reports/presentation/views/reports_screen.dart';

class MockBranchesApiService implements BranchesApiService {
  List<BranchModel> mockBranches = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<BranchModel>> getBranches({bool? isActive}) async {
    return mockBranches;
  }
}

void main() {
  final mockDashboard = DashboardMetricsModel(
    periodStart: DateTime.now().subtract(const Duration(hours: 12)),
    periodEnd: DateTime.now(),
    grossSales: 241.50,
    netSales: 241.50,
    totalOrders: 2,
    totalItemsSold: 7,
    averageBasketValue: 120.75,
    grossProfit: 101.50,
    profitMarginPct: 42.0,
    totalTax: 11.50,
    totalDiscount: 10.00,
    totalRefunds: 0.00,
    totalCollected: 191.50,
    totalDueIssued: 50.00,
    lowStockCount: 2,
    outOfStockCount: 1,
  );

  final mockTimeSeries = SalesTimeSeriesModel(
    interval: 'hourly',
    points: const [
      SalesTimeSeriesPointModel(
        periodLabel: '2026-11-04 10:00',
        salesCount: 2,
        grossSales: 241.50,
        netSales: 241.50,
        profit: 101.50,
      ),
    ],
  );

  final mockTopProducts = TopProductsModel(
    items: const [
      TopProductModel(
        productVariantId: 'v1',
        productName: 'Energy Drink 250ml',
        variantName: 'Can',
        sku: 'BEV-001',
        unitsSold: 2,
        grossRevenue: 140.0,
        cogs: 80.0,
        profit: 60.0,
        marginPct: 42.8,
      ),
    ],
  );

  final mockStock = StockValuationModel(
    totalVariantsStocked: 5,
    totalUnitsOnHand: 54,
    totalCostValue: 2048.0,
    totalRetailValue: 3580.0,
    potentialGrossProfit: 1532.0,
    lowStockCount: 2,
    outOfStockCount: 1,
    lowStockItems: const [
      StockValuationItemModel(
        variantId: 'v2',
        productName: 'Mineral Water 500ml',
        variantName: 'Bottle',
        sku: 'BEV-002',
        barcode: '1234567890',
        quantityOnHand: 4.0,
        costPrice: 12.0,
        sellingPrice: 20.0,
        stockCostValue: 48.0,
        stockRetailValue: 80.0,
        isLowStock: true,
        isOutOfStock: false,
      ),
    ],
  );

  final mockPayments = PaymentMethodBreakdownModel(
    totalCollected: 241.50,
    methods: const [
      PaymentMethodBreakdownItemModel(
        method: 'CASH',
        totalAmount: 147.0,
        transactionCount: 1,
        percentage: 60.8,
      ),
      PaymentMethodBreakdownItemModel(
        method: 'BKASH',
        totalAmount: 44.50,
        transactionCount: 1,
        percentage: 18.4,
      ),
    ],
  );

  final mockDues = CustomerDuesReportModel(
    totalCustomersWithDue: 1,
    totalOutstandingDue: 50.0,
    totalCreditLimit: 5000.0,
    overallCreditUtilizationPct: 1.0,
    topDebtors: const [
      TopDebtorModel(
        customerId: 'c1',
        name: 'Tanvir Ahmed',
        phone: '01712345678',
        dueBalance: 50.0,
        creditLimit: 5000.0,
        utilizationPct: 1.0,
      ),
    ],
  );

  final mockBranch = BranchModel(
    id: 'b1',
    businessId: 'biz1',
    name: 'Main Outlet',
    code: 'MAIN',
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final mockBranchesApi = MockBranchesApiService()..mockBranches = [mockBranch];

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        dashboardMetricsProvider.overrideWith((ref) async => mockDashboard),
        salesTimeSeriesProvider.overrideWith((ref) async => mockTimeSeries),
        topProductsProvider.overrideWith((ref) async => mockTopProducts),
        stockValuationProvider.overrideWith((ref) async => mockStock),
        paymentBreakdownProvider.overrideWith((ref) async => mockPayments),
        customerDuesReportProvider.overrideWith((ref) async => mockDues),
        branchesApiServiceProvider.overrideWithValue(mockBranchesApi),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ReportsScreen(),
      ),
    );
  }

  testWidgets('ReportsScreen renders title and all 5 report navigation tabs',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Analytics & Financial Reports'), findsOneWidget);
    expect(find.text('Executive Overview'), findsOneWidget);
    expect(find.text('Top Products'), findsOneWidget);
    expect(find.text('Stock Valuation'), findsOneWidget);
    expect(find.text('Payment Breakdown'), findsOneWidget);
    expect(find.text('Customer Dues'), findsOneWidget);
  });

  testWidgets('Executive Overview tab renders KPI cards and trend chart',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('GROSS SALES'), findsOneWidget);
    expect(find.text('NET SALES'), findsOneWidget);
    expect(find.text('GROSS PROFIT'), findsOneWidget);
    expect(find.text('AVG BASKET'), findsOneWidget);
    expect(find.text('Sales Revenue Trend'), findsOneWidget);
  });

  testWidgets('Switching tabs to Top Products and Stock Valuation displays tables',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Click Top Products Tab
    await tester.tap(find.text('Top Products'));
    await tester.pumpAndSettle();

    expect(find.text('Energy Drink 250ml'), findsOneWidget);
    expect(find.text('BEV-001'), findsOneWidget);

    // Click Stock Valuation Tab
    await tester.tap(find.text('Stock Valuation'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL CAPITAL INVESTED'), findsOneWidget);
    expect(find.text('POTENTIAL RETAIL REVENUE'), findsOneWidget);
    expect(find.text('Mineral Water 500ml'), findsOneWidget);
    expect(find.text('LOW STOCK'), findsOneWidget);
  });

  testWidgets('Payment Breakdown and Customer Dues tabs render distribution and debtors',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Click Payment Breakdown Tab
    await tester.tap(find.text('Payment Breakdown'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL VALUE RECORDED'), findsOneWidget);
    expect(find.text('CASH'), findsOneWidget);
    expect(find.text('BKASH'), findsOneWidget);

    // Click Customer Dues Tab
    await tester.tap(find.text('Customer Dues'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL RECEIVABLES (DUES)'), findsOneWidget);
    expect(find.text('Tanvir Ahmed'), findsOneWidget);
    expect(find.text('01712345678'), findsOneWidget);
  });
}
