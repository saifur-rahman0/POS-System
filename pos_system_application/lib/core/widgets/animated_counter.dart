import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnimatedCounter extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int decimalDigits;
  final Duration duration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimalDigits = 0,
    this.duration = const Duration(milliseconds: 750),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        final fmt = NumberFormat.currency(
          symbol: prefix,
          decimalDigits: decimalDigits,
        );
        final formatted = '${fmt.format(animatedValue)}$suffix';
        return Text(formatted, style: style);
      },
    );
  }
}
