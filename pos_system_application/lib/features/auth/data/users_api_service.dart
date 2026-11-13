import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/staff_user_model.dart';

class UsersApiService {
  final ApiClient _client;

  UsersApiService(this._client);

  Future<List<StaffUserModel>> getUsers() async {
    try {
      final response = await _client.dio.get('/users');
      final data = response.data;
      if (data is List) {
        return data
            .map((item) => StaffUserModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<StaffUserModel> createUser({
    required String username,
    required String password,
    required String displayName,
    String? email,
    String? phone,
    required String role,
  }) async {
    try {
      final response = await _client.dio.post(
        '/users',
        data: {
          'username': username.trim(),
          'password': password,
          'display_name': displayName.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          'role': role.trim().toUpperCase(),
        },
      );
      return StaffUserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<StaffUserModel> updateUser({
    required String userId,
    String? displayName,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
  }) async {
    try {
      final response = await _client.dio.put(
        '/users/$userId',
        data: {
          if (displayName != null) 'display_name': displayName.trim(),
          if (email != null) 'email': email.trim(),
          if (phone != null) 'phone': phone.trim(),
          if (role != null) 'role': role.trim().toUpperCase(),
          if (isActive != null) 'is_active': isActive,
        },
      );
      return StaffUserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await _client.dio.put(
        '/users/$userId/password',
        data: {'new_password': newPassword},
      );
    } on DioException catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deactivateUser(String userId) async {
    try {
      await _client.dio.delete('/users/$userId');
    } on DioException catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getRolesMeta() async {
    try {
      final response = await _client.dio.get('/users/meta/roles');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
