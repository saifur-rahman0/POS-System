import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_client/features/branches/presentation/controllers/branches_controller.dart';
import 'package:pos_client/features/reports/presentation/controllers/reports_controller.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final activeTab = ref.watch(reportsTabProvider);
    final preset = ref.watch(reportDatePresetProvider);
    final branchFilter = ref.watch(reportBranchFilterProvider);
    final branches = ref.watch(branchesListProvider).branches;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Analytics & Financial Reports',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Business intelligence, sales velocity, profit margins, and capital valuation',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // Date Presets
                Wrap(
                  spacing: 6,
                  children: ReportDatePreset.values.map((p) {
                    final isSelected = p == preset;
                    return ChoiceChip(
                      label: Text(p.label),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0F766E),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(reportDatePresetProvider.notifier).state = p;
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(width: 12),

                // Branch filter
                if (branches.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: branchFilter,
                        hint: const Text('All Outlets', style: TextStyle(fontSize: 12)),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Outlets', style: TextStyle(fontSize: 12)),
                          ),
                          ...branches.map((b) => DropdownMenuItem<String?>(
                                value: b.id,
                                child: Text(b.name, style: const TextStyle(fontSize: 12)),
                              )),
                        ],
                        onChanged: (val) {
                          ref.read(reportBranchFilterProvider.notifier).state = val;
                        },
                      ),
                    ),
                  ),
                const SizedBox(width: 12),

                // Export CSV Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onPressed: () async {
                    try {
                      final api = ref.read(reportsApiServiceProvider);
                      final (start, end) = preset.toDateRange();
                      final reportTypes = [
                        'summary',
                        'top_products',
                        'stock_valuation',
                        'payment_methods',
                        'customer_dues',
                      ];
                      final currentType = reportTypes[activeTab];
                      final csvData = await api.downloadReportCsv(
                        reportType: currentType,
                        startDate: start,
                        endDate: end,
                        branchId: branchFilter,
                      );

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Generated CSV for $currentType (${csvData.split('\n').length} lines). Export successful.',
                          ),
                          backgroundColor: const Color(0xFF0F766E),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Export failed: $e'),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Sub-Tab Switcher
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildTabButton(context, ref, 0, 'Executive Overview', Icons.dashboard_outlined),
                _buildTabButton(context, ref, 1, 'Top Products', Icons.star_outline),
                _buildTabButton(context, ref, 2, 'Stock Valuation', Icons.inventory_2_outlined),
                _buildTabButton(context, ref, 3, 'Payment Breakdown', Icons.payments_outlined),
                _buildTabButton(context, ref, 4, 'Customer Dues', Icons.people_outline),
              ],
            ),
          ),

          // Main Tab Body
          Expanded(
            child: IndexedStack(
              index: activeTab,
              children: [
                _buildOverviewTab(context, ref, currencyFmt),
                _buildTopProductsTab(context, ref, currencyFmt),
                _buildStockValuationTab(context, ref, currencyFmt),
                _buildPaymentBreakdownTab(context, ref, currencyFmt),
                _buildCustomerDuesTab(context, ref, currencyFmt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    WidgetRef ref,
    int index,
    String label,
    IconData icon,
  ) {
    final activeTab = ref.watch(reportsTabProvider);
    final isSelected = activeTab == index;

    return InkWell(
      onTap: () => ref.read(reportsTabProvider.notifier).state = index,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF0F766E) : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F766E) : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 0: Executive Overview
  // =========================================================================
  Widget _buildOverviewTab(
    BuildContext context,
    WidgetRef ref,
    NumberFormat currencyFmt,
  ) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final timeSeriesAsync = ref.watch(salesTimeSeriesProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 4 Primary KPI Summary Cards
        metricsAsync.when(
          data: (m) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'GROSS SALES',
                      value: currencyFmt.format(m.grossSales),
                      subtitle: '${m.totalOrders} total sales transactions',
                      icon: Icons.point_of_sale,
                      iconBg: Colors.blue.shade50,
                      iconColor: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'NET SALES',
                      value: currencyFmt.format(m.netSales),
                      subtitle: 'Refunds: ${currencyFmt.format(m.totalRefunds)}',
                      icon: Icons.attach_money,
                      iconBg: Colors.teal.shade50,
                      iconColor: const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'GROSS PROFIT',
                      value: currencyFmt.format(m.grossProfit),
                      subtitle: 'Margin: ${m.profitMarginPct.toStringAsFixed(1)}%',
                      icon: Icons.trending_up,
                      iconBg: Colors.green.shade50,
                      iconColor: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'AVG BASKET',
                      value: currencyFmt.format(m.averageBasketValue),
                      subtitle: '${m.totalItemsSold.toStringAsFixed(0)} units sold',
                      icon: Icons.shopping_basket_outlined,
                      iconBg: Colors.purple.shade50,
                      iconColor: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Secondary operational cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'COLLECTIONS VS DUES',
                      value: currencyFmt.format(m.totalCollected),
                      subtitle: 'Store Credit Granted: ${currencyFmt.format(m.totalDueIssued)}',
                      icon: Icons.account_balance_wallet_outlined,
                      iconBg: const Color(0xFFE6FFFA),
                      iconColor: const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'INVENTORY ALERTS',
                      value: '${m.lowStockCount} Low Stock',
                      subtitle: '${m.outOfStockCount} Out of stock items',
                      icon: Icons.warning_amber_rounded,
                      iconBg: Colors.amber.shade50,
                      iconColor: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => _buildErrorBanner('Failed to load dashboard metrics: $e'),
        ),

        const SizedBox(height: 24),

        // Sales Velocity Trend Chart Card
        Container(
          padding: const EdgeInsets.all(20),
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
                  const Text(
                    'Sales Revenue Trend',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Time-bucketed sales velocity',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              timeSeriesAsync.when(
                data: (ts) {
                  if (ts.points.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No sales recorded for the selected period',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    );
                  }

                  final maxGross = ts.points.fold<double>(
                    0.0,
                    (max, p) => p.grossSales > max ? p.grossSales : max,
                  );

                  return SizedBox(
                    height: 200,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: ts.points.map((pt) {
                        final ratio = maxGross > 0 ? (pt.grossSales / maxGross) : 0.0;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  currencyFmt.format(pt.grossSales),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: (140 * ratio).clamp(8.0, 140.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pt.periodLabel.length > 10
                                      ? pt.periodLabel.substring(11)
                                      : pt.periodLabel,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _buildErrorBanner('Failed to load sales trend: $e'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 1: Top Products
  // =========================================================================
  Widget _buildTopProductsTab(
    BuildContext context,
    WidgetRef ref,
    NumberFormat currencyFmt,
  ) {
    final topAsync = ref.watch(topProductsProvider);

    return topAsync.when(
      data: (data) {
        if (data.items.isEmpty) {
          return Center(
            child: Text(
              'No product sales recorded in this period.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Product / Variant', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Units Sold', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Gross Revenue', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('COGS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Profit', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Margin %', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: data.items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final p = entry.value;
                  return DataRow(
                    cells: [
                      DataCell(Text('#$idx', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(p.variantName, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          ],
                        ),
                      ),
                      DataCell(Text(p.sku)),
                      DataCell(Text(p.unitsSold.toStringAsFixed(1))),
                      DataCell(Text(currencyFmt.format(p.grossRevenue))),
                      DataCell(Text(currencyFmt.format(p.cogs))),
                      DataCell(Text(
                        currencyFmt.format(p.profit),
                        style: TextStyle(
                          color: p.profit >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.marginPct >= 20 ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${p.marginPct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: p.marginPct >= 20 ? Colors.green.shade800 : Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorBanner('Failed to load top products: $e'),
    );
  }

  // =========================================================================
  // TAB 2: Stock Valuation
  // =========================================================================
  Widget _buildStockValuationTab(
    BuildContext context,
    WidgetRef ref,
    NumberFormat currencyFmt,
  ) {
    final stockAsync = ref.watch(stockValuationProvider);

    return stockAsync.when(
      data: (stock) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Capital valuation KPI cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'TOTAL CAPITAL INVESTED',
                  value: currencyFmt.format(stock.totalCostValue),
                  subtitle: '${stock.totalUnitsOnHand.toStringAsFixed(0)} units on hand',
                  icon: Icons.inventory,
                  iconBg: Colors.indigo.shade50,
                  iconColor: Colors.indigo.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'POTENTIAL RETAIL REVENUE',
                  value: currencyFmt.format(stock.totalRetailValue),
                  subtitle: '${stock.totalVariantsStocked} stocked variants',
                  icon: Icons.storefront,
                  iconBg: Colors.teal.shade50,
                  iconColor: const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'PROJECTED GROSS PROFIT',
                  value: currencyFmt.format(stock.potentialGrossProfit),
                  subtitle: 'Unrealized inventory margin',
                  icon: Icons.monetization_on_outlined,
                  iconBg: Colors.green.shade50,
                  iconColor: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Low Stock Alert Table
          Container(
            padding: const EdgeInsets.all(20),
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
                    const Text(
                      'Reorder & Stock Alert Items',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${stock.lowStockCount} Low Stock • ${stock.outOfStockCount} Out of Stock',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (stock.lowStockItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'All stocked items are above low stock threshold.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 64,
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                      columns: const [
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Product / Variant', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(numeric: true, label: Text('On Hand', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(numeric: true, label: Text('Cost Price', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(numeric: true, label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(numeric: true, label: Text('Cost Capital', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: stock.lowStockItems.map((item) {
                        final isOut = item.isOutOfStock;
                        return DataRow(
                          cells: [
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOut ? Colors.red.shade50 : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isOut ? Colors.red.shade200 : Colors.amber.shade200,
                                  ),
                                ),
                                child: Text(
                                  isOut ? 'OUT OF STOCK' : 'LOW STOCK',
                                  style: TextStyle(
                                    color: isOut ? Colors.red.shade800 : Colors.amber.shade900,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(item.variantName, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                ],
                              ),
                            ),
                            DataCell(Text(item.sku)),
                            DataCell(Text(
                              item.quantityOnHand.toStringAsFixed(1),
                              style: TextStyle(
                                color: isOut ? Colors.red.shade800 : Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                            DataCell(Text(currencyFmt.format(item.costPrice))),
                            DataCell(Text(currencyFmt.format(item.sellingPrice))),
                            DataCell(Text(currencyFmt.format(item.stockCostValue))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorBanner('Failed to load stock valuation: $e'),
    );
  }

  // =========================================================================
  // TAB 3: Payment Breakdown
  // =========================================================================
  Widget _buildPaymentBreakdownTab(
    BuildContext context,
    WidgetRef ref,
    NumberFormat currencyFmt,
  ) {
    final payAsync = ref.watch(paymentBreakdownProvider);

    return payAsync.when(
      data: (data) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Total collected header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL VALUE RECORDED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFmt.format(data.totalCollected),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${data.methods.length} payment tender methods used',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Methods Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: data.methods.map((m) {
              return SizedBox(
                width: 320,
                child: Container(
                  padding: const EdgeInsets.all(18),
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
                          Text(
                            m.method,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${m.percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currencyFmt.format(m.totalAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${m.transactionCount} transactions',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: (m.percentage / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade100,
                        color: const Color(0xFF0F766E),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorBanner('Failed to load payment breakdown: $e'),
    );
  }

  // =========================================================================
  // TAB 4: Customer Dues
  // =========================================================================
  Widget _buildCustomerDuesTab(
    BuildContext context,
    WidgetRef ref,
    NumberFormat currencyFmt,
  ) {
    final duesAsync = ref.watch(customerDuesReportProvider);

    return duesAsync.when(
      data: (dues) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'TOTAL RECEIVABLES (DUES)',
                  value: currencyFmt.format(dues.totalOutstandingDue),
                  subtitle: '${dues.totalCustomersWithDue} accounts with unpaid balances',
                  icon: Icons.assignment_late_outlined,
                  iconBg: Colors.red.shade50,
                  iconColor: Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'TOTAL CREDIT LIMIT',
                  value: currencyFmt.format(dues.totalCreditLimit),
                  subtitle: 'Aggregate customer credit allowance',
                  icon: Icons.credit_score,
                  iconBg: Colors.blue.shade50,
                  iconColor: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'CREDIT UTILIZATION',
                  value: '${dues.overallCreditUtilizationPct.toStringAsFixed(1)}%',
                  subtitle: 'Outstanding vs available allowance',
                  icon: Icons.pie_chart_outline,
                  iconBg: Colors.amber.shade50,
                  iconColor: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Outstanding Debtors',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (dues.topDebtors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'Zero outstanding customer dues. All sales fully settled.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 56,
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                      columns: const [
                        DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(numeric: true, label: Text('Outstanding Due', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(numeric: true, label: Text('Credit Limit', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(numeric: true, label: Text('Utilization %', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: dues.topDebtors.map((d) {
                        return DataRow(
                          cells: [
                            DataCell(Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(d.phone ?? '—')),
                            DataCell(Text(
                              currencyFmt.format(d.dueBalance),
                              style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text(currencyFmt.format(d.creditLimit))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: d.utilizationPct > 80 ? Colors.red.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${d.utilizationPct.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: d.utilizationPct > 80 ? Colors.red.shade800 : Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorBanner('Failed to load customer dues report: $e'),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade800)),
    );
  }
}

