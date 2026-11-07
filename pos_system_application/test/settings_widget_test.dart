import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/core/network/api_client.dart';
import 'package:pos_client/features/settings/data/settings_api_service.dart';
import 'package:pos_client/features/settings/domain/models/backup_model.dart';
import 'package:pos_client/features/settings/domain/models/business_settings.dart';
import 'package:pos_client/features/settings/domain/models/hardware_settings.dart';
import 'package:pos_client/features/settings/domain/models/license_model.dart';
import 'package:pos_client/features/settings/domain/models/terminal_preferences.dart';
import 'package:pos_client/features/settings/presentation/controllers/settings_controller.dart';
import 'package:pos_client/features/settings/presentation/views/settings_screen.dart';

class FakeSettingsApiService extends SettingsApiService {
  FakeSettingsApiService() : super(apiClient: ApiClient());

  @override
  Future<BusinessSettingsModel> getBusinessProfile() async {
    return const BusinessSettingsModel(
      id: 'biz-001',
      name: 'Apex Superstore Ltd',
      legalName: 'Apex Retail Bangladesh Ltd',
      currency: 'BDT',
      timezone: 'Asia/Dhaka',
      defaultTaxRate: 0.05,
      receiptHeader: 'Apex Superstore\nDhaka, Bangladesh',
      receiptFooter: 'Thank you for choosing Apex!',
    );
  }

  @override
  Future<LicenseModel> getLicenseStatus() async {
    return LicenseModel(
      businessId: 'biz-001',
      licenseKeyId: 'LIC-TEST-001',
      status: 'ACTIVE',
      planName: 'ENTERPRISE',
      deviceLimit: 10,
      features: const ['MULTISTORE', 'OFFLINE_POS', 'WAREHOUSE_TRANSFERS'],
      daysRemaining: 180,
      message: 'Verified Active',
      expiresAt: DateTime(2027, 1, 1),
    );
  }

