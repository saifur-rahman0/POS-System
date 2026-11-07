import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../inventory/presentation/views/advanced_inventory_screen.dart';
import '../../../pricing/presentation/views/pricing_screen.dart';
import 'category_list_view.dart';
import 'product_list_view.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(appLocalizationsProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF0F766E),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF0F766E),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.inventory_2, size: 19),
                    text: loc.tr('products', 'Products'),
                  ),
                  Tab(
                    icon: const Icon(Icons.category, size: 19),
                    text: loc.tr('categories', 'Categories'),
                  ),
                  Tab(
                    icon: const Icon(Icons.warehouse, size: 19),
                    text: loc.tr('advanced_inventory', 'Advanced Inventory'),
                  ),
                  Tab(
                    icon: const Icon(Icons.price_change, size: 19),
                    text: loc.tr('pricing_promotions', 'Pricing & Promotions'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            const Expanded(
              child: TabBarView(
                children: [
                  ProductListView(),
                  CategoryListView(),
                  AdvancedInventoryScreen(),
                  PricingScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
