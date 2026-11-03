import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/checkout_request.dart';
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
}

