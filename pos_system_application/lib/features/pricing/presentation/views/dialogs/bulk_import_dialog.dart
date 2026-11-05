import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/bulk_import_result.dart';
import '../../controllers/pricing_controller.dart';

class BulkImportDialog extends ConsumerStatefulWidget {
  const BulkImportDialog({super.key});

  @override
  ConsumerState<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends ConsumerState<BulkImportDialog> {
  final _csvController = TextEditingController();
  BulkImportResultModel? _result;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  void _loadSampleData() {
    setState(() {
      _csvController.text =
          'product_sku,product_name,variant_name,barcode,cost_price,selling_price,track_stock,category_name\n'
          'SKU-USB-01,Kingston Flash Drive,32GB,890123456789,350.00,550.00,true,Storage\n'
          'SKU-USB-01,Kingston Flash Drive,64GB,890123456790,550.00,850.00,true,Storage\n'
          'SKU-MSE-02,Logitech Wireless Mouse,Matte Black,890123456791,850.00,1200.00,true,Peripherals\n';
    });
  }

  Future<void> _submit() async {
    final text = _csvController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste or load CSV content first')),
      );
      return;
    }

    final bytes = utf8.encode(text);
    final res = await ref.read(pricingControllerProvider.notifier).bulkImport(bytes);
    if (mounted && res != null) {
      setState(() {
        _result = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pricingControllerProvider);

    return AlertDialog(
      title: const Text('Bulk Product & Price CSV Import'),
      content: SizedBox(
        width: 650,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Paste CSV Data (Must include required header line):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.file_copy, size: 16),
                  label: const Text('Load Sample Template'),
                  onPressed: _loadSampleData,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _csvController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'product_sku,product_name,variant_name,cost_price,selling_price...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _result!.errorCount == 0 ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _result!.errorCount == 0 ? Colors.green.shade300 : Colors.orange.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Completed: ${_result!.totalRows} total rows | ${_result!.createdCount} created | ${_result!.updatedCount} updated | ${_result!.errorCount} errors',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _result!.errorCount == 0 ? Colors.green.shade900 : Colors.orange.shade900,
                        ),
                      ),
                      if (_result!.errors.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _result!.errors.length,
                            itemBuilder: (ctx, i) {
                              final err = _result!.errors[i];
                              return Text(
                                '• Row ${err.row}: ${err.message}',
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_result != null ? 'Close' : 'Cancel'),
        ),
        ElevatedButton.icon(
          icon: state.isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload, size: 16),
          label: const Text('Start Import'),
          onPressed: state.isLoading ? null : _submit,
        ),
      ],
    );
  }
}
