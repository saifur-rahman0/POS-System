import 'dart:math';

/// Generates a standard RFC 4122 version 4 UUID using cryptographic randomness.
String generateUuidV4() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40; // RFC4122 v4
  values[8] = (values[8] & 0x3f) | 0x80; // variant
  return '${_toHex(values.sublist(0, 4))}-${_toHex(values.sublist(4, 6))}-${_toHex(values.sublist(6, 8))}-${_toHex(values.sublist(8, 10))}-${_toHex(values.sublist(10, 16))}';
}

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

