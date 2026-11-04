import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../branches/presentation/controllers/branches_controller.dart';
import '../../branches/presentation/views/branches_screen.dart';
import '../../catalog/presentation/views/catalog_screen.dart';
import '../../checkout/presentation/views/pos_register_screen.dart';
import '../../customers/presentation/views/customers_screen.dart';
import '../../purchasing/presentation/views/purchasing_screen.dart';
import '../../sales/presentation/views/sales_history_screen.dart';
import '../../sync/presentation/controllers/sync_controller.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _selectedIndex = 0;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale),
      label: 'POS Register',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Catalog & Stock',
    ),
    NavigationDestination(
      icon: Icon(Icons.local_shipping_outlined),
      selectedIcon: Icon(Icons.local_shipping),
      label: 'Purchasing',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Sales History',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Customers',
    ),
    NavigationDestination(
      icon: Icon(Icons.store_outlined),
      selectedIcon: Icon(Icons.store),
      label: 'Stores & Transfers',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: 'Reports',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activeBranch = ref.watch(activeBranchProvider);
    final branches = ref.watch(branchesListProvider).branches;
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Retail POS — Local Terminal',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          // Active Branch Selector
          if (branches.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activeBranch?.id,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  dropdownColor: const Color(0xFF0F766E),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: branches.where((b) => b.isActive).map((b) {
                    return DropdownMenuItem(
                      value: b.id,
                      child: Row(
                        children: [
                          const Icon(Icons.store, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(b.name, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      final selected =
                          branches.firstWhere((b) => b.id == newId);
                      ref.read(activeBranchProvider.notifier).state = selected;
                    }
                  },
                ),
              ),
            ),

          // Offline Delta Sync trigger button & indicator
          InkWell(
            onTap: syncState.isSyncing
                ? null
                : () async {
                    final ok = await ref
                        .read(syncControllerProvider.notifier)
                        .pullDeltas(branchId: activeBranch?.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Catalog & Balances synced with central server'
                              : 'Sync failed: ${ref.read(syncControllerProvider).errorMessage}'),
                        ),
                      );
                    }
                  },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  syncState.isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    syncState.isSyncing ? 'Syncing...' : 'Sync: Ready',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.storefront, size: 32, color: Color(0xFF0F766E)),
            ),
            destinations: _destinations.map((d) {
              return NavigationRailDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: Text(d.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _selectedIndex == 0
                ? const PosRegisterScreen()
                : _selectedIndex == 1
                    ? const CatalogScreen()
                    : _selectedIndex == 2
                        ? const PurchasingScreen()
                        : _selectedIndex == 3
                            ? const SalesHistoryScreen()
                            : _selectedIndex == 4
                                ? const CustomersScreen()
                                : _selectedIndex == 5
                                    ? const BranchesScreen()
                                    : Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _destinations[_selectedIndex]
                                                      .icon is Icon
                                                  ? (_destinations[
                                                              _selectedIndex]
                                                          .icon as Icon)
                                                      .icon
                                                  : Icons.dashboard,
                                              size: 64,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _destinations[_selectedIndex]
                                                  .label,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall,
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Coming Soon',
                                              style: TextStyle(
                                                  color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
          ),
        ],
      ),
    );
  }
}
