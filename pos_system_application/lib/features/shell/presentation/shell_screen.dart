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

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../../core/localization/app_localizations.dart';

import '../../../core/widgets/keyboard_shortcuts_dialog.dart';

class _ShellNavTarget {
  final int screenIndex;
  final String sectionKey;
  final NavigationDestination destination;

  const _ShellNavTarget({
    required this.screenIndex,
    required this.sectionKey,
    required this.destination,
  });
}

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
            content: Text(
                '$label ${loc.isBangla ? "রিফ্রেশ সম্পন্ন" : "refreshed"}'),
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

  List<_ShellNavTarget> _getAllNavTargets(AppLocalizations loc) => [
        _ShellNavTarget(
          screenIndex: 0,
          sectionKey: 'pos',
          destination: NavigationDestination(
            icon: const Icon(Icons.point_of_sale_outlined),
            selectedIcon: const Icon(Icons.point_of_sale),
            label: loc.tr('pos_register', 'POS Register'),
          ),
        ),
        _ShellNavTarget(
          screenIndex: 1,
          sectionKey: 'catalog',
          destination: NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: loc.tr('catalog_stock', 'Catalog & Stock'),
          ),
        ),
        _ShellNavTarget(
          screenIndex: 2,
          sectionKey: 'purchasing',
          destination: NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping),
            label: loc.tr('purchasing', 'Purchasing'),
          ),
        ),
        _ShellNavTarget(
          screenIndex: 3,
          sectionKey: 'sales',
          destination: NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: loc.tr('sales_history', 'Sales History'),
          ),
        ),
        _ShellNavTarget(
          screenIndex: 4,
          sectionKey: 'expenses',
          destination: NavigationDestination(
            icon: const Icon(Icons.request_quote_outlined),
            selectedIcon: const Icon(Icons.request_quote),
            label: loc.tr('expenses', 'Expenses'),
          ),
        ),
        _ShellNavTarget(
          screenIndex: 5,
          sectionKey: 'accounts',
          destination: NavigationDestination(
            icon: const Icon(Icons.account_balance_outlined),
            selectedIcon: const Icon(Icons.account_balance),
            label: loc.tr('accounts', 'Accounts'),
          ),
        ),
        _ShellNavTarget(
          screenIndex: 6,
          sectionKey: 'customers',
          destination: NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: loc.tr('customers', 'Customers'),
          ),
        ),
        _ShellNavTarget(
          screenIndex: 7,
          sectionKey: 'transfers',
          destination: NavigationDestination(
            icon: const Icon(Icons.store_outlined),
            selectedIcon: const Icon(Icons.store),
            label: loc.tr('stores_transfers', 'Stores & Transfers'),
          ),
        ),
        _ShellNavTarget(
          screenIndex: 8,
          sectionKey: 'reports',
          destination: NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: const Icon(Icons.analytics),
            label: loc.tr('reports', 'Reports'),
          ),
        ),
        _ShellNavTarget(
          screenIndex: 9,
          sectionKey: 'settings',
          destination: NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: loc.tr('settings', 'Settings'),
          ),
        ),
      ];

  List<NavigationDestination> _getDestinations(AppLocalizations loc) =>
      _getAllNavTargets(loc).map((t) => t.destination).toList();

  Color _getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
      case 'OWNER':
        return const Color(0xFF7C3AED); // Purple
      case 'MANAGER':
        return const Color(0xFF2563EB); // Blue
      case 'STOCK_KEEPER':
      case 'STOCK':
        return const Color(0xFFD97706); // Amber
      case 'CASHIER':
      default:
        return const Color(0xFF0F766E); // Teal
    }
  }

  String _getRoleLabel(String? role, AppLocalizations loc) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
      case 'OWNER':
        return loc.tr('role_admin', 'Stall Owner');
      case 'MANAGER':
        return loc.tr('role_manager', 'Store Manager');
      case 'STOCK_KEEPER':
      case 'STOCK':
        return loc.tr('role_stock_keeper', 'Stock Keeper');
      case 'CASHIER':
      default:
        return loc.tr('role_cashier', 'Cashier');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TerminalPreferencesModel>(terminalPreferencesProvider,
        (prev, next) {
      if (prev?.autoRefreshIntervalSeconds != next.autoRefreshIntervalSeconds) {
        _setupAutoRefresh(next.autoRefreshIntervalSeconds);
      }
    });

    final activeBranch = ref.watch(activeBranchProvider);

    final branches = ref.watch(branchesListProvider).branches;

    final syncState = ref.watch(syncControllerProvider);

    final shiftState = ref.watch(currentShiftProvider).valueOrNull;

    final loc = ref.watch(appLocalizationsProvider);
    final authUser = ref.watch(authControllerProvider).user;
    final allTargets = _getAllNavTargets(loc);
    final allowedTargets = allTargets.where((t) {
      if (authUser == null) return true;
      return authUser.canAccessSection(t.sectionKey);
    }).toList();

    // Ensure _selectedIndex is valid among allowed targets
    final allowedIndices = allowedTargets.map((t) => t.screenIndex).toList();
    if (!allowedIndices.contains(_selectedIndex) && allowedIndices.isNotEmpty) {
      _selectedIndex = allowedIndices.first;
    }

    int railSelectedIndex =
        allowedTargets.indexWhere((t) => t.screenIndex == _selectedIndex);
    if (railSelectedIndex < 0) railSelectedIndex = 0;
    final destinations = _getDestinations(loc);
    final roleColor = _getRoleColor(authUser?.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.tr('app_title', 'Retail POS — Local Terminal'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          // Segmented Language Switcher (EN | বাংলা)
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 6, right: 4),
                  child: Icon(Icons.language, size: 14, color: Colors.white),
                ),
                InkWell(
                  onTap: () =>
                      ref.read(appLanguageProvider.notifier).state = 'en',
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: !loc.isBangla ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'EN',
                      style: TextStyle(
                        color: !loc.isBangla
                            ? const Color(0xFF0F766E)
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () =>
                      ref.read(appLanguageProvider.notifier).state = 'bn',
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: loc.isBangla ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      loc.tr('lang_bn', '\u09ac\u09be\u0982\u09b2\u09be'),
                      style: TextStyle(
                        color: loc.isBangla
                            ? const Color(0xFF0F766E)
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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
                      ? '${loc.tr('shift_active', 'Shift Active')}${shiftState?.cashierName != null ? " \u00B7 ${shiftState!.cashierName}" : ""}'
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
                          const Icon(Icons.store,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(b.name,
                              style: const TextStyle(color: Colors.white)),
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
            icon: const Icon(Icons.keyboard_outlined,
                color: Colors.white, size: 20),
            onPressed: () => KeyboardShortcutsDialog.show(context),
          ),

          // Screen Auto/Manual Refresh trigger button & indicator

          InkWell(
            onTap: _isRefreshing
                ? null
                : () => _refreshScreen(_selectedIndex, showFeedback: true),
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
                      : const Icon(Icons.refresh,
                          size: 16, color: Colors.white),
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

                  // User Profile & Role Switcher Popup Menu
                  PopupMenuButton<String>(
                    key: const Key('user_menu_button'),
                    tooltip: loc.tr('switch_user', 'User Account / Logout'),
                    offset: const Offset(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val.startsWith('role_')) {
                        final roleName = val.replaceFirst('role_', '');
                        ref.read(authControllerProvider.notifier).switchDemoRole(roleName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to ${_getRoleLabel(roleName, loc)}'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      } else if (val == 'manage_users') {
                        setState(() => _selectedIndex = 9);
                      } else if (val == 'logout') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              children: [
                                const Icon(Icons.logout,
                                    color: Color(0xFF0F766E)),
                                const SizedBox(width: 8),
                                Text(loc.tr('logout', 'Sign Out Terminal')),
                              ],
                            ),
                            content: Text(
                              loc.tr('confirm_logout',
                                  'Are you sure you want to sign out of this terminal?'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: Text(loc.tr('cancel', 'Cancel')),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red.shade700),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  ref
                                      .read(authControllerProvider.notifier)
                                      .logout();
                                },
                                child: Text(loc.tr('logout', 'Sign Out')),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  authUser?.displayName ?? 'Dev Cashier',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    _getRoleLabel(authUser?.role, loc),
                                    style: TextStyle(
                                      color: roleColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '@${authUser?.username ?? "dev_cashier"}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        enabled: false,
                        height: 24,
                        child: Text(
                          loc.tr('switch_role', 'Switch Role (Demo):'),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'role_ADMIN',
                        child: Row(
                          children: [
                            Text('👑', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 8),
                            Text('Stall Owner (Admin)', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'role_MANAGER',
                        child: Row(
                          children: [
                            Text('👔', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 8),
                            Text('Store Manager', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'role_CASHIER',
                        child: Row(
                          children: [
                            Text('💳', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 8),
                            Text('Cashier', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'role_STOCK_KEEPER',
                        child: Row(
                          children: [
                            Text('📦', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 8),
                            Text('Stock Keeper', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      if (authUser?.isAdmin == true) ...[
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'manage_users',
                          child: Row(
                            children: [
                              const Icon(Icons.manage_accounts, size: 16, color: Color(0xFF0F766E)),
                              const SizedBox(width: 8),
                              Text(
                                loc.tr('staff_permissions', 'Users & Permissions'),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout,
                                size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              loc.tr('logout', 'Sign Out Terminal'),
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: roleColor,
                            child: Text(
                              (authUser != null && authUser.displayName.isNotEmpty
                                      ? authUser.displayName[0]
                                      : 'U')
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            authUser?.displayName ?? 'Cashier',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: roleColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _getRoleLabel(authUser?.role, loc),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down,
                              size: 16, color: Colors.white),
                        ],
                      ),
                    ),
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
              constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height - kToolbarHeight),
              child: IntrinsicHeight(
                child: NavigationRail(
                  selectedIndex: railSelectedIndex,
                  onDestinationSelected: (int railIdx) {
                    final targetScreenIndex = allowedTargets[railIdx].screenIndex;
                    setState(() {
                      _selectedIndex = targetScreenIndex;
                    });

                    _refreshScreen(targetScreenIndex);
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Icon(Icons.storefront,
                        size: 32, color: Color(0xFF0F766E)),
                  ),
                  destinations: allowedTargets.map((t) {
                    return NavigationRailDestination(
                      icon: t.destination.icon,
                      selectedIcon: t.destination.selectedIcon,
                      label: Text(t.destination.label),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.015, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('screen_dest_$_selectedIndex'),
                child: _buildCurrentScreen(_selectedIndex, loc, destinations),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen(
    int index,
    AppLocalizations loc,
    List<NavigationDestination> destinations,
  ) {
    final authUser = ref.watch(authControllerProvider).user;
    final allTargets = _getAllNavTargets(loc);
    final target = allTargets.firstWhere(
      (t) => t.screenIndex == index,
      orElse: () => allTargets.first,
    );

    if (authUser != null && !authUser.canAccessSection(target.sectionKey)) {
      return _buildUnauthorizedScreen(loc, target.destination.label);
    }

    switch (index) {
      case 0:
        return const PosRegisterScreen();
      case 1:
        return const CatalogScreen();
      case 2:
        return const PurchasingScreen();
      case 3:
        return const SalesHistoryScreen();
      case 4:
        return const ExpensesScreen();
      case 5:
        return const FinancialAccountsScreen();
      case 6:
        return const CustomersScreen();
      case 7:
        return const BranchesScreen();
      case 8:
        return const ReportsScreen();
      case 9:
        return const SettingsScreen();
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                destinations[index].icon is Icon
                    ? (destinations[index].icon as Icon).icon
                    : Icons.dashboard,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                destinations[index].label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Coming Soon',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildUnauthorizedScreen(AppLocalizations loc, String sectionTitle) {
    final user = ref.watch(authControllerProvider).user;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_person_rounded, size: 48, color: Colors.red.shade600),
            ),
            const SizedBox(height: 18),
            Text(
              loc.tr('access_restricted', 'Access Restricted'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              loc.tr(
                'access_restricted_desc',
                'Your account role (${user?.roleDisplayName ?? "Staff"}) does not have permission to access $sectionTitle.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to Cash Register'),
              onPressed: () {
                setState(() => _selectedIndex = 0);
              },
            ),
          ],
        ),
      ),
    );
  }
}
