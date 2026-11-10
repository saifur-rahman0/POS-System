import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/pos_transaction.dart';
import '../controllers/transactions_hub_controller.dart';
import 'transaction_detail_dialog.dart';

class TransactionsHubView extends ConsumerStatefulWidget {
  final PosTransactionType? initialType;

  const TransactionsHubView({
    super.key,
    this.initialType,
  });

  @override
  ConsumerState<TransactionsHubView> createState() => _TransactionsHubViewState();
}

class _TransactionsHubViewState extends ConsumerState<TransactionsHubView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(transactionFilterProvider.notifier).setTypeFilter(widget.initialType);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportCsv(List<PosTransactionModel> txns) {
    final controller = ref.read(transactionsHubControllerProvider);
    final csvContent = controller.generateCsv(txns);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${txns.length} transactions to CSV (${csvContent.length} bytes)'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDetailDialog(PosTransactionModel txn) {
    showDialog(
      context: context,
      builder: (ctx) => TransactionDetailDialog(transaction: txn),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(transactionFilterProvider);
    final filteredTxns = ref.watch(filteredTransactionsProvider);
    final kpis = ref.watch(transactionKpisProvider);
    final allAsync = ref.watch(allTransactionsProvider);

    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top KPI Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Total Inflow (Sales & In)',
                amount: currencyFmt.format(kpis.totalInflow),
                subtitle: '${kpis.inflowCount} incoming transactions',
                icon: Icons.trending_up,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildKpiCard(
                title: 'Total Outflow (Purchases & Exp)',
                amount: currencyFmt.format(kpis.totalOutflow),
                subtitle: '${kpis.outflowCount} outgoing disbursements',
                icon: Icons.trending_down,
                color: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildKpiCard(
                title: 'Net Cash Flow Position',
                amount: '${kpis.netCashFlow >= 0 ? '+' : ''}${currencyFmt.format(kpis.netCashFlow)}',
                subtitle: 'Current net liquidity balance',
                icon: Icons.account_balance_wallet_outlined,
                color: kpis.netCashFlow >= 0 ? const Color(0xFF0F766E) : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildKpiCard(
                title: 'Total Ledger Entries',
                amount: '${kpis.totalCount}',
                subtitle: '${kpis.totalSales > 0 ? "Sales: ৳${kpis.totalSales.toStringAsFixed(0)} " : ""}${kpis.totalPurchases > 0 ? "· POs: ৳${kpis.totalPurchases.toStringAsFixed(0)}" : ""}',
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 2. Toolbar: Search, Filters & Export
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search & Actions Bar
              Row(
                children: [
                  // Search Input
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by receipt #, PO #, customer, supplier, payee, or note...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(transactionFilterProvider.notifier).setSearchQuery('');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      onChanged: (val) {
                        ref.read(transactionFilterProvider.notifier).setSearchQuery(val);
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Payment Method Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: filterState.paymentMethodFilter,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Methods')),
                          DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                          DropdownMenuItem(value: 'CARD', child: Text('Card')),
                          DropdownMenuItem(value: 'BKASH', child: Text('bKash')),
                          DropdownMenuItem(value: 'NAGAD', child: Text('Nagad')),
                          DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer')),
                          DropdownMenuItem(value: 'DUE', child: Text('Customer Due')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(transactionFilterProvider.notifier).setPaymentMethodFilter(val);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Export CSV Button
                  OutlinedButton.icon(
                    onPressed: filteredTxns.isNotEmpty ? () => _exportCsv(filteredTxns) : null,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Refresh Button
                  IconButton.filledTonal(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh All Transactions',
                    onPressed: () {
                      ref.read(transactionsHubControllerProvider).refreshAll();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Filter Chips: Date Range & Type Presets (Horizontal Scrollable)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Date Presets
                    const Text('Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 6,
                      children: TransactionDateFilter.values.map((df) {
                        final isSelected = filterState.dateFilter == df && filterState.customDateRange == null;
                        return ChoiceChip(
                          label: Text(df.label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          onSelected: (_) {
                            ref.read(transactionFilterProvider.notifier).setDateFilter(df);
                          },
                          visualDensity: VisualDensity.compact,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        );
                      }).toList(),
                    ),

                    const SizedBox(width: 24),

                    // Type Chips
                    const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('All Types', style: TextStyle(fontSize: 11)),
                          selected: filterState.typeFilter == null,
                          onSelected: (_) => ref.read(transactionFilterProvider.notifier).setTypeFilter(null),
                          visualDensity: VisualDensity.compact,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        ),
                        ...PosTransactionType.values.map((type) {
                          final isSelected = filterState.typeFilter == type;
                          return ChoiceChip(
                            label: Text(type.label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            onSelected: (_) => ref.read(transactionFilterProvider.notifier).setTypeFilter(type),
                            visualDensity: VisualDensity.compact,
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Transactions Data Table / List
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: allAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Error loading transactions: $err'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.read(transactionsHubControllerProvider).refreshAll(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (_) {
                if (filteredTxns.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No transactions match the selected filters',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try selecting "All Time" or reset your type and search filters.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(transactionFilterProvider.notifier).resetFilters();
                            },
                            icon: const Icon(Icons.filter_alt_off, size: 16),
                            label: const Text('Reset All Filters'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView.separated(
                    itemCount: filteredTxns.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final txn = filteredTxns[index];
                      final isPositive = txn.direction == TransactionDirection.inflow;
                      final directionSymbol = isPositive ? '+' : (txn.direction == TransactionDirection.outflow ? '-' : '⇄');

                      return InkWell(
                        onTap: () => _showDetailDialog(txn),
                        hoverColor: const Color(0xFFF8FAFC),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Row(
                            children: [
                              // Type & Direction Icon
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: txn.directionColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  txn.type.icon,
                                  color: txn.directionColor,
                                  size: 20,
                                ),
                              ),

                              const SizedBox(width: 14),

                              // Reference & Date
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            txn.referenceNo,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Type pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Text(
                                            txn.type.label.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      dateFmt.format(txn.timestamp),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),

                              // Party Name (Customer / Vendor / Payee)
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      txn.partyName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (txn.note != null && txn.note!.isNotEmpty)
                                      Text(
                                        txn.note!,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),

                              // Payment Method
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      txn.paymentMethod,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),

                              // Status Badge
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: txn.statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      txn.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: txn.statusColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),

                              // Amount & Direction
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '$directionSymbol ${currencyFmt.format(txn.amount)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: txn.directionColor,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Details Eye Icon
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF64748B)),
                                tooltip: 'View Transaction Details',
                                onPressed: () => _showDetailDialog(txn),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
