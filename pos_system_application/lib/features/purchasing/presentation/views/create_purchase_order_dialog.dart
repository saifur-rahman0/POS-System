import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../catalog/domain/models/product.dart';
import '../../../catalog/presentation/controllers/catalog_providers.dart';
import '../../domain/models/purchase_order.dart';
import '../controllers/purchasing_controller.dart';
import 'supplier_form_dialog.dart';

class _PoLineItemDraft {
  final ProductModel product;
  double quantity;
  double unitCost;

  _PoLineItemDraft({
    required this.product,
    required this.quantity,
    required this.unitCost,
  });

  double get subtotal => quantity * unitCost;
}

class CreatePurchaseOrderDialog extends ConsumerStatefulWidget {
  const CreatePurchaseOrderDialog({super.key});

  static Future<PurchaseOrderModel?> show(BuildContext context) {
    return showDialog<PurchaseOrderModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreatePurchaseOrderDialog(),
    );
  }

  @override
  ConsumerState<CreatePurchaseOrderDialog> createState() =>
      _CreatePurchaseOrderDialogState();
}

class _CreatePurchaseOrderDialogState
    extends ConsumerState<CreatePurchaseOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _discountController =
      TextEditingController(text: '0.00');

  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

  String? _selectedSupplierId;
  final List<_PoLineItemDraft> _lineItems = [];
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _refController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0.0;

  double get _grossSubtotal =>
      _lineItems.fold(0.0, (sum, item) => sum + item.subtotal);

  double get _netTotal => (_grossSubtotal - _discount).clamp(0.0, double.infinity);

  void _addItem(ProductModel product) {
    final variant = product.primaryVariant;
    final defaultCost = variant?.costPrice ?? 0.0;

    // Check if already in items list
    final existingIndex =
        _lineItems.indexWhere((item) => item.product.id == product.id);

    setState(() {
      if (existingIndex >= 0) {
        _lineItems[existingIndex].quantity += 1;
      } else {
        _lineItems.add(_PoLineItemDraft(
          product: product,
          quantity: 1,
          unitCost: defaultCost,
        ));
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_selectedSupplierId == null) {
      setState(() => _errorMessage = 'Please select a supplier');
      return;
    }

    if (_lineItems.isEmpty) {
      setState(() => _errorMessage = 'Please add at least one line item to the order');
      return;
    }

    for (final item in _lineItems) {
      if (item.quantity <= 0) {
        setState(() => _errorMessage =
            'Quantity for "${item.product.name}" must be greater than zero');
        return;
      }
      if (item.unitCost < 0) {
        setState(() => _errorMessage =
            'Unit cost for "${item.product.name}" cannot be negative');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final payloadItems = _lineItems.map((item) {
      final variantId = item.product.primaryVariant?.id;
      return {
        'product_variant_id': variantId,
        'quantity': item.quantity.toStringAsFixed(4),
        'unit_cost': item.unitCost.toStringAsFixed(4),
      };
    }).toList();

    try {
      final po =
          await ref.read(purchasesControllerProvider.notifier).createPurchaseOrder(
                supplierId: _selectedSupplierId!,
                items: payloadItems,
                discount: _discount,
                referenceNo: _refController.text.trim().isNotEmpty
                    ? _refController.text.trim()
                    : null,
                notes: _notesController.text.trim().isNotEmpty
                    ? _notesController.text.trim()
                    : null,
              );

      if (mounted) {
        Navigator.of(context).pop(po);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersState = ref.watch(suppliersControllerProvider);
    final suppliers = suppliersState.paginated?.items ?? [];

    final productsAsync = ref.watch(paginatedProductsProvider);
    final products = productsAsync.maybeWhen(
      data: (p) => p.items,
      orElse: () => <ProductModel>[],
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.add_shopping_cart, color: Color(0xFF0F766E), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Create Purchase Order',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Top Form: Supplier & Reference
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier Dropdown
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Supplier *',
                          prefixIcon: const Icon(Icons.store),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            tooltip: 'Add New Supplier',
                            onPressed: () async {
                              final newSup = await SupplierFormDialog.show(context);
                              if (newSup != null) {
                                setState(() {
                                  _selectedSupplierId = newSup.id;
                                });
                              }
                            },
                          ),
                        ),
                        initialValue: _selectedSupplierId,
                        items: suppliers.map((s) {
                          return DropdownMenuItem<String>(
                            value: s.id,
                            child: Text('${s.name} ${s.phone != null ? "(${s.phone})" : ""}'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedSupplierId = val),
                        validator: (v) => v == null ? 'Supplier required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // External Reference / Bill No
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(
                          labelText: 'Vendor Bill # (Optional)',
                          hintText: 'e.g. INV-9812',
                          prefixIcon: Icon(Icons.tag),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Item Selector Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Add Catalog Product:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            hintText: 'Select product to add into PO...',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: products.map((p) {
                            return DropdownMenuItem<String>(
                              value: p.id,
                              child: Text('${p.name} [SKU: ${p.sku}]'),
                            );
                          }).toList(),
                          onChanged: (prodId) {
                            if (prodId == null) return;
                            final prod = products.firstWhere((p) => p.id == prodId);
                            _addItem(prod);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Line Items Table
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _lineItems.isEmpty
                        ? const Center(
                            child: Text(
                              'No items added yet. Select a product above to add to this purchase order.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: _lineItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final item = _lineItems[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            'SKU: ${item.product.sku}',
                                            style: TextStyle(
                                                fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Qty
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        initialValue: item.quantity.toStringAsFixed(0),
                                        decoration: const InputDecoration(
                                          labelText: 'Qty',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          final parsed = double.tryParse(val) ?? 0.0;
                                          setState(() => item.quantity = parsed);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Unit Cost
                                    SizedBox(
                                      width: 120,
                                      child: TextFormField(
                                        initialValue: item.unitCost.toStringAsFixed(2),
                                        decoration: const InputDecoration(
                                          labelText: 'Unit Cost (৳)',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (val) {
                                          final parsed = double.tryParse(val) ?? 0.0;
                                          setState(() => item.unitCost = parsed);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Subtotal
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        currencyFmt.format(item.subtotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F766E),
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      onPressed: () => _removeItem(idx),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom row: Notes, Discount, Summary & Buttons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Notes field
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes / Receiving Instructions',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Discount & Calculation Box
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:'),
                                Text(currencyFmt.format(_grossSubtotal),
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Discount (৳):'),
                                SizedBox(
                                  width: 80,
                                  height: 32,
                                  child: TextFormField(
                                    controller: _discountController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Net Total:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  currencyFmt.format(_netTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Submit Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Create Purchase Order'),
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
