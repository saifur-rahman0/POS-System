import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/settings/presentation/controllers/settings_controller.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/store_profile_tab.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/hardware_tab.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/licensing_tab.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/backups_tab.dart';
import 'package:pos_client/features/settings/presentation/views/tabs/system_preferences_tab.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Top Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
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
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.settings_suggest_rounded,
                            color: theme.primaryColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings & System Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Configure store branding, thermal printers, offline licensing, and automated backups',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
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
                        foregroundColor: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: theme.primaryColor,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  indicatorColor: theme.primaryColor,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.storefront_outlined),
                      text: 'Store Profile',
                    ),
                    Tab(
                      icon: Icon(Icons.print_outlined),
                      text: 'Hardware & Printers',
                    ),
                    Tab(
                      icon: Icon(Icons.vpn_key_outlined),
                      text: 'Offline Licensing',
                    ),
                    Tab(
                      icon: Icon(Icons.backup_outlined),
                      text: 'Database Backups',
                    ),
                    Tab(
                      icon: Icon(Icons.tune_outlined),
                      text: 'System Preferences',
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
