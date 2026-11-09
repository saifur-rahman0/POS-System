import 'package:flutter/material.dart';
import 'barcode_painter.dart';
import 'code128_encoder.dart';
import 'ean13_encoder.dart';

enum BarcodeFormat {
  auto,
  code128,
  ean13,
}

/// Standalone, responsive vector barcode widget.
class PosBarcodeWidget extends StatelessWidget {
  final String data;
  final double height;
  final double? width;
  final bool showText;
  final TextStyle? textStyle;
  final Color barColor;
  final Color backgroundColor;
  final BarcodeFormat format;

  const PosBarcodeWidget({
    super.key,
    required this.data,
    this.height = 54.0,
    this.width,
    this.showText = true,
    this.textStyle,
    this.barColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.format = BarcodeFormat.auto,
  });

  @override
  Widget build(BuildContext context) {
    final cleanData = data.trim();
    if (cleanData.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: backgroundColor,
        alignment: Alignment.center,
        child: const Text('NO BARCODE',
            style: TextStyle(fontSize: 10, color: Colors.grey)),
      );
    }

    List<bool>? modules;

    if (format == BarcodeFormat.ean13 ||
        (format == BarcodeFormat.auto && _isEanCandidate(cleanData))) {
      modules = Ean13Encoder.encode(cleanData);
    }

    // Fallback to Code 128 if EAN-13 not applicable or fails
    modules ??= Code128Encoder.encode(cleanData);

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: height,
            width: width ?? double.infinity,
            child: CustomPaint(
              painter: BarcodePainter(
                modules: modules,
                barColor: barColor,
                backgroundColor: backgroundColor,
              ),
            ),
          ),
          if (showText) ...[
            const SizedBox(height: 3),
            Text(
              cleanData,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle ??
                  const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isEanCandidate(String val) {
    final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == val.length &&
        (digits.length == 12 || digits.length == 13);
  }
}
