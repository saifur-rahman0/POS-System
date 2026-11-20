import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_client/app/theme.dart';

class ResizableHeaderCell extends StatefulWidget {
  final String title;
  final double width;
  final ValueChanged<double> onResize;
  final ValueChanged<double>? onResizeEnd;
  final VoidCallback? onDoubleTapReset;
  final double minWidth;
  final double maxWidth;
  final bool isNumeric;
  final TextStyle? textStyle;
  final Widget? customContent;

  const ResizableHeaderCell({
    super.key,
    required this.title,
    required this.width,
    required this.onResize,
    this.onResizeEnd,
    this.onDoubleTapReset,
    this.minWidth = 60.0,
    this.maxWidth = 800.0,
    this.isNumeric = false,
    this.textStyle,
    this.customContent,
  });

  @override
  State<ResizableHeaderCell> createState() => _ResizableHeaderCellState();
}

class _ResizableHeaderCellState extends State<ResizableHeaderCell> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Row(
        children: [
          Expanded(
            child: widget.customContent ??
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: widget.isNumeric ? TextAlign.right : TextAlign.left,
                  style: widget.textStyle ??
                      GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF475569),
                      ),
                ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: widget.onDoubleTapReset,
              onHorizontalDragStart: (_) => setState(() => _isDragging = true),
              onHorizontalDragEnd: (_) {
                setState(() => _isDragging = false);
                widget.onResizeEnd?.call(widget.width);
              },
              onHorizontalDragUpdate: (details) {
                final next = (widget.width + details.delta.dx)
                    .clamp(widget.minWidth, widget.maxWidth);
                widget.onResize(next);
              },
              child: Container(
                width: 14,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.centerRight,
                child: Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: (_isHovering || _isDragging)
                        ? AppColors.accentTeal
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
