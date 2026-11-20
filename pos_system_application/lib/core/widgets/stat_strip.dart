import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_client/app/theme.dart';

class StatStripItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? badge;

  const StatStripItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.accentTeal,
    this.badge,
  });
}

/// A compact horizontal strip of stats shown at the top of screens.
class StatStrip extends StatelessWidget {
  final List<StatStripItem> items;
  final Color backgroundColor;
  final EdgeInsets padding;

  const StatStrip({
    super.key,
    required this.items,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final item = entry.value;
          final isLast = entry.key == items.length - 1;
          return Expanded(
            child: Row(
              children: [
                Expanded(child: _StatStripCell(item: item)),
                if (!isLast)
                  Container(
                    width: 1, height: 32, color: AppColors.cardBorder,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatStripCell extends StatelessWidget {
  final StatStripItem item;
  const _StatStripCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, size: 16, color: item.color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.label,
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 1),
            Row(
              children: [
                Text(item.value,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (item.badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(item.badge!,
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600,
                            color: item.color)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}
