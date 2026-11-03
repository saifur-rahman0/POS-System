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

  ApiClient({Dio? customDio, String? baseUrl, String? authToken})
      : dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? 'http://127.0.0.1:8000/api/v1',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  if (authToken != null) 'Authorization': 'Bearer $authToken',
                },
              ),
            );

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  ApiException handleDioError(DioException error) {
    if (error.response != null && error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        if (data['detail'] is Map<String, dynamic>) {
          final detail = data['detail'] as Map<String, dynamic>;
          return ApiException(
            message: detail['message']?.toString() ?? 'An error occurred',
            code: detail['error_code']?.toString(),
            statusCode: error.response?.statusCode,
          );
        } else if (data['detail'] is String) {
          return ApiException(
            message: data['detail'] as String,
            statusCode: error.response?.statusCode,
          );
        } else if (data['detail'] is List) {
          final list = data['detail'] as List;
          final messages = list.map((e) {
            if (e is Map<String, dynamic>) {
              return e['msg']?.toString() ?? e.toString();
            }
            return e.toString();
          }).join(', ');
          return ApiException(
            message: messages.isNotEmpty ? messages : 'Validation failed',
            code: 'VALIDATION_ERROR',
            statusCode: error.response?.statusCode,
          );
        }
      }
    }

    return ApiException(
      message: error.message ?? 'Network connection error',
      code: 'NETWORK_ERROR',
      statusCode: error.response?.statusCode,
    );
  }
}
