import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/cart_item.dart';
import '../controllers/cart_controller.dart';
import 'manager_override_dialog.dart';

class LineDiscountDialog extends ConsumerStatefulWidget {
  final CartItemModel item;

  const LineDiscountDialog({
    super.key,
    required this.item,
  });

  static Future<void> show(BuildContext context, CartItemModel item) {
    return showDialog<void>(
      context: context,
      builder: (_) => LineDiscountDialog(item: item),
    );
  }

  @override
  ConsumerState<LineDiscountDialog> createState() => _LineDiscountDialogState();
}

class _LineDiscountDialogState extends ConsumerState<LineDiscountDialog> {
  late String _discountType;
  late TextEditingController _valueController;
  late TextEditingController _reasonController;
  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

  final List<String> _quickReasons = [
    'Promotional Campaign',
    'Customer Loyalty Discount',
    'Damaged Packaging / Clearance',
    'Employee / Staff Privilege',
    'Price Match Guarantee',
  ];

  @override
  void initState() {
    super.initState();
    _discountType = widget.item.discountType;
    _valueController = TextEditingController(
      text: widget.item.discount > 0
          ? widget.item.discount.toStringAsFixed(2)
          : '',
    );
    _reasonController = TextEditingController(
      text: widget.item.discountReason ?? '',
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double get _enteredValue => double.tryParse(_valueController.text) ?? 0.0;

  double get _calculatedDiscount {
    final rawLineTotal = widget.item.quantity * widget.item.unitPrice;
    if (_discountType == 'PERCENTAGE') {
      final pct = _enteredValue.clamp(0.0, 100.0);
      return (rawLineTotal * (pct / 100.0));
    } else {
      return _enteredValue.clamp(0.0, rawLineTotal);
    }
  }

  double get _effectivePercentage {
    final rawLineTotal = widget.item.quantity * widget.item.unitPrice;
    if (rawLineTotal <= 0) return 0.0;
    return (_calculatedDiscount / rawLineTotal) * 100.0;
  }

  bool get _requiresManagerApproval => _effectivePercentage > 20.0;

  Future<void> _applyDiscount() async {
    final entered = _enteredValue;
    if (entered <= 0) {
      // Clear discount
      ref.read(cartProvider.notifier).updateItemDiscount(
            widget.item.variantId,
            0.0,
            discountType: 'FIXED',
            discountReason: null,
          );
      Navigator.of(context).pop();
      return;
    }

    final reason = _reasonController.text.trim();

    // Check if high discount threshold requires manager override
    if (_requiresManagerApproval) {
      final managerName = await ManagerOverrideDialog.show(
        context,
        action: 'DISCOUNT_OVERRIDE',
        defaultReason:
            'Discount ${_effectivePercentage.toStringAsFixed(1)}% on ${widget.item.productName}: $reason',
      );

      if (managerName == null) {
        // Manager declined or canceled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Discount > 20% requires supervisor PIN approval to apply.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    ref.read(cartProvider.notifier).updateItemDiscount(
          widget.item.variantId,
          entered,
          discountType: _discountType,
          discountReason: reason.isNotEmpty ? reason : null,
        );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawLineTotal = widget.item.quantity * widget.item.unitPrice;
    final discountAmount = _calculatedDiscount;
    final finalTotal = (rawLineTotal - discountAmount).clamp(0.0, rawLineTotal);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        Text(
                          widget.item.productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.item.variantName != null)
                          Text(
                            widget.item.variantName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
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
              const Divider(height: 20),

              // Item Unit Price & Quantity Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.item.quantity.toStringAsFixed(widget.item.quantity % 1 == 0 ? 0 : 2)} × ${currencyFmt.format(widget.item.unitPrice)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Base: ${currencyFmt.format(rawLineTotal)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Type Selector: Percentage vs Fixed
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'PERCENTAGE',
                    label: Text('Percentage (%)'),
                    icon: Icon(Icons.percent, size: 16),
                  ),
                  ButtonSegment(
                    value: 'FIXED',
                    label: Text('Fixed (৳)'),
                    icon: Icon(Icons.money, size: 16),
                  ),
                ],
                selected: {_discountType},
                onSelectionChanged: (val) {
                  setState(() {
                    _discountType = val.first;
                  });
                },
              ),

              const SizedBox(height: 14),

              // Discount Value Input
              TextField(
                controller: _valueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _discountType == 'PERCENTAGE'
                      ? 'Discount Rate'
                      : 'Discount Amount',
                  prefixText: _discountType == 'PERCENTAGE' ? '' : '৳ ',
                  suffixText: _discountType == 'PERCENTAGE' ? '%' : '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              // Quick percentage chips (if percentage selected)
              if (_discountType == 'PERCENTAGE') ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [5.0, 10.0, 15.0, 20.0, 25.0].map((rate) {
                    final isSel = _enteredValue == rate;
                    return ChoiceChip(
                      label: Text('${rate.toInt()}%'),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() {
                          _valueController.text = rate.toStringAsFixed(0);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 14),

              // Discount Reason Field
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Discount Reason',
                  hintText: 'e.g. VIP client, promo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),

              const SizedBox(height: 8),

              // Quick reason chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _quickReasons.map((reason) {
                  return ActionChip(
                    label: Text(
                      reason,
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _reasonController.text = reason;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Approval Alert Indicator if > 20%
              if (_requiresManagerApproval)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Discount exceeds 20% (${_effectivePercentage.toStringAsFixed(1)}%). Requires supervisor authorization.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),

              // Calculation Breakdown Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
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
                          'Discount: - ${currencyFmt.format(discountAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        Text(
                          'Effective: ${_effectivePercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Net Line Total',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          currencyFmt.format(finalTotal),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Dialog Actions
              Row(
                children: [
                  if (widget.item.discount > 0)
                    TextButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).updateItemDiscount(
                              widget.item.variantId,
                              0.0,
                              discountType: 'FIXED',
                              discountReason: null,
                            );
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reset Discount'),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _applyDiscount,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                    child: const Text('Apply'),
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

