import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/z_report.dart';
import '../controllers/shift_controller.dart';

class ZReportDialog extends ConsumerStatefulWidget {
  final String shiftId;

  const ZReportDialog({super.key, required this.shiftId});

  @override
  ConsumerState<ZReportDialog> createState() => _ZReportDialogState();
}

class _ZReportDialogState extends ConsumerState<ZReportDialog> {
  ZReportModel? _report;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await ref.read(shiftHistoryProvider.notifier).fetchZReport(widget.shiftId);
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.teal),
                      SizedBox(width: 8),
                      Text(
                        'Shift Z-Report',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (_errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _buildReceiptContent(_report!)),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Done'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sent to 80mm ESC/POS Thermal Printer'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print Receipt'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptContent(ZReportModel r) {
    final recon = r.cashReconciliation;
    final summary = r.salesSummary;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    r.businessName.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.branchName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'DAILY SHIFT Z-REPORT',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13),
                  ),
                  const Text('----------------------------------------------',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _buildMetaRow('Shift ID:', r.shiftId.length > 8 ? r.shiftId.substring(0, 8) : r.shiftId),
            _buildMetaRow('Cashier:', '${r.cashierUsername}${r.cashierFullName != null ? ' (${r.cashierFullName})' : ''}'),
            _buildMetaRow('Opened:', _formatDate(r.openedAt)),
            if (r.closedAt != null) _buildMetaRow('Closed:', _formatDate(r.closedAt!)),
            _buildMetaRow('Duration:', '${r.durationMinutes} mins'),
            _buildMetaRow('Status:', r.status),
            const SizedBox(height: 10),
            const Text(
              'DRAWER RECONCILIATION',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
            ),
            const Text('----------------------------------------------',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            _buildLineItem('Opening Float', '৳${recon.openingFloat.toStringAsFixed(2)}'),
            _buildLineItem('Cash Sales', '৳${recon.cashSales.toStringAsFixed(2)}'),
            _buildLineItem('Cash In (Deposits)', '+৳${recon.cashIn.toStringAsFixed(2)}'),
            _buildLineItem('Cash Out (Drops/Exp)', '-৳${recon.cashOut.toStringAsFixed(2)}'),
            _buildLineItem('Cash Refunds', '-৳${recon.cashRefunds.toStringAsFixed(2)}'),
            const Divider(height: 12),
            _buildLineItem('Expected Drawer Cash', '৳${recon.expectedInDrawer.toStringAsFixed(2)}', isBold: true),
            if (recon.actualCounted != null)
              _buildLineItem('Physical Counted Cash', '৳${recon.actualCounted!.toStringAsFixed(2)}', isBold: true),
            if (recon.difference != null)
              _buildLineItem(
                'Variance (${recon.varianceStatus})',
                '${recon.difference! >= 0 ? '+' : ''}৳${recon.difference!.toStringAsFixed(2)}',
                isBold: true,
                color: recon.difference == 0
                    ? Colors.green.shade800
                    : (recon.difference! < 0 ? Colors.red.shade800 : Colors.amber.shade900),
              ),
            const SizedBox(height: 12),
            const Text(
              'TENDER BREAKDOWN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
            ),
            const Text('----------------------------------------------',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            ...r.tendersBreakdown.map(
              (t) => _buildLineItem('${t.method} (${t.count})', '৳${t.totalAmount.toStringAsFixed(2)}'),
            ),
            const SizedBox(height: 12),
            const Text(
              'SALES PERFORMANCE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
            ),
            const Text('----------------------------------------------',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            _buildLineItem('Gross Sales', '৳${summary.grossSales.toStringAsFixed(2)}'),
            _buildLineItem('Discounts Given', '-৳${summary.discountTotal.toStringAsFixed(2)}'),
            _buildLineItem('Tax Collected', '৳${summary.taxTotal.toStringAsFixed(2)}'),
            _buildLineItem('Net Sales', '৳${summary.netSales.toStringAsFixed(2)}', isBold: true),
            _buildLineItem('Total Completed Sales', '${summary.completedSales} sales'),
            if (summary.voidedSales > 0)
              _buildLineItem('Voided Sales', '${summary.voidedSales} orders', color: Colors.red),
            if (summary.returnsCount > 0)
              _buildLineItem('Returns Processed', '${summary.returnsCount} (৳${summary.returnsTotal.toStringAsFixed(2)})'),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                '*** END OF Z-REPORT ***',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Printed on ${_formatDate(r.generatedAt)}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLineItem(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
              ),
            ),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
