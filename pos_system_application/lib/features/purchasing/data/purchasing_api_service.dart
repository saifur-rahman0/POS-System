import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/paginated_purchases.dart';
import '../domain/models/paginated_suppliers.dart';
import '../domain/models/purchase_order.dart';
import '../domain/models/supplier.dart';

class PurchasingApiService {
  final ApiClient _apiClient;

  PurchasingApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  // --- Suppliers ---

  Future<PaginatedSuppliersModel> getSuppliers({
    String? search,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (isActive != null) {
        queryParams['is_active'] = isActive;
      }

      final response = await _apiClient.dio.get(
        '/suppliers',
        queryParameters: queryParams,
      );

      return PaginatedSuppliersModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<SupplierModel> createSupplier(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post(
        '/suppliers',
        data: data,
      );
      return SupplierModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<SupplierModel> updateSupplier(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put(
        '/suppliers/$id',
        data: data,
      );
      return SupplierModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // --- Purchase Orders ---

  Future<PaginatedPurchasesModel> getPurchases({
    String? status,
    String? supplierId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (supplierId != null && supplierId.isNotEmpty) {
        queryParams['supplier_id'] = supplierId;
      }

      final response = await _apiClient.dio.get(
        '/purchasing/orders',
        queryParameters: queryParams,
      );

      return PaginatedPurchasesModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PurchaseOrderModel> getPurchase(String id) async {
    try {
      final response = await _apiClient.dio.get('/purchasing/orders/$id');
      return PurchaseOrderModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PurchaseOrderModel> createPurchase(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post(
        '/purchasing/orders',
        data: data,
      );
      return PurchaseOrderModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PurchaseOrderModel> receivePurchase(String id) async {
    try {
      final response = await _apiClient.dio.post('/purchasing/orders/$id/receive');
      return PurchaseOrderModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PurchasePaymentModel> addPurchasePayment(
    String id, {
    required double amount,
    required String method,
    String? reference,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/purchasing/orders/$id/payments',
        data: {
          'amount': amount.toStringAsFixed(4),
          'method': method,
          if (reference != null && reference.isNotEmpty) 'reference': reference,
        },
      );
      return PurchasePaymentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }
}

