import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/pos_error_card.dart';
import 'package:pos_client/features/inventory/presentation/controllers/transfers_controller.dart';
import 'package:pos_client/features/inventory/presentation/views/create_transfer_dialog.dart';
import '../controllers/branches_controller.dart';
import 'branch_form_dialog.dart';

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(appLocalizationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Plain white background header & TabBar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.tr('branches_title', 'Store Branches & Transfers'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh Branches & Transfers',
                      onPressed: () {
                        ref.read(branchesListProvider.notifier).loadBranches();
                        ref.read(transfersListProvider.notifier).loadTransfers();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF0F766E),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0F766E),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(icon: const Icon(Icons.store, size: 18), text: loc.tr('retail_branches', 'Retail Branches')),
                    Tab(icon: const Icon(Icons.swap_horiz, size: 18), text: loc.tr('stock_transfers', 'Stock Transfers')),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _BranchesTab(),
                _TransfersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchesTab extends ConsumerWidget {
  const _BranchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(branchesListProvider);
    final activeBranch = ref.watch(activeBranchProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top action bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store Locations',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Manage company physical stores, warehouses, and terminal assignments',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.outlined(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Branches',
                      onPressed: () => ref.read(branchesListProvider.notifier).loadBranches(),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => BranchFormDialog.show(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Branch'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (state.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (state.errorMessage != null)
              Expanded(
                child: PosErrorCard(
                  error: state.errorMessage,
                  title: 'Unable to Load Store Branches',
                  icon: Icons.store_outlined,
                  onRetry: () => ref.read(branchesListProvider.notifier).loadBranches(),
                ),
              )
            else if (state.branches.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No branches registered yet.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: state.branches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final branch = state.branches[index];
                    final isCurrentTerminal = activeBranch?.id == branch.id;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isCurrentTerminal
                              ? const Color(0xFF0F766E)
                              : Colors.grey.shade200,
                          width: isCurrentTerminal ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isCurrentTerminal
                                  ? const Color(0xFF0F766E)
                                  : Colors.grey.shade100,
                              child: Icon(
                                Icons.storefront,
                                color: isCurrentTerminal
                                    ? Colors.white
                                    : const Color(0xFF0F766E),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        branch.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (branch.code != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            branch.code!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isCurrentTerminal) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F766E)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'ACTIVE TERMINAL',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F766E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (branch.phone != null) ...[
                                        Icon(Icons.phone,
                                            size: 14,
                                            color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          branch.phone!,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600),
                                        ),
                                        const SizedBox(width: 16),
                                      ],
                                      if (branch.address != null) ...[
                                        Icon(Icons.location_on,
                                            size: 14,
                                            color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            branch.address!,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                if (!isCurrentTerminal && branch.isActive)
                                  OutlinedButton(
                                    onPressed: () {
                                      ref
                                          .read(activeBranchProvider.notifier)
                                          .state = branch;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(
                                            'Terminal switched to ${branch.name}'),
                                      ));
                                    },
                                    child: const Text('Set as Active Store'),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit Branch',
                                  onPressed: () => BranchFormDialog.show(
                                      context,
                                      branch: branch),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TransfersTab extends ConsumerStatefulWidget {
  const _TransfersTab();

  @override
  ConsumerState<_TransfersTab> createState() => _TransfersTabState();
}

class _TransfersTabState extends ConsumerState<_TransfersTab> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(transfersListProvider.notifier).loadTransfers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transfersListProvider);
    final branches = ref.watch(branchesListProvider).branches;
    final activeBranch = ref.watch(activeBranchProvider);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top action bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inter-Store Transfers',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Dispatch and receive stock shipments between company retail branches',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.outlined(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Transfers',
                      onPressed: () => ref.read(transfersListProvider.notifier).loadTransfers(),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => CreateTransferDialog.show(
                        context,
                        branches: branches,
                        initialSourceBranchId: activeBranch?.id,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('New Transfer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(null, 'All Transfers'),
                  const SizedBox(width: 8),
                  _filterChip('DRAFT', 'Drafts'),
                  const SizedBox(width: 8),
                  _filterChip('IN_TRANSIT', 'In Transit'),
                  const SizedBox(width: 8),
                  _filterChip('RECEIVED', 'Received'),
                  const SizedBox(width: 8),
                  _filterChip('CANCELLED', 'Cancelled'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (state.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (state.errorMessage != null)
              Expanded(
                child: PosErrorCard(
                  error: state.errorMessage,
                  title: 'Unable to Load Stock Transfers',
                  icon: Icons.local_shipping_outlined,
                  onRetry: () => ref.read(transfersListProvider.notifier).loadTransfers(),
                ),
              )
            else if (state.transfers.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No stock transfers found.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: state.transfers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final t = state.transfers[index];

                    Color statusColor;
                    switch (t.status) {
                      case 'IN_TRANSIT':
                        statusColor = Colors.orange;
                        break;
                      case 'RECEIVED':
                        statusColor = Colors.green;
                        break;
                      case 'CANCELLED':
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.blue;
                    }

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t.transferNo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color:
                                            statusColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    t.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  t.sourceBranchName ?? 'Source Branch',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.arrow_forward,
                                      size: 16, color: Colors.grey),
                                ),
                                Text(
                                  t.destinationBranchName ??
                                      'Destination Branch',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Items: ${t.totalItemsCount} variants (${t.totalQuantity.toStringAsFixed(1)} units) • Created: ${dateFormat.format(t.createdAt)}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if (t.notes != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Notes: ${t.notes}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (t.status == 'DRAFT') ...[
                                  OutlinedButton(
                                    onPressed: () => ref
                                        .read(transfersListProvider.notifier)
                                        .cancelTransfer(t.id),
                                    child: const Text('Cancel Order'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () => ref
                                        .read(transfersListProvider.notifier)
                                        .sendTransfer(t.id),
                                    icon: const Icon(Icons.send, size: 16),
                                    label: const Text('Dispatch / Send'),
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF0F766E)),
                                  ),
                                ] else if (t.status == 'IN_TRANSIT') ...[
                                  OutlinedButton(
                                    onPressed: () => ref
                                        .read(transfersListProvider.notifier)
                                        .cancelTransfer(t.id),
                                    child: const Text('Recall & Cancel'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () => ref
                                        .read(transfersListProvider.notifier)
                                        .receiveTransfer(t.id),
                                    icon: const Icon(Icons.check_circle_outline,
                                        size: 16),
                                    label: const Text('Receive Stock'),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green.shade700),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String? status, String label) {
    final isSelected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = status);
        ref.read(transfersListProvider.notifier).loadTransfers(status: status);
      },
    );
  }
}
