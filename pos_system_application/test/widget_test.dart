import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/app/app.dart';
import 'package:pos_client/core/network/api_client.dart';
import 'package:pos_client/features/catalog/data/catalog_api_service.dart';
import 'package:pos_client/features/catalog/domain/models/category.dart';
import 'package:pos_client/features/catalog/presentation/controllers/catalog_providers.dart';
import 'package:pos_client/features/checkout/presentation/views/pos_register_screen.dart';

void main() {
  testWidgets('App shell boots and displays title and destinations', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          posProductsProvider.overrideWith((ref) async => []),
          categoryListProvider.overrideWith((ref) => DummyCategoryNotifier([])),
        ],
        child: const PosApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app bar title
    expect(find.text('Retail POS — Local Terminal'), findsOneWidget);

    // Verify navigation destinations
    expect(find.text('POS Register'), findsWidgets);
    expect(find.text('Catalog & Stock'), findsOneWidget);
    expect(find.text('Sales History'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

class DummyCategoryNotifier extends CategoryListNotifier {
  final List<CategoryModel> initialData;

  DummyCategoryNotifier(this.initialData) : super(FakeCatalogApiService()) {
    state = AsyncValue.data(initialData);
  }

  @override
  Future<void> fetchCategories({bool? isActive}) async {
    state = AsyncValue.data(initialData);
  }
}

class FakeCatalogApiService extends CatalogApiService {
  FakeCatalogApiService() : super(apiClient: DummyApiClient());
}

class DummyApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

