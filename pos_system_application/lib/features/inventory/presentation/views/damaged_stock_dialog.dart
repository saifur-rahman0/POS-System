import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../catalog/presentation/controllers/catalog_providers.dart';
import '../controllers/advanced_inventory_controller.dart';

class DamagedStockDialog extends ConsumerStatefulWidget {
  const DamagedStockDialog({super.key});

  @override
  ConsumerState<DamagedStockDialog> createState() => _DamagedStockDialogState();
}

class _DamagedStockDialogState extends ConsumerState<DamagedStockDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedVariantId;
  String _selectedReason = 'EXPIRED';
  String _selectedDisposal = 'DESTROYED';
  late TextEditingController _qtyCtrl;
  late TextEditingController _notesCtrl;
  bool _isSaving = false;

  final List<String> _reasons = [
    'EXPIRED',
    'BROKEN',
    'TRANSIT_DAMAGE',
    'WATER_DAMAGE',
    'THEFT',
    'OTHER',
  ];

  final List<String> _disposals = [
    'DESTROYED',
    'RETURNED_TO_VENDOR',
    'SOLD_AT_DISCOUNT',
    'WRITTEN_OFF',
  ];

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1.0');
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
      final notifier = ref.read(damagedStockListProvider.notifier);
      await notifier.recordDamagedStock(
        productVariantId: _selectedVariantId!,
        quantity: double.tryParse(_qtyCtrl.text.trim()) ?? 1.0,
        reason: _selectedReason,
        disposalMethod: _selectedDisposal,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Damaged stock write-off recorded!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                      const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Damaged / Spoilage Write-off',
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
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity to Deduct *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.delete_outline),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final val = double.tryParse(v ?? '');
                      if (val == null || val <= 0) return 'Enter quantity > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedReason,
                          decoration: const InputDecoration(
                            labelText: 'Damage Reason *',
                            border: OutlineInputBorder(),
                          ),
                          items: _reasons.map((r) {
                            return DropdownMenuItem<String>(value: r, child: Text(r));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedReason = val!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedDisposal,
                          decoration: const InputDecoration(
                            labelText: 'Disposal Method *',
                            border: OutlineInputBorder(),
                          ),
                          items: _disposals.map((d) {
                            return DropdownMenuItem<String>(value: d, child: Text(d));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedDisposal = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Incident Description',
                      hintText: 'e.g. Broken in shipping carton during transit',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 2,
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
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('Post Write-Off'),
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
