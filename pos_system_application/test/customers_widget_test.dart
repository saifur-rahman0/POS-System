import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/customers/data/customers_api_service.dart';
import 'package:pos_client/features/customers/domain/models/customer.dart';
import 'package:pos_client/features/customers/domain/models/customer_due_payment.dart';
import 'package:pos_client/features/customers/domain/models/customer_ledger.dart';
import 'package:pos_client/features/customers/domain/models/paginated_customers.dart';
import 'package:pos_client/features/customers/presentation/controllers/customer_controller.dart';
import 'package:pos_client/features/customers/presentation/views/collect_due_dialog.dart';
import 'package:pos_client/features/customers/presentation/views/customer_form_dialog.dart';
import 'package:pos_client/features/customers/presentation/views/customer_selection_dialog.dart';
import 'package:pos_client/features/customers/presentation/views/customers_screen.dart';

class MockCustomersApiService implements CustomersApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<CustomerModel> mockList = [
    CustomerModel(
      id: 'cust-1',
      businessId: 'biz-1',
      name: 'Rahim Uddin',
      phone: '01711000111',
      email: 'rahim@test.com',
      address: 'Gulshan, Dhaka',
      creditLimit: 5000.0,
      dueBalance: 1200.0,
      availableCredit: 3800.0,
      totalSalesCount: 15,
      totalSpent: 25000.0,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    CustomerModel(
      id: 'cust-2',
      businessId: 'biz-1',
      name: 'Karim Ahmed',
      phone: '01811222333',
      creditLimit: 2000.0,
      dueBalance: 0.0,
      availableCredit: 2000.0,
      totalSalesCount: 3,
      totalSpent: 4500.0,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  @override
  Future<PaginatedCustomersModel> getCustomers({
    String? search,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async {
    var items = mockList;
    if (search != null && search.isNotEmpty) {
      items = items
          .where((c) =>
              c.name.toLowerCase().contains(search.toLowerCase()) ||
              (c.phone != null && c.phone!.contains(search)))
          .toList();
    }
    return PaginatedCustomersModel(
      items: items,
      total: items.length,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
      totalOutstandingDues: 1200.0,
    );
  }

  @override
  Future<CustomerModel> createCustomer(Map<String, dynamic> data) async {
    return CustomerModel(
      id: 'cust-new',
      businessId: 'biz-1',
      name: data['name'] as String,
      phone: data['phone'] as String?,
      creditLimit: double.tryParse(data['credit_limit']?.toString() ?? '0') ?? 0.0,
      dueBalance: 0.0,
      availableCredit: double.tryParse(data['credit_limit']?.toString() ?? '0') ?? 0.0,
      totalSalesCount: 0,
      totalSpent: 0.0,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<CustomerDuePaymentModel> collectDuePayment(
    String customerId, {
    required double amount,
    required String paymentMethod,
    String? reference,
    String? notes,
    String? saleId,
  }) async {
    return CustomerDuePaymentModel(
      customerId: customerId,
      customerName: 'Rahim Uddin',
      amountPaid: amount,
      previousDue: 1200.0,
      remainingDue: 1200.0 - amount,
      paymentMethod: paymentMethod,
      reference: reference,
      allocatedSales: [
        AllocatedSalePaymentModel(
          saleId: 'sale-1',
          receiptNo: 'REC-001',
          allocatedAmount: amount,
          remainingSaleDue: 1200.0 - amount,
        ),
      ],
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<CustomerLedgerEntryModel>> getCustomerLedger(String customerId) async {
    return [
      CustomerLedgerEntryModel(
        date: DateTime.now().subtract(const Duration(days: 2)),
        entryType: 'SALE_CHARGE',
        receiptNo: 'REC-001',
        description: 'Purchase: REC-001',
        debit: 1200.0,
        credit: 0.0,
        balance: 1200.0,
      ),
      CustomerLedgerEntryModel(
        date: DateTime.now().subtract(const Duration(hours: 1)),
        entryType: 'PAYMENT',
        receiptNo: 'REC-001',
        description: 'Payment (CASH) against REC-001',
        debit: 0.0,
        credit: 500.0,
        balance: 700.0,
      ),
    ];
  }
}

Widget buildTestWidget({
  required Widget child,
  required MockCustomersApiService mockApi,
}) {
  return ProviderScope(
    overrides: [
      customersApiServiceProvider.overrideWithValue(mockApi),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late MockCustomersApiService mockApi;

  setUp(() {
    mockApi = MockCustomersApiService();
  });

  group('CustomersScreen & Directory Tests', () {
    testWidgets('renders KPI summary cards and customer records', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        buildTestWidget(child: const CustomersScreen(), mockApi: mockApi),
      );
      await tester.pumpAndSettle();

      // Verify header and KPIs
      expect(find.text('Customer Management & Store Credit'), findsOneWidget);
      expect(find.text('Total Customers'), findsOneWidget);
      expect(find.text('Total Outstanding Dues'), findsOneWidget);

      // Verify customer rows
      expect(find.text('Rahim Uddin'), findsOneWidget);
      expect(find.text('Karim Ahmed'), findsOneWidget);
      expect(find.text('01711000111'), findsOneWidget);

      // Verify Collect button appears for customer with due
      expect(find.text('Collect'), findsOneWidget);
    });

    testWidgets('search filters customer list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        buildTestWidget(child: const CustomersScreen(), mockApi: mockApi),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Karim');
      await tester.pumpAndSettle();

      expect(find.text('Karim Ahmed'), findsOneWidget);
      expect(find.text('Rahim Uddin'), findsNothing);
    });
  });

  group('CustomerSelectionDialog Tests', () {
    testWidgets('displays Walk-in option and registered customers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));

      await tester.pumpWidget(
        buildTestWidget(
          child: const CustomerSelectionDialog(),
          mockApi: mockApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Customer'), findsOneWidget);
      expect(find.text('Walk-in Customer (General / Anonymous)'), findsOneWidget);
      expect(find.text('Rahim Uddin'), findsOneWidget);
      expect(find.text('Karim Ahmed'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    });
  });

  group('CollectDueDialog Tests', () {
    testWidgets('shows customer due details and allows amount shortcuts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));

      final cust = mockApi.mockList.first; // Rahim, due = 1200

      await tester.pumpWidget(
        buildTestWidget(
          child: CollectDueDialog(customer: cust),
          mockApi: mockApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collect Due Repayment'), findsOneWidget);
      expect(find.text('Rahim Uddin'), findsOneWidget);

      // Find quick amount chips
      expect(find.text('৳ 100'), findsOneWidget);
      expect(find.text('৳ 500'), findsOneWidget);
      expect(find.text('৳ 1000'), findsOneWidget);

      // Tap ৳ 500 chip
      await tester.tap(find.text('৳ 500'));
      await tester.pumpAndSettle();

      expect(find.text('500.00'), findsOneWidget);

      // Verify submit button is enabled
      expect(find.text('Confirm & Collect Payment'), findsOneWidget);
    });
  });

  group('CustomerFormDialog Tests', () {
    testWidgets('validates required name field', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 600));

      await tester.pumpWidget(
        buildTestWidget(
          child: const CustomerFormDialog(),
          mockApi: mockApi,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add New Customer'), findsOneWidget);

      // Click Create without name
      await tester.tap(find.text('Create Customer'));
      await tester.pumpAndSettle();

      expect(find.text('Customer name is required'), findsOneWidget);
    });
  });
}

