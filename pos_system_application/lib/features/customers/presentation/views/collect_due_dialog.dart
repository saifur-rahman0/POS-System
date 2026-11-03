import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/customer_due_payment.dart';
import '../controllers/customer_controller.dart';

class CollectDueDialog extends ConsumerStatefulWidget {
  final CustomerModel customer;

  const CollectDueDialog({super.key, required this.customer});

  static Future<CustomerDuePaymentModel?> show(
    BuildContext context, {
    required CustomerModel customer,
  }) {
    return showDialog<CustomerDuePaymentModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CollectDueDialog(customer: customer),
    );
  }

  @override
  ConsumerState<CollectDueDialog> createState() => _CollectDueDialogState();
}

class _CollectDueDialogState extends ConsumerState<CollectDueDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _paymentMethod = 'CASH';
  bool _isProcessing = false;
  String? _errorMessage;

  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    // Default to the full due balance
    _amountController = TextEditingController(
      text: widget.customer.dueBalance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setAmount(double val) {
    setState(() {
      _amountController.text = val.toStringAsFixed(2);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (enteredAmount <= 0) {
      setState(() => _errorMessage = 'Payment amount must be greater than zero');
      return;
    }
    if (enteredAmount > widget.customer.dueBalance) {
      setState(() => _errorMessage =
          'Payment amount cannot exceed customer outstanding due (${currencyFmt.format(widget.customer.dueBalance)})');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final payment = await ref
          .read(customersControllerProvider.notifier)
          .collectDuePayment(
            customerId: widget.customer.id,
            amount: enteredAmount,
            paymentMethod: _paymentMethod,
            reference: _refController.text.trim(),
            notes: _notesController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop(payment);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.payments_outlined, color: Color(0xFF0F766E), size: 24),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Collect Due Repayment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                const SizedBox(height: 16),

                // Customer summary card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.phone ?? 'No phone',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Outstanding Due',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            currencyFmt.format(c.dueBalance),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Quick Amount Shortcuts
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: Text('Full (${currencyFmt.format(c.dueBalance)})'),
                      onPressed: () => _setAmount(c.dueBalance),
                    ),
                    if (c.dueBalance > 100)
                      ActionChip(
                        label: const Text('৳ 100'),
                        onPressed: () => _setAmount(100),
                      ),
                    if (c.dueBalance > 500)
                      ActionChip(
                        label: const Text('৳ 500'),
                        onPressed: () => _setAmount(500),
                      ),
                    if (c.dueBalance > 1000)
                      ActionChip(
                        label: const Text('৳ 1000'),
                        onPressed: () => _setAmount(1000),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Repayment Amount *',
                    prefixText: '৳ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final num = double.tryParse(val.trim());
                    if (num == null || num <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Method + Reference Row
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        initialValue: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                          DropdownMenuItem(value: 'BKASH', child: Text('bKash')),
                          DropdownMenuItem(value: 'NAGAD', child: Text('Nagad')),
                          DropdownMenuItem(value: 'ROCKET', child: Text('Rocket')),
                          DropdownMenuItem(value: 'CARD', child: Text('Card')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _paymentMethod = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(
                          labelText: 'Txn / Card Ref',
                          hintText: 'e.g. TrxID982',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'e.g. Cleared pending dues for grocery',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _submit,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm & Collect Payment',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
