import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/category.dart';
import '../controllers/catalog_providers.dart';
import 'category_form_dialog.dart';

class CategoryListView extends ConsumerWidget {
  const CategoryListView({super.key});

  void _openFormDialog(BuildContext context, [CategoryModel? category]) {
    showDialog<bool>(
      context: context,
      builder: (_) => CategoryFormDialog(category: category),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final notifier = ref.read(categoryListProvider.notifier);
    final isActiveFilter = notifier.isActiveFilter;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                'Product Categories',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<bool?>(
                    segments: const [
                      ButtonSegment<bool?>(value: null, label: Text('All')),
                      ButtonSegment<bool?>(value: true, label: Text('Active')),
                      ButtonSegment<bool?>(value: false, label: Text('Inactive')),
                    ],
                    selected: {isActiveFilter},
                    onSelectionChanged: (selected) {
                      notifier.fetchCategories(isActive: selected.first);
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Categories',
                    onPressed: () => notifier.fetchCategories(isActive: isActiveFilter),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    key: const Key('add_category_button'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _openFormDialog(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load categories: $err'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => notifier.fetchCategories(isActive: isActiveFilter),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (categories) {
                if (categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No categories found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          key: const Key('create_first_category_button'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Category'),
                          onPressed: () => _openFormDialog(context),
                        ),
                      ],
                    ),
                  );
                }

                // Map of ID to name for parent lookup
                final categoryMap = {for (final c in categories) c.id: c.name};

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final parentName = cat.parentId != null
                            ? categoryMap[cat.parentId] ?? 'Parent'
                            : null;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cat.isActive
                                ? const Color(0xFFCCFBF1)
                                : Colors.grey.shade200,
                            foregroundColor: cat.isActive
                                ? const Color(0xFF0F766E)
                                : Colors.grey.shade600,
                            child: const Icon(Icons.category, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (cat.code != null && cat.code!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    cat.code!,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            parentName != null ? 'Parent: $parentName' : 'Top Level Category',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cat.isActive
                                      ? Colors.green.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: cat.isActive
                                        ? Colors.green.shade300
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  cat.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: cat.isActive
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit Category',
                                onPressed: () => _openFormDialog(context, cat),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
