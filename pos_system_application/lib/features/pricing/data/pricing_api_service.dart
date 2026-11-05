import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/branch_price_override.dart';
import '../domain/models/bulk_import_result.dart';
import '../domain/models/customer_group.dart';
import '../domain/models/price_list.dart';
import '../domain/models/product_bundle.dart';
import '../domain/models/promotion.dart';

class PricingApiService {
  final ApiClient _apiClient;

  PricingApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  // -------------------------------------------------------------------------
  // Customer Groups
  // -------------------------------------------------------------------------
  Future<List<CustomerGroupModel>> getCustomerGroups({bool? isActive}) async {
    try {
      final res = await _apiClient.dio.get(
        '/pricing/customer-groups',
        queryParameters: {if (isActive != null) 'is_active': isActive},
      );
      final list = res.data as List<dynamic>;
      return list.map((e) => CustomerGroupModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<CustomerGroupModel> createCustomerGroup(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.post('/pricing/customer-groups', data: data);
      return CustomerGroupModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<CustomerGroupModel> updateCustomerGroup(String id, Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.put('/pricing/customer-groups/$id', data: data);
      return CustomerGroupModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<void> addCustomerToGroup(String groupId, String customerId) async {
    try {
      await _apiClient.dio.post(
        '/pricing/customer-groups/$groupId/members',
        data: {'customer_id': customerId},
      );
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<void> removeCustomerFromGroup(String groupId, String customerId) async {
    try {
      await _apiClient.dio.delete('/pricing/customer-groups/$groupId/members/$customerId');
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Price Lists & Items
  // -------------------------------------------------------------------------
  Future<List<PriceListModel>> getPriceLists({bool? isActive}) async {
    try {
      final res = await _apiClient.dio.get(
        '/pricing/price-lists',
        queryParameters: {if (isActive != null) 'is_active': isActive},
      );
      final list = res.data as List<dynamic>;
      return list.map((e) => PriceListModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PriceListModel> getPriceList(String id) async {
    try {
      final res = await _apiClient.dio.get('/pricing/price-lists/$id');
      return PriceListModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PriceListModel> createPriceList(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.post('/pricing/price-lists', data: data);
      return PriceListModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PriceListItemModel> addOrUpdatePriceListItem(
    String priceListId,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _apiClient.dio.post('/pricing/price-lists/$priceListId/items', data: data);
      return PriceListItemModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<void> deletePriceListItem(String priceListId, String itemId) async {
    try {
      await _apiClient.dio.delete('/pricing/price-lists/$priceListId/items/$itemId');
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Branch Price Overrides
  // -------------------------------------------------------------------------
  Future<List<BranchPriceOverrideModel>> getBranchOverrides({String? branchId}) async {
    try {
      final res = await _apiClient.dio.get(
        '/pricing/branch-overrides',
        queryParameters: {if (branchId != null) 'branch_id': branchId},
      );
      final list = res.data as List<dynamic>;
      return list.map((e) => BranchPriceOverrideModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<BranchPriceOverrideModel> upsertBranchOverride(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.post('/pricing/branch-overrides', data: data);
      return BranchPriceOverrideModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<void> deleteBranchOverride(String id) async {
    try {
      await _apiClient.dio.delete('/pricing/branch-overrides/$id');
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Bundles & Kits
  // -------------------------------------------------------------------------
  Future<List<ProductBundleModel>> getBundles({bool? isActive}) async {
    try {
      final res = await _apiClient.dio.get(
        '/pricing/bundles',
        queryParameters: {if (isActive != null) 'is_active': isActive},
      );
      final list = res.data as List<dynamic>;
      return list.map((e) => ProductBundleModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<ProductBundleModel> createBundle(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.post('/pricing/bundles', data: data);
      return ProductBundleModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<ProductBundleItemModel> addBundleComponent(
    String bundleId,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _apiClient.dio.post('/pricing/bundles/$bundleId/components', data: data);
      return ProductBundleItemModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<void> deleteBundleComponent(String bundleId, String componentId) async {
    try {
      await _apiClient.dio.delete('/pricing/bundles/$bundleId/components/$componentId');
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Promotions & Coupons
  // -------------------------------------------------------------------------
  Future<List<PromotionModel>> getPromotions({bool? isActive}) async {
    try {
      final res = await _apiClient.dio.get(
        '/pricing/promotions',
        queryParameters: {if (isActive != null) 'is_active': isActive},
      );
      final list = res.data as List<dynamic>;
      return list.map((e) => PromotionModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PromotionModel> createPromotion(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.dio.post('/pricing/promotions', data: data);
      return PromotionModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<PromotionValidationResult> validatePromotion({
    required String code,
    required String branchId,
    required double subtotal,
    String? customerId,
  }) async {
    try {
      final res = await _apiClient.dio.post(
        '/pricing/promotions/validate',
        data: {
          'code': code,
          'branch_id': branchId,
          'subtotal': subtotal,
          if (customerId != null) 'customer_id': customerId,
        },
      );
      return PromotionValidationResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // -------------------------------------------------------------------------
  // Bulk CSV Import
  // -------------------------------------------------------------------------
  Future<BulkImportResultModel> bulkImportCsv(List<int> bytes) async {
    try {
      final res = await _apiClient.dio.post(
        '/pricing/bulk-import',
        data: bytes,
        options: Options(
          headers: {'Content-Type': 'text/csv'},
        ),
      );
      return BulkImportResultModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<String> getBulkImportTemplate() async {
    try {
      final res = await _apiClient.dio.get<String>(
        '/pricing/bulk-import/template',
        options: Options(responseType: ResponseType.plain),
      );
      return res.data ?? '';
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }
}
