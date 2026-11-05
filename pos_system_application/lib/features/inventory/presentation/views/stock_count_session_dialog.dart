import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/advanced_inventory_controller.dart';
import '../../domain/models/stock_count.dart';

class StockCountSessionDialog extends ConsumerStatefulWidget {
  final StockCountModel stockCount;

  const StockCountSessionDialog({super.key, required this.stockCount});

  @override
  ConsumerState<StockCountSessionDialog> createState() => _StockCountSessionDialogState();
}

class _StockCountSessionDialogState extends ConsumerState<StockCountSessionDialog> {
  late StockCountModel _currentCount;
  late TextEditingController _barcodeCtrl;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentCount = widget.stockCount;
    _barcodeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScan() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final notifier = ref.read(stockCountsListProvider.notifier);
      final updated = await notifier.scanItem(
        countId: _currentCount.id,
        barcode: barcode,
        incrementQty: 1.0,
      );
      setState(() {
        _currentCount = updated;
        _barcodeCtrl.clear();
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _completeAudit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Stock Audit?'),
        content: const Text(
          'Finalizing will automatically generate adjustment ledger movements for any discrepancies found.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Finalize Audit')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final notifier = ref.read(stockCountsListProvider.notifier);
      final completed = await notifier.completeCount(_currentCount.id);
      if (mounted) {
        setState(() {
          _currentCount = completed;
          _isProcessing = false;
        });
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Physical stock count completed and balances reconciled!')),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Completion Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _currentCount.status == 'COMPLETED';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check, color: Colors.indigo, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Audit Session: ${_currentCount.status}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Branch: ${_currentCount.branchName ?? 'Central Store'} | Created: ${_currentCount.createdAt.toIso8601String().substring(0, 10)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (!isCompleted) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Scan Barcode or Type SKU',
                          hintText: 'Press enter to tally +1',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.qr_code_scanner),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: _isProcessing ? null : _handleBarcodeScan,
                          ),
                        ),
                        onSubmitted: (_) => _handleBarcodeScan(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Complete Audit'),
                      onPressed: _isProcessing ? null : _completeAudit,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Audit Lines & Variances',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _currentCount.lines.isEmpty
                  ? const Center(child: Text('No lines added yet. Scan a barcode above.'))
                  : ListView.separated(
                      itemCount: _currentCount.lines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final line = _currentCount.lines[idx];
                        final variance = line.variance;
                        final hasDiscrepancy = variance != 0.0;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: hasDiscrepancy
                                ? (variance > 0 ? Colors.green.shade100 : Colors.red.shade100)
                                : Colors.grey.shade200,
                            child: Icon(
                              hasDiscrepancy
                                  ? (variance > 0 ? Icons.arrow_upward : Icons.arrow_downward)
                                  : Icons.check,
                              color: hasDiscrepancy
                                  ? (variance > 0 ? Colors.green.shade800 : Colors.red.shade800)
                                  : Colors.grey.shade700,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            line.productName ?? 'Unknown Variant',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Barcode: ${line.barcode ?? 'N/A'} | Expected: ${line.expectedQty.toStringAsFixed(2)} | Counted: ${line.countedQty.toStringAsFixed(2)}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: hasDiscrepancy
                                  ? (variance > 0 ? Colors.green.shade50 : Colors.red.shade50)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: hasDiscrepancy
                                    ? (variance > 0 ? Colors.green : Colors.red)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              variance > 0
                                  ? '+${variance.toStringAsFixed(2)}'
                                  : variance.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: hasDiscrepancy
                                    ? (variance > 0 ? Colors.green.shade800 : Colors.red.shade800)
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

