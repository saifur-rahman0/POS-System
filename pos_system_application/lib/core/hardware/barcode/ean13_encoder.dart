/// Pure Dart EAN-13 Barcode Encoder (GS1 Standard)
class Ean13Encoder {
  static const List<String> lPatterns = [
    '0001101',
    '0011001',
    '0010011',
    '0111101',
    '0100011',
    '0110001',
    '0101111',
    '0111011',
    '0110111',
    '0001011',
  ];

  static const List<String> gPatterns = [
    '0100111',
    '0110011',
    '0011011',
    '0100001',
    '0011101',
    '0111101',
    '0000101',
    '0010001',
    '0001001',
    '0010111',
  ];

  static const List<String> rPatterns = [
    '1110010',
    '1100110',
    '1101100',
    '1000010',
    '1011100',
    '1001110',
    '1010000',
    '1000100',
    '1001000',
    '1110100',
  ];

  static const List<String> parityMap = [
    'LLLLLL',
    'LLGLGG',
    'LLGGLG',
    'LLGGGL',
    'LGLLGG',
    'LGGLLG',
    'LGGGLL',
    'LGLGLG',
    'LGLGGL',
    'LGGLGL',
  ];

  /// Calculates the modulo 10 checksum digit for a 12-digit string
  static int calculateCheckDigit(String digits12) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(digits12[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    final mod = sum % 10;
    return mod == 0 ? 0 : 10 - mod;
  }

  /// Encodes a 12 or 13 digit string into boolean binary modules.
  static List<bool>? encode(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 12 && digitsOnly.length != 13) {
      return null;
    }

    String full13;
    if (digitsOnly.length == 12) {
      final check = calculateCheckDigit(digitsOnly);
      full13 = '$digitsOnly$check';
    } else {
      full13 = digitsOnly;
    }

    final firstDigit = int.parse(full13[0]);
    final parity = parityMap[firstDigit];

    final modules = <bool>[];

    // Left quiet zone (9 modules)
    modules.addAll(List.filled(9, false));

    // Start guard: 101
    modules.addAll([true, false, true]);

    // Digits 2 to 7 (left side)
    for (int i = 1; i <= 6; i++) {
      final d = int.parse(full13[i]);
      final p = parity[i - 1];
      final pattern = (p == 'L') ? lPatterns[d] : gPatterns[d];
      for (int c = 0; c < pattern.length; c++) {
        modules.add(pattern[c] == '1');
      }
    }

    // Center guard: 01010
    modules.addAll([false, true, false, true, false]);

    // Digits 8 to 13 (right side, R-patterns)
    for (int i = 7; i <= 12; i++) {
      final d = int.parse(full13[i]);
      final pattern = rPatterns[d];
      for (int c = 0; c < pattern.length; c++) {
        modules.add(pattern[c] == '1');
      }
    }

    // End guard: 101
    modules.addAll([true, false, true]);

    // Right quiet zone (9 modules)
    modules.addAll(List.filled(9, false));

    return modules;
  }
}
