import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../branches/presentation/controllers/branches_controller.dart';
import '../../../shifts/presentation/controllers/shift_controller.dart';
import '../controllers/cart_controller.dart';
import '../../domain/models/payment_tender.dart';
import 'receipt_dialog.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PaymentDialog(),
    );
  }

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _TenderRow {
  String method;
  final TextEditingController amountController;
  final TextEditingController refController;

  _TenderRow({
    required this.method,
    required double initialAmount,
  })  : amountController =
            TextEditingController(text: initialAmount.toStringAsFixed(2)),
        refController = TextEditingController();

  double get amount => double.tryParse(amountController.text) ?? 0.0;

  void dispose() {
    amountController.dispose();
    refController.dispose();
  }
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final List<_TenderRow> _tenders = [];
  String? _errorMessage;
  bool _isProcessing = false;

  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    final grandTotal = ref.read(cartProvider).grandTotal;
    _tenders.add(_TenderRow(method: 'CASH', initialAmount: grandTotal));
  }

  @override
  void dispose() {
    for (final t in _tenders) {
      t.dispose();
    }
    super.dispose();
  }

  double get _totalEntered =>
      _tenders.fold(0.0, (acc, t) => acc + t.amount);

  void _addSplitTender(double remainingPayable) {
    setState(() {
      _tenders.add(
        _TenderRow(
          method: 'BKASH',
          initialAmount: remainingPayable > 0 ? remainingPayable : 0.0,
        ),
      );
    });
  }

  void _removeTender(int index) {
    if (_tenders.length <= 1) return;
    setState(() {
      final removed = _tenders.removeAt(index);
      removed.dispose();
    });
  }

  void _setCashAmount(double val) {
    if (_tenders.isEmpty) return;
    setState(() {
      _tenders.first.amountController.text = val.toStringAsFixed(2);
    });
  }

  void _addCashIncrement(double increment) {
    if (_tenders.isEmpty) return;
    final current = _tenders.first.amount;
    setState(() {
      _tenders.first.amountController.text =
          (current + increment).toStringAsFixed(2);
    });
  }

  Future<void> _submitCheckout() async {
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    final cart = ref.read(cartProvider);
    final grandTotal = cart.grandTotal;

    final tenderInputs = _tenders.map((t) {
      return PaymentTenderInput(
        method: t.method,
        amount: t.amount,
        reference: t.refController.text,
      );
    }).toList();

    // Basic client validation
    if (_totalEntered < grandTotal && cart.customerId == null) {
      setState(() {
        _errorMessage =
            'Due payments require a linked customer profile. Please select or register a customer first.';
        _isProcessing = false;
      });
      return;
    }

    final activeBranch = ref.read(activeBranchProvider);
    final currentShift = ref.read(currentShiftProvider).valueOrNull;
    final effectiveBranchId = activeBranch?.id ?? currentShift?.branchId;

    try {
      final sale = await ref
          .read(checkoutControllerProvider.notifier)
          .processCheckout(
            payments: tenderInputs,
            branchId: effectiveBranchId,
          );

      if (!mounted) return;

      if (sale != null) {
        // Close payment dialog and open verified receipt
        Navigator.of(context).pop();
        ReceiptDialog.show(context, sale);
      } else {
        final err = ref.read(checkoutControllerProvider).errorMessage;
        setState(() {
          _errorMessage = err ?? 'Checkout failed. Please try again.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final grandTotal = cart.grandTotal;
    final totalEntered = _totalEntered;
    final changeAmount =
        totalEntered > grandTotal ? totalEntered - grandTotal : 0.0;
    final dueAmount =
        totalEntered < grandTotal ? grandTotal - totalEntered : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Complete Payment',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Total Payable Highlight Card
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL PAYABLE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFmt.format(grandTotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    if (cart.customerName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              cart.customerName!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Error Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Quick Cash Suggestion Chips (applicable when first tender is CASH)
              if (_tenders.isNotEmpty && _tenders.first.method == 'CASH') ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Quick Cash:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey),
                    ),
                    ActionChip(
                      label: const Text('Exact'),
                      onPressed: () => _setCashAmount(grandTotal),
                    ),
                    ActionChip(
                      label: const Text('+50'),
                      onPressed: () => _addCashIncrement(50),
                    ),
                    ActionChip(
                      label: const Text('+100'),
                      onPressed: () => _addCashIncrement(100),
                    ),
                    ActionChip(
                      label: const Text('+500'),
                      onPressed: () => _addCashIncrement(500),
                    ),
                    ActionChip(
                      label: const Text('+1000'),
                      onPressed: () => _addCashIncrement(1000),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Split Tenders List
              Expanded(
                child: ListView.separated(
                  itemCount: _tenders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final t = _tenders[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          // Tender Method Dropdown
                          SizedBox(
                            width: 135,
                            child: DropdownButtonFormField<String>(
                              initialValue: t.method,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Method',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'CASH', child: Text('Cash')),
                                DropdownMenuItem(
                                    value: 'CARD', child: Text('Card')),
                                DropdownMenuItem(
                                    value: 'BKASH', child: Text('bKash')),
                                DropdownMenuItem(
                                    value: 'NAGAD', child: Text('Nagad')),
                                DropdownMenuItem(
                                    value: 'ROCKET', child: Text('Rocket')),
                                DropdownMenuItem(
                                    value: 'LOYALTY_POINTS', child: Text('Points')),
                                DropdownMenuItem(
                                    value: 'GIFT_CARD', child: Text('Gift Card')),
                                DropdownMenuItem(
                                    value: 'STORE_CREDIT', child: Text('Store Credit')),
                                DropdownMenuItem(
                                    value: 'DUE', child: Text('Due / Credit')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => t.method = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Amount Field
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: t.amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixText: '৳ ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Reference Field (optional)
                          if (t.method != 'CASH')
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: t.refController,
                                decoration: InputDecoration(
                                  labelText: t.method == 'GIFT_CARD'
                                      ? 'Card:PIN'
                                      : t.method == 'LOYALTY_POINTS'
                                          ? 'Points Note'
                                          : 'Txn / Card Ref',
                                  hintText: t.method == 'GIFT_CARD' ? 'GC-...:1234' : null,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                ),
                              ),
                            ),

                          // Remove Tender Button
                          if (_tenders.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _removeTender(index),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Add Split Tender Button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('+ Split Tender / Add Payment'),
                  onPressed: () => _addSplitTender(dueAmount),
                ),
              ),

              const SizedBox(height: 12),
              const Divider(),

              // Calculation Summary: Paid, Change or Due
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Tendered: ${currencyFmt.format(totalEntered)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        if (changeAmount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'Change: ${currencyFmt.format(changeAmount)}',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else if (dueAmount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              'Remaining Due: ${currencyFmt.format(dueAmount)}',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Payment Balanced (Exact)',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Submit Button
                  FilledButton(
                    onPressed: _isProcessing ? null : _submitCheckout,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Complete Sale (${currencyFmt.format(grandTotal)})',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
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
}
