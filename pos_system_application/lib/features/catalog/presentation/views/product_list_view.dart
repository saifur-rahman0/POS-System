import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../inventory/presentation/controllers/inventory_controller.dart';
import '../../../inventory/presentation/views/stock_adjustment_dialog.dart';
import '../../../inventory/presentation/views/stock_movements_dialog.dart';
import '../../domain/models/product.dart';
import '../controllers/catalog_providers.dart';
import 'product_form_dialog.dart';

class ProductListView extends ConsumerStatefulWidget {
  const ProductListView({super.key});

  @override
  ConsumerState<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends ConsumerState<ProductListView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFormDialog([ProductModel? product]) {
    showDialog<bool>(
      context: context,
      builder: (_) => ProductFormDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(paginatedProductsProvider);
    final filter = ref.watch(productFilterProvider);
    final filterNotifier = ref.read(productFilterProvider.notifier);
    final categoriesAsync = ref.watch(categoryListProvider);
    final balancesAsync = ref.watch(stockBalancesProvider);
    final balancesMap = balancesAsync.maybeWhen(
      data: (map) => map,
      orElse: () => <String, double>{},
    );

    final categories = categoriesAsync.maybeWhen(
      data: (cats) => cats,
      orElse: () => [],
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Search input
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, SKU, or barcode...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  filterNotifier.setSearch('');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (val) {
                        filterNotifier.setSearch(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category Dropdown
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey(filter.categoryId),
                      initialValue: filter.categoryId,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Categories', overflow: TextOverflow.ellipsis),
                        ),
                        ...categories.map((c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.name, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) {
                        filterNotifier.setCategory(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status Segmented Button
                  SegmentedButton<bool?>(
                    segments: const [
                      ButtonSegment<bool?>(value: null, label: Text('All')),
                      ButtonSegment<bool?>(value: true, label: Text('Active')),
                      ButtonSegment<bool?>(value: false, label: Text('Inactive')),
                    ],
                    selected: {filter.isActive},
                    onSelectionChanged: (selected) {
                      filterNotifier.setIsActive(selected.first);
                    },
                  ),
                  const SizedBox(width: 12),
                  // Refresh button
                  IconButton.outlined(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Products',
                    onPressed: () {
                      ref.invalidate(paginatedProductsProvider);
                    },
                  ),
                  const SizedBox(width: 12),
                  // Add Product Button
                  ElevatedButton.icon(
                    key: const Key('add_product_button'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: () => _openFormDialog(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Main Content / Table
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load products: $err'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(paginatedProductsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No products found matching the criteria',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          key: const Key('create_first_product_button'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Product'),
                          onPressed: () => _openFormDialog(),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                              columns: const [
                                DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Barcode', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Cost Price', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Stock on Hand', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: paginated.items.map((prod) {
                                final variant = prod.primaryVariant;
                                final sellingPrice = variant != null
                                    ? '\$${variant.sellingPrice.toStringAsFixed(2)}'
                                    : '-';
                                final costPrice = variant != null
                                    ? '\$${variant.costPrice.toStringAsFixed(2)}'
                                    : '-';
                                final barcode = variant?.barcode ?? '-';
                                final stockQty = variant != null
                                    ? (balancesMap[variant.id] ?? 0.0)
                                    : 0.0;

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        prod.sku,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 220),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              prod.name,
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (prod.description != null && prod.description!.isNotEmpty)
                                              Text(
                                                prod.description!,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 140),
                                        child: Text(
                                          prod.categoryName ?? 'Uncategorized',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: prod.categoryName != null ? Colors.black87 : Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (variant?.barcode != null)
                                            const Icon(Icons.qr_code_2, size: 16, color: Colors.grey),
                                          if (variant?.barcode != null) const SizedBox(width: 4),
                                          Text(barcode),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        sellingPrice,
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                                      ),
                                    ),
                                    DataCell(Text(costPrice)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: stockQty <= 0
                                              ? Colors.red.shade50
                                              : stockQty <= 5
                                                  ? Colors.amber.shade50
                                                  : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: stockQty <= 0
                                                ? Colors.red.shade300
                                                : stockQty <= 5
                                                    ? Colors.amber.shade300
                                                    : Colors.green.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          stockQty <= 0
                                              ? 'Out of Stock (0)'
                                              : stockQty <= 5
                                                  ? 'Low: ${stockQty.toStringAsFixed(0)}'
                                                  : '${stockQty.toStringAsFixed(0)} on hand',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: stockQty <= 0
                                                ? Colors.red.shade800
                                                : stockQty <= 5
                                                    ? Colors.amber.shade900
                                                    : Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: prod.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: prod.isActive ? Colors.green.shade300 : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          prod.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: prod.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.tune, size: 20),
                                            tooltip: 'Adjust Physical Stock',
                                            onPressed: () async {
                                              if (variant == null) return;
                                              final adjusted = await StockAdjustmentDialog.show(
                                                context,
                                                productVariantId: variant.id,
                                                productName: prod.name,
                                                currentStock: stockQty,
                                              );
                                              if (adjusted != null) {
                                                ref.invalidate(stockBalancesProvider);
                                                ref.invalidate(paginatedProductsProvider);
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.history, size: 20),
                                            tooltip: 'Stock Movement Ledger',
                                            onPressed: () {
                                              if (variant == null) return;
                                              StockMovementsDialog.show(
                                                context,
                                                productVariantId: variant.id,
                                                productName: prod.name,
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            tooltip: 'Edit Product',
                                            onPressed: () => _openFormDialog(prod),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),

                      // Pagination Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(top: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing page ${paginated.page} of ${paginated.pages} (Total: ${paginated.total} products)',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.chevron_left, size: 18),
                                  label: const Text('Previous'),
                                  onPressed: paginated.page > 1
                                      ? () => filterNotifier.setPage(paginated.page - 1)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  label: const Text('Next'),
                                  icon: const Icon(Icons.chevron_right, size: 18),
                                  onPressed: paginated.page < paginated.pages
                                      ? () => filterNotifier.setPage(paginated.page + 1)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
