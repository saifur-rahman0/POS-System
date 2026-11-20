import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/reports/domain/models/sales_time_series.dart';

class SalesTrendChart extends StatefulWidget {
  final SalesTimeSeriesModel timeSeries;
  final NumberFormat currencyFmt;

  const SalesTrendChart({
    super.key,
    required this.timeSeries,
    required this.currencyFmt,
  });

  @override
  State<SalesTrendChart> createState() => _SalesTrendChartState();
}

class _SalesTrendChartState extends State<SalesTrendChart> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final points = widget.timeSeries.points;
    if (points.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'No sales activity in this period',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < points.length; i++) {
      final y = points[i].grossSales;
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }
    if (maxY == 0) maxY = 1000;
    final yInterval = (maxY / 4).clamp(1.0, double.infinity);
    final totalPeriodGross = points.fold<double>(0.0, (acc, p) => acc + p.grossSales);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary header strip inside chart
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accentTeal, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      'Gross Revenue: ${widget.currencyFmt.format(totalPeriodGross)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentTeal),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${points.length} data intervals',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              ),
              const Spacer(),
              if (_hoveredIndex >= 0 && _hoveredIndex < points.length)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.sidebarBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${points[_hoveredIndex].periodLabel}: ${widget.currencyFmt.format(points[_hoveredIndex].grossSales)} (${points[_hoveredIndex].salesCount} orders)',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        // Line chart
        SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                  if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                    setState(() {
                      _hoveredIndex = response.lineBarSpots!.first.x.toInt();
                    });
                  } else {
                    setState(() => _hoveredIndex = -1);
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.sidebarBg,
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final idx = spot.x.toInt();
                      final pt = idx < points.length ? points[idx] : null;
                      return LineTooltipItem(
                        '${pt?.periodLabel ?? ""}\n',
                        GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                        children: [
                          TextSpan(
                            text: widget.currencyFmt.format(spot.y),
                            style: GoogleFonts.inter(color: AppColors.accentTeal, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if (pt != null)
                            TextSpan(
                              text: '\n${pt.salesCount} orders',
                              style: GoogleFonts.inter(color: Colors.white60, fontSize: 10),
                            ),
                        ],
                      );
                    }).toList();
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
                    reservedSize: 32,
                    interval: (points.length / 6).clamp(1.0, double.infinity).ceilToDouble(),
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                      String label = points[idx].periodLabel;
                      if (label.length > 10) {
                        label = label.substring(11); // e.g. "14:00" from "2026-11-20 14:00"
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: 0,
              maxY: maxY * 1.15,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.accentTeal,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: points.length <= 15,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: AppColors.accentTeal,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.accentTeal.withValues(alpha: 0.30),
                        AppColors.accentTeal.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
