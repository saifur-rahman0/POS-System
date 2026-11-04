import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/checkout/domain/models/sale_receipt.dart';
import 'esc_pos_commands.dart';
import 'receipt_esc_pos_generator.dart';

enum PrinterConnectionType {
  networkTcp,
  windowsSpooler,
  fileSimulator,
}

class PrinterConfig {
  final PrinterConnectionType connectionType;
  final String ipAddress;
  final int port;
  final String printerName;
  final ReceiptEscPosConfig receiptConfig;

  const PrinterConfig({
    this.connectionType = PrinterConnectionType.fileSimulator,
    this.ipAddress = '192.168.1.200',
    this.port = 9100,
    this.printerName = 'POS-80-Thermal',
    this.receiptConfig = const ReceiptEscPosConfig(),
  });
}

class PrinterService {
  final PrinterConfig config;
  final ReceiptEscPosGenerator _generator;

  PrinterService({PrinterConfig? config})
      : config = config ?? const PrinterConfig(),
        _generator = ReceiptEscPosGenerator(config: config?.receiptConfig);

  /// Prints a formatted ESC/POS sales receipt and kicks the cash drawer
  Future<bool> printReceipt(SaleReceiptModel sale) async {
    final bytes = _generator.generate(sale);
    return await _sendBytes(bytes, 'Receipt for ${sale.receiptNo}');
  }

  /// Sends standalone pulse command to open the cash drawer
  Future<bool> openCashDrawer() async {
    const bytes = EscPosCommands.kickCashDrawerPin2;
    return await _sendBytes(bytes, 'Cash Drawer Kick Pulse');
  }

  Future<bool> _sendBytes(List<int> bytes, String description) async {
    try {
      switch (config.connectionType) {
        case PrinterConnectionType.networkTcp:
          final socket = await Socket.connect(config.ipAddress, config.port, timeout: const Duration(seconds: 3));
          socket.add(bytes);
          await socket.flush();
          await socket.close();
          developer.log('Sent ${bytes.length} bytes via TCP to ${config.ipAddress}:${config.port} [$description]');
          return true;

        case PrinterConnectionType.windowsSpooler:
        case PrinterConnectionType.fileSimulator:
          // In desktop simulator, write to a persistent spool debug file for verification
          final tempDir = Directory.systemTemp;
          final file = File('${tempDir.path}/pos_thermal_spool.bin');
          await file.writeAsBytes(bytes);
          developer.log('Simulated print [${bytes.length} bytes written to ${file.path}]: $description');
          return true;
      }
    } catch (e) {
      developer.log('Printer error: $e');
      return false;
    }
  }
}

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});
