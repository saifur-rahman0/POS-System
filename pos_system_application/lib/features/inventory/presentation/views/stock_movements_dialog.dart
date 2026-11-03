import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/inventory_controller.dart';

class StockMovementsDialog extends ConsumerWidget {
  final String productVariantId;
  final String productName;

  const StockMovementsDialog({
    super.key,
    required this.productVariantId,
    required this.productName,
  });

  static void show(
    BuildContext context, {
    required String productVariantId,
    required String productName,
  }) {
    showDialog(
      context: context,
      builder: (_) => StockMovementsDialog(
        productVariantId: productVariantId,
        productName: productName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsProvider(productVariantId));
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history, color: Color(0xFF0F766E), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Stock Audit Trail — $productName',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Movement Ledger Table
              Expanded(
                child: movementsAsync.when(
                  data: (data) {
                    if (data.items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            const Text(
                              'No stock movement ledger records found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                          columns: const [
                            DataColumn(label: Text('Date & Time')),
                            DataColumn(label: Text('Movement Type')),
                            DataColumn(
                                label: Text('Quantity Delta', textAlign: TextAlign.right)),
                            DataColumn(
                                label: Text('Unit Cost', textAlign: TextAlign.right)),
                            DataColumn(label: Text('Reference')),
                          ],
                          rows: data.items.map((m) {
                            final isPositive = m.quantityDelta > 0;

                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  dateFmt.format(m.createdAt),
                                  style: const TextStyle(fontSize: 12),
                                )),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPositive
                                          ? Colors.green.shade50
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isPositive
                                            ? Colors.green.shade200
                                            : Colors.red.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      m.movementType,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isPositive
                                            ? Colors.green.shade900
                                            : Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(
                                  '${isPositive ? '+' : ''}${m.quantityDelta.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isPositive
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                )),
                                DataCell(Text(
                                  currencyFmt.format(m.unitCost),
                                  style: const TextStyle(fontSize: 12),
                                )),
                                DataCell(Text(
                                  '${m.referenceType} (${m.referenceId.length > 8 ? m.referenceId.substring(0, 8) : m.referenceId})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      'Failed to load movements: $err',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
