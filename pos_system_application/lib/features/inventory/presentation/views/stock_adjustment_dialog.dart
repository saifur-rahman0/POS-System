import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/stock_adjustment.dart';
import '../controllers/inventory_controller.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final String productVariantId;
  final String productName;
  final double currentStock;

  const StockAdjustmentDialog({
    super.key,
    required this.productVariantId,
    required this.productName,
    required this.currentStock,
  });

  static Future<StockAdjustmentModel?> show(
    BuildContext context, {
    required String productVariantId,
    required String productName,
    required double currentStock,
  }) {
    return showDialog<StockAdjustmentModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockAdjustmentDialog(
        productVariantId: productVariantId,
        productName: productName,
        currentStock: currentStock,
      ),
    );
  }

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _adjustmentType = 'ADJUSTMENT_DOWN';
  String _reason = 'DAMAGE';
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _enteredQty => double.tryParse(_qtyController.text.trim()) ?? 0.0;

  double get _projectedStock {
    if (_adjustmentType == 'ADJUSTMENT_UP') {
      return widget.currentStock + _enteredQty;
    } else {
      return widget.currentStock - _enteredQty;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = _enteredQty;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Adjustment quantity must be greater than zero');
      return;
    }

    if (_adjustmentType == 'ADJUSTMENT_DOWN' && qty > widget.currentStock) {
      setState(() => _errorMessage =
          'Cannot deduct more than current stock on hand (${widget.currentStock.toStringAsFixed(2)})');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final res = await ref.read(inventoryNotifierProvider).adjustStock(
            productVariantId: widget.productVariantId,
            adjustmentType: _adjustmentType,
            quantity: qty,
            reason: _reason,
            notes: _notesController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop(res);
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
    final projected = _projectedStock;
    final isNegative = projected < 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.tune, color: Color(0xFF0F766E), size: 24),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Adjust Stock — ${widget.productName}',
                              style: const TextStyle(
                                fontSize: 17,
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

                // Current stock status banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current On-Hand Stock',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            '${widget.currentStock.toStringAsFixed(2)} units',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Projected Stock',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            '${projected.toStringAsFixed(2)} units',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isNegative
                                  ? Colors.red
                                  : (_adjustmentType == 'ADJUSTMENT_UP'
                                      ? Colors.green.shade700
                                      : Colors.orange.shade800),
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
                    margin: const EdgeInsets.only(bottom: 12),
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

                // Adjustment Type Selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'ADJUSTMENT_DOWN',
                      label: Text('Deduct Stock (-)'),
                      icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                    ),
                    ButtonSegment(
                      value: 'ADJUSTMENT_UP',
                      label: Text('Add Stock (+)'),
                      icon: Icon(Icons.add_circle_outline, color: Colors.green),
                    ),
                  ],
                  selected: {_adjustmentType},
                  onSelectionChanged: (val) {
                    setState(() {
                      _adjustmentType = val.first;
                      if (_adjustmentType == 'ADJUSTMENT_UP') {
                        _reason = 'STOCKTAKE_CORRECTION';
                      } else {
                        _reason = 'DAMAGE';
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Reason & Quantity Row
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        initialValue: _reason,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          border: OutlineInputBorder(),
                        ),
                        items: _adjustmentType == 'ADJUSTMENT_DOWN'
                            ? const [
                                DropdownMenuItem(value: 'DAMAGE', child: Text('Damage / Broken')),
                                DropdownMenuItem(value: 'SPOILAGE', child: Text('Spoilage / Rot')),
                                DropdownMenuItem(value: 'THEFT', child: Text('Theft / Shrinkage')),
                                DropdownMenuItem(
                                    value: 'STOCKTAKE_CORRECTION',
                                    child: Text('Count Correction')),
                                DropdownMenuItem(
                                    value: 'INTERNAL_USE', child: Text('Internal Shop Use')),
                                DropdownMenuItem(value: 'EXPIRED', child: Text('Expired Date')),
                                DropdownMenuItem(value: 'OTHER', child: Text('Other Reason')),
                              ]
                            : const [
                                DropdownMenuItem(
                                    value: 'STOCKTAKE_CORRECTION',
                                    child: Text('Count Correction / Found Extra')),
                                DropdownMenuItem(
                                    value: 'INTERNAL_RETURN', child: Text('Internal Return')),
                                DropdownMenuItem(value: 'OTHER', child: Text('Other Reason')),
                              ],
                        onChanged: (val) {
                          if (val != null) setState(() => _reason = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Required';
                          }
                          final num = double.tryParse(val.trim());
                          if (num == null || num <= 0) {
                            return 'Must be > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'e.g. Found damaged bag during monthly inventory check',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Action
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      : Text(
                          _adjustmentType == 'ADJUSTMENT_UP'
                              ? 'Confirm & Add Stock'
                              : 'Confirm & Deduct Stock',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
