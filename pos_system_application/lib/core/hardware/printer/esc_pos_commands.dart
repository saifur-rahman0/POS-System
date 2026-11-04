/// ESC/POS Command Byte Definitions for Thermal Receipt Printers
/// Compatible with Epson, Citizen, Star, Bixolon, Xprinter, and POS-80/58 devices.
class EscPosCommands {
  // --- Initialization ---
  static const List<int> initialize = [0x1B, 0x40]; // ESC @

  // --- Alignment ---
  static const List<int> alignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> alignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> alignRight = [0x1B, 0x61, 0x02]; // ESC a 2

  // --- Font & Character Styling ---
  static const List<int> boldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> boldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const List<int> underlineOn = [0x1B, 0x2D, 0x01]; // ESC - 1
  static const List<int> underlineOff = [0x1B, 0x2D, 0x00]; // ESC - 0

  // Text Scaling (GS ! n)
  static const List<int> textNormal = [0x1D, 0x21, 0x00];
  static const List<int> textDoubleHeight = [0x1D, 0x21, 0x01];
  static const List<int> textDoubleWidth = [0x1D, 0x21, 0x10];
  static const List<int> textDoubleSize = [0x1D, 0x21, 0x11];

  // --- Paper Movement ---
  static const List<int> lineFeed = [0x0A]; // LF
  static List<int> feedLines(int count) => [0x1B, 0x64, count.clamp(1, 255)]; // ESC d n

  // --- Paper Cutting ---
  static const List<int> cutFull = [0x1D, 0x56, 0x00]; // GS V 0
  static const List<int> cutPartial = [0x1D, 0x56, 0x42, 0x00]; // GS V 66 0 (Feed and partial cut)

  // --- Cash Drawer Trigger (Kick) ---
  /// Pulses Cash Drawer Connector (RJ11/RJ12). Pin 2 (Standard), on: 50ms, off: 500ms
  static const List<int> kickCashDrawerPin2 = [0x1B, 0x70, 0x00, 0x19, 0xFA];
  /// Pulses Cash Drawer Connector Pin 5 (Secondary drawer)
  static const List<int> kickCashDrawerPin5 = [0x1B, 0x70, 0x01, 0x19, 0xFA];
}

