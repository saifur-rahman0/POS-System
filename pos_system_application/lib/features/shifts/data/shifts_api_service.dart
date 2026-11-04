import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/paginated_shifts.dart';
import '../domain/models/register_shift.dart';
import '../domain/models/z_report.dart';

class ShiftsApiService {
  final ApiClient _apiClient;

  ShiftsApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<RegisterShiftModel?> getCurrentShift({String? branchId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (branchId != null) queryParams['branch_id'] = branchId;

      final response = await _apiClient.dio.get(
        '/shifts/current',
        queryParameters: queryParams,
      );

      if (response.data == null) return null;
      return RegisterShiftModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _apiClient.handleDioError(e);
    }
  }

  Future<RegisterShiftModel> openShift({
    required double openingCash,
    String? notes,
    String? deviceId,
    String? branchId,
  }) async {
    try {
      final data = <String, dynamic>{
        'opening_cash': openingCash.toStringAsFixed(4),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (deviceId != null) 'device_id': deviceId,
        if (branchId != null) 'branch_id': branchId,
      };

      final response = await _apiClient.dio.post(
        '/shifts/open',
        data: data,
      );

      return RegisterShiftModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<ShiftCashTransactionModel> recordCashIn({
    required String shiftId,
    required double amount,
    required String reason,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{
        'amount': amount.toStringAsFixed(4),
        'reason': reason,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await _apiClient.dio.post(
        '/shifts/$shiftId/cash-in',
        data: data,
      );

      return ShiftCashTransactionModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<ShiftCashTransactionModel> recordCashOut({
    required String shiftId,
    required double amount,
    required String reason,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{
        'amount': amount.toStringAsFixed(4),
        'reason': reason,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await _apiClient.dio.post(
        '/shifts/$shiftId/cash-out',
        data: data,
      );

      return ShiftCashTransactionModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<RegisterShiftModel> closeShift({
    required String shiftId,
    required double closingCashCounted,
    String? notes,
    Map<String, int> denominations = const {},
  }) async {
    try {
      final data = <String, dynamic>{
        'closing_cash_counted': closingCashCounted.toStringAsFixed(4),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'denominations': denominations,
      };

      final response = await _apiClient.dio.post(
        '/shifts/$shiftId/close',
        data: data,
      );

      return RegisterShiftModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<ZReportModel> getZReport({required String shiftId}) async {
    try {
      final response = await _apiClient.dio.get('/shifts/$shiftId/z-report');
      return ZReportModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PaginatedShiftsModel> listShifts({
    String? branchId,
    String? userId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (branchId != null) queryParams['branch_id'] = branchId;
      if (userId != null) queryParams['user_id'] = userId;
      if (status != null) queryParams['status'] = status;
      if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

      final response = await _apiClient.dio.get(
        '/shifts',
        queryParameters: queryParams,
      );

      return PaginatedShiftsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }
}

