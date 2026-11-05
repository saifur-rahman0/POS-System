import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/checkout_request.dart';
import '../domain/models/exchange.dart';
import '../domain/models/held_cart.dart';
import '../domain/models/quotation.dart';
import '../domain/models/sale_receipt.dart';

class CheckoutApiService {
  final ApiClient apiClient;

  CheckoutApiService({required this.apiClient});

  Future<SaleReceiptModel> checkout(CheckoutRequestModel request) async {
    try {
      final response = await apiClient.dio.post(
        '/sales/checkout',
        data: request.toJson(),
        options: Options(
          headers: {
            'X-Idempotency-Key': request.idempotencyKey,
          },
        ),
      );

      final data = response.data;
      if (data is Map) {
        return SaleReceiptModel.fromJson(data);
      }
      throw 'Invalid response format from checkout server';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<SaleReceiptModel> getSaleReceipt(String saleId) async {
    try {
      final response = await apiClient.dio.get('/sales/$saleId');
      final data = response.data;
      if (data is Map) {
        return SaleReceiptModel.fromJson(data);
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<SaleReceiptModel> getSaleByReceiptNo(String receiptNo) async {
    try {
      final response = await apiClient.dio.get('/sales/receipt/$receiptNo');
      final data = response.data;
      if (data is Map) {
        return SaleReceiptModel.fromJson(data);
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Held Carts
  // ---------------------------------------------------------------------------
  Future<HeldCartModel> createHeldCart(Map<String, dynamic> payload) async {
    try {
      final response = await apiClient.dio.post('/sales/held-carts', data: payload);
      final data = response.data;
      if (data is Map) {
        return HeldCartModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<List<HeldCartModel>> listHeldCarts({String? branchId}) async {
    try {
      final response = await apiClient.dio.get(
        '/sales/held-carts',
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );
      final data = response.data;
      if (data is List) {
        return data
            .map((item) => item is Map ? HeldCartModel.fromJson(Map<String, dynamic>.from(item)) : null)
            .whereType<HeldCartModel>()
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<HeldCartModel> getHeldCart(String heldCartId) async {
    try {
      final response = await apiClient.dio.get('/sales/held-carts/$heldCartId');
      final data = response.data;
      if (data is Map) {
        return HeldCartModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<void> deleteHeldCart(String heldCartId) async {
    try {
      await apiClient.dio.delete('/sales/held-carts/$heldCartId');
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Quotations
  // ---------------------------------------------------------------------------
  Future<QuotationModel> createQuotation(Map<String, dynamic> payload) async {
    try {
      final response = await apiClient.dio.post('/sales/quotations', data: payload);
      final data = response.data;
      if (data is Map) {
        return QuotationModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<List<QuotationModel>> listQuotations({
    String? branchId,
    String? status,
    String? search,
  }) async {
    try {
      final response = await apiClient.dio.get(
        '/sales/quotations',
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
          if (status != null) 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final data = response.data;
      if (data is List) {
        return data
            .map((item) => item is Map ? QuotationModel.fromJson(Map<String, dynamic>.from(item)) : null)
            .whereType<QuotationModel>()
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<QuotationModel> getQuotation(String quotationId) async {
    try {
      final response = await apiClient.dio.get('/sales/quotations/$quotationId');
      final data = response.data;
      if (data is Map) {
        return QuotationModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<SaleReceiptModel> convertQuotation(String quotationId, Map<String, dynamic> payload) async {
    try {
      final response = await apiClient.dio.post(
        '/sales/quotations/$quotationId/convert',
        data: payload,
      );
      final data = response.data;
      if (data is Map) {
        return SaleReceiptModel.fromJson(data);
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Exchanges & Manager Override
  // ---------------------------------------------------------------------------
  Future<ExchangeResultModel> exchange(ExchangeRequestModel request) async {
    try {
      final response = await apiClient.dio.post('/sales/exchange', data: request.toJson());
      final data = response.data;
      if (data is Map) {
        return ExchangeResultModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> verifyManagerOverride({
    required String pin,
    required String action,
    required String reason,
    String? username,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/sales/manager-override',
        data: {
          'pin': pin,
          'action': action,
          'reason': reason,
          if (username != null) 'username': username,
        },
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw 'Invalid response format';
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }
}
