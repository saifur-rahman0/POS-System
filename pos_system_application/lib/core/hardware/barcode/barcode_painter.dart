import 'package:flutter/material.dart';

/// High-precision vector painter for rendering 1D barcode modules onto any canvas.
class BarcodePainter extends CustomPainter {
  final List<bool> modules;
  final Color barColor;
  final Color backgroundColor;

  const BarcodePainter({
    required this.modules,
    this.barColor = Colors.black,
    this.backgroundColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (modules.isEmpty) return;

    // Draw background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final moduleWidth = size.width / modules.length;

    for (int i = 0; i < modules.length; i++) {
      if (modules[i]) {
        // Draw crisp rectangle without antialiasing sub-pixel gaps
        final left = i * moduleWidth;
        final rect = Rect.fromLTWH(left, 0, moduleWidth + 0.35, size.height);
        canvas.drawRect(rect, barPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BarcodePainter oldDelegate) {
    return oldDelegate.modules != modules ||
        oldDelegate.barColor != barColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
