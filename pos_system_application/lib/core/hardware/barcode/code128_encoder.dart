/// Pure Dart Code 128 Barcode Encoder (ISO/IEC 15417)
/// Supports alphanumeric ASCII encoding with automatic checksum calculation.
class Code128Encoder {
  static const int startCodeB = 104;
  static const int stopCode = 106;

  /// Patterns for symbols 0 to 106.
  /// Each string contains widths of alternating bars and spaces.
  static const List<String> patterns = [
    '212222', '222122', '222221', '121223', '121322', '131222', // 0-5
    '122213', '122312', '132212', '221213', '221312', '231212', // 6-11
    '112232', '122132', '122231', '113222', '123122', '123221', // 12-17
    '223211', '221132', '221231', '213212', '223112', '312131', // 18-23
    '311222', '321122', '321221', '312212', '322112', '322211', // 24-29
    '212123', '212321', '232121', '111323', '131123', '131321', // 30-35
    '112313', '132113', '132311', '211313', '231113', '231311', // 36-41
    '112133', '112331', '132131', '113123', '113321', '133121', // 42-47
    '313121', '211331', '231131', '213113', '213311', '213131', // 48-53
    '311123', '311321', '331121', '312113', '312311', '332111', // 54-59
    '314111', '221411', '431111', '111224', '111422', '121124', // 60-65
    '121421', '141122', '141221', '112214', '112412', '122114', // 66-71
    '122411', '142112', '142211', '241211', '221114', '413111', // 72-77
    '241112', '134111', '111242', '121142', '121241', '114212', // 78-83
    '124112', '124211', '411212', '421112', '421211', '212141', // 84-89
    '214121', '412121', '111143', '111341', '131141', '114113', // 90-95
    '114311', '411113', '411311', '113141', '114131', '311141', // 96-101
    '411131', '211412', '211214', '211232', '2331112', // 102-106
  ];

  /// Encodes [text] using Code 128 Subset B.
  /// Returns a boolean list where `true` indicates a black bar module and `false` indicates a space module.
  static List<bool> encode(String text) {
    if (text.isEmpty) {
      text = '000000';
    }

    final symbols = <int>[startCodeB];
    int checksumSum = startCodeB;

    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      // Code 128 Subset B maps ASCII 32 (' ') to 127
      final symbolValue = (codeUnit >= 32 && codeUnit <= 126)
          ? codeUnit - 32
          : 0; // fallback to space if non-printable
      symbols.add(symbolValue);
      checksumSum += (i + 1) * symbolValue;
    }

    final checkDigit = checksumSum % 103;
    symbols.add(checkDigit);
    symbols.add(stopCode);

    // Expand symbols to binary modules (true = bar, false = space)
    final modules = <bool>[];

    // Quiet zone at start (standard 10 modules minimum)
    modules.addAll(List.filled(10, false));

    for (final sym in symbols) {
      if (sym >= 0 && sym < patterns.length) {
        final pattern = patterns[sym];
        bool isBar = true;
        for (int i = 0; i < pattern.length; i++) {
          final width = int.parse(pattern[i]);
          for (int w = 0; w < width; w++) {
            modules.add(isBar);
          }
          isBar = !isBar;
        }
      }
    }

    // Quiet zone at end (standard 10 modules minimum)
    modules.addAll(List.filled(10, false));

    return modules;
  }
}
