import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/register_shift.dart';
import '../controllers/shift_controller.dart';

enum CashMovementType { cashIn, cashOut }

class CashInOutDialog extends ConsumerStatefulWidget {
  final RegisterShiftModel shift;
  final CashMovementType initialType;

  const CashInOutDialog({
    super.key,
    required this.shift,
    this.initialType = CashMovementType.cashIn,
  });

  @override
  ConsumerState<CashInOutDialog> createState() => _CashInOutDialogState();
}

class _CashInOutDialogState extends ConsumerState<CashInOutDialog> {
  final _formKey = GlobalKey<FormState>();
  late CashMovementType _type;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  late String _selectedReason;
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _inReasons = [
    'Float Top-up',
    'Customer Change Reserve',
    'Owner Investment / Deposit',
    'Other Cash In',
  ];

  final List<String> _outReasons = [
    'Petty Expense / Supplies',
    'Bank Cash Drop',
    'Mid-day Safe Drop',
    'Refreshment / Staff Food',
    'Delivery / Courier Fee',
    'Vendor Cash Payment',
    'Other Cash Out',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _selectedReason = _type == CashMovementType.cashIn ? _inReasons.first : _outReasons.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(CashMovementType type) {
    setState(() {
      _type = type;
      _selectedReason = type == CashMovementType.cashIn ? _inReasons.first : _outReasons.first;
      _errorMessage = null;
    });
  }

  void _addQuickAmount(double amount) {
    final current = double.tryParse(_amountController.text.trim()) ?? 0.0;
    setState(() {
      _amountController.text = (current + amount).toStringAsFixed(2);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Amount must be greater than zero');
      return;
    }

    final expectedCash = widget.shift.totals?.expectedCash ?? widget.shift.openingCash;
    if (_type == CashMovementType.cashOut && amount > expectedCash) {
      setState(() => _errorMessage =
          'Withdrawal (৳${amount.toStringAsFixed(2)}) exceeds drawer cash on hand (৳${expectedCash.toStringAsFixed(2)})');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_type == CashMovementType.cashIn) {
        await ref.read(currentShiftProvider.notifier).recordCashIn(
              shiftId: widget.shift.id,
              amount: amount,
              reason: _selectedReason,
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            );
      } else {
        await ref.read(currentShiftProvider.notifier).recordCashOut(
              shiftId: widget.shift.id,
              amount: amount,
              reason: _selectedReason,
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expectedCash = widget.shift.totals?.expectedCash ?? widget.shift.openingCash;
    final isCashIn = _type == CashMovementType.cashIn;
    final reasons = isCashIn ? _inReasons : _outReasons;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isCashIn ? 'Cash In (Deposit)' : 'Cash Out (Drop / Expense)',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<CashMovementType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: CashMovementType.cashIn,
                      label: Text('Cash In (+)'),
                    ),
                    ButtonSegment(
                      value: CashMovementType.cashOut,
                      label: Text('Cash Out (-)'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (set) => _onTypeChanged(set.first),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Live Expected Drawer Cash:',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                      Text(
                        '৳${expectedCash.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                const Text('Reason *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: reasons.contains(_selectedReason) ? _selectedReason : reasons.first,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedReason = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Amount (৳) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter amount';
                    final val = double.tryParse(v.trim());
                    if (val == null || val <= 0) return 'Enter a positive amount';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [100.0, 500.0, 1000.0, 2000.0].map((amt) {
                    return ActionChip(
                      label: Text('+৳${amt.toInt()}'),
                      onPressed: () => _addQuickAmount(amt),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Notes / Description (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Receipt details, payee name, or reference',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCashIn ? Colors.green.shade700 : Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isCashIn ? 'Confirm Cash In' : 'Confirm Cash Out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
