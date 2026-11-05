import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/pricing_controller.dart';

class PromotionDialog extends ConsumerStatefulWidget {
  const PromotionDialog({super.key});

  @override
  ConsumerState<PromotionDialog> createState() => _PromotionDialogState();
}

class _PromotionDialogState extends ConsumerState<PromotionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _minSpendController = TextEditingController(text: '0.0');
  final _capController = TextEditingController();
  final _limitController = TextEditingController();

  String _discountType = 'PERCENTAGE';
  DateTime _validFrom = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _valueController.dispose();
    _minSpendController.dispose();
    _capController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_validUntil.isBefore(_validFrom)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid Until cannot be earlier than Valid From')),
      );
      return;
    }

    final value = double.tryParse(_valueController.text) ?? 0.0;
    if (_discountType == 'PERCENTAGE' && value > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percentage discount cannot exceed 100%')),
      );
      return;
    }

    final minSpend = double.tryParse(_minSpendController.text) ?? 0.0;
    final cap = _capController.text.trim().isEmpty ? null : double.tryParse(_capController.text);
    final limit = _limitController.text.trim().isEmpty ? null : int.tryParse(_limitController.text);

    final success = await ref.read(pricingControllerProvider.notifier).createPromotion({
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().isEmpty ? null : _codeController.text.trim().toUpperCase(),
      'discount_type': _discountType,
      'discount_value': value,
      'min_spend': minSpend,
      if (cap != null) 'max_discount_cap': cap,
      if (limit != null) 'usage_limit': limit,
      'valid_from': _validFrom.toIso8601String().substring(0, 10),
      'valid_until': _validUntil.toIso8601String().substring(0, 10),
      'applies_to': 'ALL',
      'scope_ids': [],
      'is_active': true,
    });

    if (mounted && success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pricingControllerProvider);

    return AlertDialog(
      title: const Text('New Promotion / Coupon'),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Campaign Name *',
                    hintText: 'e.g. Eid Mega Sale, Flash 20% Off',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Coupon Code (Optional)',
                          hintText: 'e.g. EID2026',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Discount Type *',
                          border: OutlineInputBorder(),
                        ),
                        value: _discountType,
                        items: const [
                          DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage (%)')),
                          DropdownMenuItem(value: 'FIXED_AMOUNT', child: Text('Fixed Amount (৳)')),
                        ],
                        onChanged: (val) => setState(() => _discountType = val ?? 'PERCENTAGE'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _valueController,
                        decoration: InputDecoration(
                          labelText: _discountType == 'PERCENTAGE'
                              ? 'Discount (%) *'
                              : 'Discount Amount (৳) *',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          final n = double.tryParse(val ?? '');
                          if (n == null || n <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minSpendController,
                        decoration: const InputDecoration(
                          labelText: 'Min Spend (৳)',
                          hintText: '0 for no min',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _capController,
                        decoration: const InputDecoration(
                          labelText: 'Max Cap (৳) (Optional)',
                          hintText: 'No cap if empty',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _limitController,
                        decoration: const InputDecoration(
                          labelText: 'Usage Limit (Optional)',
                          hintText: 'Unlimited if empty',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text('From: ${_validFrom.toIso8601String().substring(0, 10)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _validFrom,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => _validFrom = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text('Until: ${_validUntil.toIso8601String().substring(0, 10)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _validUntil,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => _validUntil = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: state.isLoading ? null : _submit,
          child: state.isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Promotion'),
        ),
      ],
    );
  }
}
