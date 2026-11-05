import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../crm/domain/models/loyalty_settings.dart';
import '../../../crm/domain/models/membership_tier.dart';
import '../../../crm/domain/models/rfm_analytics.dart';
import '../../../crm/presentation/controllers/crm_controller.dart';
import '../../../crm/presentation/views/dialogs/adjust_points_dialog.dart';
import '../../../crm/presentation/views/dialogs/campaign_dialog.dart';
import '../../../crm/presentation/views/dialogs/issue_gift_card_dialog.dart';
import '../../../crm/presentation/views/dialogs/loyalty_settings_dialog.dart';
import '../../../crm/presentation/views/dialogs/membership_tier_dialog.dart';
import '../../../crm/presentation/views/dialogs/reload_gift_card_dialog.dart';
import '../controllers/customer_controller.dart';
import 'collect_due_dialog.dart';
import 'customer_form_dialog.dart';
import 'customer_ledger_dialog.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    // Listen to CRM action alerts
    ref.listen<CrmActionState>(crmControllerProvider, (_, state) {
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
          // Tab Header Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF0F766E),
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF0F766E),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: const [
                      Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Directory & Credit'),
                      Tab(icon: Icon(Icons.stars_outlined, size: 18), text: 'Loyalty & Tiers'),
                      Tab(icon: Icon(Icons.card_giftcard, size: 18), text: 'Gift Cards'),
                      Tab(icon: Icon(Icons.pie_chart_outline, size: 18), text: 'RFM Segments & Retention'),
                      Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Promotional Campaigns'),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh All',
                  onPressed: () {
                    ref.read(customersControllerProvider.notifier).refresh();
                    ref.read(crmControllerProvider.notifier).refreshAll();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _CustomerDirectoryTab(),
                _LoyaltyTiersTab(),
                _GiftCardsTab(),
                _RfmSegmentsTab(),
                _PromotionalCampaignsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 1: Customer Directory & Store Credit
// =============================================================================
class _CustomerDirectoryTab extends ConsumerStatefulWidget {
  const _CustomerDirectoryTab();

  @override
  ConsumerState<_CustomerDirectoryTab> createState() => _CustomerDirectoryTabState();
}

class _CustomerDirectoryTabState extends ConsumerState<_CustomerDirectoryTab> {
  final TextEditingController _searchController = TextEditingController();
  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersControllerProvider);
    final notifier = ref.read(customersControllerProvider.notifier);
    final paginated = state.paginated;
    final customers = paginated?.items ?? [];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Add Customer Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Management & Store Credit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customer balances, credit limits, and due settlement',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => CustomerFormDialog.show(context),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add Customer'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Total Customers',
                  value: '${paginated?.total ?? 0}',
                  icon: Icons.people,
                  color: const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildKpiCard(
                  title: 'Total Outstanding Dues',
                  value: currencyFmt.format(paginated?.totalOutstandingDues ?? 0.0),
                  icon: Icons.account_balance_wallet,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers by name or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          notifier.search('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) => notifier.search(val),
            ),
          ),
          const SizedBox(height: 12),

          // Customer Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : customers.isEmpty
                      ? const Center(child: Text('No customers found', style: TextStyle(color: Colors.grey)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                                    columns: const [
                                      DataColumn(label: Text('Customer Name')),
                                      DataColumn(label: Text('Phone')),
                                      DataColumn(label: Text('Points')),
                                      DataColumn(label: Text('Credit Limit', textAlign: TextAlign.right)),
                                      DataColumn(label: Text('Due Balance', textAlign: TextAlign.right)),
                                      DataColumn(label: Text('Store Credit', textAlign: TextAlign.right)),
                                      DataColumn(label: Text('Segment')),
                                      DataColumn(label: Text('Actions', textAlign: TextAlign.center)),
                                    ],
                                    rows: customers.map((c) {
                                      final hasDue = c.dueBalance > 0;
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                                  child: Text(
                                                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                          DataCell(Text(c.phone ?? '—', style: const TextStyle(fontSize: 12))),
                                          DataCell(
                                            Chip(
                                              label: Text('${c.loyaltyPointsBalance} pts', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              backgroundColor: Colors.amber.shade50,
                                              padding: EdgeInsets.zero,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                          DataCell(Text(currencyFmt.format(c.creditLimit), style: const TextStyle(fontSize: 12))),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: hasDue ? Colors.red.shade50 : Colors.transparent,
                                                borderRadius: BorderRadius.circular(4),
                                                border: hasDue ? Border.all(color: Colors.red.shade200) : null,
                                              ),
                                              child: Text(
                                                currencyFmt.format(c.dueBalance),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: hasDue ? FontWeight.bold : FontWeight.normal,
                                                  color: hasDue ? Colors.red.shade800 : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(currencyFmt.format(c.storeCreditBalance), style: const TextStyle(fontSize: 12, color: Colors.teal))),
                                          DataCell(
                                            Text(
                                              (c.rfmSegment ?? 'NEW').replaceAll('_', ' '),
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (hasDue)
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF0F766E),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    icon: const Icon(Icons.payments_outlined, size: 12),
                                                    label: const Text('Collect', style: TextStyle(fontSize: 11)),
                                                    onPressed: () => CollectDueDialog.show(context, customer: c),
                                                  ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.stars, size: 16, color: Colors.amber),
                                                  tooltip: 'Adjust Points',
                                                  onPressed: () => AdjustPointsDialog.show(
                                                    context,
                                                    customerId: c.id,
                                                    customerName: c.name,
                                                    currentPoints: c.loyaltyPointsBalance,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.history_edu, size: 16),
                                                  tooltip: 'Statement / Ledger',
                                                  onPressed: () => CustomerLedgerDialog.show(context, c),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                                  tooltip: 'Edit Profile',
                                                  onPressed: () => CustomerFormDialog.show(context, customer: c),
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
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 2: Loyalty Program & Membership Tiers
// =============================================================================
class _LoyaltyTiersTab extends ConsumerWidget {
  const _LoyaltyTiersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(loyaltySettingsProvider);
    final tiersAsync = ref.watch(membershipTiersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Loyalty Settings Card
          settingsAsync.when(
            data: (settings) => _buildSettingsCard(context, settings),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading settings: $e'),
          ),
          const SizedBox(height: 24),

          // Tiers Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Membership VIP Tiers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                onPressed: () => MembershipTierDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Tier'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tiers Grid
          tiersAsync.when(
            data: (tiers) {
              if (tiers.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No membership tiers configured yet. Click "Add Tier" to create Bronze, Silver, Gold tiers.')),
                  ),
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: tiers.map((tier) => _buildTierCard(context, ref, tier)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading tiers: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, LoyaltySettingsModel settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (settings.isEnabled ? Colors.amber : Colors.grey).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.stars, color: settings.isEnabled ? Colors.amber.shade800 : Colors.grey, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Loyalty Program Status: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Chip(
                            label: Text(settings.isEnabled ? 'ACTIVE' : 'DISABLED', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            backgroundColor: settings.isEnabled ? Colors.green : Colors.grey,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Earn Rate: ${settings.earnRate} pt/৳100  •  Redeem: 1 pt = ৳${settings.redeemRate}  •  Min Redeem: ${settings.minRedeemPoints} pts  •  Expiry: ${settings.pointsExpiryDays} days',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => LoyaltySettingsDialog.show(context, settings),
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Configure Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(BuildContext context, WidgetRef ref, MembershipTierModel tier) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(
                      tier.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: _parseColor(tier.badgeColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => MembershipTierDialog.show(context, tier: tier),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Tier'),
                          content: Text('Are you sure you want to delete ${tier.name}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        ref.read(crmControllerProvider.notifier).deleteTier(tier.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Spend Requirement: ৳ ${tier.minSpend.toStringAsFixed(0)}+', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Points Multiplier: ${tier.pointsMultiplier}x', style: const TextStyle(fontSize: 12)),
          Text('Discount Privilege: ${tier.discountPct}%', style: const TextStyle(fontSize: 12)),
          if (tier.perksDescription != null) ...[
            const SizedBox(height: 6),
            Text(tier.perksDescription!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF64748B);
    }
  }
}

// =============================================================================
// TAB 3: Gift Cards
// =============================================================================
class _GiftCardsTab extends ConsumerWidget {
  const _GiftCardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftCardsAsync = ref.watch(giftCardsProvider);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Issue Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Stored-Value Gift Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                onPressed: () => IssueGiftCardDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Issue Gift Card'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search by card number or recipient...', prefixIcon: Icon(Icons.search, size: 20), border: InputBorder.none, isDense: true),
              onChanged: (val) => ref.read(giftCardSearchQueryProvider.notifier).state = val,
            ),
          ),
          const SizedBox(height: 12),

          // Cards Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              clipBehavior: Clip.antiAlias,
              child: giftCardsAsync.when(
                data: (cards) {
                  if (cards.isEmpty) {
                    return const Center(child: Text('No gift cards found', style: TextStyle(color: Colors.grey)));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                        columns: const [
                          DataColumn(label: Text('Card Number')),
                          DataColumn(label: Text('Initial Value')),
                          DataColumn(label: Text('Current Balance')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Recipient')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: cards.map((card) {
                          final isActive = card.status == 'ACTIVE';
                          return DataRow(
                            cells: [
                              DataCell(Text(card.cardNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                              DataCell(Text('৳ ${card.initialBalance.toStringAsFixed(2)}')),
                              DataCell(Text('৳ ${card.currentBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E)))),
                              DataCell(
                                Chip(
                                  label: Text(card.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                  backgroundColor: isActive ? Colors.green : Colors.grey,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              DataCell(Text(card.recipientName ?? '—')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                                      icon: const Icon(Icons.add, size: 12),
                                      label: const Text('Reload', style: TextStyle(fontSize: 11)),
                                      onPressed: () => ReloadGiftCardDialog.show(context, card),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: Icon(isActive ? Icons.lock_outline : Icons.lock_open, size: 16),
                                      tooltip: isActive ? 'Lock Card' : 'Unlock Card',
                                      onPressed: () {
                                        ref.read(crmControllerProvider.notifier).toggleGiftCardStatus(card.id, isActive ? 'LOCKED' : 'ACTIVE');
                                      },
                                    ),
                                  ],
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
                error: (e, _) => Text('Error loading gift cards: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 4: RFM Segments & Customer Retention
// =============================================================================
class _RfmSegmentsTab extends ConsumerWidget {
  const _RfmSegmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rfmAsync = ref.watch(rfmAnalyticsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Customer Retention & Churn Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
          const SizedBox(height: 12),

          rfmAsync.when(
            data: (analytics) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // KPI Header
                Row(
                  children: [
                    Expanded(child: _buildMetricTile('Active Customers (90d)', '${analytics.totalActiveCustomers}', Icons.verified_user, Colors.teal)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricTile('Repeat Purchase Rate', '${analytics.repeatPurchaseRate}%', Icons.repeat, Colors.indigo)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricTile('90-Day Churn Rate', '${analytics.churnRate90d}%', Icons.warning_amber, Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricTile('Avg Lifetime Value', '৳ ${analytics.avgClv.toStringAsFixed(0)}', Icons.monetization_on, Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricTile('Revenue at Risk', '৳ ${analytics.revenueAtRisk.toStringAsFixed(0)}', Icons.crisis_alert, Colors.red)),
                  ],
                ),
                const SizedBox(height: 20),

                // Segments Grid
                const Text('RFM Behavioral Cohorts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: analytics.segments.map((seg) => _buildSegmentCard(seg)).toList(),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading RFM analytics: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(RfmSegmentSummary seg) {
    Color segColor = Colors.grey;
    if (seg.segment == 'CHAMPIONS') segColor = Colors.amber.shade700;
    if (seg.segment == 'LOYAL') segColor = Colors.green;
    if (seg.segment == 'POTENTIAL_LOYALIST') segColor = Colors.blue;
    if (seg.segment == 'AT_RISK') segColor = Colors.red;
    if (seg.segment == 'LOST') segColor = Colors.blueGrey;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(seg.segment.replaceAll('_', ' '), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: segColor)),
              Text('${seg.percentage}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${seg.count} customers', style: const TextStyle(fontSize: 12)),
          Text('Total Spent: ৳ ${seg.totalMonetary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text('Avg Recency: ${seg.avgRecencyDays.toStringAsFixed(0)} days ago', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 5: Promotional Campaigns
// =============================================================================
class _PromotionalCampaignsTab extends ConsumerWidget {
  const _PromotionalCampaignsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(promotionalCampaignsProvider);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Targeted Promotional Campaigns', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                onPressed: () => CampaignDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Campaign'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              clipBehavior: Clip.antiAlias,
              child: campaignsAsync.when(
                data: (campaigns) {
                  if (campaigns.isEmpty) {
                    return const Center(child: Text('No promotional campaigns drafted yet.', style: TextStyle(color: Colors.grey)));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                        columns: const [
                          DataColumn(label: Text('Campaign Title')),
                          DataColumn(label: Text('Target Segment')),
                          DataColumn(label: Text('Channel')),
                          DataColumn(label: Text('Audience')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: campaigns.map((camp) {
                          return DataRow(
                            cells: [
                              DataCell(Text(camp.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(camp.targetSegment.replaceAll('_', ' '))),
                              DataCell(Text(camp.channel)),
                              DataCell(Text('${camp.audienceCount} recipients')),
                              DataCell(
                                Chip(
                                  label: Text(camp.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                  backgroundColor: camp.status == 'SENT' ? Colors.green : Colors.blueGrey,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                                      icon: const Icon(Icons.download, size: 12),
                                      label: const Text('Export CSV', style: TextStyle(fontSize: 11)),
                                      onPressed: () async {
                                        final csv = await ref.read(crmControllerProvider.notifier).exportCampaignCsv(camp.id);
                                        if (csv != null && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Campaign audience CSV exported successfully')),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      onPressed: () => CampaignDialog.show(context, campaign: camp),
                                    ),
                                  ],
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
                error: (e, _) => Text('Error loading campaigns: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
