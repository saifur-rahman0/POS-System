import 'package:flutter/material.dart';
import 'category_list_view.dart';
import 'product_list_view.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
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
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            const Expanded(
              child: TabBarView(
                children: [
                  ProductListView(),
                  CategoryListView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
