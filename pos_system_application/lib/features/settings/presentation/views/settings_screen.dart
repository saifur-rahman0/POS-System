import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/auth/presentation/controllers/auth_controller.dart';
import 'package:pos_client/features/settings/presentation/controllers/settings_controller.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/store_profile_tab.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/hardware_tab.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/licensing_tab.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/backups_tab.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/system_preferences_tab.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/users_tab.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(businessSettingsProvider.notifier).loadSettings(),
      ref.read(licenseStatusProvider.notifier).loadLicense(),
      ref.read(backupsListProvider.notifier).loadBackups(),
    ]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings and license status refreshed successfully'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).user;
    final canManageUsers = currentUser?.isAdmin == true || currentUser?.hasPermission('users:manage') == true;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          // Top Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.cardBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.settings_suggest_rounded,
                            color: AppColors.accentTeal,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings & System Management',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Configure store branding, staff permissions, thermal printers, and automated backups',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Refresh Settings',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _refreshAll,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (currentUser?.isAdmin != true) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 14, color: AppColors.accentAmber),
                        const SizedBox(width: 6),
                        Text(
                          'Non-admin role (${currentUser?.roleDisplayName ?? "Staff"}): Some management actions require administrator privileges',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFB45309), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.accentTeal,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  indicatorColor: AppColors.accentTeal,
                  indicatorWeight: 3,
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.storefront_outlined),
                      text: 'Store Profile',
                    ),
                    const Tab(
                      icon: Icon(Icons.print_outlined),
                      text: 'Hardware & Printers',
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.vpn_key_outlined),
                          if (currentUser?.isAdmin != true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock_rounded, size: 12, color: AppColors.accentAmber),
                          ],
                        ],
                      ),
                      text: 'Offline Licensing',
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.backup_outlined),
                          if (currentUser?.isAdmin != true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock_rounded, size: 12, color: AppColors.accentAmber),
                          ],
                        ],
                      ),
                      text: 'Database Backups',
                    ),
                    const Tab(
                      icon: Icon(Icons.tune_outlined),
                      text: 'System Preferences',
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge_outlined),
                          if (!canManageUsers) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock_rounded, size: 12, color: AppColors.accentAmber),
                          ],
                        ],
                      ),
                      text: canManageUsers ? 'Users & Permissions' : 'My Permissions',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                StoreProfileTab(),
                HardwareTab(),
                LicensingTab(),
                BackupsTab(),
                SystemPreferencesTab(),
                UsersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
