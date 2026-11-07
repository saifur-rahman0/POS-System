import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../catalog/presentation/controllers/catalog_providers.dart';
import '../../controllers/pricing_controller.dart';

class ProductBundleDialog extends ConsumerStatefulWidget {
  const ProductBundleDialog({super.key});

  @override
  ConsumerState<ProductBundleDialog> createState() => _ProductBundleDialogState();
}

class _ProductBundleDialogState extends ConsumerState<ProductBundleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedProductId;
  bool _isKit = false;

  final List<Map<String, dynamic>> _components = [];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addComponent(String variantId, String variantName, double qty) {
    setState(() {
      _components.add({
        'component_variant_id': variantId,
        'component_name': variantName,
        'quantity': qty,
        'is_optional': false,
      });
    });
  }

  void _removeComponent(int index) {
    setState(() {
      _components.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a parent product')),
      );
      return;
    }

    if (_components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one component to the bundle')),
      );
      return;
    }

    final price = _priceController.text.trim().isEmpty
        ? null
        : double.tryParse(_priceController.text);

    final success = await ref.read(pricingControllerProvider.notifier).createBundle({
      'product_id': _selectedProductId,
      'name': _nameController.text.trim(),
      if (price != null) 'bundle_price': price,
      'is_kit': _isKit,
      'is_active': true,
      'items': _components
          .map((c) => {
                'component_variant_id': c['component_variant_id'],
                'quantity': c['quantity'],
                'is_optional': c['is_optional'],
              })
          .toList(),
    });

    if (mounted && success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pricingControllerProvider);
    final productsAsync = ref.watch(paginatedProductsProvider);

    return AlertDialog(
      title: const Text('Create Product Bundle / Kit'),
      content: SizedBox(
        width: 600,
        height: 520,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              productsAsync.when(
                data: (paginated) => DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Parent Bundle Product *',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _selectedProductId,
                  items: paginated.items.map((p) {
                    return DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.sku})'));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProductId = val;
                      final p = paginated.items.where((i) => i.id == val).firstOrNull;
                      if (p != null && _nameController.text.isEmpty) {
                        _nameController.text = '${p.name} Bundle';
                      }
                    });
                  },
                  validator: (val) => val == null ? 'Parent product required' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Error loading products: $err'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Bundle Display Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Fixed Price (Optional)',
                        hintText: 'Sum if empty',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Is Customizable Kit (Customer picks options)'),
                value: _isKit,
                onChanged: (val) => setState(() => _isKit = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bundle Components', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Component'),
                    onPressed: () => _showAddComponentDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _components.isEmpty
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No components added yet. Click "+ Add Component" above.'),
                      )
                    : ListView.builder(
                        itemCount: _components.length,
                        itemBuilder: (context, idx) {
                          final c = _components[idx];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              title: Text(c['component_name'] as String),
                              subtitle: Text('Qty: ${c['quantity']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                onPressed: () => _removeComponent(idx),
                              ),
                            ),
                          );
                        },
                      ),
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
              : const Text('Create Bundle'),
        ),
      ],
    );
  }

  void _showAddComponentDialog() {
    String? selectedVariantId;
    String? selectedVariantName;
    final qtyController = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final productsAsync = ref.watch(paginatedProductsProvider);
          return AlertDialog(
            title: const Text('Select Component Variant'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  productsAsync.when(
                    data: (paginated) {
                      final variants = paginated.items.expand((p) => p.variants).toList();
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Component *',
                          border: OutlineInputBorder(),
                        ),
                        items: variants.map((v) {
                          return DropdownMenuItem(value: v.id, child: Text(v.name));
                        }).toList(),
                        onChanged: (val) {
                          selectedVariantId = val;
                          selectedVariantName = variants.firstWhere((v) => v.id == val).name;
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Error: $err'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Required Quantity *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (selectedVariantId != null && selectedVariantName != null) {
                    final qty = double.tryParse(qtyController.text) ?? 1.0;
                    _addComponent(selectedVariantId!, selectedVariantName!, qty);
                    Navigator.of(ctx).pop();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}
