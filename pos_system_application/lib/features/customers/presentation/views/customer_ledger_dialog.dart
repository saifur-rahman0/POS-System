import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/customer.dart';
import '../controllers/customer_controller.dart';

class CustomerLedgerDialog extends ConsumerWidget {
  final CustomerModel customer;

  const CustomerLedgerDialog({super.key, required this.customer});

  static void show(BuildContext context, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (_) => CustomerLedgerDialog(customer: customer),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(customerLedgerProvider(customer.id));
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
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
                      const Icon(Icons.history_edu_outlined,
                          color: Color(0xFF0F766E), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Ledger Statement — ${customer.name}',
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
              const SizedBox(height: 8),

              // Summary card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Credit Limit',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          currencyFmt.format(customer.creditLimit),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Available Credit',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          currencyFmt.format(customer.availableCredit),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Total Outstanding Due',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          currencyFmt.format(customer.dueBalance),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Ledger Transactions
              Expanded(
                child: ledgerAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            const Text(
                              'No ledger entries found for this customer',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                        columns: const [
                          DataColumn(label: Text('Date & Time')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Debit (+Due)', textAlign: TextAlign.right)),
                          DataColumn(label: Text('Credit (-Due)', textAlign: TextAlign.right)),
                          DataColumn(label: Text('Balance', textAlign: TextAlign.right)),
                        ],
                        rows: entries.map((entry) {
                          final isDebit = entry.debit > 0;
                          final isCredit = entry.credit > 0;

                          return DataRow(
                            cells: [
                              DataCell(Text(
                                dateFmt.format(entry.date),
                                style: const TextStyle(fontSize: 12),
                              )),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: entry.entryType == 'SALE_CHARGE'
                                        ? Colors.orange.shade50
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: entry.entryType == 'SALE_CHARGE'
                                          ? Colors.orange.shade200
                                          : Colors.green.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    entry.entryType,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: entry.entryType == 'SALE_CHARGE'
                                          ? Colors.orange.shade900
                                          : Colors.green.shade900,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(
                                entry.description,
                                style: const TextStyle(fontSize: 12),
                              )),
                              DataCell(Text(
                                isDebit ? currencyFmt.format(entry.debit) : '—',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isDebit ? FontWeight.w600 : FontWeight.normal,
                                  color: isDebit ? Colors.red.shade700 : Colors.black,
                                ),
                              )),
                              DataCell(Text(
                                isCredit ? currencyFmt.format(entry.credit) : '—',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCredit ? FontWeight.w600 : FontWeight.normal,
                                  color: isCredit ? Colors.green.shade700 : Colors.black,
                                ),
                              )),
                              DataCell(Text(
                                currencyFmt.format(entry.balance),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      'Failed to load ledger: $err',
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
