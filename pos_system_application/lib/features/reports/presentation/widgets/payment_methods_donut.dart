import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/reports/domain/models/payment_method_breakdown.dart';

class PaymentMethodsDonutChart extends StatefulWidget {
  final PaymentMethodBreakdownModel breakdown;
  final NumberFormat currencyFmt;

  const PaymentMethodsDonutChart({
    super.key,
    required this.breakdown,
    required this.currencyFmt,
  });

  @override
  State<PaymentMethodsDonutChart> createState() => _PaymentMethodsDonutChartState();
}

class _PaymentMethodsDonutChartState extends State<PaymentMethodsDonutChart> {
  int _touchedIndex = -1;

  Color _getMethodColor(String method, int index) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return AppColors.accentTeal;
      case 'CARD':
        return AppColors.accentBlue;
      case 'BKASH':
        return const Color(0xFFE2136E); // bKash brand pink
      case 'NAGAD':
        return const Color(0xFFF7941D); // Nagad orange
      case 'DUE':
      case 'CREDIT':
        return AppColors.accentRose;
      case 'GIFT_CARD':
        return AppColors.accentPurple;
      default:
        final palette = [
          AppColors.accentTeal,
          AppColors.accentPurple,
          AppColors.accentBlue,
          AppColors.accentAmber,
          AppColors.accentGreen,
          AppColors.accentRose,
        ];
        return palette[index % palette.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = widget.breakdown.methods;
    if (methods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No payment transactions recorded',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 52,
                  sections: methods.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final m = entry.value;
                    final isTouched = idx == _touchedIndex;
                    final radius = isTouched ? 48.0 : 40.0;
                    final color = _getMethodColor(m.method, idx);

                    return PieChartSectionData(
                      color: color,
                      value: m.totalAmount > 0 ? m.totalAmount : 0.01,
                      title: isTouched ? '${m.percentage.toStringAsFixed(1)}%' : '',
                      radius: radius,
                      titleStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Center KPI text inside donut
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _touchedIndex >= 0 && _touchedIndex < methods.length
                        ? methods[_touchedIndex].method
                        : 'TOTAL',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _touchedIndex >= 0 && _touchedIndex < methods.length
                        ? widget.currencyFmt.format(methods[_touchedIndex].totalAmount)
                        : widget.currencyFmt.format(widget.breakdown.totalCollected),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Legend List
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: methods.asMap().entries.map((entry) {
            final idx = entry.key;
            final m = entry.value;
            final color = _getMethodColor(m.method, idx);
            final isTouched = idx == _touchedIndex;

            return InkWell(
              onTap: () {
                setState(() {
                  _touchedIndex = _touchedIndex == idx ? -1 : idx;
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isTouched ? color.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isTouched ? Border.all(color: color) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.method,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${m.percentage.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
