import 'package:flutter/material.dart';

/// A card with subtle hover scaling, elevation lift, and tap bounce animations.
class PosHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final double baseElevation;
  final double hoverElevation;
  final double hoverScale;
  final EdgeInsetsGeometry? padding;

  const PosHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.baseColor,
    this.borderColor,
    this.hoverBorderColor,
    this.baseElevation = 1.0,
    this.hoverElevation = 4.0,
    this.hoverScale = 1.02,
    this.padding,
  });

  @override
  State<PosHoverCard> createState() => _PosHoverCardState();
}

class _PosHoverCardState extends State<PosHoverCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);
    final theme = Theme.of(context);
    final activeBorderColor =
        widget.hoverBorderColor ?? theme.colorScheme.primary;
    final normalBorderColor = widget.borderColor ?? Colors.grey.shade200;

    final currentScale =
        _isPressed ? 0.98 : (_isHovered ? widget.hoverScale : 1.0);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) => setState(() => _isPressed = false)
            : null,
        onTapCancel: widget.onTap != null
            ? () => setState(() => _isPressed = false)
            : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: currentScale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.baseColor ?? Colors.white,
              borderRadius: radius,
              border: Border.all(
                color: _isHovered ? activeBorderColor : normalBorderColor,
                width: _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? const Color(0xFF0F766E).withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: _isHovered ? 10 : 3,
                  offset: Offset(0, _isHovered ? 4 : 1),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Smooth cross-fade transition whenever text/number values change
class PosAnimatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;

  const PosAnimatedText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
      ),
    );
  }
}
