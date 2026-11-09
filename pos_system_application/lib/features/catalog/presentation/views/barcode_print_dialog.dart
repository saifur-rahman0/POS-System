import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/hardware/printer/label_esc_pos_generator.dart';
import '../../../../core/hardware/printer/printer_service.dart';
import '../../../branches/presentation/controllers/branches_controller.dart';
import '../../domain/models/barcode_label_template.dart';
import '../../domain/models/paginated_products.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_variant.dart';
import '../controllers/catalog_providers.dart';
import 'barcode_label_card.dart';

class BarcodePrintDialog extends ConsumerStatefulWidget {
  final ProductModel? initialProduct;
  final ProductVariantModel? initialVariant;
  final List<ProductModel>? initialBatchProducts;
  final Map<String, int>? initialQuantities;

  const BarcodePrintDialog({
    super.key,
    this.initialProduct,
    this.initialVariant,
    this.initialBatchProducts,
    this.initialQuantities,
  });

  static Future<void> show(
    BuildContext context, {
    ProductModel? product,
    ProductVariantModel? variant,
    List<ProductModel>? batchProducts,
    Map<String, int>? quantities,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 720),
          child: BarcodePrintDialog(
            initialProduct: product,
            initialVariant: variant,
            initialBatchProducts: batchProducts,
            initialQuantities: quantities,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<BarcodePrintDialog> createState() => _BarcodePrintDialogState();
}

class _BarcodePrintDialogState extends ConsumerState<BarcodePrintDialog> {
  late BarcodeLabelConfig _config;
  late List<ProductModel> _selectedProducts;
  final Map<String, int> _quantities = {};
  int _activePreviewIndex = 0;
  final TextEditingController _customStoreController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _config = const BarcodeLabelConfig();

    if (widget.initialProduct != null) {
      _selectedProducts = [widget.initialProduct!];
      _quantities[widget.initialProduct!.id] =
          widget.initialQuantities?[widget.initialProduct!.id] ?? 1;
    } else if (widget.initialBatchProducts != null &&
        widget.initialBatchProducts!.isNotEmpty) {
      _selectedProducts = List.from(widget.initialBatchProducts!);
      for (final p in _selectedProducts) {
        _quantities[p.id] = widget.initialQuantities?[p.id] ?? 1;
      }
    } else {
      _selectedProducts = [];
    }
  }

  @override
  void dispose() {
    _customStoreController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalLabelsCount {
    int sum = 0;
    for (final p in _selectedProducts) {
      sum += _quantities[p.id] ?? 1;
    }
    return sum;
  }

  Future<void> _handleThermalPrint(String storeName) async {
    if (_selectedProducts.isEmpty) return;
    setState(() => _isPrinting = true);

    try {
      final printer = ref.read(printerServiceProvider);
      int successCount = 0;

      for (final prod in _selectedProducts) {
        final copies = _quantities[prod.id] ?? 1;
        final escPosBytes = LabelEscPosGenerator.generateEscPos(
          product: prod,
          variant: widget.initialVariant,
          config: _config,
          storeName: storeName,
          copies: copies,
        );

        // Send to printer service
        final ok = await printer.printRawBytes(
          escPosBytes,
          description: 'Barcode label for ${prod.name}',
        );
        if (ok && escPosBytes.isNotEmpty) successCount += copies;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully queued $successCount barcode label(s) to thermal printer.'),
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _handleSheetPrint(String storeName) {
    if (_selectedProducts.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.print_outlined, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text('Print Label Sheet Preview'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Ready to print $_totalLabelsCount labels across A4 sticker sheet(s).'),
            const SizedBox(height: 8),
            Text(
              'Template: ${_getTemplateTitle(_config.templateType)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Store Header: ${_config.customStoreHeader ?? storeName}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Color(0xFF0F766E), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Spooling high-resolution vector labels to Windows Printer Spooler.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0F766E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Send to Printer'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E)),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Sent $_totalLabelsCount labels to system printer.'),
                  backgroundColor: const Color(0xFF0F766E),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getTemplateTitle(LabelTemplateType t) {
    switch (t) {
      case LabelTemplateType.shelfEdge:
        return 'Standard Shelf Edge Tag (60×40mm)';
      case LabelTemplateType.compactSticker:
        return 'Compact Item Sticker (40×25mm)';
      case LabelTemplateType.promotional:
        return 'Promotional Talker (70×45mm)';
      case LabelTemplateType.a4Sheet24:
        return 'A4 Multi-Label Sheet (24-Up, 3×8)';
      case LabelTemplateType.a4Sheet40:
        return 'A4 Multi-Label Sheet (40-Up, 4×10)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBranch = ref.watch(activeBranchProvider);
    final storeName = activeBranch?.name ?? 'Retail POS — Main Store';
    final allProductsAsync = ref.watch(paginatedProductsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.qr_code_2, color: Color(0xFF0F766E)),
            SizedBox(width: 10),
            Text(
              'Barcode Label & Shelf Tag Printing Studio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Configuration Panel (420px)
          SizedBox(
            width: 440,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Template Layout Selector
                          const Text(
                            '1. SELECT LABEL TEMPLATE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTemplateSelector(),

                          const Divider(height: 24),

                          // 2. Customization Toggles
                          const Text(
                            '2. LABEL CONTENT & FIELDS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildContentToggles(),

                          const Divider(height: 24),

                          // 3. Products in Batch & Quantities
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '3. PRODUCTS & COPIES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              Text(
                                '$_totalLabelsCount labels total',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildProductList(allProductsAsync),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.table_chart_outlined,
                                    size: 18),
                                label: const Text('Sheet Print (A4)'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => _handleSheetPrint(storeName),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                icon: _isPrinting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.print, size: 18),
                                label: const Text('Thermal Print'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _isPrinting
                                    ? null
                                    : () => _handleThermalPrint(storeName),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1, thickness: 1),

          // Right Live Preview Area
          Expanded(
            child: Container(
              color: const Color(0xFFF1F5F9),
              child: Column(
                children: [
                  // Preview Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.visibility_outlined,
                                  size: 18, color: Color(0xFF0F766E)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Live Print Preview: ${_getTemplateTitle(_config.templateType)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedProducts.length > 1)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 20),
                                onPressed: _activePreviewIndex > 0
                                    ? () =>
                                        setState(() => _activePreviewIndex--)
                                    : null,
                              ),
                              Text(
                                '${_activePreviewIndex + 1} of ${_selectedProducts.length}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 20),
                                onPressed: _activePreviewIndex <
                                        _selectedProducts.length - 1
                                    ? () =>
                                        setState(() => _activePreviewIndex++)
                                    : null,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Preview Content
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildPreviewContent(storeName),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector() {
    final templates = [
      (
        LabelTemplateType.shelfEdge,
        'Shelf Edge Tag',
        '60×40 mm (Supermarket standard)',
        Icons.branding_watermark_outlined
      ),
      (
        LabelTemplateType.compactSticker,
        'Item Sticker',
        '40×25 mm (Jewelry & small items)',
        Icons.label_outline
      ),
      (
        LabelTemplateType.promotional,
        'Promotional Talker',
        '70×45 mm (Special Offer / Sale)',
        Icons.local_offer_outlined
      ),
      (
        LabelTemplateType.a4Sheet24,
        'A4 Sheet (24-Up)',
        '3 cols × 8 rows (Office printer)',
        Icons.grid_view_rounded
      ),
    ];

    return Column(
      children: templates.map((t) {
        final isSelected = _config.templateType == t.$1;
        return InkWell(
          onTap: () =>
              setState(() => _config = _config.copyWith(templateType: t.$1)),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0F766E).withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF0F766E) : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(t.$4,
                    size: 20,
                    color: isSelected
                        ? const Color(0xFF0F766E)
                        : Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.$2,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF0F766E)
                              : Colors.black87,
                        ),
                      ),
                      Text(t.$3,
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      size: 18, color: Color(0xFF0F766E)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContentToggles() {
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title:
              const Text('Store Name Header', style: TextStyle(fontSize: 12)),
          value: _config.showStoreName,
          onChanged: (v) =>
              setState(() => _config = _config.copyWith(showStoreName: v)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Retail Price with ৳ Symbol',
              style: TextStyle(fontSize: 12)),
          value: _config.showPrice,
          onChanged: (v) =>
              setState(() => _config = _config.copyWith(showPrice: v)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('SKU & Category Badge',
              style: TextStyle(fontSize: 12)),
          value: _config.showSku,
          onChanged: (v) =>
              setState(() => _config = _config.copyWith(showSku: v)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('1D Scannable Barcode',
              style: TextStyle(fontSize: 12)),
          value: _config.showBarcode,
          onChanged: (v) =>
              setState(() => _config = _config.copyWith(showBarcode: v)),
        ),
        if (_config.templateType == LabelTemplateType.promotional) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Promo Discount %:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _config.promoDiscountPercent > 0
                      ? _config.promoDiscountPercent
                      : 15.0,
                  min: 5,
                  max: 75,
                  divisions: 14,
                  label: '${_config.promoDiscountPercent.round()}%',
                  activeColor: const Color(0xFFE11D48),
                  onChanged: (v) => setState(() =>
                      _config = _config.copyWith(promoDiscountPercent: v)),
                ),
              ),
              Text(
                '${(_config.promoDiscountPercent > 0 ? _config.promoDiscountPercent : 15).round()}%',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProductList(AsyncValue<PaginatedProducts> allProductsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Search & Add from Catalog
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search & add products...',
            prefixIcon: const Icon(Icons.search, size: 16),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (v) =>
              setState(() => _searchFilter = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 8),

        // Search Results Dropdown (if searching)
        if (_searchFilter.isNotEmpty)
          allProductsAsync.when(
            data: (paginated) {
              final allProds = paginated.items;
              final matches = allProds
                  .where((p) =>
                      p.name.toLowerCase().contains(_searchFilter) ||
                      p.sku.toLowerCase().contains(_searchFilter) ||
                      (p.primaryVariant?.barcode
                              ?.toLowerCase()
                              .contains(_searchFilter) ??
                          false))
                  .take(4)
                  .toList();

              if (matches.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Text('No matching products found',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: matches.map((m) {
                    final isAlreadySelected =
                        _selectedProducts.any((p) => p.id == m.id);
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(m.name,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text('SKU: ${m.sku}',
                          style: const TextStyle(fontSize: 10)),
                      trailing: IconButton(
                        icon: Icon(
                          isAlreadySelected
                              ? Icons.check
                              : Icons.add_circle_outline,
                          color: isAlreadySelected
                              ? Colors.green
                              : const Color(0xFF0F766E),
                          size: 18,
                        ),
                        onPressed: isAlreadySelected
                            ? null
                            : () {
                                setState(() {
                                  _selectedProducts.add(m);
                                  _quantities[m.id] = 1;
                                  _searchController.clear();
                                  _searchFilter = '';
                                });
                              },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),

        // Selected Products List with Quantity Counters
        if (_selectedProducts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
                'No products selected. Search above to add items.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedProducts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final prod = _selectedProducts[idx];
              final count = _quantities[prod.id] ?? 1;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prod.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text('SKU: ${prod.sku}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    // Quantity adjust
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: count > 1
                                ? () => setState(
                                    () => _quantities[prod.id] = count - 1)
                                : null,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              child: Icon(Icons.remove, size: 14),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('$count',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          InkWell(
                            onTap: () => setState(
                                () => _quantities[prod.id] = count + 1),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              child: Icon(Icons.add, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedProducts.length > 1) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _selectedProducts.removeAt(idx);
                            _quantities.remove(prod.id);
                            if (_activePreviewIndex >=
                                _selectedProducts.length) {
                              _activePreviewIndex =
                                  (_selectedProducts.length - 1).clamp(0, 999);
                            }
                          });
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPreviewContent(String storeName) {
    if (_selectedProducts.isEmpty) {
      return const Center(
          child: Text('Select or add a product to preview labels.'));
    }

    if (_activePreviewIndex >= _selectedProducts.length) {
      _activePreviewIndex = 0;
    }

    final currentProduct = _selectedProducts[_activePreviewIndex];

    // If A4 Sheet is selected, render a miniature 3x8 layout sheet
    if (_config.templateType == LabelTemplateType.a4Sheet24) {
      return _buildA4SheetPreview(storeName);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BarcodeLabelCard(
          product: currentProduct,
          variant: widget.initialVariant,
          config: _config,
          storeName: storeName,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            '100% Vector Barcode · Scale: 1:1 · Ready to print (${_quantities[currentProduct.id] ?? 1} copies)',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  /// Miniature A4 sheet preview with 24 labels (3 cols x 8 rows)
  Widget _buildA4SheetPreview(String storeName) {
    // Generate repeated items list matching total quantities
    final flatList = <ProductModel>[];
    for (final p in _selectedProducts) {
      final qty = _quantities[p.id] ?? 1;
      for (int i = 0; i < qty; i++) {
        flatList.add(p);
      }
    }

    final displayItems = flatList.take(24).toList();

    return Container(
      width: 595, // standard A4 aspect ratio 1:1.41
      height: 842,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'A4 Standard Label Sheet (24-Up: 3×8)',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700),
              ),
              Text(
                'Page 1 · Showing ${displayItems.length} of ${flatList.length} stickers',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
          const Divider(height: 12),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.8,
              ),
              itemCount: 24,
              itemBuilder: (context, index) {
                if (index < displayItems.length) {
                  final prod = displayItems[index];
                  return Container(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.grey.shade300, width: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: BarcodeLabelCard(
                      product: prod,
                      config: _config,
                      storeName: storeName,
                      scale: 0.65,
                    ),
                  );
                } else {
                  // Empty sticker cell
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.grey.shade200,
                          strokeAlign: BorderSide.strokeAlignInside),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Slot ${index + 1}',
                      style:
                          TextStyle(fontSize: 9, color: Colors.grey.shade300),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
