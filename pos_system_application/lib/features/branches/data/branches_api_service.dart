import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/branch.dart';

class BranchesApiService {
  final ApiClient apiClient;

  BranchesApiService({required this.apiClient});

  Future<List<BranchModel>> getBranches({bool? isActive}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (isActive != null) {
        queryParams['is_active'] = isActive;
      }

      final response = await apiClient.dio.get(
        '/branches',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map((item) => BranchModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<BranchModel> getBranch(String branchId) async {
    try {
      final response = await apiClient.dio.get('/branches/$branchId');
      final data = response.data;
      if (data is Map) {
        return BranchModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<BranchModel> createBranch({
    required String name,
    String? code,
    String? address,
    String? phone,
    bool isActive = true,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/branches',
        data: {
          'name': name,
          'code': code,
          'address': address,
          'phone': phone,
          'is_active': isActive,
        },
      );

      final data = response.data;
      if (data is Map) {
        return BranchModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<BranchModel> updateBranch(
    String branchId, {
    String? name,
    String? code,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    try {
      final response = await apiClient.dio.put(
        '/branches/$branchId',
        data: {
          if (name != null) 'name': name,
          if (code != null) 'code': code,
          if (address != null) 'address': address,
          if (phone != null) 'phone': phone,
          if (isActive != null) 'is_active': isActive,
        },
      );

      final data = response.data;
      if (data is Map) {
        return BranchModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }
}

