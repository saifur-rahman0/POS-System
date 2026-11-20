import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_client/app/theme.dart';

class TrendBadge extends StatelessWidget {
  final double value;
  final String? suffix;
  final bool invertColors;

  const TrendBadge({
    super.key,
    required this.value,
    this.suffix = '%',
    this.invertColors = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = invertColors ? value < 0 : value >= 0;
    final color = isPositive ? AppColors.accentGreen : AppColors.accentRose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 10, color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${value.abs().toStringAsFixed(1)}${suffix ?? ''}',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
