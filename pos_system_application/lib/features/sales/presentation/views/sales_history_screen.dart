import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme.dart';
import '../../../../core/widgets/pos_error_card.dart';
import '../../../../core/widgets/stat_strip.dart';
import '../../domain/models/pos_transaction.dart';
import '../controllers/sales_history_controller.dart';
import '../controllers/transactions_hub_controller.dart';
import 'product_exchange_dialog.dart';
import 'quotations_view.dart';
import 'return_dialog.dart';
import 'sale_detail_drawer.dart';
import 'transactions_hub_view.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const SalesHistoryScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  late int _selectedTab = widget.initialTab; // 0 = Sales Receipts, 1 = All Transactions, 2 = Purchases, 3 = Payments, 4 = Quotations

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getHeaderTitle() {
    switch (_selectedTab) {
      case 0:
        return 'Sales History & Receipts';
      case 1:
        return 'All Transactions History & Audit Ledger';
      case 2:
        return 'Purchases & Supplier Orders';
      case 3:
        return 'Payments & Tender History';
      case 4:
        return 'Pro-Forma Quotations';
      default:
        return 'Sales History & Receipts';
    }
  }

  String _getHeaderSubtitle() {
    switch (_selectedTab) {
      case 0:
        return 'Audit customer transactions, reprint thermal receipts, and issue returns / exchanges';
      case 1:
        return 'Comprehensive real-time financial timeline: Purchases, Sales, Payments, Expenses, and Transfers';
      case 2:
        return 'Supplier purchase orders, goods receipts, and vendor disbursements';
      case 3:
        return 'Payment inflows, customer collections, and supplier disbursements across all tender methods';
      case 4:
        return 'Manage price quotations, pro-forma estimates, and convert them to live sales';
      default:
        return 'Audit customer transactions, reprint thermal receipts, and issue returns / exchanges';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF0F766E);
      case 'PARTIALLY_REFUNDED':
        return Colors.amber.shade800;
      case 'REFUNDED':
        return Colors.indigo;
      case 'VOIDED':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(salesFilterProvider);
    final salesAsync = ref.watch(salesListProvider);
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header title & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getHeaderTitle(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getHeaderSubtitle(),
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: _selectedTab == 0
                      ? 'Refresh Sales'
                      : (_selectedTab == 4 ? 'Refresh Quotations' : 'Refresh Transactions'),
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    if (_selectedTab == 0) {
                      ref.invalidate(salesListProvider);
                    } else if (_selectedTab == 4) {
                      // Handled inside QuotationsView
                    } else {
                      ref.read(transactionsHubControllerProvider).refreshAll();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal Tab Navigation
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('Sales Receipts'),
                    icon: Icon(Icons.receipt_long, size: 16),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('All Transactions'),
                    icon: Icon(Icons.account_balance_wallet_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text('Purchases'),
                    icon: Icon(Icons.shopping_bag_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 3,
                    label: Text('Payments'),
                    icon: Icon(Icons.payments_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 4,
                    label: Text('Quotations'),
                    icon: Icon(Icons.request_quote_outlined, size: 16),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (val) {
                  setState(() {
                    _selectedTab = val.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedTab == 0 && salesAsync.hasValue) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: StatStrip(
                  items: [
                    StatStripItem(
                      label: 'TOTAL SALES RECEIPTS',
                      value: '${salesAsync.value?.total ?? 0}',
                      numericValue: salesAsync.value?.total ?? 0,
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.accentTeal,
                    ),
                    StatStripItem(
                      label: 'GROSS VOLUME',
                      value: currencyFmt.format(salesAsync.value?.items.fold<double>(0.0, (acc, s) => acc + s.grandTotal) ?? 0.0),
                      numericValue: salesAsync.value?.items.fold<double>(0.0, (acc, s) => acc + s.grandTotal) ?? 0.0,
                      prefix: '৳ ',
                      decimalDigits: 2,
                      icon: Icons.payments_outlined,
                      color: AppColors.accentPurple,
                    ),
                    StatStripItem(
                      label: 'PAID COLLECTED',
                      value: currencyFmt.format(salesAsync.value?.items.fold<double>(0.0, (acc, s) => acc + s.paidTotal) ?? 0.0),
                      numericValue: salesAsync.value?.items.fold<double>(0.0, (acc, s) => acc + s.paidTotal) ?? 0.0,
                      prefix: '৳ ',
                      decimalDigits: 2,
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.accentGreen,
                    ),
                    StatStripItem(
                      label: 'OUTSTANDING DUE',
                      value: currencyFmt.format(salesAsync.value?.items.fold<double>(0.0, (acc, s) => acc + s.dueTotal) ?? 0.0),
                      numericValue: salesAsync.value?.items.fold<double>(0.0, (acc, s) => acc + s.dueTotal) ?? 0.0,
                      prefix: '৳ ',
                      decimalDigits: 2,
                      icon: Icons.credit_card_off_outlined,
                      color: AppColors.accentRose,
                      badge: (salesAsync.value?.items.fold<double>(0.0, (acc, s) => acc + s.dueTotal) ?? 0.0) > 0 ? 'DUE' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _selectedTab == 1
                    ? const KeyedSubtree(
                        key: ValueKey('all_transactions_tab_view'),
                        child: TransactionsHubView(),
                      )
                    : _selectedTab == 2
                        ? const KeyedSubtree(
                            key: ValueKey('purchases_tab_view'),
                            child: TransactionsHubView(
                              initialType: PosTransactionType.purchase,
                            ),
                          )
                        : _selectedTab == 3
                            ? const KeyedSubtree(
                                key: ValueKey('payments_tab_view'),
                                child: TransactionsHubView(
                                  initialType: PosTransactionType.payment,
                                ),
                              )
                            : _selectedTab == 4
                                ? const KeyedSubtree(
                                    key: ValueKey('quotations_tab_view'),
                                    child: QuotationsView(),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('sales_history_tab_view'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Filter Bar
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    // Search box
                                    SizedBox(
                                      width: 260,
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          hintText: 'Search Receipt #...',
                                          prefixIcon: const Icon(Icons.search,
                                              size: 18),
                                          suffixIcon: _searchController
                                                  .text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear,
                                                      size: 16),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    ref
                                                        .read(
                                                            salesFilterProvider
                                                                .notifier)
                                                        .setSearchQuery('');
                                                  },
                                                )
                                              : null,
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          ref
                                              .read(
                                                  salesFilterProvider.notifier)
                                              .setSearchQuery(val);
                                        },
                                      ),
                                    ),

                                    // Date Filters
                                    Wrap(
                                      spacing: 6,
                                      children:
                                          SalesDateFilter.values.map((df) {
                                        final isSelected =
                                            filterState.dateFilter == df;
                                        return ChoiceChip(
                                          label: Text(df.label),
                                          selected: isSelected,
                                          selectedColor: const Color(0xFF0F766E)
                                              .withValues(alpha: 0.15),
                                          labelStyle: TextStyle(
                                            color: isSelected
                                                ? const Color(0xFF0F766E)
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                          onSelected: (selected) {
                                            if (selected) {
                                              ref
                                                  .read(salesFilterProvider
                                                      .notifier)
                                                  .setDateFilter(df);
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),

                                    // Status Dropdown
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: filterState.statusFilter,
                                          isDense: true,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'ALL',
                                                child: Text('All Statuses')),
                                            DropdownMenuItem(
                                                value: 'COMPLETED',
                                                child: Text('Completed')),
                                            DropdownMenuItem(
                                                value: 'PARTIALLY_REFUNDED',
                                                child:
                                                    Text('Partially Refunded')),
                                            DropdownMenuItem(
                                                value: 'REFUNDED',
                                                child: Text('Refunded')),
                                            DropdownMenuItem(
                                                value: 'VOIDED',
                                                child: Text('Voided')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              ref
                                                  .read(salesFilterProvider
                                                      .notifier)
                                                  .setStatusFilter(val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Table Content Area
                            Expanded(
                              child: Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: salesAsync.when(
                                  loading: () => const Center(
                                      child: CircularProgressIndicator()),
                                  error: (err, _) => PosErrorCard(
                                    error: err,
                                    title: 'Unable to Load Sales History',
                                    icon: Icons.receipt_long_outlined,
                                    onRetry: () =>
                                        ref.invalidate(salesListProvider),
                                  ),
                                  data: (pageData) {
                                    if (pageData.items.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.receipt_long_outlined,
                                              size: 56,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'No sales found matching your filters',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Try selecting a different date range or clearing the search query',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Sales Table
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.vertical,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: DataTable(
                                                headingRowColor:
                                                    WidgetStateProperty.all(
                                                  Colors.grey.shade50,
                                                ),
                                                columns: const [
                                                  DataColumn(
                                                    label: Text(
                                                      'Receipt #',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Date & Time',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Customer',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Items',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Grand Total',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Status',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Actions',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                rows:
                                                    pageData.items.map((sale) {
                                                  return DataRow(
                                                    cells: [
                                                      DataCell(
                                                        Text(
                                                          sale.receiptNo,
                                                          style:
                                                              const TextStyle(
                                                            fontFamily:
                                                                'monospace',
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                                0xFF0F766E),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Text(dateFmt.format(
                                                            sale.createdAt)),
                                                      ),
                                                      DataCell(
                                                        Text(
                                                            sale.customerName ??
                                                                'Walk-in'),
                                                      ),
                                                      DataCell(
                                                        Text(
                                                            '${sale.itemsCount} items'),
                                                      ),
                                                      DataCell(
                                                        Text(
                                                          currencyFmt.format(
                                                              sale.grandTotal),
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _getStatusColor(
                                                                    sale.status)
                                                                .withValues(
                                                                    alpha: 0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            border: Border.all(
                                                              color:
                                                                  _getStatusColor(
                                                                sale.status,
                                                              ).withValues(
                                                                      alpha:
                                                                          0.3),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            sale.status,
                                                            style: TextStyle(
                                                              color: _getStatusColor(
                                                                  sale.status),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              tooltip:
                                                                  'View Details',
                                                              icon: const Icon(
                                                                Icons
                                                                    .visibility_outlined,
                                                                size: 18,
                                                              ),
                                                              onPressed: () {
                                                                SaleDetailDrawer
                                                                    .show(
                                                                  context,
                                                                  sale.id,
                                                                  () => ref
                                                                      .refresh(
                                                                    salesListProvider,
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                            if (sale.status !=
                                                                    'VOIDED' &&
                                                                sale.status !=
                                                                    'REFUNDED') ...[
                                                              IconButton(
                                                                tooltip:
                                                                    'Process Return',
                                                                icon:
                                                                    const Icon(
                                                                  Icons
                                                                      .assignment_return_outlined,
                                                                  size: 18,
                                                                  color: Color(
                                                                      0xFF0F766E),
                                                                ),
                                                                onPressed: () {
                                                                  showDialog(
                                                                    context:
                                                                        context,
                                                                    builder:
                                                                        (ctx) =>
                                                                            ReturnDialog(
                                                                      saleId:
                                                                          sale.id,
                                                                      receiptNo:
                                                                          sale.receiptNo,
                                                                      onReturnSuccess:
                                                                          () {
                                                                        ref.invalidate(
                                                                          salesListProvider,
                                                                        );
                                                                      },
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                              IconButton(
                                                                tooltip:
                                                                    'Product Exchange',
                                                                icon:
                                                                    const Icon(
                                                                  Icons
                                                                      .swap_horiz,
                                                                  size: 20,
                                                                  color: Color(
                                                                      0xFF0F766E),
                                                                ),
                                                                onPressed: () {
                                                                  showDialog(
                                                                    context:
                                                                        context,
                                                                    builder:
                                                                        (ctx) =>
                                                                            ProductExchangeDialog(
                                                                      saleId:
                                                                          sale.id,
                                                                      receiptNo:
                                                                          sale.receiptNo,
                                                                      onExchangeSuccess:
                                                                          () {
                                                                        ref.invalidate(
                                                                          salesListProvider,
                                                                        );
                                                                      },
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ],
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

                                        // Pagination bar
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                  color: Colors.grey.shade200),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Showing ${pageData.items.length} of ${pageData.total} sales (Page ${pageData.page} of ${pageData.totalPages})',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  OutlinedButton.icon(
                                                    icon: const Icon(
                                                      Icons.chevron_left,
                                                      size: 18,
                                                    ),
                                                    label:
                                                        const Text('Previous'),
                                                    onPressed: pageData.page > 1
                                                        ? () {
                                                            ref
                                                                .read(
                                                                  salesFilterProvider
                                                                      .notifier,
                                                                )
                                                                .setPage(pageData
                                                                        .page -
                                                                    1);
                                                          }
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  OutlinedButton.icon(
                                                    icon: const Icon(
                                                      Icons.chevron_right,
                                                      size: 18,
                                                    ),
                                                    label: const Text('Next'),
                                                    onPressed: pageData.page <
                                                            pageData.totalPages
                                                        ? () {
                                                            ref
                                                                .read(
                                                                  salesFilterProvider
                                                                      .notifier,
                                                                )
                                                                .setPage(pageData
                                                                        .page +
                                                                    1);
                                                          }
                                                        : null,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
