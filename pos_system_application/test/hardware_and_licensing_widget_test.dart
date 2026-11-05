import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_client/core/hardware/printer/esc_pos_commands.dart';
import 'package:pos_client/core/hardware/printer/printer_service.dart';
import 'package:pos_client/core/hardware/printer/receipt_esc_pos_generator.dart';
import 'package:pos_client/core/hardware/scanner/barcode_scanner_listener.dart';
import 'package:pos_client/features/checkout/domain/models/sale_receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummySale = SaleReceiptModel(
    id: '00000000-0000-0000-0000-000000000001',
    receiptNo: 'REC-20261104-MAIN-0001',
    status: 'COMPLETED',
    cashierId: '00000000-0000-0000-0000-000000000001',
    customerName: 'Anisur Rahman',
    financials: const SaleFinancialsModel(
      subtotal: 100.0,
      discountTotal: 10.0,
      taxTotal: 4.5,
      grandTotal: 94.5,
      paidTotal: 100.0,
      dueTotal: 0.0,
      changeAmount: 5.5,
    ),
    items: const [
      SaleReceiptItemModel(
        id: '1',
        productVariantId: 'v1',
        productName: 'Aarong Pure Ghee 500g',
        sku: 'GHEE-500G',
        barcode: '8941100123456',
        quantity: 1.0,
        unitPrice: 100.0,
        discount: 10.0,
        lineTotal: 90.0,
      ),
    ],
    payments: const [
      SaleReceiptPaymentModel(
        id: 'p1',
        method: 'CASH',
        amount: 100.0,
        status: 'CONFIRMED',
      ),
    ],
    notes: 'Test thermal print',
    createdAt: DateTime(2026, 11, 4, 14, 30),
  );

  group('Track 8: Hardware Integration Tests', () {
    test('ESC/POS Command Bytes definitions are accurate', () {
      expect(EscPosCommands.initialize, equals([0x1B, 0x40]));
      expect(EscPosCommands.cutPartial, equals([0x1D, 0x56, 0x42, 0x00]));
      expect(EscPosCommands.kickCashDrawerPin2, equals([0x1B, 0x70, 0x00, 0x19, 0xFA]));
      expect(EscPosCommands.alignCenter, equals([0x1B, 0x61, 0x01]));
      expect(EscPosCommands.boldOn, equals([0x1B, 0x45, 0x01]));
    });

    test('ReceiptEscPosGenerator generates valid thermal stream with kick and cut', () {
      final generator = ReceiptEscPosGenerator(
        config: const ReceiptEscPosConfig(
          paperWidth: PaperWidth.mm80,
          storeName: 'Test Store Ltd',
          kickDrawer: true,
          cutPaper: true,
        ),
      );

      final bytes = generator.generate(dummySale);
      expect(bytes, isNotEmpty);

      // Verify begins with cash drawer kick command
      expect(bytes.sublist(0, 5), equals(EscPosCommands.kickCashDrawerPin2));

      // Verify followed by initialize command
      expect(bytes.sublist(5, 7), equals(EscPosCommands.initialize));

      // Convert printable parts to string and verify contents
      final decoded = latin1.decode(bytes);
      expect(decoded.contains('Test Store Ltd'), isTrue);
      expect(decoded.contains('REC-20261104-MAIN-0001'), isTrue);
      expect(decoded.contains('Aarong Pure Ghee'), isTrue);
      expect(decoded.contains('GRAND TOTAL:'), isTrue);
      expect(decoded.contains('94.50'), isTrue);
      expect(decoded.contains('Anisur Rahman'), isTrue);

      // Verify ends with partial cut command
      expect(bytes.sublist(bytes.length - 4), equals(EscPosCommands.cutPartial));
    });

    test('PrinterService file simulator executes print receipt and open drawer', () async {
      final printerService = PrinterService(
        config: const PrinterConfig(
          connectionType: PrinterConnectionType.fileSimulator,
        ),
      );

      final printSuccess = await printerService.printReceipt(dummySale);
      expect(printSuccess, isTrue);

      final drawerSuccess = await printerService.openCashDrawer();
      expect(drawerSuccess, isTrue);
    });

    test('BarcodeScannerService captures programmatic scans and triggers listeners', () {
      final scanner = BarcodeScannerService();
      String? capturedBarcode;

      scanner.addListener((barcode) {
        capturedBarcode = barcode;
      });

      scanner.simulateScan('8941100123456');
      expect(capturedBarcode, equals('8941100123456'));

      scanner.dispose();
    });
  });
}
