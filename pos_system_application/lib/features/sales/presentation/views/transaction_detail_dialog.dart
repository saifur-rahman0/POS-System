import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/pos_transaction.dart';

class TransactionDetailDialog extends StatelessWidget {
  final PosTransactionModel transaction;
  final VoidCallback? onReprint;

  const TransactionDetailDialog({
    super.key,
    required this.transaction,
    this.onReprint,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    final isPositive = transaction.direction == TransactionDirection.inflow;
    final directionSymbol = isPositive ? '+' : (transaction.direction == TransactionDirection.outflow ? '-' : '⇄');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: transaction.directionColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      transaction.type.icon,
                      color: transaction.directionColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              transaction.referenceNo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Type Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                transaction.type.label.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: transaction.statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                transaction.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: transaction.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFmt.format(transaction.timestamp),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount Callout Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: transaction.directionColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: transaction.directionColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.direction.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: transaction.directionColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$directionSymbol ${currencyFmt.format(transaction.amount)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: transaction.directionColor,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.payment, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  transaction.paymentMethod,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Information Grid (Party, Cashier, Note)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            'Party / Entity',
                            transaction.partyName,
                            icon: Icons.person_outline,
                            isBold: true,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            'Payment Method',
                            transaction.paymentMethod,
                            icon: Icons.credit_card_outlined,
                          ),
                          if (transaction.cashierName != null) ...[
                            const Divider(height: 16),
                            _buildDetailRow(
                              'Cashier / User',
                              transaction.cashierName!,
                              icon: Icons.badge_outlined,
                            ),
                          ],
                          if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                            const Divider(height: 16),
                            _buildDetailRow(
                              'Notes / Remarks',
                              transaction.note!,
                              icon: Icons.notes_outlined,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Line Items Table (if any)
                    if (transaction.items.isNotEmpty) ...[
                      const Text(
                        'Line Items',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                            headingRowHeight: 38,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 46,
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                            ],
                            rows: transaction.items.map((item) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.sku != '-')
                                          Text(
                                            item.sku,
                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(item.quantity.toStringAsFixed(1), style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(currencyFmt.format(item.unitPrice), style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(currencyFmt.format(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Financials Summary (Subtotal, Discount, Tax, Total, Paid, Due)
                    if (transaction.subtotal != null || transaction.paidAmount != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            if (transaction.subtotal != null)
                              _buildSummaryLine('Subtotal', currencyFmt.format(transaction.subtotal!)),
                            if (transaction.discount != null && transaction.discount! > 0)
                              _buildSummaryLine('Discount', '- ${currencyFmt.format(transaction.discount!)}', color: Colors.green.shade700),
                            if (transaction.tax != null && transaction.tax! > 0)
                              _buildSummaryLine('Tax / VAT', '+ ${currencyFmt.format(transaction.tax!)}'),
                            const Divider(height: 16),
                            _buildSummaryLine('Net Total', currencyFmt.format(transaction.amount), isTotal: true),
                            if (transaction.paidAmount != null) ...[
                              const SizedBox(height: 4),
                              _buildSummaryLine('Amount Paid', currencyFmt.format(transaction.paidAmount!), color: const Color(0xFF0F766E)),
                            ],
                            if (transaction.dueAmount != null && transaction.dueAmount! > 0) ...[
                              const SizedBox(height: 4),
                              _buildSummaryLine('Due Balance', currencyFmt.format(transaction.dueAmount!), color: Colors.red.shade700, isBold: true),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Payments Allocation (if any)
                    if (transaction.payments.isNotEmpty) ...[
                      const Text(
                        'Payment Allocations',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      ...transaction.payments.map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF0F766E)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.method,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      if (p.reference != null && p.reference!.isNotEmpty)
                                        Text('Ref: ${p.reference}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                Text(
                                  currencyFmt.format(p.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onReprint != null)
                    OutlinedButton.icon(
                      onPressed: onReprint,
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Reprint Receipt'),
                    )
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {IconData? icon, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(String label, String amount, {bool isTotal = false, bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal || isBold ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal || isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isTotal ? const Color(0xFF0F766E) : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}
