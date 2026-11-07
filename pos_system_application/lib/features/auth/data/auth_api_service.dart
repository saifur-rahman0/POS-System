import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/auth_user.dart';

class AuthApiService {
  final ApiClient _client;

  AuthApiService(this._client);

  Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/login',
        data: {
          'username': username.trim(),
          'password': password,
        },
      );
      final model = AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
      _client.setAuthToken(model.accessToken);
      return model;
    } on DioException catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<AuthResponseModel> register({
    required String username,
    required String password,
    required String displayName,
    String? email,
    String? phone,
    String? businessName,
    String? currency,
    String? timezone,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/register',
        data: {
          'username': username.trim(),
          'password': password,
          'display_name': displayName.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          'business_name': businessName?.trim().isNotEmpty == true ? businessName!.trim() : 'Retail Store',
          'currency': currency ?? 'BDT',
          'timezone': timezone ?? 'Asia/Dhaka',
        },
      );
      final model = AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
      _client.setAuthToken(model.accessToken);
      return model;
    } on DioException catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<AuthResponseModel> getMe() async {
    try {
      final response = await _client.dio.get('/auth/me');
      return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/auth/logout');
    } catch (_) {
      // Ignore network failure on logout
    } finally {
      _client.setAuthToken('dev-token');
    }
  }
}

