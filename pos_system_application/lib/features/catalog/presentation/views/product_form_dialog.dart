import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/product.dart';
import '../controllers/catalog_providers.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final ProductModel? product;

  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _taxRateController;

  String? _categoryId;
  late bool _trackStock;
  late bool _isActive;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final primary = p?.primaryVariant;

    _skuController = TextEditingController(text: p?.sku ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _barcodeController = TextEditingController(text: primary?.barcode ?? '');
    _sellingPriceController = TextEditingController(
      text: primary != null ? primary.sellingPrice.toStringAsFixed(2) : '',
    );
    _costPriceController = TextEditingController(
      text: primary != null ? primary.costPrice.toStringAsFixed(2) : '0.00',
    );
    _taxRateController = TextEditingController(
      text: p != null ? p.taxRate.toStringAsFixed(2) : '0.00',
    );

    _categoryId = p?.categoryId;
    _trackStock = primary?.trackStock ?? true;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _barcodeController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final mutation = ref.read(productMutationProvider.notifier);
    final sellingPrice = double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
    final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
    final taxRate = double.tryParse(_taxRateController.text.trim()) ?? 0.0;

    try {
      if (widget.product == null) {
        await mutation.createProduct(
          sku: _skuController.text.trim(),
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          categoryId: _categoryId,
          taxRate: taxRate,
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          costPrice: costPrice,
          sellingPrice: sellingPrice,
          trackStock: _trackStock,
          isActive: _isActive,
        );
      } else {
        await mutation.updateProduct(
          id: widget.product!.id,
          sku: _skuController.text.trim(),
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          categoryId: _categoryId,
          taxRate: taxRate,
          isActive: _isActive,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final isEditing = widget.product != null;

    final categories = categoriesAsync.maybeWhen(
      data: (cats) => cats,
      orElse: () => [],
    );

    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error, size: 20, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Name & SKU Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          hintText: 'e.g. Wireless Mouse',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Product name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _skuController,
                        decoration: const InputDecoration(
                          labelText: 'SKU *',
                          hintText: 'e.g. WM-001',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'SKU is required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Category & Barcode Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _categoryId ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Uncategorized'),
                          ),
                          ...categories.map((cat) => DropdownMenuItem<String>(
                                value: cat.id,
                                child: Text(cat.name),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _categoryId = (val == null || val.isEmpty) ? null : val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Barcode / UPC',
                          hintText: 'e.g. 8901234567890',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code_scanner, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Pricing Row (Selling Price, Cost Price, Tax Rate)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Selling Price *',
                          hintText: '0.00',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Price is required';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Must be >= 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Cost Price *',
                          hintText: '0.00',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Cost is required';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Must be >= 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _taxRateController,
                        decoration: const InputDecoration(
                          labelText: 'Tax Rate (%)',
                          hintText: '0.00',
                          suffixText: '%',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final parsed = double.tryParse(value.trim());
                            if (parsed == null || parsed < 0) {
                              return 'Invalid tax';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Toggles Row
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Active Product'),
                        subtitle: const Text('Visible on POS registers'),
                        value: _isActive,
                        onChanged: (val) {
                          setState(() {
                            _isActive = val;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Track Stock'),
                        subtitle: const Text('Enable inventory count tracking'),
                        value: _trackStock,
                        onChanged: (val) {
                          setState(() {
                            _trackStock = val;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
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
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Save Changes' : 'Create Product'),
        ),
      ],
    );
  }
}
