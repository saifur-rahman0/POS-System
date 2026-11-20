import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/reports/domain/models/top_product.dart';

class TopProductsBarChart extends StatefulWidget {
  final List<TopProductModel> items;
  final NumberFormat currencyFmt;

  const TopProductsBarChart({
    super.key,
    required this.items,
    required this.currencyFmt,
  });

  @override
  State<TopProductsBarChart> createState() => _TopProductsBarChartState();
}

class _TopProductsBarChartState extends State<TopProductsBarChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final topList = widget.items.take(7).toList();
    if (topList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No sales data available to rank products',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }

    final maxRevenue = topList.fold<double>(
      0.0,
      (max, item) => item.grossRevenue > max ? item.grossRevenue : max,
    );
    final yInterval = (maxRevenue / 4).clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              barTouchData: BarTouchData(
                touchCallback: (FlTouchEvent event, barTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        barTouchResponse == null ||
                        barTouchResponse.spot == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.sidebarBg,
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final item = topList[group.x.toInt()];
                    return BarTooltipItem(
                      '${item.productName}\n',
                      GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      children: [
                        TextSpan(
                          text: '${widget.currencyFmt.format(rod.toY)}\n',
                          style: GoogleFonts.inter(color: AppColors.accentTeal, fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                        TextSpan(
                          text: '${item.unitsSold.toInt()} sold · Margin: ${item.marginPct.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (val) => const FlLine(
                  color: AppColors.cardBorder,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    interval: yInterval,
                    getTitlesWidget: (val, meta) {
                      if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                      String text;
                      if (val >= 1000000) {
                        text = '৳${(val / 1000000).toStringAsFixed(1)}M';
                      } else if (val >= 1000) {
                        text = '৳${(val / 1000).toStringAsFixed(0)}k';
                      } else {
                        text = '৳${val.toInt()}';
                      }
                      return Text(
                        text,
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= topList.length) return const SizedBox.shrink();
                      final name = topList[idx].productName;
                      final shortName = name.length > 8 ? '${name.substring(0, 7)}…' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          shortName,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: idx == _touchedIndex ? FontWeight.bold : FontWeight.w500,
                            color: idx == _touchedIndex ? AppColors.accentTeal : AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              maxY: maxRevenue * 1.15,
              barGroups: topList.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isSelected = idx == _touchedIndex;

                return BarChartGroupData(
                  x: idx,
                  barRods: [
                    BarChartRodData(
                      toY: item.grossRevenue,
                      width: 22,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      color: isSelected ? AppColors.accentTeal : AppColors.accentPurple,
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxRevenue * 1.15,
                        color: AppColors.cardBorder.withValues(alpha: 0.3),
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
  }
}
