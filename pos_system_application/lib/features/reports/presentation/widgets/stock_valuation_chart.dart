import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/reports/domain/models/stock_valuation.dart';

class StockValuationBarChart extends StatelessWidget {
  final StockValuationModel valuation;
  final NumberFormat currencyFmt;

  const StockValuationBarChart({
    super.key,
    required this.valuation,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context) {
    final items = valuation.lowStockItems.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KPI summary badges inside chart card
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Capital at Cost',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(currencyFmt.format(valuation.totalCostValue),
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expected Retail Value',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.accentGreen, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(currencyFmt.format(valuation.totalRetailValue),
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Potential Profit Margin',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.accentAmber, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(currencyFmt.format(valuation.potentialGrossProfit),
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (items.isNotEmpty) ...[
          Text('Stock At Risk (Low / Out of Stock Items)',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                        final name = items[idx].productName;
                        final shortName = name.length > 10 ? '${name.substring(0, 9)}…' : name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            shortName,
                            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final it = entry.value;
                  return BarChartGroupData(
                    x: idx,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: it.stockCostValue,
                        color: AppColors.accentBlue,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: it.stockRetailValue,
                        color: AppColors.accentGreen,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppColors.accentBlue, 'Cost Value'),
              const SizedBox(width: 16),
              _legendDot(AppColors.accentGreen, 'Retail Value'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
