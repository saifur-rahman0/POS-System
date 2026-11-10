import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';
import '../../domain/services/catalog_code_generator.dart';
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

  // Automatic SKU & Barcode Generation state
  late bool _autoGenerateCodes;
  bool _isSkuCustom = false;
  bool _isBarcodeCustom = false;
  bool _showRuleOptions = false;
  SkuRuleType _skuRule = SkuRuleType.categoryInitialsNumber;
  BarcodeRuleType _barcodeRule = BarcodeRuleType.ean13InStore;

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

    // Default auto-generation to ON for new items, OFF for existing edits
    _autoGenerateCodes = widget.product == null;
    _isSkuCustom = widget.product != null && (p?.sku.isNotEmpty ?? false);
    _isBarcodeCustom =
        widget.product != null && (primary?.barcode?.isNotEmpty ?? false);
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

  void _onNameChanged(String val, List<CategoryModel> categories) {
    if (!_autoGenerateCodes) return;

    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      if (!_isSkuCustom) _skuController.text = '';
      if (!_isBarcodeCustom) _barcodeController.text = '';
      setState(() {});
      return;
    }

    final cat = categories.where((c) => c.id == _categoryId).firstOrNull;

    if (!_isSkuCustom) {
      _skuController.text = CatalogCodeGenerator.generateSku(
        productName: trimmed,
        category: cat,
        rule: _skuRule,
      );
    }

    if (!_isBarcodeCustom && _barcodeController.text.trim().isEmpty) {
      _barcodeController.text = CatalogCodeGenerator.generateBarcode(
        rule: _barcodeRule,
        sku: _skuController.text,
      );
    }

    setState(() {});
  }

  void _onCategoryChanged(String? val, List<CategoryModel> categories) {
    setState(() {
      _categoryId = (val == null || val.isEmpty) ? null : val;
    });

    if (_autoGenerateCodes &&
        !_isSkuCustom &&
        _nameController.text.trim().isNotEmpty) {
      final cat = categories.where((c) => c.id == _categoryId).firstOrNull;
      setState(() {
        _skuController.text = CatalogCodeGenerator.generateSku(
          productName: _nameController.text.trim(),
          category: cat,
          rule: _skuRule,
        );
      });
    }
  }

  void _manualRegenerateSku(List<CategoryModel> categories) {
    final cat = categories.where((c) => c.id == _categoryId).firstOrNull;
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Item';
    setState(() {
      _skuController.text = CatalogCodeGenerator.generateSku(
        productName: name,
        category: cat,
        rule: _skuRule,
      );
      _isSkuCustom = false;
    });
  }

  void _manualRegenerateBarcode() {
    setState(() {
      _barcodeController.text = CatalogCodeGenerator.generateBarcode(
        rule: _barcodeRule,
        sku: _skuController.text,
      );
      _isBarcodeCustom = false;
    });
  }

  void _regenerateBoth(List<CategoryModel> categories) {
    final cat = categories.where((c) => c.id == _categoryId).firstOrNull;
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Item';
    setState(() {
      _skuController.text = CatalogCodeGenerator.generateSku(
        productName: name,
        category: cat,
        rule: _skuRule,
      );
      _isSkuCustom = false;

      _barcodeController.text = CatalogCodeGenerator.generateBarcode(
        rule: _barcodeRule,
        sku: _skuController.text,
      );
      _isBarcodeCustom = false;
    });
  }

  String _getSkuRuleLabel(SkuRuleType r) {
    switch (r) {
      case SkuRuleType.categoryInitialsNumber:
        return 'Category + Initials + Number (e.g. BEV-MC250-101)';
      case SkuRuleType.categorySlugNumber:
        return 'Category + Slug + Number (e.g. BEV-MOJO-COLA-101)';
      case SkuRuleType.prefixNumber:
        return 'Standard Prefix + Number (e.g. SKU-104921)';
    }
  }

  String _getBarcodeRuleLabel(BarcodeRuleType r) {
    switch (r) {
      case BarcodeRuleType.ean13InStore:
        return 'GS1 EAN-13 (In-Store prefix 200 + Checksum)';
      case BarcodeRuleType.code128Numeric:
        return 'Code 128 / UPC (12-Digit Numeric)';
      case BarcodeRuleType.skuMatch:
        return 'Code 128 (Match SKU String)';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final mutation = ref.read(productMutationProvider.notifier);
    final sellingPrice =
        double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
    final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
    final taxRate = double.tryParse(_taxRateController.text.trim()) ?? 0.0;

    try {
      if (widget.product == null) {
        await mutation.createProduct(
          sku: _skuController.text.trim(),
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          categoryId: _categoryId,
          taxRate: taxRate,
          barcode: _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim(),
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
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          categoryId: _categoryId,
          taxRate: taxRate,
          isActive: _isActive,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
          barcode: _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim(),
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
      orElse: () => <CategoryModel>[],
    );

    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
      content: SizedBox(
        width: 620,
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
                            style: TextStyle(
                                color: Colors.red.shade900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Auto-Generation Rule Card
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _autoGenerateCodes
                        ? const Color(0xFF0F766E).withValues(alpha: 0.06)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _autoGenerateCodes
                          ? const Color(0xFF0F766E).withValues(alpha: 0.25)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: _autoGenerateCodes
                                ? const Color(0xFF0F766E)
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-Generate SKU & Barcode',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: _autoGenerateCodes
                                        ? const Color(0xFF0F766E)
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  _autoGenerateCodes
                                      ? 'Smart rules based on Name & Category'
                                      : 'Auto-generation disabled (Manual entry mode)',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          if (_autoGenerateCodes)
                            TextButton.icon(
                              icon: const Icon(Icons.refresh, size: 15),
                              label: const Text('Generate Both',
                                  style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF0F766E),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _regenerateBoth(categories),
                            ),
                          IconButton(
                            icon: Icon(
                              _showRuleOptions ? Icons.expand_less : Icons.tune,
                              size: 18,
                              color: const Color(0xFF0F766E),
                            ),
                            tooltip: 'Configure Rules',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(
                                () => _showRuleOptions = !_showRuleOptions),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: _autoGenerateCodes,
                              onChanged: (val) {
                                setState(() {
                                  _autoGenerateCodes = val;
                                  if (val &&
                                      _nameController.text.trim().isNotEmpty) {
                                    _regenerateBoth(categories);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_showRuleOptions) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            // SKU Rule Dropdown
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('SKU Generation Rule',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<SkuRuleType>(
                                    initialValue: _skuRule,
                                    isExpanded: true,
                                    isDense: true,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                    items: SkuRuleType.values.map((r) {
                                      return DropdownMenuItem(
                                        value: r,
                                        child: Text(_getSkuRuleLabel(r),
                                            style: const TextStyle(
                                                fontSize: 11.5)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _skuRule = val);
                                        if (_autoGenerateCodes) {
                                          _manualRegenerateSku(categories);
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Barcode Rule Dropdown
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Barcode Rule',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<BarcodeRuleType>(
                                    initialValue: _barcodeRule,
                                    isExpanded: true,
                                    isDense: true,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                    items: BarcodeRuleType.values.map((r) {
                                      return DropdownMenuItem(
                                        value: r,
                                        child: Text(_getBarcodeRuleLabel(r),
                                            style: const TextStyle(
                                                fontSize: 11.5)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _barcodeRule = val);
                                        if (_autoGenerateCodes) {
                                          _manualRegenerateBarcode();
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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
                        onChanged: (val) => _onNameChanged(val, categories),
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
                        decoration: InputDecoration(
                          labelText: 'SKU *',
                          hintText: 'e.g. WM-001',
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSkuCustom)
                                Container(
                                  margin: const EdgeInsets.only(right: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('CUSTOM',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.brown)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.auto_fix_high, size: 18),
                                tooltip: 'Regenerate SKU using rule',
                                onPressed: () =>
                                    _manualRegenerateSku(categories),
                              ),
                            ],
                          ),
                        ),
                        onChanged: (val) {
                          if (!_isSkuCustom) {
                            setState(() => _isSkuCustom = true);
                          }
                        },
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        onChanged: (val) => _onCategoryChanged(val, categories),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _barcodeController,
                            decoration: InputDecoration(
                              labelText: 'Barcode / UPC',
                              hintText: 'e.g. 2001948201842',
                              border: const OutlineInputBorder(),
                              prefixIcon:
                                  const Icon(Icons.qr_code_scanner, size: 20),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isBarcodeCustom)
                                    Container(
                                      margin: const EdgeInsets.only(right: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('CUSTOM',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.brown)),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh, size: 18),
                                    tooltip: 'Regenerate Barcode using rule',
                                    onPressed: _manualRegenerateBarcode,
                                  ),
                                ],
                              ),
                            ),
                            onChanged: (val) {
                              if (!_isBarcodeCustom) {
                                setState(() => _isBarcodeCustom = true);
                              } else {
                                setState(() {});
                              }
                            },
                          ),
                          if (_barcodeController.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  CatalogCodeGenerator.isValidEan13(
                                          _barcodeController.text.trim())
                                      ? Icons.check_circle_outline
                                      : Icons.tag,
                                  size: 13,
                                  color: CatalogCodeGenerator.isValidEan13(
                                          _barcodeController.text.trim())
                                      ? Colors.green.shade700
                                      : const Color(0xFF0F766E),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  CatalogCodeGenerator.isValidEan13(
                                          _barcodeController.text.trim())
                                      ? 'Valid GS1 EAN-13 Checksum'
                                      : 'Scannable Code 128 / Barcode',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: CatalogCodeGenerator.isValidEan13(
                                            _barcodeController.text.trim())
                                        ? Colors.green.shade700
                                        : const Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
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
                          prefixText: '৳ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
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
                          prefixText: '৳ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
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
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Save Changes' : 'Create Product'),
        ),
      ],
    );
  }
}
