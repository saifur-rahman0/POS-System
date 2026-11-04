import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/register_shift.dart';
import '../controllers/shift_controller.dart';
import 'z_report_dialog.dart';

class CloseShiftDialog extends ConsumerStatefulWidget {
  final RegisterShiftModel shift;

  const CloseShiftDialog({super.key, required this.shift});

  @override
  ConsumerState<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends ConsumerState<CloseShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _countedDirectController = TextEditingController();

  final Map<int, int> _noteDenominations = {
    1000: 0,
    500: 0,
    200: 0,
    100: 0,
    50: 0,
    20: 0,
    10: 0,
  };

  bool _useDenominationCounter = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final expected = widget.shift.totals?.expectedCash ?? widget.shift.openingCash;
    _countedDirectController.text = expected.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _countedDirectController.dispose();
    super.dispose();
  }

  double get _calculatedCountedAmount {
    if (_useDenominationCounter) {
      double total = 0.0;
      _noteDenominations.forEach((denom, count) {
        total += denom * count;
      });
      return total;
    } else {
      return double.tryParse(_countedDirectController.text.trim()) ?? 0.0;
    }
  }

  double get _expectedCash {
    return widget.shift.totals?.expectedCash ?? widget.shift.openingCash;
  }

  double get _variance {
    return _calculatedCountedAmount - _expectedCash;
  }

  Future<void> _submitClose() async {
    if (!_formKey.currentState!.validate()) return;

    final counted = _calculatedCountedAmount;
    if (counted < 0) {
      setState(() => _errorMessage = 'Physical count cannot be negative');
      return;
    }

    final denomPayload = <String, int>{};
    _noteDenominations.forEach((denom, count) {
      if (count > 0) denomPayload[denom.toString()] = count;
    });

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final closedShift = await ref.read(currentShiftProvider.notifier).closeShift(
            shiftId: widget.shift.id,
            closingCashCounted: counted,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            denominations: denomPayload,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        // Prompt Z-Report dialog
        showDialog(
          context: context,
          builder: (ctx) => ZReportDialog(shiftId: closedShift.id),
        );
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
    final expected = _expectedCash;
    final counted = _calculatedCountedAmount;
    final diff = _variance;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lock, color: Colors.amber.shade900, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Close Register Shift',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Reconcile cash drawer and finalize daily shift',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
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
                const SizedBox(height: 18),
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
                // Drawer Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildSummaryItem('Opening Float', '৳${widget.shift.openingCash.toStringAsFixed(2)}')),
                      Expanded(
                        child: _buildSummaryItem(
                          'Cash Sales',
                          '৳${(widget.shift.totals?.cashSales ?? 0.0).toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        child: _buildSummaryItem(
                          'Net Moves',
                          '৳${((widget.shift.totals?.cashIn ?? 0.0) - (widget.shift.totals?.cashOut ?? 0.0) - (widget.shift.totals?.cashRefunds ?? 0.0)).toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        child: _buildSummaryItem(
                          'Expected Cash',
                          '৳${expected.toStringAsFixed(2)}',
                          isBold: true,
                          color: Colors.teal.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Cash Count Method:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    ChoiceChip(
                      label: const Text('Denomination Counter'),
                      selected: _useDenominationCounter,
                      onSelected: (val) {
                        setState(() => _useDenominationCounter = true);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Direct Total'),
                      selected: !_useDenominationCounter,
                      onSelected: (val) {
                        setState(() => _useDenominationCounter = false);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_useDenominationCounter) ...[
                  const Text(
                    'Count Bills / Notes (৳)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: _noteDenominations.keys.map((denom) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '৳$denom',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const Text('x', style: TextStyle(color: Colors.grey)),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                height: 36,
                                child: TextFormField(
                                  initialValue: _noteDenominations[denom]?.toString() ?? '0',
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onChanged: (val) {
                                    final count = int.tryParse(val.trim()) ?? 0;
                                    setState(() {
                                      _noteDenominations[denom] = count >= 0 ? count : 0;
                                    });
                                  },
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '= ৳${(denom * (_noteDenominations[denom] ?? 0)).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  const Text('Counted Physical Cash (৳) *', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _countedDirectController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                // Live Variance Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: diff == 0
                        ? Colors.green.shade50
                        : (diff < 0 ? Colors.red.shade50 : Colors.amber.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: diff == 0
                          ? Colors.green.shade300
                          : (diff < 0 ? Colors.red.shade300 : Colors.amber.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Physical Count: ৳${counted.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              'Drawer Variance: ${diff >= 0 ? '+' : ''}৳${diff.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: diff == 0
                                    ? Colors.green.shade800
                                    : (diff < 0 ? Colors.red.shade800 : Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        backgroundColor: diff == 0
                            ? Colors.green.shade100
                            : (diff < 0 ? Colors.red.shade100 : Colors.amber.shade100),
                        label: Text(
                          diff == 0 ? 'BALANCED' : (diff < 0 ? 'SHORTAGE' : 'OVERAGE'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: diff == 0
                                ? Colors.green.shade900
                                : (diff < 0 ? Colors.red.shade900 : Colors.amber.shade900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Closing Handover Notes (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Explain any shortage/overage or end-of-day observations',
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
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _submitClose,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(_isSubmitting ? 'Closing...' : 'Reconcile & Close Shift'),
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

  Widget _buildSummaryItem(String label, String value, {bool isBold = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