  @override
  Future<List<BackupRecordModel>> listBackups() async {
    return [
      BackupRecordModel(
        id: 'b1',
        backupType: 'MANUAL',
        fileName: 'pos_snapshot_20261107.sql.gz',
        sizeBytes: 2097152,
        checksum: 'a1b2c3d4e5f6',
        status: 'COMPLETED',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Domain Models Tests', () {
    test('BusinessSettingsModel serialization and copyWith', () {
      final json = {
        'id': 'b1',
        'name': 'Dhaka Superstore',
        'legal_name': 'Dhaka Retail Ltd',
        'email': 'contact@dhakasuperstore.com',
        'phone': '+8801700000000',
        'currency': 'BDT',
        'timezone': 'Asia/Dhaka',
        'tax_identification_number': 'TIN-987654321',
        'default_tax_rate': 0.05,
        'tax_inclusive_pricing': true,
        'receipt_header': 'Welcome to Dhaka Superstore',
        'receipt_footer': 'Thank you for shopping with us!',
        'is_active': true,
      };

      final model = BusinessSettingsModel.fromJson(json);
      expect(model.name, equals('Dhaka Superstore'));
      expect(model.legalName, equals('Dhaka Retail Ltd'));
      expect(model.defaultTaxRate, equals(0.05));
      expect(model.receiptHeader, equals('Welcome to Dhaka Superstore'));

      final updated = model.copyWith(name: 'Chittagong Mart', defaultTaxRate: 0.075);
      expect(updated.name, equals('Chittagong Mart'));
      expect(updated.defaultTaxRate, equals(0.075));
      expect(updated.legalName, equals('Dhaka Retail Ltd'));
    });

    test('LicenseModel serialization and active detection', () {
      final json = {
        'business_id': 'biz-001',
        'license_key_id': 'LIC-ENT-2026',
        'status': 'ACTIVE',
        'plan_name': 'ENTERPRISE',
        'device_limit': 5,
        'features': ['MULTISTORE', 'OFFLINE_POS', 'WAREHOUSE_TRANSFERS', 'CRM_LOYALTY'],
        'days_remaining': 365,
        'is_perpetual': false,
        'message': 'Enterprise Offline License Valid',
      };

      final lic = LicenseModel.fromJson(json);
      expect(lic.isActive, isTrue);
      expect(lic.planName, equals('ENTERPRISE'));
      expect(lic.deviceLimit, equals(5));
      expect(lic.features, contains('CRM_LOYALTY'));
      expect(lic.daysRemaining, equals(365));
    });

    test('BackupRecordModel serialization', () {
      final json = {
        'id': 'bkp-1',
        'backup_type': 'MANUAL',
        'file_name': 'backup_20261107_120000.sql.gz',
        'size_bytes': 1572864,
        'checksum': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'status': 'COMPLETED',
        'created_at': '2026-11-07T12:00:00.000Z',
      };

      final record = BackupRecordModel.fromJson(json);
      expect(record.fileName, equals('backup_20261107_120000.sql.gz'));
      expect(record.formattedSize, equals('1.50 MB'));
      expect(record.status, equals('COMPLETED'));
    });

    test('HardwareSettingsModel defaults and copyWith', () {
      const hw = HardwareSettingsModel();
      expect(hw.printerMode, equals(PrinterConnectionMode.fileSimulator));
      expect(hw.paperSize, equals(ReceiptPaperSize.mm80));
      expect(hw.scannerLatencyThresholdMs, equals(65));

      final updated = hw.copyWith(
        printerMode: PrinterConnectionMode.networkTcp,
        printerIp: '192.168.1.150',
        kickCashDrawer: false,
      );
      expect(updated.printerMode, equals(PrinterConnectionMode.networkTcp));
      expect(updated.printerIp, equals('192.168.1.150'));
      expect(updated.kickCashDrawer, isFalse);
    });

    test('TerminalPreferencesModel copyWith and sound toggle', () {
      const prefs = TerminalPreferencesModel();
      expect(prefs.terminalName, equals('Main Register Terminal 01'));
      expect(prefs.autoRefreshIntervalSeconds, equals(30));
      expect(prefs.soundEffectsEnabled, isTrue);

      final updated = prefs.copyWith(
        terminalName: 'Express Checkout Counter',
        autoRefreshIntervalSeconds: 15,
        soundEffectsEnabled: false,
      );
      expect(updated.terminalName, equals('Express Checkout Counter'));
      expect(updated.autoRefreshIntervalSeconds, equals(15));
      expect(updated.soundEffectsEnabled, isFalse);
    });
  });

  group('SettingsScreen Widget & Tab Navigation Tests', () {
    testWidgets('Renders all 5 tabs and allows tab navigation', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsApiServiceProvider.overrideWithValue(FakeSettingsApiService()),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Settings & System Management'), findsOneWidget);

      // Verify Tab Labels
      expect(find.text('Store Profile'), findsOneWidget);
      expect(find.text('Hardware & Printers'), findsOneWidget);
      expect(find.text('Offline Licensing'), findsOneWidget);
      expect(find.text('Database Backups'), findsOneWidget);
      expect(find.text('System Preferences'), findsOneWidget);

      // 1. Initial Tab: Store Profile
      expect(find.text('Live Thermal Preview'), findsOneWidget);
      expect(find.text('Store / Display Name *'), findsOneWidget);

      // 2. Switch to Hardware & Printers Tab
      await tester.tap(find.text('Hardware & Printers'));
      await tester.pumpAndSettle();
      expect(find.text('ESC/POS Thermal Receipt Printer'), findsOneWidget);
      expect(find.text('Hardware Barcode Scanner Wedge'), findsOneWidget);
      expect(find.text('Print Diagnostic Slip'), findsOneWidget);

      // 3. Switch to Offline Licensing Tab
      await tester.tap(find.text('Offline Licensing'));
      await tester.pumpAndSettle();
      expect(find.text('Activate Offline License Token'), findsOneWidget);
      expect(find.text('Generate Demo Certificate'), findsOneWidget);

      // 4. Switch to Database Backups Tab
      await tester.tap(find.text('Database Backups'));
      await tester.pumpAndSettle();
      expect(find.text('Database Backups & Disaster Recovery'), findsOneWidget);
      expect(find.text('pos_snapshot_20261107.sql.gz'), findsOneWidget);

      // 5. Switch to System Preferences Tab
      await tester.tap(find.text('System Preferences'));
      await tester.pumpAndSettle();
      expect(find.text('Terminal & Workstation Identity'), findsOneWidget);
      expect(find.text('Real-Time Data & Auto-Refresh'), findsOneWidget);
      expect(find.text('Central Server & Local Database'), findsOneWidget);
    });
  });
}
