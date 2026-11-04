import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/branches/domain/models/branch.dart';
import 'package:pos_client/features/catalog/presentation/controllers/catalog_providers.dart';
import '../controllers/transfers_controller.dart';

class CreateTransferDialog extends ConsumerStatefulWidget {
  final List<BranchModel> branches;
  final String? initialSourceBranchId;

  const CreateTransferDialog({
    super.key,
    required this.branches,
    this.initialSourceBranchId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<BranchModel> branches,
    String? initialSourceBranchId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateTransferDialog(
        branches: branches,
        initialSourceBranchId: initialSourceBranchId,
      ),
    );
  }

  @override
  ConsumerState<CreateTransferDialog> createState() =>
      _CreateTransferDialogState();
}

class _CreateTransferDialogState extends ConsumerState<CreateTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _sourceBranchId;
  String? _destinationBranchId;
  String? _selectedVariantId;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final activeBranches = widget.branches.where((b) => b.isActive).toList();
    if (activeBranches.isNotEmpty) {
      _sourceBranchId = widget.initialSourceBranchId ?? activeBranches.first.id;
      final other = activeBranches.where((b) => b.id != _sourceBranchId).toList();
      if (other.isNotEmpty) {
        _destinationBranchId = other.first.id;
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceBranchId == null || _destinationBranchId == null) {
      setState(() => _errorMessage = 'Please select source and destination branches');
      return;
    }
    if (_sourceBranchId == _destinationBranchId) {
      setState(() => _errorMessage = 'Destination branch must differ from source');
      return;
    }
    if (_selectedVariantId == null) {
      setState(() => _errorMessage = 'Please select a product variant to transfer');
      return;
    }

    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      setState(() => _errorMessage = 'Transfer quantity must be greater than zero');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final notifier = ref.read(transfersListProvider.notifier);
    final success = await notifier.createTransfer(
      sourceBranchId: _sourceBranchId!,
      destinationBranchId: _destinationBranchId!,
      items: [
        {
          'product_variant_id': _selectedVariantId,
          'quantity': qty,
        }
      ],
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = ref.read(transfersListProvider).errorMessage ??
            'Failed to create transfer order.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(paginatedProductsProvider);
    final products = productsAsync.valueOrNull?.items ?? [];
    final activeBranches = widget.branches.where((b) => b.isActive).toList();

    // Flatten all variants from loaded products
    final allVariants = <Map<String, String>>[];
    for (final prod in products) {
      for (final v in prod.variants) {
        if (v.trackStock) {
          allVariants.add({
            'id': v.id,
            'label': '${prod.name} — ${v.name} (SKU: ${prod.sku})',
          });
        }
      }
    }

    if (_selectedVariantId == null && allVariants.isNotEmpty) {
      _selectedVariantId = allVariants.first['id'];
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create Stock Transfer',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _sourceBranchId,
                        decoration: const InputDecoration(
                          labelText: 'Source Store *',
                          border: OutlineInputBorder(),
                        ),
                        items: activeBranches
                            .map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _sourceBranchId = val),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward, color: Colors.grey),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _destinationBranchId,
                        decoration: const InputDecoration(
                          labelText: 'Destination Store *',
                          border: OutlineInputBorder(),
                        ),
                        items: activeBranches
                            .map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _destinationBranchId = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (allVariants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Loading trackable catalog variants...'),
                  )
                else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedVariantId,
                    decoration: const InputDecoration(
                      labelText: 'Product Variant *',
                      border: OutlineInputBorder(),
                    ),
                    items: allVariants
                        .map((v) => DropdownMenuItem(
                              value: v['id']!,
                              child: Text(v['label']!,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedVariantId = val),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Transfer Quantity *',
                    hintText: 'e.g. 10',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter quantity';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Transfer Notes / Reference',
                    hintText: 'e.g. Weekly restock request from downtown shop',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Draft Order'),
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
