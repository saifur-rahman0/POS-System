import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../branches/presentation/controllers/branches_controller.dart';
import '../../../../catalog/presentation/controllers/catalog_providers.dart';
import '../../controllers/pricing_controller.dart';

class BranchOverrideDialog extends ConsumerStatefulWidget {
  const BranchOverrideDialog({super.key});

  @override
  ConsumerState<BranchOverrideDialog> createState() => _BranchOverrideDialogState();
}

class _BranchOverrideDialogState extends ConsumerState<BranchOverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  String? _selectedBranchId;
  String? _selectedVariantId;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _selectedBranchId == null ||
        _selectedVariantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both Branch and Variant')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text) ?? 0.0;
    final success = await ref.read(pricingControllerProvider.notifier).upsertBranchOverride({
      'branch_id': _selectedBranchId,
      'product_variant_id': _selectedVariantId,
      'selling_price': price,
      'is_active': true,
    });

    if (mounted && success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pricingControllerProvider);
    final branchesState = ref.watch(branchesListProvider);
    final productsAsync = ref.watch(paginatedProductsProvider);

    return AlertDialog(
      title: const Text('New Branch Price Override'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Target Branch *',
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedBranchId,
                items: branchesState.branches.map((b) {
                  return DropdownMenuItem(value: b.id, child: Text('${b.name} (${b.code})'));
                }).toList(),
                onChanged: (val) => setState(() => _selectedBranchId = val),
                validator: (val) => val == null ? 'Branch is required' : null,
              ),
              const SizedBox(height: 16),
              productsAsync.when(
                data: (paginated) {
                  final variants = paginated.items.expand((p) => p.variants).toList();
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Product Variant *',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedVariantId,
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
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Override Selling Price (৳) *',
                  hintText: 'e.g. 550.00',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  final n = double.tryParse(val ?? '');
                  if (n == null || n < 0) return 'Valid non-negative price required';
                  return null;
                },
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
              : const Text('Save Override'),
        ),
      ],
    );
  }
}
