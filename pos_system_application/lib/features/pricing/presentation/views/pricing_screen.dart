import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/pricing_controller.dart';
import 'dialogs/add_price_list_item_dialog.dart';
import 'dialogs/branch_override_dialog.dart';
import 'dialogs/bulk_import_dialog.dart';
import 'dialogs/customer_group_dialog.dart';
import 'dialogs/price_list_dialog.dart';
import 'dialogs/product_bundle_dialog.dart';
import 'dialogs/promotion_dialog.dart';

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listen to state alerts
    ref.listen<PricingState>(pricingControllerProvider, (_, state) {
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
        );
      } else if (state.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.successMessage!), backgroundColor: Colors.green),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: theme.colorScheme.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: const [
                      Tab(icon: Icon(Icons.format_list_numbered, size: 18), text: 'Price Lists'),
                      Tab(icon: Icon(Icons.group, size: 18), text: 'Customer Groups'),
                      Tab(icon: Icon(Icons.store, size: 18), text: 'Branch Overrides'),
                      Tab(icon: Icon(Icons.widgets, size: 18), text: 'Bundles & Kits'),
                      Tab(icon: Icon(Icons.local_offer, size: 18), text: 'Promotions & Coupons'),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Bulk CSV Import'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const BulkImportDialog(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _PriceListsTab(),
                _CustomerGroupsTab(),
                _BranchOverridesTab(),
                _BundlesTab(),
                _PromotionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 1: Price Lists Master-Detail View
// ============================================================================
class _PriceListsTab extends ConsumerWidget {
  const _PriceListsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(priceListsProvider);
    final selectedId = ref.watch(selectedPriceListIdProvider);
    final selectedDetailAsync = ref.watch(selectedPriceListDetailProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Price Lists List
          SizedBox(
            width: 320,
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('Price Schedules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          tooltip: 'New Price List',
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const PriceListDialog(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: listsAsync.when(
                      data: (lists) {
                        if (lists.isEmpty) {
                          return const Center(child: Text('No price lists yet'));
                        }
                        return ListView.separated(
                          itemCount: lists.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final pl = lists[i];
                            final isSelected = pl.id == selectedId;
                            return ListTile(
                              selected: isSelected,
                              title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${pl.currency} • ${pl.items.length} items'),
                              trailing: pl.isDefault
                                  ? Chip(
                                      label: const Text('DEFAULT', style: TextStyle(fontSize: 10, color: Colors.white)),
                                      backgroundColor: Colors.blue.shade700,
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : null,
                              onTap: () {
                                ref.read(selectedPriceListIdProvider.notifier).state = pl.id;
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right: Items in Selected Price List
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: selectedId == null
                  ? const Center(
                      child: Text('Select a price list from the left or create one to manage items'),
                    )
                  : selectedDetailAsync.when(
                      data: (detail) {
                        if (detail == null) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        detail.name,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      if (detail.description != null)
                                        Text(detail.description!, style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add / Set Variant Price'),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => AddPriceListItemDialog(priceListId: detail.id),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: detail.items.isEmpty
                                  ? const Center(
                                      child: Text('No variant prices in this list. Click "+ Add / Set Variant Price" above.'),
                                    )
                                  : SingleChildScrollView(
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Variant Name')),
                                          DataColumn(label: Text('Min Qty Break')),
                                          DataColumn(label: Text('Price (৳)')),
                                          DataColumn(label: Text('Schedule Window')),
                                          DataColumn(label: Text('Actions')),
                                        ],
                                        rows: detail.items.map((item) {
                                          final hasSchedule = item.startDate != null || item.endDate != null;
                                          final windowText = hasSchedule
                                              ? '${item.startDate?.toIso8601String().substring(0, 10) ?? "Any"} to ${item.endDate?.toIso8601String().substring(0, 10) ?? "Any"}'
                                              : 'Always Active';
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(item.variantName ?? item.productVariantId)),
                                              DataCell(Text(item.minQuantity.toStringAsFixed(1))),
                                              DataCell(Text(
                                                '৳${item.price.toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              )),
                                              DataCell(Text(windowText)),
                                              DataCell(
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                  tooltip: 'Remove',
                                                  onPressed: () {
                                                    ref
                                                        .read(pricingControllerProvider.notifier)
                                                        .deletePriceListItem(detail.id, item.id);
                                                  },
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 2: Customer Groups
// ============================================================================
class _CustomerGroupsTab extends ConsumerWidget {
  const _CustomerGroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(customerGroupsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Customer Groups & Tiers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Group'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const CustomerGroupDialog(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Center(child: Text('No customer groups yet. Click "+ New Group" to create.'));
                  }
                  return SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Group Name')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Members')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Created Date')),
                        ],
                        rows: groups.map((g) {
                          return DataRow(
                            cells: [
                              DataCell(Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(g.description ?? '-')),
                              DataCell(Chip(label: Text('${g.memberCount} members'))),
                              DataCell(
                                g.isActive
                                    ? const Chip(label: Text('Active'), backgroundColor: Color(0xFFE8F5E9))
                                    : const Chip(label: Text('Inactive')),
                              ),
                              DataCell(Text(g.createdAt.toIso8601String().substring(0, 10))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Tab 3: Branch Price Overrides
// ============================================================================
class _BranchOverridesTab extends ConsumerWidget {
  const _BranchOverridesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overridesAsync = ref.watch(branchOverridesProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Branch-Specific Price Overrides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Override'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const BranchOverrideDialog(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: overridesAsync.when(
                data: (overrides) {
                  if (overrides.isEmpty) {
                    return const Center(child: Text('No branch price overrides set. Click "+ New Override" to create.'));
                  }
                  return SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Branch')),
                          DataColumn(label: Text('Product Variant')),
                          DataColumn(label: Text('Override Price (৳)')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: overrides.map((ov) {
                          return DataRow(
                            cells: [
                              DataCell(Text(ov.branchName ?? ov.branchId)),
                              DataCell(Text(ov.variantName ?? ov.productVariantId, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('৳${ov.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                  onPressed: () {
                                    ref.read(pricingControllerProvider.notifier).deleteBranchOverride(ov.id);
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Tab 4: Product Bundles & Kits
// ============================================================================
class _BundlesTab extends ConsumerWidget {
  const _BundlesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundlesAsync = ref.watch(productBundlesProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Product Bundles & Composite Kits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create Bundle'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const ProductBundleDialog(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: bundlesAsync.when(
                data: (bundles) {
                  if (bundles.isEmpty) {
                    return const Center(child: Text('No bundles created yet. Click "+ Create Bundle" to define one.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: bundles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final b = bundles[i];
                      return ExpansionTile(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(
                          '${b.items.length} components • Price: ${b.bundlePrice != null ? "৳${b.bundlePrice!.toStringAsFixed(2)}" : "Sum of components"}',
                        ),
                        trailing: b.isKit
                            ? const Chip(label: Text('KIT', style: TextStyle(fontSize: 10)))
                            : const Chip(label: Text('BUNDLE', style: TextStyle(fontSize: 10))),
                        children: [
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Included Items:', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                ...b.items.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                        const SizedBox(width: 8),
                                        Text('${item.componentName ?? item.componentVariantId} × ${item.quantity}'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Tab 5: Promotions & Coupons
// ============================================================================
class _PromotionsTab extends ConsumerWidget {
  const _PromotionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promosAsync = ref.watch(promotionsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Active Promotions & Coupons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Promotion'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const PromotionDialog(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: promosAsync.when(
                data: (promos) {
                  if (promos.isEmpty) {
                    return const Center(child: Text('No promotions created yet. Click "+ New Promotion" to set one up.'));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('Campaign Name')),
                          DataColumn(label: Text('Coupon Code')),
                          DataColumn(label: Text('Discount')),
                          DataColumn(label: Text('Validity Period')),
                          DataColumn(label: Text('Usage / Limit')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: promos.map((p) {
                          final discountStr = p.discountType == 'PERCENTAGE'
                              ? '${p.discountValue.toStringAsFixed(0)}% Off'
                              : '৳${p.discountValue.toStringAsFixed(2)} Off';
                          final usageStr = p.usageLimit != null
                              ? '${p.timesUsed} / ${p.usageLimit}'
                              : '${p.timesUsed} / ∞';
                          return DataRow(
                            cells: [
                              DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(
                                p.code != null
                                    ? Chip(
                                        label: Text(p.code!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        backgroundColor: Colors.amber.shade100,
                                      )
                                    : const Text('Auto-applied'),
                              ),
                              DataCell(Text(discountStr, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('${p.validFrom.toIso8601String().substring(0, 10)} to ${p.validUntil.toIso8601String().substring(0, 10)}')),
                              DataCell(Text(usageStr)),
                              DataCell(
                                p.isActive
                                    ? const Chip(label: Text('Active'), backgroundColor: Color(0xFFE8F5E9))
                                    : const Chip(label: Text('Inactive')),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
