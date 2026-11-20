import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_client/app/theme.dart';

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
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String group;

  const _ShellNavTarget({
    required this.screenIndex,
    required this.sectionKey,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.group,
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
  Timer? _clockTimer;
  bool _isRefreshing = false;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(terminalPreferencesProvider);
    _setupAutoRefresh(prefs.autoRefreshIntervalSeconds);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
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
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshScreen(int index, {bool showFeedback = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      switch (index) {
        case 0:
          ref.invalidate(posProductsProvider);
          ref.read(currentShiftProvider.notifier).loadCurrentShift();
          ref.read(branchesListProvider.notifier).loadBranches();
          break;
        case 1:
          ref.invalidate(paginatedProductsProvider);
          ref.invalidate(categoryListProvider);
          ref.invalidate(stockBalancesProvider);
          ref.invalidate(inventoryValuationProvider);
          ref.invalidate(batchesListProvider);
          ref.invalidate(expiryAlertsProvider);
          ref.invalidate(reorderSuggestionsProvider);
          break;
        case 2:
          ref.read(purchasesControllerProvider.notifier).refresh();
          ref.read(suppliersControllerProvider.notifier).refresh();
          break;
        case 3:
          ref.invalidate(salesListProvider);
          break;
        case 4:
          ref.read(expensesListProvider.notifier).loadExpenses();
          ref.read(expenseCategoriesProvider.notifier).loadCategories();
          ref.read(recurringExpensesProvider.notifier).loadRecurringExpenses();
          break;
        case 5:
          ref.read(financialAccountsProvider.notifier).loadAccounts();
          ref.invalidate(cashFlowReportProvider);
          ref.invalidate(apAgingReportProvider);
          ref.invalidate(accountTransfersProvider);
          break;
        case 6:
          ref.read(customersControllerProvider.notifier).refresh();
          break;
        case 7:
          ref.read(branchesListProvider.notifier).loadBranches();
          ref.read(transfersListProvider.notifier).loadTransfers();
          break;
        case 8:
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(salesTimeSeriesProvider);
          ref.invalidate(stockValuationProvider);
          ref.invalidate(paymentBreakdownProvider);
          ref.invalidate(topProductsProvider);
          ref.invalidate(customerDuesReportProvider);
          break;
        case 9:
          ref.read(businessSettingsProvider.notifier).loadSettings();
          ref.read(licenseStatusProvider.notifier).loadLicense();
          ref.read(backupsListProvider.notifier).loadBackups();
          break;
      }

      if (showFeedback && mounted) {
        final loc = ref.read(appLocalizationsProvider);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.isBangla ? 'রিফ্রেশ সম্পন্ন হয়েছে' : 'Screen refreshed successfully'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
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
          group: 'SALES',
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          label: loc.tr('pos_register', 'POS Register'),
        ),
        _ShellNavTarget(
          screenIndex: 3,
          sectionKey: 'sales',
          group: 'SALES',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: loc.tr('sales_history', 'Sales History'),
        ),
        _ShellNavTarget(
          screenIndex: 1,
          sectionKey: 'catalog',
          group: 'STOCK & CATALOG',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: loc.tr('catalog_stock', 'Catalog & Stock'),
        ),
        _ShellNavTarget(
          screenIndex: 2,
          sectionKey: 'purchasing',
          group: 'STOCK & CATALOG',
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping,
          label: loc.tr('purchasing', 'Purchasing'),
        ),
        _ShellNavTarget(
          screenIndex: 7,
          sectionKey: 'transfers',
          group: 'STOCK & CATALOG',
          icon: Icons.store_outlined,
          selectedIcon: Icons.store,
          label: loc.tr('stores_transfers', 'Stores & Transfers'),
        ),
        _ShellNavTarget(
          screenIndex: 4,
          sectionKey: 'expenses',
          group: 'FINANCE & ACCOUNTS',
          icon: Icons.request_quote_outlined,
          selectedIcon: Icons.request_quote,
          label: loc.tr('expenses', 'Expenses'),
        ),
        _ShellNavTarget(
          screenIndex: 5,
          sectionKey: 'accounts',
          group: 'FINANCE & ACCOUNTS',
          icon: Icons.account_balance_outlined,
          selectedIcon: Icons.account_balance,
          label: loc.tr('accounts', 'Accounts'),
        ),
        _ShellNavTarget(
          screenIndex: 6,
          sectionKey: 'customers',
          group: 'CRM & CUSTOMERS',
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: loc.tr('customers', 'Customers'),
        ),
        _ShellNavTarget(
          screenIndex: 8,
          sectionKey: 'reports',
          group: 'MANAGEMENT',
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics,
          label: loc.tr('reports', 'Reports'),
        ),
        _ShellNavTarget(
          screenIndex: 9,
          sectionKey: 'settings',
          group: 'MANAGEMENT',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: loc.tr('settings', 'Settings'),
        ),
      ];

  Color _getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
      case 'OWNER':
        return AppColors.accentPurple;
      case 'MANAGER':
        return AppColors.accentBlue;
      case 'STOCK_KEEPER':
      case 'STOCK':
        return AppColors.accentAmber;
      case 'CASHIER':
      default:
        return AppColors.accentTeal;
    }
  }

  String _getRoleLabel(String? role, AppLocalizations loc) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
      case 'OWNER':
        return loc.tr('role_admin', 'Stall Owner (Admin)');
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

  String _clockString() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${_now.day} ${months[_now.month - 1]} · $h:$m:$s';
  }

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

    final roleColor = _getRoleColor(authUser?.role);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          // ── Premium Dark Header Bar (56px) ──────────────────────────────
          _buildHeaderBar(loc, authUser, roleColor, activeBranch, branches, syncState, shiftState),

          // ── Main Layout: Dark Sidebar Rail + Content Body ───────────────
          Expanded(
            child: Row(
              children: [
                // Dark Sidebar Rail
                _buildSidebarRail(allowedTargets, loc, authUser, roleColor),

                // Main Page Content with Smooth Transition
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
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
                      key: ValueKey('screen_idx_$_selectedIndex'),
                      child: _buildCurrentScreen(_selectedIndex, loc),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(
    AppLocalizations loc,
    dynamic authUser,
    Color roleColor,
    dynamic activeBranch,
    List branches,
    dynamic syncState,
    dynamic shiftState,
  ) {
    return Container(
      height: 56,
      color: AppColors.headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Logo & Brand
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accentTeal, Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentTeal.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Apex Mobile',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '& Gadgets',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    loc.tr('terminal_mode', 'Terminal 01 · Gulshan Branch'),
                    style: GoogleFonts.inter(
                      color: AppColors.accentTeal,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),

          // Live digital clock pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 13, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  _clockString(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Shift Status Pill
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (shiftState?.isOpen ?? false)
                  ? AppColors.accentGreen.withValues(alpha: 0.18)
                  : AppColors.accentAmber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (shiftState?.isOpen ?? false)
                    ? AppColors.accentGreen.withValues(alpha: 0.45)
                    : AppColors.accentAmber.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: (shiftState?.isOpen ?? false) ? AppColors.accentGreen : AppColors.accentAmber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  (shiftState?.isOpen ?? false)
                      ? '${loc.tr('shift_active', 'Shift Active')}${shiftState?.cashierName != null ? " · ${shiftState!.cashierName}" : ""}'
                      : loc.tr('shift_inactive', 'Shift Inactive'),
                  style: GoogleFonts.inter(
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
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activeBranch?.id,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                  dropdownColor: AppColors.sidebarHover,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                  items: branches.where((b) => b.isActive).map<DropdownMenuItem<String>>((b) {
                    return DropdownMenuItem<String>(
                      value: b.id,
                      child: Row(
                        children: [
                          const Icon(Icons.store, size: 14, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(b.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      final selected = branches.firstWhere((b) => b.id == newId);
                      ref.read(activeBranchProvider.notifier).state = selected;
                    }
                  },
                ),
              ),
            ),

          // Segmented Language Switcher (EN | বাংলা)
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _langBtn('EN', !loc.isBangla, () => ref.read(appLanguageProvider.notifier).state = 'en'),
                _langBtn(loc.tr('lang_bn', 'বাং'), loc.isBangla, () => ref.read(appLanguageProvider.notifier).state = 'bn'),
              ],
            ),
          ),

          // Keyboard Shortcuts Trigger
          IconButton(
            tooltip: 'Keyboard Shortcuts (F1)',
            icon: const Icon(Icons.keyboard_outlined, color: Colors.white70, size: 19),
            onPressed: () => KeyboardShortcutsDialog.show(context),
          ),

          // Screen Auto/Manual Refresh
          InkWell(
            onTap: _isRefreshing ? null : () => _refreshScreen(_selectedIndex, showFeedback: true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isRefreshing
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                        )
                      : const Icon(Icons.refresh, size: 15, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text(
                    _isRefreshing ? 'Refreshing…' : 'Refresh',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          // Offline Delta Sync trigger
          InkWell(
            onTap: syncState.isSyncing
                ? null
                : () async {
                    final ok = await ref.read(syncControllerProvider.notifier).pullDeltas(branchId: activeBranch?.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Catalog & Balances synced with central server'
                              : 'Sync failed: ${ref.read(syncControllerProvider).errorMessage}'),
                        ),
                      );
                    }
                  },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  syncState.isSyncing
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_sync_outlined, size: 15, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text(
                    syncState.isSyncing ? 'Syncing…' : 'Sync',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.accentTeal : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarRail(
    List<_ShellNavTarget> targets,
    AppLocalizations loc,
    dynamic authUser,
    Color roleColor,
  ) {
    // Group targets
    final groups = <String, List<_ShellNavTarget>>{};
    for (final t in targets) {
      groups.putIfAbsent(t.group, () => []).add(t);
    }

    return Container(
      width: 216,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groups.entries.map((group) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Text(
                          group.key,
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white30,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      ...group.value.map((target) => _buildNavItem(target)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Bottom User Profile & Role Switcher
          _buildSidebarUserFooter(authUser, roleColor, loc),
        ],
      ),
    );
  }

  Widget _buildNavItem(_ShellNavTarget target) {
    final isSelected = _selectedIndex == target.screenIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentTeal.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppColors.accentTeal.withValues(alpha: 0.35))
              : null,
        ),
        child: InkWell(
          onTap: () {
            setState(() => _selectedIndex = target.screenIndex);
            _refreshScreen(target.screenIndex);
          },
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
            child: Row(
              children: [
                Icon(
                  isSelected ? target.selectedIcon : target.icon,
                  size: 18,
                  color: isSelected ? AppColors.accentTeal : Colors.white54,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    target.label,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.accentTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarUserFooter(dynamic authUser, Color roleColor, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: PopupMenuButton<String>(
        key: const Key('user_menu_button'),
        offset: const Offset(216, -100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                title: Row(
                  children: [
                    const Icon(Icons.logout, color: AppColors.accentTeal),
                    const SizedBox(width: 8),
                    Text(loc.tr('logout', 'Sign Out Terminal')),
                  ],
                ),
                content: Text(loc.tr('confirm_logout', 'Are you sure you want to sign out of this terminal?')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(loc.tr('cancel', 'Cancel')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accentRose),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ref.read(authControllerProvider.notifier).logout();
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
                Text(
                  authUser?.displayName ?? 'Stall Owner (Admin)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                Text(
                  '@${authUser?.username ?? "admin"}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
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
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          const PopupMenuItem(
            value: 'role_ADMIN',
            child: Row(children: [Text('👑', style: TextStyle(fontSize: 14)), SizedBox(width: 8), Text('Stall Owner (Admin)', style: TextStyle(fontSize: 13))]),
          ),
          const PopupMenuItem(
            value: 'role_MANAGER',
            child: Row(children: [Text('👔', style: TextStyle(fontSize: 14)), SizedBox(width: 8), Text('Store Manager', style: TextStyle(fontSize: 13))]),
          ),
          const PopupMenuItem(
            value: 'role_CASHIER',
            child: Row(children: [Text('💳', style: TextStyle(fontSize: 14)), SizedBox(width: 8), Text('Cashier', style: TextStyle(fontSize: 13))]),
          ),
          const PopupMenuItem(
            value: 'role_STOCK_KEEPER',
            child: Row(children: [Text('📦', style: TextStyle(fontSize: 14)), SizedBox(width: 8), Text('Stock Keeper', style: TextStyle(fontSize: 13))]),
          ),
          if (authUser?.isAdmin == true) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'manage_users',
              child: Row(
                children: [
                  const Icon(Icons.manage_accounts, size: 16, color: AppColors.accentTeal),
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
                const Icon(Icons.logout, size: 16, color: AppColors.accentRose),
                const SizedBox(width: 8),
                Text(loc.tr('logout', 'Sign Out Terminal'), style: const TextStyle(color: AppColors.accentRose, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: roleColor,
                child: Text(
                  (authUser != null && authUser.displayName.isNotEmpty
                          ? authUser.displayName[0]
                          : 'A')
                      .toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      authUser?.displayName ?? 'Stall Owner (Admin)',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getRoleLabel(authUser?.role, loc),
                        style: GoogleFonts.inter(
                          color: roleColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.unfold_more, size: 16, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen(int index, AppLocalizations loc) {
    final authUser = ref.watch(authControllerProvider).user;
    final allTargets = _getAllNavTargets(loc);
    final target = allTargets.firstWhere(
      (t) => t.screenIndex == index,
      orElse: () => allTargets.first,
    );

    if (authUser != null && !authUser.canAccessSection(target.sectionKey)) {
      return _buildUnauthorizedScreen(loc, target.label);
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
        return const PosRegisterScreen();
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
          border: Border.all(color: AppColors.cardBorder),
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
                color: AppColors.accentRose.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded, size: 48, color: AppColors.accentRose),
            ),
            const SizedBox(height: 18),
            Text(
              loc.tr('access_restricted', 'Access Restricted'),
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              loc.tr(
                'access_restricted_desc',
                'Your account role (${user?.roleDisplayName ?? "Staff"}) does not have permission to access $sectionTitle.',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
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
