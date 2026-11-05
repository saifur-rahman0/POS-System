import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../catalog/presentation/controllers/catalog_providers.dart';
import '../../controllers/pricing_controller.dart';

class AddPriceListItemDialog extends ConsumerStatefulWidget {
  final String priceListId;

  const AddPriceListItemDialog({super.key, required this.priceListId});

  @override
  ConsumerState<AddPriceListItemDialog> createState() => _AddPriceListItemDialogState();
}

class _AddPriceListItemDialogState extends ConsumerState<AddPriceListItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController(text: '1.0');
  final _priceController = TextEditingController();
  String? _selectedVariantId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedVariantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product variant')),
      );
      return;
    }

    final minQty = double.tryParse(_qtyController.text) ?? 1.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    final success = await ref.read(pricingControllerProvider.notifier).addOrUpdatePriceListItem(
      widget.priceListId,
      {
        'product_variant_id': _selectedVariantId,
        'min_quantity': minQty,
        'price': price,
        if (_startDate != null) 'start_date': _startDate!.toIso8601String().substring(0, 10),
        if (_endDate != null) 'end_date': _endDate!.toIso8601String().substring(0, 10),
        'is_active': true,
      },
    );

    if (mounted && success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pricingControllerProvider);
    final productsAsync = ref.watch(paginatedProductsProvider);

    return AlertDialog(
      title: const Text('Add Item to Price List'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              productsAsync.when(
                data: (paginated) {
                  final variants = paginated.items.expand((p) => p.variants).toList();
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Variant *',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedVariantId,
                    items: variants.map((v) {
                      return DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.name} (Base: ৳${v.sellingPrice.toStringAsFixed(2)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedVariantId = val;
                        final found = variants.where((v) => v.id == val).firstOrNull;
                        if (found != null && _priceController.text.isEmpty) {
                          _priceController.text = found.sellingPrice.toStringAsFixed(2);
                        }
                      });
                    },
                    validator: (val) => val == null ? 'Variant is required' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Error loading products: $err'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      decoration: const InputDecoration(
                        labelText: 'Min Quantity Break *',
                        hintText: 'e.g. 1.0 or 10.0',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        if (n == null || n <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (৳) *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        if (n == null || n < 0) return 'Must be >= 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        _startDate == null
                            ? 'Start Date (Optional)'
                            : 'From: ${_startDate!.toIso8601String().substring(0, 10)}',
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        _endDate == null
                            ? 'End Date (Optional)'
                            : 'Until: ${_endDate!.toIso8601String().substring(0, 10)}',
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _endDate = picked);
                      },
                    ),
                  ),
                ],
              ),
            ],
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
              : const Text('Save Item'),
        ),
      ],
    );
  }
}
