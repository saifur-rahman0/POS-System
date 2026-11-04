import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handler callback signature for barcode detection
typedef BarcodeScannedCallback = void Function(String barcode);

/// Global Hardware Keyboard Wedge Barcode Scanner Listener.
///
/// Hardware USB/Bluetooth laser and 2D barcode scanners emulate keyboard input,
/// sending characters at speeds typical of hardware chips (< 50ms per keystroke),
/// terminated by an Enter or Tab key.
class BarcodeScannerService {
  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeystrokeTime = DateTime.fromMillisecondsSinceEpoch(0);
  final List<Duration> _intervals = [];

  /// Maximum allowed duration between keystrokes to qualify as a hardware scanner burst
  final Duration maxInterKeystrokeInterval;

  /// Minimum characters to qualify as a valid scanned barcode
  final int minBarcodeLength;

  final List<BarcodeScannedCallback> _listeners = [];

  BarcodeScannerService({
    this.maxInterKeystrokeInterval = const Duration(milliseconds: 65),
    this.minBarcodeLength = 3,
  }) {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  void addListener(BarcodeScannedCallback callback) {
    if (!_listeners.contains(callback)) {
      _listeners.add(callback);
    }
  }

  void removeListener(BarcodeScannedCallback callback) {
    _listeners.remove(callback);
  }

  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _listeners.clear();
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Only process KeyDown events
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final elapsed = now.difference(_lastKeystrokeTime);
    _lastKeystrokeTime = now;

    // Check for scanner termination (Enter or Tab)
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      if (_buffer.isNotEmpty && _buffer.length >= minBarcodeLength) {
        // Compute average interval
        final avgIntervalMs = _intervals.isNotEmpty
            ? _intervals.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / _intervals.length
            : 0;

        // If average typing interval is under hardware threshold, it's a scanner!
        if (avgIntervalMs <= maxInterKeystrokeInterval.inMilliseconds || _intervals.isEmpty) {
          final barcode = _buffer.toString().trim();
          _buffer.clear();
          _intervals.clear();

          _dispatchBarcode(barcode);
          // Handled - prevent submitting focused forms
          return true;
        }
      }
      _buffer.clear();
      _intervals.clear();
      return false;
    }

    // Capture printable character
    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
      if (elapsed > const Duration(milliseconds: 150)) {
        // Human typing pause: reset buffer
        _buffer.clear();
        _intervals.clear();
      } else {
        _intervals.add(elapsed);
      }
      _buffer.write(char);
    }

    return false;
  }

  void _dispatchBarcode(String barcode) {
    for (final listener in List<BarcodeScannedCallback>.from(_listeners)) {
      try {
        listener(barcode);
      } catch (e) {
        debugPrint('Error in barcode listener: $e');
      }
    }
  }

  /// Programmatic test injection simulating a hardware barcode scan event
  void simulateScan(String barcode) {
    _dispatchBarcode(barcode);
  }
}

/// Widget that wraps a screen or POS terminal to automatically handle hardware barcode scans
class BarcodeScannerWrapper extends StatefulWidget {
  final Widget child;
  final BarcodeScannedCallback onBarcodeScanned;

  const BarcodeScannerWrapper({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
  });

  @override
  State<BarcodeScannerWrapper> createState() => _BarcodeScannerWrapperState();
}

class _BarcodeScannerWrapperState extends State<BarcodeScannerWrapper> {
  late final BarcodeScannerService _scannerService;

  @override
  void initState() {
    super.initState();
    _scannerService = BarcodeScannerService();
    _scannerService.addListener(widget.onBarcodeScanned);
  }

  @override
  void didUpdateWidget(covariant BarcodeScannerWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onBarcodeScanned != widget.onBarcodeScanned) {
      _scannerService.removeListener(oldWidget.onBarcodeScanned);
      _scannerService.addListener(widget.onBarcodeScanned);
    }
  }

  @override
  void dispose() {
    _scannerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
