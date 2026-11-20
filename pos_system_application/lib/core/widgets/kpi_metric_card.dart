import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_client/app/theme.dart';
import 'animated_counter.dart';

class KpiMetricCard extends StatefulWidget {
  final String title;
  final String value;
  final num? numericValue;
  final String? prefix;
  final int? decimalDigits;
  final String? subtitle;
  final double? changePercent;
  final String? changeLabel;
  final Color accentColor;
  final IconData icon;
  final List<double>? sparklineData;
  final VoidCallback? onTap;

  const KpiMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.numericValue,
    this.prefix,
    this.decimalDigits,
    this.subtitle,
    this.changePercent,
    this.changeLabel,
    this.accentColor = AppColors.accentTeal,
    this.icon = Icons.trending_up,
    this.sparklineData,
    this.onTap,
  });

  @override
  State<KpiMetricCard> createState() => _KpiMetricCardState();
}

class _KpiMetricCardState extends State<KpiMetricCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = (widget.changePercent ?? 0) >= 0;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, size: 18, color: widget.accentColor),
                    ),
                    const Spacer(),
                    if (widget.changePercent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isPositive ? AppColors.accentGreen : AppColors.accentRose)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 10,
                              color: isPositive ? AppColors.accentGreen : AppColors.accentRose,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${widget.changePercent!.abs().toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: isPositive ? AppColors.accentGreen : AppColors.accentRose,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.numericValue != null)
                  AnimatedCounter(
                    value: widget.numericValue!,
                    prefix: widget.prefix ?? '',
                    decimalDigits: widget.decimalDigits ?? 0,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  )
                else
                  Text(
                    widget.value,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                if (widget.changeLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.changeLabel!,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
                if (widget.sparklineData != null && widget.sparklineData!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _MiniSparkline(data: widget.sparklineData!, color: widget.accentColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  const _MiniSparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: CustomPaint(
        painter: _SparklinePainter(data: data, color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs();
    if (range == 0) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final step = size.width / (data.length - 1);
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - ((data[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo((data.length - 1) * step, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}
