import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/hardware/printer/printer_service.dart';
import '../../domain/models/sale_receipt.dart';

class ReceiptDialog extends StatelessWidget {
  final SaleReceiptModel sale;

  const ReceiptDialog({super.key, required this.sale});

  static Future<void> show(BuildContext context, SaleReceiptModel sale) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiptDialog(sale: sale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF0F766E),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Payment Successful',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scrollable Thermal Receipt View
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Store Header
                        const Center(
                          child: Text(
                            'RETAIL POS STORE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Center(
                          child: Text(
                            'Main Branch — Dhaka, Bangladesh',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Receipt Metadata
                        _metaRow('Receipt No:', sale.receiptNo, isBold: true),
                        _metaRow('Date & Time:', dateFmt.format(sale.createdAt.toLocal())),
                        _metaRow('Status:', sale.status),
                        if (sale.customerName != null)
                          _metaRow('Customer:', sale.customerName!),

                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Line Items Table
                        const Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                'Item',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Qty',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Price',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Total',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Divider(height: 1),
                        const SizedBox(height: 6),

                        ...sale.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                      if (item.sku != null)
                                        Text(
                                          item.sku!,
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    currencyFmt.format(item.unitPrice),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    currencyFmt.format(item.lineTotal),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Financials
                        _finRow('Subtotal', currencyFmt.format(sale.financials.subtotal)),
                        if (sale.financials.discountTotal > 0)
                          _finRow(
                            'Total Discount',
                            '- ${currencyFmt.format(sale.financials.discountTotal)}',
                            color: Colors.red.shade700,
                          ),
                        if (sale.financials.taxTotal > 0)
                          _finRow('VAT / Tax', '+ ${currencyFmt.format(sale.financials.taxTotal)}'),

                        const SizedBox(height: 4),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 4),

                        // Grand Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'GRAND TOTAL',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              currencyFmt.format(sale.financials.grandTotal),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Tenders
                        const Text(
                          'Payment Details:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        ...sale.payments.map((p) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  p.reference != null && p.reference!.isNotEmpty
                                      ? '${p.method} (${p.reference})'
                                      : p.method,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                Text(
                                  currencyFmt.format(p.amount),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 4),
                        _finRow('Paid Total', currencyFmt.format(sale.financials.paidTotal)),
                        if (sale.financials.changeAmount > 0)
                          _finRow(
                            'Change Returned',
                            currencyFmt.format(sale.financials.changeAmount),
                            isBold: true,
                            color: Colors.green.shade800,
                          ),
                        if (sale.financials.dueTotal > 0)
                          _finRow(
                            'Remaining Due',
                            currencyFmt.format(sale.financials.dueTotal),
                            isBold: true,
                            color: Colors.red.shade800,
                          ),

                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            '*** THANK YOU FOR SHOPPING! ***',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Actions: Print & New Sale
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print Receipt'),
                      onPressed: () async {
                        final printer = PrinterService();
                        final ok = await printer.printReceipt(sale);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Receipt ${sale.receiptNo} sent to thermal printer & drawer kicked.'
                                  : 'Printer spooling completed (Simulator).',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Kick Cash Drawer',
                    icon: const Icon(Icons.point_of_sale),
                    onPressed: () async {
                      await PrinterService().openCashDrawer();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cash drawer kick pulse sent.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('New Sale'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _finRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.grey.shade800,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
