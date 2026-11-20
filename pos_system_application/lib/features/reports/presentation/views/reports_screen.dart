import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:pos_client/app/theme.dart';
import 'package:pos_client/core/widgets/chart_shimmer.dart';
import 'package:pos_client/core/widgets/empty_state_widget.dart';
import 'package:pos_client/core/widgets/kpi_metric_card.dart';
import 'package:pos_client/core/widgets/section_header.dart';
import 'package:pos_client/core/widgets/trend_badge.dart';
import 'package:pos_client/features/branches/presentation/controllers/branches_controller.dart';
import 'package:pos_client/features/reports/presentation/controllers/reports_controller.dart';
import 'package:pos_client/features/reports/presentation/widgets/payment_methods_donut.dart';
import 'package:pos_client/features/reports/presentation/widgets/sales_trend_chart.dart';
import 'package:pos_client/features/reports/presentation/widgets/stock_valuation_chart.dart';
import 'package:pos_client/features/reports/presentation/widgets/top_products_chart.dart';

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
      backgroundColor: AppColors.pageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Header Bar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.accentTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.analytics_rounded, size: 18, color: AppColors.accentTeal),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Business Intelligence & Analytics',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live revenue velocity, profit margins, stock valuation, and tender breakdowns',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                // Date Filter Chips
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ReportDatePreset.values.map((p) {
                      final isSelected = p == preset;
                      return InkWell(
                        onTap: () => ref.read(reportDatePresetProvider.notifier).state = p,
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            p.label,
                            style: GoogleFonts.inter(
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 12),

                // Branch filter
                if (branches.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: branchFilter,
                        hint: Text('All Stores', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Stores', style: GoogleFonts.inter(fontSize: 12)),
                          ),
                          ...branches.map((b) => DropdownMenuItem<String?>(
                                value: b.id,
                                child: Text(b.name, style: GoogleFonts.inter(fontSize: 12)),
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
                FilledButton.icon(
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Export CSV'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sidebarBg,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          content: Text('Exported $currentType (${csvData.split('\n').length} rows) successfully.'),
                          backgroundColor: AppColors.accentTeal,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Export failed: $e'),
                          backgroundColor: AppColors.accentRose,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Sub-Tab Switcher ───────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildTabButton(context, ref, 0, 'Executive Dashboard', Icons.dashboard_rounded),
                _buildTabButton(context, ref, 1, 'Top Products SAR', Icons.star_rounded),
                _buildTabButton(context, ref, 2, 'Stock Valuation & Risk', Icons.inventory_2_rounded),
                _buildTabButton(context, ref, 3, 'Payment Breakdown', Icons.account_balance_wallet_rounded),
                _buildTabButton(context, ref, 4, 'Customer Dues & Credit', Icons.people_alt_rounded),
              ],
            ),
          ),

          // ── Main Tab Views ─────────────────────────────────────────────
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
              color: isSelected ? AppColors.accentTeal : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.accentTeal : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? AppColors.accentTeal : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
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
    final paymentAsync = ref.watch(paymentBreakdownProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 4 Primary KPI Summary Cards with micro-animations & sparklines
        metricsAsync.when(
          data: (m) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: KpiMetricCard(
                      title: 'GROSS REVENUE',
                      value: currencyFmt.format(m.grossSales),
                      changeLabel: '${m.totalOrders} total sales transactions',
                      accentColor: AppColors.accentTeal,
                      icon: Icons.payments_rounded,
                      sparklineData: const [10, 15, 12, 19, 22, 28, 35, 42],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: KpiMetricCard(
                      title: 'NET SALES',
                      value: currencyFmt.format(m.netSales),
                      changeLabel: 'Refunds: ${currencyFmt.format(m.totalRefunds)}',
                      accentColor: AppColors.accentPurple,
                      icon: Icons.account_balance_wallet_rounded,
                      sparklineData: const [8, 12, 14, 16, 20, 25, 30, 38],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: KpiMetricCard(
                      title: 'GROSS PROFIT',
                      value: currencyFmt.format(m.grossProfit),
                      changePercent: m.profitMarginPct,
                      changeLabel: 'Margin: ${m.profitMarginPct.toStringAsFixed(1)}%',
                      accentColor: AppColors.accentGreen,
                      icon: Icons.trending_up_rounded,
                      sparklineData: const [5, 7, 9, 11, 14, 18, 22, 26],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: KpiMetricCard(
                      title: 'AVG ORDER VALUE',
                      value: currencyFmt.format(m.averageBasketValue),
                      changeLabel: '${m.totalItemsSold.toStringAsFixed(0)} units sold',
                      accentColor: AppColors.accentBlue,
                      icon: Icons.shopping_bag_outlined,
                      sparklineData: const [12, 11, 13, 14, 13, 15, 16, 17],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Secondary Quick Stats Strip
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accentTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.savings_outlined, size: 18, color: AppColors.accentTeal),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('COLLECTIONS VS DUES', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(currencyFmt.format(m.totalCollected), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          const Spacer(),
                          Text('Due: ${currencyFmt.format(m.totalDueIssued)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.accentRose, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.accentAmber),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('INVENTORY RISK ALERTS', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${m.lowStockCount} Low · ${m.outOfStockCount} Out of Stock', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          loading: () => const Row(
            children: [
              Expanded(child: CardShimmer(height: 140)),
              SizedBox(width: 16),
              Expanded(child: CardShimmer(height: 140)),
              SizedBox(width: 16),
              Expanded(child: CardShimmer(height: 140)),
              SizedBox(width: 16),
              Expanded(child: CardShimmer(height: 140)),
            ],
          ),
          error: (e, _) => _buildErrorBanner('Failed to load dashboard metrics: $e'),
        ),

        const SizedBox(height: 24),

        // Main Charts Row: 2/3 Sales Trend Area Chart + 1/3 Tender Donut Chart
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left 2/3: Sales Trend
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Sales Revenue Velocity',
                      subtitle: 'Interactive real-time sales curves by time-bucketed intervals',
                    ),
                    timeSeriesAsync.when(
                      data: (ts) => SalesTrendChart(
                        timeSeries: ts,
                        currencyFmt: currencyFmt,
                      ),
                      loading: () => const ChartShimmer(height: 240),
                      error: (e, _) => _buildErrorBanner('Failed to load sales trend: $e'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Right 1/3: Payment Method Donut
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Payment Breakdown',
                      subtitle: 'Tender share by revenue',
                    ),
                    paymentAsync.when(
                      data: (pb) => PaymentMethodsDonutChart(
                        breakdown: pb,
                        currencyFmt: currencyFmt,
                      ),
                      loading: () => const ChartShimmer(height: 240),
                      error: (e, _) => _buildErrorBanner('Failed to load payment breakdown: $e'),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        topAsync.when(
          data: (top) {
            if (top.items.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.star_border_rounded,
                title: 'No product performance data',
                subtitle: 'Execute checkout transactions in the POS terminal to populate velocity metrics.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chart Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Top 7 Revenue Generators',
                        subtitle: 'Ranked comparison of high-velocity catalog items',
                      ),
                      TopProductsBarChart(
                        items: top.items,
                        currencyFmt: currencyFmt,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Detailed Table Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Full Catalog Ranking & Profit Margins',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      const Divider(height: 1),
                      DataTable(
                        columnSpacing: 20,
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        headingTextStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        dataTextStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                        columns: const [
                          DataColumn(label: Text('#')),
                          DataColumn(label: Text('PRODUCT & VARIANT')),
                          DataColumn(label: Text('SKU')),
                          DataColumn(numeric: true, label: Text('UNITS SOLD')),
                          DataColumn(numeric: true, label: Text('GROSS REVENUE')),
                          DataColumn(numeric: true, label: Text('EST. PROFIT')),
                          DataColumn(numeric: true, label: Text('MARGIN')),
                        ],
                        rows: top.items.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final p = entry.value;
                          final isTop3 = idx <= 3;
                          return DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isTop3 ? AppColors.accentTeal.withValues(alpha: 0.15) : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$idx',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isTop3 ? AppColors.accentTeal : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.productName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
                                    if (p.variantName.isNotEmpty)
                                      Text(p.variantName, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              DataCell(Text(p.sku, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                              DataCell(Text(p.unitsSold.toStringAsFixed(0), style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                              DataCell(Text(currencyFmt.format(p.grossRevenue), style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                              DataCell(Text(currencyFmt.format(p.profit), style: GoogleFonts.inter(color: AppColors.accentGreen, fontWeight: FontWeight.w600))),
                              DataCell(
                                TrendBadge(value: p.marginPct, suffix: '%'),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const ChartShimmer(height: 400),
          error: (e, _) => _buildErrorBanner('Failed to load top products: $e'),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: Stock Valuation & Risk
  // =========================================================================
  Widget _buildStockValuationTab(
    BuildContext context,
    WidgetRef ref,
    NumberFormat currencyFmt,
  ) {
    final valAsync = ref.watch(stockValuationProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        valAsync.when(
          data: (val) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Capital Valuation & Inventory Exposure',
                        subtitle: 'Comparison of cost invested vs expected retail revenue',
                      ),
                      StockValuationBarChart(
                        valuation: val,
                        currencyFmt: currencyFmt,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Low Stock Warning Table
                if (val.lowStockItems.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Low Stock / Out of Stock Reorder Alerts (${val.lowStockItems.length})',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('PRODUCT')),
                            DataColumn(label: Text('SKU')),
                            DataColumn(numeric: true, label: Text('ON HAND')),
                            DataColumn(numeric: true, label: Text('COST PRICE')),
                            DataColumn(numeric: true, label: Text('RETAIL PRICE')),
                            DataColumn(label: Text('STATUS')),
                          ],
                          rows: val.lowStockItems.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(Text(item.productName, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                                DataCell(Text(item.sku, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                                DataCell(Text(item.quantityOnHand.toStringAsFixed(0), style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                                DataCell(Text(currencyFmt.format(item.costPrice))),
                                DataCell(Text(currencyFmt.format(item.sellingPrice))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (item.isOutOfStock ? AppColors.accentRose : AppColors.accentAmber).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      item.isOutOfStock ? 'OUT OF STOCK' : 'LOW STOCK',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: item.isOutOfStock ? AppColors.accentRose : AppColors.accentAmber,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const ChartShimmer(height: 380),
          error: (e, _) => _buildErrorBanner('Failed to load stock valuation: $e'),
        ),
      ],
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
    final paymentAsync = ref.watch(paymentBreakdownProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        paymentAsync.when(
          data: (pb) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Tender Methods Distribution',
                        subtitle: 'Multi-tender analysis across retail checkouts',
                      ),
                      PaymentMethodsDonutChart(
                        breakdown: pb,
                        currencyFmt: currencyFmt,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Table
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('PAYMENT METHOD')),
                      DataColumn(numeric: true, label: Text('TRANSACTIONS')),
                      DataColumn(numeric: true, label: Text('TOTAL COLLECTED')),
                      DataColumn(numeric: true, label: Text('SHARE %')),
                    ],
                    rows: pb.methods.map((m) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                const Icon(Icons.payment, size: 16, color: AppColors.accentTeal),
                                const SizedBox(width: 8),
                                Text(m.method, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DataCell(Text('${m.transactionCount}')),
                          DataCell(Text(currencyFmt.format(m.totalAmount), style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                          DataCell(Text('${m.percentage.toStringAsFixed(1)}%')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
          loading: () => const ChartShimmer(height: 350),
          error: (e, _) => _buildErrorBanner('Failed to load payment methods: $e'),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 4: Customer Dues & Credit
  // =========================================================================
  Widget _buildCustomerDuesTab(
    BuildContext context,
    WidgetRef ref,
    NumberFormat currencyFmt,
  ) {
    final duesAsync = ref.watch(customerDuesReportProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        duesAsync.when(
          data: (dues) {
            final overdueAccountsCount = dues.topDebtors.where((d) => d.dueBalance > d.creditLimit && d.creditLimit > 0).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Summary Strip
                Row(
                  children: [
                    Expanded(
                      child: KpiMetricCard(
                        title: 'TOTAL OUTSTANDING DUES',
                        value: currencyFmt.format(dues.totalOutstandingDue),
                        changeLabel: '${dues.totalCustomersWithDue} accounts with active credit balance',
                        accentColor: AppColors.accentRose,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: KpiMetricCard(
                        title: 'ACCOUNTS OVER CREDIT LIMIT',
                        value: '$overdueAccountsCount',
                        changeLabel: 'Over credit limit threshold',
                        accentColor: AppColors.accentAmber,
                        icon: Icons.warning_amber_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Table
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('CUSTOMER')),
                      DataColumn(label: Text('PHONE')),
                      DataColumn(numeric: true, label: Text('CREDIT LIMIT')),
                      DataColumn(numeric: true, label: Text('TOTAL DUE')),
                      DataColumn(label: Text('STATUS')),
                    ],
                    rows: dues.topDebtors.map((d) {
                      final isOverLimit = d.dueBalance > d.creditLimit && d.creditLimit > 0;
                      return DataRow(
                        cells: [
                          DataCell(Text(d.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                          DataCell(Text(d.phone ?? '—', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))),
                          DataCell(Text(d.creditLimit > 0 ? currencyFmt.format(d.creditLimit) : 'Unlimited')),
                          DataCell(Text(currencyFmt.format(d.dueBalance), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.accentRose))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isOverLimit ? AppColors.accentRose : AppColors.accentTeal).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isOverLimit ? 'OVER LIMIT' : 'ACTIVE CREDIT',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isOverLimit ? AppColors.accentRose : AppColors.accentTeal,
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
            );
          },
          loading: () => const ChartShimmer(height: 300),
          error: (e, _) => _buildErrorBanner('Failed to load customer dues: $e'),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentRose.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentRose.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.accentRose, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: AppColors.accentRose))),
        ],
      ),
    );
  }
}
