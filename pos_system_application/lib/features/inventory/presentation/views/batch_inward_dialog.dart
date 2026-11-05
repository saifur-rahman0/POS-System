import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../catalog/presentation/controllers/catalog_providers.dart';
import '../controllers/advanced_inventory_controller.dart';

class BatchInwardDialog extends ConsumerStatefulWidget {
  final String? initialVariantId;

  const BatchInwardDialog({super.key, this.initialVariantId});

  @override
  ConsumerState<BatchInwardDialog> createState() => _BatchInwardDialogState();
}

class _BatchInwardDialogState extends ConsumerState<BatchInwardDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _batchNumberCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _costPriceCtrl;

  String? _selectedVariantId;
  DateTime? _manufacturingDate;
  DateTime? _expiryDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedVariantId = widget.initialVariantId;
    _batchNumberCtrl = TextEditingController();
    _qtyCtrl = TextEditingController(text: '1.0');
    _costPriceCtrl = TextEditingController(text: '0.00');
  }

  @override
  void dispose() {
    _batchNumberCtrl.dispose;
    _qtyCtrl.dispose;
    _costPriceCtrl.dispose;
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isExpiry) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry ? now.add(const Duration(days: 180)) : now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _manufacturingDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVariantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product variant')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(batchesListProvider.notifier);
      await notifier.createBatch(
        productVariantId: _selectedVariantId!,
        batchNumber: _batchNumberCtrl.text.trim(),
        manufacturingDate: _manufacturingDate,
        expiryDate: _expiryDate,
        quantityReceived: double.tryParse(_qtyCtrl.text.trim()) ?? 1.0,
        costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory batch successfully recorded!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating batch: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(paginatedProductsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2, color: Colors.blueAccent, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Inward Stock Batch / Lot',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Variant selector
                  productsState.when(
                    data: (paginated) {
                      final variants = paginated.items.expand((p) => p.variants).toList();
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedVariantId,
                        decoration: const InputDecoration(
                          labelText: 'Product Variant *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        items: variants.map((v) {
                          return DropdownMenuItem<String>(
                            value: v.id,
                            child: Text(
                              '${v.name} (${v.barcode ?? 'No Barcode'})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedVariantId = val),
                        validator: (v) => v == null ? 'Please select a variant' : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Error loading products: $err', style: const TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _batchNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Batch / Lot Number *',
                      hintText: 'e.g. BATCH-2026-A1',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Batch number required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Quantity Received *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.add_shopping_cart),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            final val = double.tryParse(v ?? '');
                            if (val == null || val <= 0) return 'Enter quantity > 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _costPriceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Unit Cost (BDT)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _manufacturingDate == null
                                ? 'Mfg Date (Optional)'
                                : 'Mfg: ${_manufacturingDate!.toIso8601String().substring(0, 10)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => _selectDate(context, false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_busy, size: 18, color: Colors.orange),
                          label: Text(
                            _expiryDate == null
                                ? 'Expiry Date *'
                                : 'Exp: ${_expiryDate!.toIso8601String().substring(0, 10)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _expiryDate != null ? Colors.orange.shade800 : null,
                              fontWeight: _expiryDate != null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          onPressed: () => _selectDate(context, true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Save Batch'),
                        onPressed: _isSaving ? null : _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
