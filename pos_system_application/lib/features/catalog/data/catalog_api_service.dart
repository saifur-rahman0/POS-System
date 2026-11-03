import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/category.dart';
import '../domain/models/paginated_products.dart';
import '../domain/models/product.dart';

class CatalogApiService {
  final ApiClient apiClient;

  CatalogApiService({required this.apiClient});

  // --- Categories ---

  Future<List<CategoryModel>> getCategories({bool? isActive}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (isActive != null) {
        queryParams['is_active'] = isActive;
      }

      final response = await apiClient.dio.get(
        '/categories',
        queryParameters: queryParams,
      );

      final list = response.data as List<dynamic>;
      return list.map((json) => CategoryModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    String? code,
    String? parentId,
    bool isActive = true,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/categories',
        data: {
          'name': name.trim(),
          if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
          if (parentId != null && parentId.trim().isNotEmpty) 'parent_id': parentId.trim(),
          'is_active': isActive,
        },
      );
      return CategoryModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<CategoryModel> updateCategory({
    required String id,
    String? name,
    String? code,
    String? parentId,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name.trim();
      if (code != null) data['code'] = code.trim().isEmpty ? null : code.trim();
      if (parentId != null) data['parent_id'] = parentId.trim().isEmpty ? null : parentId.trim();
      if (isActive != null) data['is_active'] = isActive;

      final response = await apiClient.dio.put(
        '/categories/$id',
        data: data,
      );
      return CategoryModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  // --- Products ---

  Future<PaginatedProducts> getProducts({
    String? search,
    String? categoryId,
    bool? isActive,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (categoryId != null && categoryId.trim().isNotEmpty) {
        queryParams['category_id'] = categoryId.trim();
      }
      if (isActive != null) {
        queryParams['is_active'] = isActive;
      }

      final response = await apiClient.dio.get(
        '/products',
        queryParameters: queryParams,
      );

      return PaginatedProducts.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<ProductModel> getProductById(String id) async {
    try {
      final response = await apiClient.dio.get('/products/$id');
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<ProductModel> getProductByBarcode(String barcode) async {
    try {
      final response = await apiClient.dio.get('/products/barcode/$barcode');
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<ProductModel> createProduct({
    required String sku,
    required String name,
    String? description,
    String? categoryId,
    String productType = 'standard',
    double taxRate = 0.0,
    String? barcode,
    required double costPrice,
    required double sellingPrice,
    bool trackStock = true,
    bool isActive = true,
  }) async {
    try {
      final data = {
        'sku': sku.trim(),
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        if (categoryId != null && categoryId.trim().isNotEmpty) 'category_id': categoryId.trim(),
        'product_type': productType,
        'tax_rate': taxRate,
        if (barcode != null && barcode.trim().isNotEmpty) 'barcode': barcode.trim(),
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'track_stock': trackStock,
        'is_active': isActive,
      };

      final response = await apiClient.dio.post(
        '/products',
        data: data,
      );
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }

  Future<ProductModel> updateProduct({
    required String id,
    String? sku,
    String? name,
    String? description,
    String? categoryId,
    double? taxRate,
    bool? isActive,
    double? sellingPrice,
    double? costPrice,
    String? barcode,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (sku != null) data['sku'] = sku.trim();
      if (name != null) data['name'] = name.trim();
      if (description != null) data['description'] = description.trim().isEmpty ? null : description.trim();
      if (categoryId != null) data['category_id'] = categoryId.trim().isEmpty ? null : categoryId.trim();
      if (taxRate != null) data['tax_rate'] = taxRate;
      if (isActive != null) data['is_active'] = isActive;
      if (sellingPrice != null) data['selling_price'] = sellingPrice;
      if (costPrice != null) data['cost_price'] = costPrice;
      if (barcode != null) data['barcode'] = barcode.trim().isEmpty ? null : barcode.trim();

      final response = await apiClient.dio.put(
        '/products/$id',
        data: data,
      );
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw apiClient.handleDioError(e);
    }
  }
}

