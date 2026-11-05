import 'package:flutter/material.dart';
import '../../../inventory/presentation/views/advanced_inventory_screen.dart';
import '../../../pricing/presentation/views/pricing_screen.dart';
import 'category_list_view.dart';
import 'product_list_view.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.inventory_2, size: 20),
                    text: 'Products',
                  ),
                  Tab(
                    icon: Icon(Icons.category, size: 20),
                    text: 'Categories',
                  ),
                  Tab(
                    icon: Icon(Icons.warehouse, size: 20),
                    text: 'Advanced Inventory',
                  ),
                  Tab(
                    icon: Icon(Icons.price_change, size: 20),
                    text: 'Pricing & Promotions',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
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
