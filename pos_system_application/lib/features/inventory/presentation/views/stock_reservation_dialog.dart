import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../catalog/presentation/controllers/catalog_providers.dart';
import '../controllers/advanced_inventory_controller.dart';

class StockReservationDialog extends ConsumerStatefulWidget {
  const StockReservationDialog({super.key});

  @override
  ConsumerState<StockReservationDialog> createState() => _StockReservationDialogState();
}

class _StockReservationDialogState extends ConsumerState<StockReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedVariantId;
  String _selectedRefType = 'QUOTATION';
  late TextEditingController _qtyCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _refIdCtrl;
  bool _isSaving = false;

  final List<String> _refTypes = ['QUOTATION', 'LAYAWAY', 'SALES_ORDER'];

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1.0');
    _durationCtrl = TextEditingController(text: '48');
    _refIdCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _durationCtrl.dispose();
    _refIdCtrl.dispose();
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
      final notifier = ref.read(stockReservationsListProvider.notifier);
      await notifier.createReservation(
        productVariantId: _selectedVariantId!,
        quantity: double.tryParse(_qtyCtrl.text.trim()) ?? 1.0,
        referenceType: _selectedRefType,
        referenceId: _refIdCtrl.text.trim().isNotEmpty
            ? _refIdCtrl.text.trim()
            : '00000000-0000-0000-0000-000000000001',
        durationHours: int.tryParse(_durationCtrl.text.trim()) ?? 24,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock allocation reserved!')),
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
                      const Icon(Icons.bookmark_added, color: Colors.teal, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Create Stock Reservation',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Hold Quantity *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin),
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
                          controller: _durationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Duration (Hours) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final val = int.tryParse(v ?? '');
                            if (val == null || val <= 0) return 'Enter hours > 0';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedRefType,
                    decoration: const InputDecoration(
                      labelText: 'Reference Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.assignment),
                    ),
                    items: _refTypes.map((t) {
                      return DropdownMenuItem<String>(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedRefType = val!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _refIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reference UUID (Optional)',
                      hintText: 'e.g. Quotation ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
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
                        style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.bookmark),
                        label: const Text('Reserve Stock'),
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
