import 'dart:convert';
import 'package:intl/intl.dart';

import '../../../features/checkout/domain/models/sale_receipt.dart';
import 'esc_pos_commands.dart';

enum PaperWidth {
  mm80(48),
  mm58(32);

  final int charsPerLine;
  const PaperWidth(this.charsPerLine);
}

class ReceiptEscPosConfig {
  final PaperWidth paperWidth;
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String headerTitle;
  final String footerMessage;
  final bool kickDrawer;
  final bool cutPaper;

  const ReceiptEscPosConfig({
    this.paperWidth = PaperWidth.mm80,
    this.storeName = 'Retail POS Store',
    this.storeAddress = 'Gulshan-1, Dhaka, Bangladesh',
    this.storePhone = '+880 1700-000000',
    this.headerTitle = 'CASH MEMO / TAX INVOICE',
    this.footerMessage = 'Thank you for shopping with us!\nExchange within 7 days with original receipt.',
    this.kickDrawer = true,
    this.cutPaper = true,
  });
}

/// Generates raw binary ESC/POS streams for thermal POS receipt printers.
class ReceiptEscPosGenerator {
  final ReceiptEscPosConfig config;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  ReceiptEscPosGenerator({ReceiptEscPosConfig? config})
      : config = config ?? const ReceiptEscPosConfig();

  List<int> generate(SaleReceiptModel sale) {
    final List<int> bytes = [];
    final int width = config.paperWidth.charsPerLine;

    void add(List<int> data) => bytes.addAll(data);
    void text(String str) => bytes.addAll(utf8.encode(str));
    void line(String str) {
      text(str);
      add(EscPosCommands.lineFeed);
    }

    void divider([String char = '-']) {
      line(char * width);
    }

    void twoColumn(String left, String right) {
      final available = width - right.length;
      if (left.length > available) {
        left = left.substring(0, available - 1);
      }
      final spaces = width - left.length - right.length;
      line(left + (' ' * (spaces > 0 ? spaces : 1)) + right);
    }

    // 1. Kick Cash Drawer at the start of transaction printing
    if (config.kickDrawer) {
      add(EscPosCommands.kickCashDrawerPin2);
    }

    // 2. Initialize Printer
    add(EscPosCommands.initialize);

    // 3. Header
    add(EscPosCommands.alignCenter);
    add(EscPosCommands.boldOn);
    add(EscPosCommands.textDoubleSize);
    line(config.storeName);

    add(EscPosCommands.textNormal);
    add(EscPosCommands.boldOff);
    line(config.storeAddress);
    line('Tel: ${config.storePhone}');
    line(config.headerTitle);
    add(EscPosCommands.lineFeed);

    // 4. Receipt Meta
    add(EscPosCommands.alignLeft);
    divider('=');
    line('Receipt No: ${sale.receiptNo}');
    twoColumn('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt)}', 'Status: ${sale.status}');
    line('Cashier: Dev Cashier');
    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      line('Customer: ${sale.customerName}');
    }
    divider('-');

    // 5. Column Headers
    if (config.paperWidth == PaperWidth.mm80) {
      // 80mm: Item Name (24) | Qty x Price (12) | Total (12)
      line(_padRight('Item Description', 24) + _padLeft('Qty x Rate', 12) + _padLeft('Total', 12));
    } else {
      // 58mm: Item (16) | Qty (4) | Total (12)
      line(_padRight('Item', 16) + _padLeft('Qty', 4) + _padLeft('Total', 12));
    }
    divider('-');

    // 6. Items
    for (final item in sale.items) {
      final qtyStr = item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2);
      final rateStr = _currencyFormat.format(item.unitPrice);
      final totalStr = _currencyFormat.format(item.lineTotal);

      if (config.paperWidth == PaperWidth.mm80) {
        String name = item.productName;
        if (name.length > 24) name = '${name.substring(0, 21)}...';
        final rateCol = '$qtyStr x $rateStr';
        line(_padRight(name, 24) + _padLeft(rateCol, 12) + _padLeft(totalStr, 12));
      } else {
        String name = item.productName;
        if (name.length > 16) name = '${name.substring(0, 13)}...';
        line(_padRight(name, 16) + _padLeft(qtyStr, 4) + _padLeft(totalStr, 12));
      }

      if (item.discount > 0) {
        twoColumn('  (Item Disc.)', '-${_currencyFormat.format(item.discount)}');
      }
    }

    // 7. Financial Totals
    divider('-');
    twoColumn('Subtotal:', _currencyFormat.format(sale.financials.subtotal));
    if (sale.financials.discountTotal > 0) {
      twoColumn('Total Discount:', '-${_currencyFormat.format(sale.financials.discountTotal)}');
    }
    if (sale.financials.taxTotal > 0) {
      twoColumn('VAT / Tax (5%):', _currencyFormat.format(sale.financials.taxTotal));
    }

    divider('=');
    add(EscPosCommands.boldOn);
    add(EscPosCommands.textDoubleHeight);
    twoColumn('GRAND TOTAL:', 'BDT ${_currencyFormat.format(sale.financials.grandTotal)}');
    add(EscPosCommands.textNormal);
    add(EscPosCommands.boldOff);
    divider('=');

    // 8. Payments Breakdown
    for (final p in sale.payments) {
      twoColumn('Payment [${p.method}]:', _currencyFormat.format(p.amount));
    }
    twoColumn('Paid Amount:', _currencyFormat.format(sale.financials.paidTotal));
    if (sale.financials.changeAmount > 0) {
      twoColumn('Change Due:', _currencyFormat.format(sale.financials.changeAmount));
    }
    if (sale.financials.dueTotal > 0) {
      add(EscPosCommands.boldOn);
      twoColumn('Customer Debt / Due:', _currencyFormat.format(sale.financials.dueTotal));
      add(EscPosCommands.boldOff);
    }

    // 9. Notes & Footer
    if (sale.notes != null && sale.notes!.isNotEmpty) {
      add(EscPosCommands.lineFeed);
      line('Note: ${sale.notes}');
    }

    add(EscPosCommands.lineFeed);
    add(EscPosCommands.alignCenter);
    for (final lineStr in config.footerMessage.split('\n')) {
      line(lineStr);
    }
    line('Antigravity POS v1.0 - Offline Ready');

    // Feed lines before cut
    add(EscPosCommands.feedLines(4));

    // 10. Cut Paper
    if (config.cutPaper) {
      add(EscPosCommands.cutPartial);
    }

    return bytes;
  }

  String _padRight(String s, int width) {
    if (s.length >= width) return s.substring(0, width);
    return s + (' ' * (width - s.length));
  }

  String _padLeft(String s, int width) {
    if (s.length >= width) return s.substring(0, width);
    return (' ' * (width - s.length)) + s;
  }
}
