import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../branches/presentation/controllers/branches_controller.dart';
import '../../branches/presentation/views/branches_screen.dart';
import '../../catalog/presentation/controllers/catalog_providers.dart';
import '../../catalog/presentation/views/catalog_screen.dart';
import '../../checkout/presentation/views/pos_register_screen.dart';
import '../../customers/presentation/controllers/customer_controller.dart';
import '../../customers/presentation/views/customers_screen.dart';
import '../../expenses/presentation/controllers/expenses_controller.dart';
import '../../expenses/presentation/controllers/financial_accounts_controller.dart';
import '../../expenses/presentation/views/expenses_screen.dart';
import '../../expenses/presentation/views/financial_accounts_screen.dart';
import '../../inventory/presentation/controllers/advanced_inventory_controller.dart';
import '../../inventory/presentation/controllers/inventory_controller.dart';
import '../../inventory/presentation/controllers/transfers_controller.dart';
import '../../purchasing/presentation/controllers/purchasing_controller.dart';
import '../../purchasing/presentation/views/purchasing_screen.dart';
import '../../reports/presentation/controllers/reports_controller.dart';
import '../../reports/presentation/views/reports_screen.dart';
import '../../sales/presentation/controllers/sales_history_controller.dart';
import '../../sales/presentation/views/sales_history_screen.dart';
import '../../settings/domain/models/terminal_preferences.dart';
import '../../settings/presentation/controllers/settings_controller.dart';
import '../../settings/presentation/views/settings_screen.dart';
import '../../shifts/presentation/controllers/shift_controller.dart';
import '../../sync/presentation/controllers/sync_controller.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/keyboard_shortcuts_dialog.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _selectedIndex = 0;
  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(terminalPreferencesProvider);
    _setupAutoRefresh(prefs.autoRefreshIntervalSeconds);
  }

  void _setupAutoRefresh(int seconds) {
    _autoRefreshTimer?.cancel();
    if (seconds > 0) {
      _autoRefreshTimer = Timer.periodic(Duration(seconds: seconds), (_) {
        if (mounted) {
          _refreshScreen(_selectedIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshScreen(int index, {bool showFeedback = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      switch (index) {
        case 0: // POS Register
          ref.invalidate(posProductsProvider);
          ref.read(currentShiftProvider.notifier).loadCurrentShift();
          ref.read(branchesListProvider.notifier).loadBranches();
          break;
        case 1: // Catalog & Stock
          ref.invalidate(paginatedProductsProvider);
          ref.invalidate(categoryListProvider);
          ref.invalidate(stockBalancesProvider);
          ref.invalidate(inventoryValuationProvider);
          ref.invalidate(batchesListProvider);
          ref.invalidate(expiryAlertsProvider);
          ref.invalidate(reorderSuggestionsProvider);
          break;
        case 2: // Purchasing
          ref.read(purchasesControllerProvider.notifier).refresh();
          ref.read(suppliersControllerProvider.notifier).refresh();
          break;
        case 3: // Sales History
          ref.invalidate(salesListProvider);
          break;
        case 4: // Expenses
          ref.read(expensesListProvider.notifier).loadExpenses();
          ref.read(expenseCategoriesProvider.notifier).loadCategories();
          ref.read(recurringExpensesProvider.notifier).loadRecurringExpenses();
          break;
        case 5: // Accounts
          ref.read(financialAccountsProvider.notifier).loadAccounts();
          ref.invalidate(cashFlowReportProvider);
          ref.invalidate(apAgingReportProvider);
          ref.invalidate(accountTransfersProvider);
          break;
        case 6: // Customers
          ref.read(customersControllerProvider.notifier).refresh();
          break;
        case 7: // Stores & Transfers
          ref.read(branchesListProvider.notifier).loadBranches();
          ref.read(transfersListProvider.notifier).loadTransfers();
          break;
        case 8: // Reports
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(salesTimeSeriesProvider);
          ref.invalidate(stockValuationProvider);
          ref.invalidate(paymentBreakdownProvider);
          ref.invalidate(topProductsProvider);
          ref.invalidate(customerDuesReportProvider);
          break;
        case 9: // Settings
          ref.read(businessSettingsProvider.notifier).loadSettings();
          ref.read(licenseStatusProvider.notifier).loadLicense();
          ref.read(backupsListProvider.notifier).loadBackups();
          break;
      }
      if (showFeedback && mounted) {
        final loc = ref.read(appLocalizationsProvider);
        final label = _getDestinations(loc)[index].label;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label ${loc.isBangla ? "à¦°à¦¿à¦«à§à¦°à§‡à¦¶ à¦¸à¦®à§à¦ªà¦¨à§à¦¨" : "refreshed"}'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Ignored: screen state notifier or future captures failure
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  List<NavigationDestination> _getDestinations(AppLocalizations loc) => [
    NavigationDestination(
      icon: const Icon(Icons.point_of_sale_outlined),
      selectedIcon: const Icon(Icons.point_of_sale),
      label: loc.tr('pos_register', 'POS Register'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.inventory_2_outlined),
      selectedIcon: const Icon(Icons.inventory_2),
      label: loc.tr('catalog_stock', 'Catalog & Stock'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.local_shipping_outlined),
      selectedIcon: const Icon(Icons.local_shipping),
      label: loc.tr('purchasing', 'Purchasing'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.receipt_long_outlined),
      selectedIcon: const Icon(Icons.receipt_long),
      label: loc.tr('sales_history', 'Sales History'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.request_quote_outlined),
      selectedIcon: const Icon(Icons.request_quote),
      label: loc.tr('expenses', 'Expenses'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.account_balance_outlined),
      selectedIcon: const Icon(Icons.account_balance),
      label: loc.tr('accounts', 'Accounts'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.people_outline),
      selectedIcon: const Icon(Icons.people),
      label: loc.tr('customers', 'Customers'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.store_outlined),
      selectedIcon: const Icon(Icons.store),
      label: loc.tr('stores_transfers', 'Stores & Transfers'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.analytics_outlined),
      selectedIcon: const Icon(Icons.analytics),
      label: loc.tr('reports', 'Reports'),
    ),
    NavigationDestination(
      icon: const Icon(Icons.settings_outlined),
      selectedIcon: const Icon(Icons.settings),
      label: loc.tr('settings', 'Settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen<TerminalPreferencesModel>(terminalPreferencesProvider, (prev, next) {
      if (prev?.autoRefreshIntervalSeconds != next.autoRefreshIntervalSeconds) {
        _setupAutoRefresh(next.autoRefreshIntervalSeconds);
      }
    });

    final activeBranch = ref.watch(activeBranchProvider);
    final branches = ref.watch(branchesListProvider).branches;
    final syncState = ref.watch(syncControllerProvider);
    final shiftState = ref.watch(currentShiftProvider).valueOrNull;
    final loc = ref.watch(appLocalizationsProvider);
    final destinations = _getDestinations(loc);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.tr('app_title', 'Retail POS â€” Local Terminal'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          // Language Switcher (EN / à¦¬à¦¾à¦‚à¦²à¦¾)
          InkWell(
            onTap: () {
              final currentLang = ref.read(appLanguageProvider);
              ref.read(appLanguageProvider.notifier).state =
                  currentLang == 'en' ? 'bn' : 'en';
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    loc.isBangla ? 'English' : 'à¦¬à¦¾à¦‚à¦²à¦¾',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Shift Status Pill
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (shiftState?.isOpen ?? false)
                  ? const Color(0xFF10B981).withValues(alpha: 0.25)
                  : Colors.amber.shade700.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (shiftState?.isOpen ?? false)
                    ? const Color(0xFF10B981).withValues(alpha: 0.5)
                    : Colors.amber.shade300.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  (shiftState?.isOpen ?? false)
                      ? Icons.check_circle
                      : Icons.pause_circle_outline,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  (shiftState?.isOpen ?? false)
                      ? '${loc.tr('shift_active', 'Shift Active')}${shiftState?.cashierName != null ? " Â· ${shiftState!.cashierName}" : ""}'
                      : loc.tr('shift_inactive', 'Shift Inactive'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

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

          // Keyboard Shortcuts Trigger
          IconButton(
            tooltip: 'Keyboard Shortcuts (F1)',
            icon: const Icon(Icons.keyboard_outlined, color: Colors.white, size: 20),
            onPressed: () => KeyboardShortcutsDialog.show(context),
          ),

          // Screen Auto/Manual Refresh trigger button & indicator
          InkWell(
            onTap: _isRefreshing ? null : () => _refreshScreen(_selectedIndex, showFeedback: true),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isRefreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    _isRefreshing ? 'Refreshing...' : 'Refresh',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
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
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - kToolbarHeight),
              child: IntrinsicHeight(
                child: NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                    _refreshScreen(index);
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Icon(Icons.storefront, size: 32, color: Color(0xFF0F766E)),
                  ),
                  destinations: destinations.map((d) {
                    return NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    );
                  }).toList(),
                ),
              ),
            ),
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
                                ? const ExpensesScreen()
                                : _selectedIndex == 5
                                    ? const FinancialAccountsScreen()
                                    : _selectedIndex == 6
                                        ? const CustomersScreen()
                                        : _selectedIndex == 7
                                            ? const BranchesScreen()
                                            : _selectedIndex == 8
                                                ? const ReportsScreen()
                                                : _selectedIndex == 9
                                                    ? const SettingsScreen()
                                                    : Center(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          destinations[_selectedIndex].icon is Icon
                                                              ? (destinations[_selectedIndex].icon as Icon).icon
                                                              : Icons.dashboard,
                                                          size: 64,
                                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                                        ),
                                                        const SizedBox(height: 16),
                                                        Text(
                                                          destinations[_selectedIndex].label,
                                                          style: Theme.of(context).textTheme.headlineSmall,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        const Text(
                                                          'Coming Soon',
                                                          style: TextStyle(color: Colors.grey),
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
