import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  ApiException({
    required this.message,
    this.code,
    this.statusCode,
  });

  @override
  String toString() => message;
}

class ApiClient {
  final Dio dio;

  ApiClient({Dio? customDio, String? baseUrl, String? authToken = 'dev-token'})
      : dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? 'http://127.0.0.1:8000/api/v1',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
                },
              ),
            );

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  ApiException handleDioError(DioException error) {
    if (error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          return ApiException(
            message: detail['message']?.toString() ?? 'An error occurred',
            code: detail['error_code']?.toString(),
            statusCode: error.response?.statusCode,
          );
        } else if (detail is String) {
          return ApiException(
            message: detail,
            statusCode: error.response?.statusCode,
          );
        } else if (detail is List) {
          final messages = detail.map((e) {
            if (e is Map) {
              return e['msg']?.toString() ?? e.toString();
            }
            return e.toString();
          }).join(', ');
          return ApiException(
            message: messages.isNotEmpty ? messages : 'Validation failed',
            code: 'VALIDATION_ERROR',
            statusCode: error.response?.statusCode,
          );
        } else if (data['message'] != null) {
          return ApiException(
            message: data['message'].toString(),
            code: data['error_code']?.toString(),
            statusCode: error.response?.statusCode,
          );
        }
      } else if (data is String && data.isNotEmpty) {
        return ApiException(
          message: data,
          statusCode: error.response?.statusCode,
        );
      }
    }

    if (error.response?.statusCode == 409) {
      return ApiException(
        message: 'A duplicate record already exists (e.g. duplicate SKU or Barcode).',
        code: 'CONFLICT',
        statusCode: 409,
      );
    }

    if (error.response?.statusCode == 401) {
      return ApiException(
        message: 'Authentication token required or expired.',
        code: 'UNAUTHORIZED',
        statusCode: 401,
      );
    }

    return ApiException(
      message: error.message ?? 'Network connection error',
      code: 'NETWORK_ERROR',
      statusCode: error.response?.statusCode,
    );
  }
}

