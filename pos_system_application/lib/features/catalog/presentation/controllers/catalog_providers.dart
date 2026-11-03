import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/catalog_api_service.dart';
import '../../domain/models/category.dart';
import '../../domain/models/paginated_products.dart';
import '../../domain/models/product.dart';

final catalogApiServiceProvider = Provider<CatalogApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CatalogApiService(apiClient: client);
});

// ---------------- Categories State ----------------

class CategoryListNotifier extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final CatalogApiService _apiService;
  bool? _isActiveFilter;

  CategoryListNotifier(this._apiService) : super(const AsyncValue.loading()) {
    fetchCategories();
  }

  bool? get isActiveFilter => _isActiveFilter;

  Future<void> fetchCategories({bool? isActive}) async {
    _isActiveFilter = isActive;
    state = const AsyncValue.loading();
    try {
      final categories = await _apiService.getCategories(isActive: _isActiveFilter);
      state = AsyncValue.data(categories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    String? code,
    String? parentId,
    bool isActive = true,
  }) async {
    final newCategory = await _apiService.createCategory(
      name: name,
      code: code,
      parentId: parentId,
      isActive: isActive,
    );
    await fetchCategories(isActive: _isActiveFilter);
    return newCategory;
  }

  Future<CategoryModel> updateCategory({
    required String id,
    String? name,
    String? code,
    String? parentId,
    bool? isActive,
  }) async {
    final updated = await _apiService.updateCategory(
      id: id,
      name: name,
      code: code,
      parentId: parentId,
      isActive: isActive,
    );
    await fetchCategories(isActive: _isActiveFilter);
    return updated;
  }
}

final categoryListProvider =
    StateNotifierProvider<CategoryListNotifier, AsyncValue<List<CategoryModel>>>((ref) {
  final apiService = ref.watch(catalogApiServiceProvider);
  return CategoryListNotifier(apiService);
});

// ---------------- Products State ----------------

class ProductFilterState {
  final String search;
  final String? categoryId;
  final bool? isActive;
  final int page;
  final int limit;

  const ProductFilterState({
    this.search = '',
    this.categoryId,
    this.isActive,
    this.page = 1,
    this.limit = 15,
  });

  ProductFilterState copyWith({
    String? search,
    String? categoryId,
    bool? isActive,
    int? page,
    int? limit,
    bool clearCategory = false,
    bool clearIsActive = false,
  }) {
    return ProductFilterState(
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      isActive: clearIsActive ? null : (isActive ?? this.isActive),
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

class ProductFilterNotifier extends StateNotifier<ProductFilterState> {
  ProductFilterNotifier() : super(const ProductFilterState());

  void setSearch(String search) {
    state = state.copyWith(search: search, page: 1);
  }

  void setCategory(String? categoryId) {
    if (categoryId == null) {
      state = state.copyWith(clearCategory: true, page: 1);
    } else {
      state = state.copyWith(categoryId: categoryId, page: 1);
    }
  }

  void setIsActive(bool? isActive) {
    if (isActive == null) {
      state = state.copyWith(clearIsActive: true, page: 1);
    } else {
      state = state.copyWith(isActive: isActive, page: 1);
    }
  }

  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  void reset() {
    state = const ProductFilterState();
  }
}

final productFilterProvider =
    StateNotifierProvider<ProductFilterNotifier, ProductFilterState>((ref) {
  return ProductFilterNotifier();
});

final paginatedProductsProvider =
    FutureProvider<PaginatedProducts>((ref) async {
  final apiService = ref.watch(catalogApiServiceProvider);
  final filter = ref.watch(productFilterProvider);

  return apiService.getProducts(
    search: filter.search.isNotEmpty ? filter.search : null,
    categoryId: filter.categoryId,
    isActive: filter.isActive,
    page: filter.page,
    limit: filter.limit,
  );
});

class ProductMutationNotifier extends StateNotifier<AsyncValue<ProductModel?>> {
  final CatalogApiService _apiService;
  final Ref _ref;

  ProductMutationNotifier(this._apiService, this._ref)
      : super(const AsyncValue.data(null));

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
    state = const AsyncValue.loading();
    try {
      final product = await _apiService.createProduct(
        sku: sku,
        name: name,
        description: description,
        categoryId: categoryId,
        productType: productType,
        taxRate: taxRate,
        barcode: barcode,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        trackStock: trackStock,
        isActive: isActive,
      );
      state = AsyncValue.data(product);
      _ref.invalidate(paginatedProductsProvider);
      return product;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
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
    state = const AsyncValue.loading();
    try {
      final product = await _apiService.updateProduct(
        id: id,
        sku: sku,
        name: name,
        description: description,
        categoryId: categoryId,
        taxRate: taxRate,
        isActive: isActive,
        sellingPrice: sellingPrice,
        costPrice: costPrice,
        barcode: barcode,
      );
      state = AsyncValue.data(product);
      _ref.invalidate(paginatedProductsProvider);
      return product;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final productMutationProvider =
    StateNotifierProvider<ProductMutationNotifier, AsyncValue<ProductModel?>>((ref) {
  final apiService = ref.watch(catalogApiServiceProvider);
  return ProductMutationNotifier(apiService, ref);
});

