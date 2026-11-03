import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/customer.dart';
import '../domain/models/customer_due_payment.dart';
import '../domain/models/customer_ledger.dart';
import '../domain/models/paginated_customers.dart';

class CustomersApiService {
  final ApiClient _apiClient;

  CustomersApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<PaginatedCustomersModel> getCustomers({
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
        '/customers',
        queryParameters: queryParams,
      );

      return PaginatedCustomersModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<CustomerModel> getCustomer(String customerId) async {
    try {
      final response = await _apiClient.dio.get('/customers/$customerId');
      return CustomerModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<CustomerModel> createCustomer(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post(
        '/customers',
        data: data,
      );
      return CustomerModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<CustomerModel> updateCustomer(
    String customerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put(
        '/customers/$customerId',
        data: data,
      );
      return CustomerModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<CustomerDuePaymentModel> collectDuePayment(
    String customerId, {
    required double amount,
    required String paymentMethod,
    String? reference,
    String? notes,
    String? saleId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'amount': amount.toStringAsFixed(4),
        'payment_method': paymentMethod,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (saleId != null && saleId.isNotEmpty) 'sale_id': saleId,
      };

      final response = await _apiClient.dio.post(
        '/customers/$customerId/payments',
        data: payload,
      );
      return CustomerDuePaymentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<List<CustomerLedgerEntryModel>> getCustomerLedger(String customerId) async {
    try {
      final response = await _apiClient.dio.get('/customers/$customerId/ledger');
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((item) => CustomerLedgerEntryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }
}
