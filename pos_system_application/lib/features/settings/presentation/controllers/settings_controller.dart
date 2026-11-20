import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/core/hardware/printer/printer_service.dart';
import 'package:pos_client/core/hardware/printer/receipt_esc_pos_generator.dart';
import 'package:pos_client/core/network/api_provider.dart';
import 'package:pos_client/features/checkout/domain/models/sale_receipt.dart';
import 'package:pos_client/features/settings/data/settings_api_service.dart';
import 'package:pos_client/features/settings/domain/models/backup_model.dart';
import 'package:pos_client/features/settings/domain/models/business_settings.dart';
import 'package:pos_client/features/settings/domain/models/hardware_settings.dart';
import 'package:pos_client/features/settings/domain/models/license_model.dart';
import 'package:pos_client/features/settings/domain/models/terminal_preferences.dart';

final settingsApiServiceProvider = Provider<SettingsApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SettingsApiService(apiClient: apiClient);
});

// ============================================================================
// Business Settings State & Notifier
// ============================================================================
class BusinessSettingsNotifier extends StateNotifier<AsyncValue<BusinessSettingsModel>> {
  final SettingsApiService _apiService;

  BusinessSettingsNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final res = await _apiService.getBusinessProfile();
      state = AsyncValue.data(res);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? legalName,
    String? timezone,
    String? currency,
  }) async {
    try {
      final updated = await _apiService.updateBusinessProfile(
        name: name,
        legalName: legalName,
        timezone: timezone,
        currency: currency,
      );
      state = AsyncValue.data(updated);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final businessSettingsProvider =
    StateNotifierProvider<BusinessSettingsNotifier, AsyncValue<BusinessSettingsModel>>((ref) {
  final api = ref.watch(settingsApiServiceProvider);
  return BusinessSettingsNotifier(api);
});

// ============================================================================
// Offline Licensing Provider & Notifier
// ============================================================================
class LicenseNotifier extends StateNotifier<AsyncValue<LicenseModel>> {
  final SettingsApiService _apiService;

  LicenseNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadLicense();
  }

  Future<void> loadLicense() async {
    state = const AsyncValue.loading();
    try {
      final res = await _apiService.getLicenseStatus();
      state = AsyncValue.data(res);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> activateLicense(String token) async {
    state = const AsyncValue.loading();
    try {
      final res = await _apiService.activateLicense(token);
      state = AsyncValue.data(res);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<String?> generateDevLicense(String businessId) async {
    try {
      final res = await _apiService.generateLicense(
        businessId: businessId,
        planName: 'ENTERPRISE',
        deviceLimit: 10,
        daysValid: 365,
      );
      return res['license_token']?.toString();
    } catch (e) {
      return null;
    }
  }
}

final licenseStatusProvider =
    StateNotifierProvider<LicenseNotifier, AsyncValue<LicenseModel>>((ref) {
  final api = ref.watch(settingsApiServiceProvider);
  return LicenseNotifier(api);
});

// ============================================================================
// Database Backups & Disaster Recovery Notifier
// ============================================================================
class BackupsNotifier extends StateNotifier<AsyncValue<List<BackupRecordModel>>> {
  final SettingsApiService _apiService;

  BackupsNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadBackups();
  }

  Future<void> loadBackups() async {
    state = const AsyncValue.loading();
    try {
      final res = await _apiService.listBackups();
      state = AsyncValue.data(res);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> createBackup({String backupType = 'MANUAL'}) async {
    try {
      await _apiService.createBackup(backupType: backupType);
      await loadBackups();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<BackupRestoreResultModel?> restoreBackup(String backupId) async {
    try {
      final res = await _apiService.restoreBackup(backupId);
      await loadBackups();
      return res;
    } catch (e) {
      return null;
    }
  }
}

final backupsListProvider =
    StateNotifierProvider<BackupsNotifier, AsyncValue<List<BackupRecordModel>>>((ref) {
  final api = ref.watch(settingsApiServiceProvider);
  return BackupsNotifier(api);
});

// ============================================================================
// Hardware & Thermal Printer Settings
// ============================================================================
class HardwareSettingsNotifier extends StateNotifier<HardwareSettingsModel> {
  HardwareSettingsNotifier() : super(const HardwareSettingsModel());

  void updateSettings(HardwareSettingsModel settings) {
    state = settings;
    // Keep printer service configuration in sync
    _syncPrinterService();
  }

  PrinterConfig _buildPrinterConfig() {
    PrinterConnectionType pMode;
    switch (state.printerMode) {
      case PrinterConnectionMode.networkTcp:
        pMode = PrinterConnectionType.networkTcp;
        break;
      case PrinterConnectionMode.windowsSpooler:
        pMode = PrinterConnectionType.windowsSpooler;
        break;
      case PrinterConnectionMode.fileSimulator:
        pMode = PrinterConnectionType.fileSimulator;
        break;
    }

    return PrinterConfig(
      connectionType: pMode,
      ipAddress: state.printerIp,
      port: state.printerPort,
      printerName: state.printerName,
      receiptConfig: ReceiptEscPosConfig(
        paperWidth: state.paperSize == ReceiptPaperSize.mm58 ? PaperWidth.mm58 : PaperWidth.mm80,
        kickDrawer: state.kickCashDrawer,
        cutPaper: state.autoCutPaper,
      ),
    );
  }

  void _syncPrinterService() {}

  Future<bool> testPrintReceipt() async {
    final printer = PrinterService(config: _buildPrinterConfig());
    final dummy = SaleReceiptModel(
      id: 'test-print-receipt',
      receiptNo: 'TEST-SLIP-001',
      status: 'TEST',
      cashierId: 'cashier-01',
      customerName: 'Hardware Test Slip',
      financials: const SaleFinancialsModel(
        subtotal: 50.0,
        discountTotal: 0.0,
        taxTotal: 2.5,
        grandTotal: 52.5,
        paidTotal: 52.5,
        dueTotal: 0.0,
        changeAmount: 0.0,
      ),
      items: const [
        SaleReceiptItemModel(
          id: 't1',
          productVariantId: 'v1',
          productName: 'Thermal Printer Diagnostic Slip',
          quantity: 1,
          unitPrice: 50.0,
          discount: 0.0,
          lineTotal: 50.0,
        ),
      ],
      payments: const [
        SaleReceiptPaymentModel(
          id: 'p1',
          method: 'CASH',
          amount: 52.5,
          status: 'CONFIRMED',
        ),
      ],
      notes: 'Diagnostic test print successful.',
      createdAt: DateTime.now(),
    );

    return printer.printReceipt(dummy);
  }

  Future<bool> testKickCashDrawer() async {
    final printer = PrinterService(config: _buildPrinterConfig());
    return printer.openCashDrawer();
  }
}

final hardwareSettingsProvider =
    StateNotifierProvider<HardwareSettingsNotifier, HardwareSettingsModel>((ref) {
  return HardwareSettingsNotifier();
});

// ============================================================================
// Terminal & System Preferences Notifier
// ============================================================================
class TerminalPreferencesNotifier extends StateNotifier<TerminalPreferencesModel> {
  TerminalPreferencesNotifier() : super(const TerminalPreferencesModel()) {
    _loadFromDisk();
  }

  void _loadFromDisk() {
    try {
      final file = File('pos_terminal_preferences.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>;
        state = TerminalPreferencesModel.fromJson(json);
      }
    } catch (_) {}
  }

  void _saveToDisk() {
    try {
      final file = File('pos_terminal_preferences.json');
      file.writeAsStringSync(jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void setTerminalName(String name) {
    state = state.copyWith(terminalName: name);
    _saveToDisk();
  }

  void setDeviceId(String id) {
    state = state.copyWith(deviceId: id);
    _saveToDisk();
  }

  void setAutoRefreshInterval(int seconds) {
    state = state.copyWith(autoRefreshIntervalSeconds: seconds);
    _saveToDisk();
  }

  void toggleSoundEffects(bool enabled) {
    state = state.copyWith(soundEffectsEnabled: enabled);
    _saveToDisk();
  }

  void toggleDarkMode(bool enabled) {
    state = state.copyWith(isDarkMode: enabled);
    _saveToDisk();
  }

  void setPosTableView(bool isTable) {
    state = state.copyWith(isPosTableView: isTable);
    _saveToDisk();
  }
}

final terminalPreferencesProvider =
    StateNotifierProvider<TerminalPreferencesNotifier, TerminalPreferencesModel>((ref) {
  return TerminalPreferencesNotifier();
});
