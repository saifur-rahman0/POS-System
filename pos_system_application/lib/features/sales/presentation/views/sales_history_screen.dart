import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/pos_error_card.dart';
import '../controllers/sales_history_controller.dart';
import 'product_exchange_dialog.dart';
import 'quotations_view.dart';
import 'return_dialog.dart';
import 'sale_detail_drawer.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0 = Sales Receipts, 1 = Quotations

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            // Header title & Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTab == 0
                            ? 'Sales History & Receipts'
                            : 'Pro-Forma Quotations',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedTab == 0
                            ? 'Audit customer transactions, reprint thermal receipts, and issue returns / exchanges'
                            : 'Manage price quotations, pro-forma estimates, and convert them to live sales',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Text('Sales Receipts'),
                          icon: Icon(Icons.receipt_long, size: 16),
                        ),
                        ButtonSegment(
                          value: 1,
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
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      tooltip: _selectedTab == 0 ? 'Refresh Sales' : 'Refresh Quotations',
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        if (_selectedTab == 0) {
                          ref.invalidate(salesListProvider);
                        } else {
                          // Handled inside QuotationsView
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedTab == 1)
              const Expanded(child: QuotationsView())
            else ...[

            // Filter Bar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(salesFilterProvider.notifier)
                                        .setSearchQuery('');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (val) {
                          ref
                              .read(salesFilterProvider.notifier)
                              .setSearchQuery(val);
                        },
                      ),
                    ),

                    // Date Filters
                    Wrap(
                      spacing: 6,
                      children: SalesDateFilter.values.map((df) {
                        final isSelected = filterState.dateFilter == df;
                        return ChoiceChip(
                          label: Text(df.label),
                          selected: isSelected,
                          selectedColor:
                              const Color(0xFF0F766E).withValues(alpha: 0.15),
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
                                  .read(salesFilterProvider.notifier)
                                  .setDateFilter(df);
                            }
                          },
                        );
                      }).toList(),
                    ),

                    // Status Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
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
                                value: 'ALL', child: Text('All Statuses')),
                            DropdownMenuItem(
                                value: 'COMPLETED', child: Text('Completed')),
                            DropdownMenuItem(
                                value: 'PARTIALLY_REFUNDED',
                                child: Text('Partially Refunded')),
                            DropdownMenuItem(
                                value: 'REFUNDED', child: Text('Refunded')),
                            DropdownMenuItem(
                                value: 'VOIDED', child: Text('Voided')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(salesFilterProvider.notifier)
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => PosErrorCard(
                    error: err,
                    title: 'Unable to Load Sales History',
                    icon: Icons.receipt_long_outlined,
                    onRetry: () => ref.invalidate(salesListProvider),
                  ),
                  data: (pageData) {
                    if (pageData.items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sales Table
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.grey.shade50,
                                ),
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Receipt #',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Date & Time',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Customer',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Items',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Grand Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Actions',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: pageData.items.map((sale) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          sale.receiptNo,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(dateFmt.format(sale.createdAt)),
                                      ),
                                      DataCell(
                                        Text(sale.customerName ?? 'Walk-in'),
                                      ),
                                      DataCell(
                                        Text('${sale.itemsCount} items'),
                                      ),
                                      DataCell(
                                        Text(
                                          currencyFmt.format(sale.grandTotal),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(sale.status)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: _getStatusColor(
                                                sale.status,
                                              ).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            sale.status,
                                            style: TextStyle(
                                              color:
                                                  _getStatusColor(sale.status),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'View Details',
                                              icon: const Icon(
                                                Icons.visibility_outlined,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                SaleDetailDrawer.show(
                                                  context,
                                                  sale.id,
                                                  () => ref.refresh(
                                                    salesListProvider,
                                                  ),
                                                );
                                              },
                                            ),
                                            if (sale.status != 'VOIDED' &&
                                                sale.status != 'REFUNDED') ...[
                                              IconButton(
                                                tooltip: 'Process Return',
                                                icon: const Icon(
                                                  Icons
                                                      .assignment_return_outlined,
                                                  size: 18,
                                                  color: Color(0xFF0F766E),
                                                ),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        ReturnDialog(
                                                      saleId: sale.id,
                                                      receiptNo: sale.receiptNo,
                                                      onReturnSuccess: () {
                                                        ref.invalidate(
                                                          salesListProvider,
                                                        );
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                tooltip: 'Product Exchange',
                                                icon: const Icon(
                                                  Icons.swap_horiz,
                                                  size: 20,
                                                  color: Color(0xFF0F766E),
                                                ),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        ProductExchangeDialog(
                                                      saleId: sale.id,
                                                      receiptNo: sale.receiptNo,
                                                      onExchangeSuccess: () {
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
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    label: const Text('Previous'),
                                    onPressed: pageData.page > 1
                                        ? () {
                                            ref
                                                .read(
                                                  salesFilterProvider.notifier,
                                                )
                                                .setPage(pageData.page - 1);
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
                                    onPressed:
                                        pageData.page < pageData.totalPages
                                            ? () {
                                                ref
                                                    .read(
                                                      salesFilterProvider
                                                          .notifier,
                                                    )
                                                    .setPage(pageData.page + 1);
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
          ],
        ),
      ),
    );
  }
}
