import 'package:dio/dio.dart';
import 'package:pos_client/core/network/api_client.dart';
import 'package:pos_client/features/settings/domain/models/backup_model.dart';
import 'package:pos_client/features/settings/domain/models/business_settings.dart';
import 'package:pos_client/features/settings/domain/models/license_model.dart';

class SettingsApiService {
  final ApiClient _apiClient;

  SettingsApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  // --- Business Profile ---
  Future<BusinessSettingsModel> getBusinessProfile() async {
    try {
      final res = await _apiClient.dio.get('/business');
      return BusinessSettingsModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<BusinessSettingsModel> updateBusinessProfile({
    String? name,
    String? legalName,
    String? timezone,
    String? currency,
  }) async {
    try {
      final res = await _apiClient.dio.patch(
        '/business',
        data: {
          if (name != null) 'name': name.trim(),
          if (legalName != null) 'legal_name': legalName.trim(),
          if (timezone != null) 'timezone': timezone.trim(),
          if (currency != null) 'currency': currency.trim(),
        },
      );
      return BusinessSettingsModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // --- Offline Cryptographic Licensing ---
  Future<LicenseModel> getLicenseStatus() async {
    try {
      final res = await _apiClient.dio.get('/license/status');
      return LicenseModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<LicenseModel> activateLicense(String token) async {
    try {
      final res = await _apiClient.dio.post(
        '/license/activate',
        data: {'license_token': token.trim()},
      );
      return LicenseModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> generateLicense({
    required String businessId,
    String planName = 'PRO',
    int deviceLimit = 5,
    int? daysValid = 365,
  }) async {
    try {
      final res = await _apiClient.dio.post(
        '/license/generate',
        data: {
          'business_id': businessId,
          'plan_name': planName,
          'device_limit': deviceLimit,
          'days_valid': daysValid,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // --- Database Backups & Disaster Recovery ---
  Future<List<BackupRecordModel>> listBackups() async {
    try {
      final res = await _apiClient.dio.get('/backups');
      final list = res.data as List<dynamic>;
      return list.map((e) => BackupRecordModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<BackupRecordModel> createBackup({String backupType = 'MANUAL'}) async {
    try {
      final res = await _apiClient.dio.post(
        '/backups/create',
        data: {'backup_type': backupType},
      );
      return BackupRecordModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<BackupRestoreResultModel> restoreBackup(String backupId) async {
    try {
      final res = await _apiClient.dio.post('/backups/$backupId/restore');
      return BackupRestoreResultModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }
}
