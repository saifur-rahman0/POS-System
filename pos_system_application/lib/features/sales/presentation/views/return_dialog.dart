import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sales_api_service.dart';
import '../../domain/models/sale_returnable_item.dart';

class ReturnDialog extends ConsumerStatefulWidget {
  final String saleId;
  final String receiptNo;
  final VoidCallback onReturnSuccess;

  const ReturnDialog({
    super.key,
    required this.saleId,
    required this.receiptNo,
    required this.onReturnSuccess,
  });

  @override
  ConsumerState<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends ConsumerState<ReturnDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<SaleReturnableItemModel> _returnableItems = [];
  final Map<String, double> _selectedQuantities = {};
  bool _restock = true;
  String _refundMethod = 'CASH';
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReturnableItems();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadReturnableItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await ref
          .read(salesApiServiceProvider)
          .getReturnableItems(widget.saleId);
      setState(() {
        _returnableItems = items;
        for (final item in items) {
          _selectedQuantities[item.saleItemId] = 0.0;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  double get _totalRefundAmount {
    double total = 0.0;
    for (final item in _returnableItems) {
      final qty = _selectedQuantities[item.saleItemId] ?? 0.0;
      if (qty > 0) {
        final unitPrice = item.quantitySold > 0
            ? (item.lineTotal / item.quantitySold)
            : item.unitPrice;
        total += unitPrice * qty;
      }
    }
    return total;
  }

  bool get _canSubmit {
    return _selectedQuantities.values.any((q) => q > 0) && !_isSubmitting;
  }

  Future<void> _submitReturn() async {
    final itemsToReturn = <Map<String, dynamic>>[];
    for (final item in _returnableItems) {
      final qty = _selectedQuantities[item.saleItemId] ?? 0.0;
      if (qty > 0) {
        itemsToReturn.add({
          'original_sale_item_id': item.saleItemId,
          'quantity': qty.toStringAsFixed(4),
          'restock': _restock,
          'restock_status': _restock ? 'RESTOCKED' : 'SCRAPPED',
        });
      }
    }

    if (itemsToReturn.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final returnResult = await ref.read(salesApiServiceProvider).createReturn(
            widget.saleId,
            items: itemsToReturn,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
            refundMethod: _refundMethod,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            content: Text(
              'Return ${returnResult.returnNo} processed successfully! Refund: ৳ ${returnResult.refundTotal.toStringAsFixed(2)}',
            ),
          ),
        );
        widget.onReturnSuccess();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Process Customer Return',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sale: ${widget.receiptNo}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
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

              // Error display
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Body content
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_returnableItems.isEmpty ||
                  _returnableItems.every((i) => i.quantityReturnable <= 0))
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                        SizedBox(height: 12),
                        Text(
                          'All items from this sale have already been returned.',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      const Text(
                        'Select Items & Quantities to Return:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ..._returnableItems.map((item) {
                        if (item.quantityReturnable <= 0) {
                          return const SizedBox.shrink();
                        }
                        final currentQty = _selectedQuantities[item.saleItemId] ?? 0.0;
                        final unitPrice = item.quantitySold > 0
                            ? (item.lineTotal / item.quantitySold)
                            : item.unitPrice;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: currentQty > 0
                                ? const Color(0xFF0F766E).withValues(alpha: 0.04)
                                : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'SKU: ${item.sku} | Unit: ৳ ${unitPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      'Returnable: ${item.quantityReturnable.toStringAsFixed(0)} (Sold: ${item.quantitySold.toStringAsFixed(0)})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF0F766E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Counter controls
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.remove, size: 16),
                                    onPressed: currentQty > 0
                                        ? () {
                                            setState(() {
                                              _selectedQuantities[item.saleItemId] =
                                                  currentQty - 1;
                                            });
                                          }
                                        : null,
                                  ),
                                  Container(
                                    width: 44,
                                    alignment: Alignment.center,
                                    child: Text(
                                      currentQty.toStringAsFixed(0),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.add, size: 16),
                                    onPressed: currentQty < item.quantityReturnable
                                        ? () {
                                            setState(() {
                                              _selectedQuantities[item.saleItemId] =
                                                  currentQty + 1;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),

                      // Restock option
                      SwitchListTile(
                        title: const Text('Restock into Inventory'),
                        subtitle: const Text(
                          'Increments stock quantity on hand and records SALE_RETURN ledger entry',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _restock,
                        activeThumbColor: const Color(0xFF0F766E),
                        onChanged: (val) {
                          setState(() {
                            _restock = val;
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Refund tender method
                      Row(
                        children: [
                          const Text(
                            'Refund Method:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<String>(
                            value: _refundMethod,
                            items: const [
                              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                              DropdownMenuItem(value: 'CARD', child: Text('Card')),
                              DropdownMenuItem(value: 'BKASH', child: Text('bKash')),
                              DropdownMenuItem(value: 'NAGAD', child: Text('Nagad')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _refundMethod = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Reason input
                      TextField(
                        controller: _reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Return Reason (Optional)',
                          hintText: 'e.g. Customer change of mind, defective packaging',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 24),

              // Bottom Summary & Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Refund Amount:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '৳ ${_totalRefundAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed:
                            _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed: _canSubmit ? _submitReturn : null,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.assignment_return, size: 18),
                        label: Text(
                          _isSubmitting ? 'Processing...' : 'Complete Refund',
                        ),
                      ),
                    ],
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
