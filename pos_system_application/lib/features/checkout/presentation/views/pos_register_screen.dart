import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/hardware/scanner/barcode_scanner_listener.dart';
import '../../../catalog/domain/models/product.dart';
import '../../../catalog/presentation/controllers/catalog_providers.dart';
import '../../../customers/presentation/views/customer_selection_dialog.dart';
import '../../../shifts/presentation/controllers/shift_controller.dart';
import '../../../shifts/presentation/widgets/shift_status_bar.dart';
import '../controllers/cart_controller.dart';
import 'payment_dialog.dart';
import '../controllers/held_carts_controller.dart';
import 'delivery_charge_dialog.dart';
import 'held_carts_dialog.dart';
import 'line_discount_dialog.dart';
import 'save_quotation_dialog.dart';

final posCatalogSearchProvider = StateProvider<String>((ref) => '');
final posSelectedCategoryProvider = StateProvider<String?>((ref) => null);

final posProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final apiService = ref.watch(catalogApiServiceProvider);
  final search = ref.watch(posCatalogSearchProvider);
  final categoryId = ref.watch(posSelectedCategoryProvider);

  final res = await apiService.getProducts(
    search: search.isNotEmpty ? search : null,
    categoryId: categoryId,
    isActive: true,
    page: 1,
    limit: 100,
  );
  return res.items;
});

class PosRegisterScreen extends ConsumerStatefulWidget {
  const PosRegisterScreen({super.key});

  @override
  ConsumerState<PosRegisterScreen> createState() => _PosRegisterScreenState();
}

class _PosRegisterScreenState extends ConsumerState<PosRegisterScreen> {
  final TextEditingController _barcodeSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(heldCartsProvider.notifier).loadHeldCarts();
    });
  }

  void _holdCurrentCart() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text('Park / Hold Order'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Save this active cart temporarily to serve another customer.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Note / Identifier (Optional)',
                hintText: 'e.g. Red shirt customer, waiting for payment',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final note = noteController.text.trim();
              final res = await ref.read(heldCartsProvider.notifier).holdCart(
                    cart,
                    notes: note.isNotEmpty ? note : null,
                  );
              if (res != null && mounted) {
                ref.read(cartProvider.notifier).clearCart();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Order parked successfully. You can restore it anytime.'),
                    backgroundColor: Color(0xFF0F766E),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
            child: const Text('Park Order'),
          ),
        ],
      ),
    );
  }
  final FocusNode _barcodeFocusNode = FocusNode();
  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

  @override
  void dispose() {
    _barcodeSearchController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _handleBarcodeSubmit(String query, List<ProductModel> catalog) {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final cartNotifier = ref.read(cartProvider.notifier);
    final added = cartNotifier.addByBarcode(clean, catalog);

    if (added) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added item ($clean) to order'),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _barcodeSearchController.clear();
      ref.read(posCatalogSearchProvider.notifier).state = '';
    } else {
      // Set as general filter query
      ref.read(posCatalogSearchProvider.notifier).state = clean;
    }
  }

  void _showDiscountDialog() {
    final currentDiscount = ref.read(cartProvider).cartDiscount;
    final controller = TextEditingController(
      text: currentDiscount > 0 ? currentDiscount.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cart Discount'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Discount Amount',
            prefixText: '৳ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0.0;
              ref.read(cartProvider.notifier).setCartDiscount(val);
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _onProductTap(ProductModel product) {
    if (product.variants.length > 1) {
      _showVariantPicker(product);
    } else {
      ref.read(cartProvider.notifier).addItem(product);
    }
  }

  void _showVariantPicker(ProductModel product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Variant: ${product.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...product.variants.map((variant) {
                return ListTile(
                  title: Text(variant.name),
                  subtitle: Text(
                    'SKU: ${variant.sku ?? product.sku} | Price: ${currencyFmt.format(variant.sellingPrice)}',
                  ),
                  trailing: const Icon(Icons.add_shopping_cart, color: Color(0xFF0F766E)),
                  onTap: () {
                    ref.read(cartProvider.notifier).addItem(product, variant);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(posProductsProvider);
    final categoriesAsync = ref.watch(categoryListProvider);
    final selectedCategory = ref.watch(posSelectedCategoryProvider);
    final cart = ref.watch(cartProvider);
    final heldCarts = ref.watch(heldCartsProvider).heldCarts;

    return BarcodeScannerWrapper(
      onBarcodeScanned: (scanned) {
        catalogAsync.whenData((catalog) {
          _handleBarcodeSubmit(scanned, catalog);
        });
      },
      child: Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // =================================================================
          // LEFT PANEL: Catalog, Search & Barcode Entry (Expanded)
          // =================================================================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Register Shift Status & Drawer Quick Actions
                  const ShiftStatusBar(),

                  // Search & Barcode Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcodeSearchController,
                          focusNode: _barcodeFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Scan barcode or search product name / SKU...',
                            prefixIcon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0F766E)),
                            suffixIcon: _barcodeSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _barcodeSearchController.clear();
                                      ref.read(posCatalogSearchProvider.notifier).state = '';
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (val) {
                            ref.read(posCatalogSearchProvider.notifier).state = val.trim();
                            setState(() {});
                          },
                          onSubmitted: (query) {
                            catalogAsync.whenData((catalog) {
                              _handleBarcodeSubmit(query, catalog);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Refresh Catalog',
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          ref.invalidate(posProductsProvider);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Category Filter Chips
                  SizedBox(
                    height: 38,
                    child: categoriesAsync.when(
                      data: (cats) {
                        return ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: const Text('All Products'),
                                selected: selectedCategory == null,
                                onSelected: (_) {
                                  ref.read(posSelectedCategoryProvider.notifier).state = null;
                                },
                              ),
                            ),
                            ...cats.map((c) {
                              final isSelected = selectedCategory == c.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text(c.name),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    ref.read(posSelectedCategoryProvider.notifier).state =
                                        isSelected ? null : c.id;
                                  },
                                ),
                              );
                            }),
                          ],
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Product Grid
                  Expanded(
                    child: catalogAsync.when(
                      data: (products) {
                        if (products.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No matching products found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.88,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final prod = products[index];
                            final price = prod.primaryVariant?.sellingPrice ?? 0.0;

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _onProductTap(prod),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Product Category Pill & Multi-variant indicator
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              prod.categoryName ?? 'General',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                          if (prod.variants.length > 1)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${prod.variants.length} vars',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F766E),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const Spacer(),

                                      // Product Name
                                      Text(
                                        prod.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),

                                      // SKU
                                      Text(
                                        prod.sku,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const Spacer(),

                                      // Price & Add button
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                currencyFmt.format(price),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF0F766E),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F766E),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(
                        child: Text(
                          'Failed to load products: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =================================================================
          // RIGHT PANEL: Cart, Order Summary & Checkout Actions (Fixed width 380)
          // =================================================================
          SizedBox(
            width: 380,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cart Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_outlined,
                                color: Color(0xFF0F766E), size: 20),
                            const SizedBox(width: 6),
                            const Text(
                              'Order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (!cart.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${cart.totalQuantity} items',
                                  style: const TextStyle(
                                    color: Color(0xFF0F766E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Parked Carts Button with badge
                            Badge(
                              label: Text('${heldCarts.length}'),
                              isLabelVisible: heldCarts.isNotEmpty,
                              child: InkWell(
                                onTap: () => HeldCartsDialog.show(context),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.pause_circle_outline,
                                    size: 18,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // More order options: Hold Cart, Save as Quotation
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Order options',
                              onSelected: (val) {
                                if (val == 'hold') _holdCurrentCart();
                                if (val == 'quote') SaveQuotationDialog.show(context);
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'hold',
                                  enabled: !cart.isEmpty,
                                  child: const Row(
                                    children: [
                                      Icon(Icons.pause, size: 18),
                                      SizedBox(width: 8),
                                      Text('Hold / Park Order'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'quote',
                                  enabled: !cart.isEmpty,
                                  child: const Row(
                                    children: [
                                      Icon(Icons.request_quote_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Save as Quotation'),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Clear Cart
                            if (!cart.isEmpty) ...[
                              const SizedBox(width: 2),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  ref.read(cartProvider.notifier).clearCart();
                                },
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (cart.heldCartId != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Restored from Parked Cart (auto-clears on checkout)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),

                  // Customer Selection Bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cart.customerId != null
                          ? const Color(0xFF0F766E).withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cart.customerId != null
                            ? const Color(0xFF0F766E).withValues(alpha: 0.3)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final selected = await CustomerSelectionDialog.show(
                          context,
                          currentCustomerId: cart.customerId,
                        );
                        if (context.mounted) {
                          if (selected == null) {
                            ref.read(cartProvider.notifier).setCustomer(null, null);
                          } else {
                            ref
                                .read(cartProvider.notifier)
                                .setCustomer(selected.id, selected.name);
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              cart.customerId != null ? Icons.person : Icons.person_outline,
                              size: 18,
                              color: cart.customerId != null
                                  ? const Color(0xFF0F766E)
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cart.customerName ?? 'Walk-in Customer',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: cart.customerId != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: cart.customerId != null
                                          ? const Color(0xFF0F766E)
                                          : Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (cart.customerId != null)
                                    Text(
                                      'Linked Account · Credit Enabled',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.teal.shade700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (cart.customerId != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Remove customer',
                                onPressed: () {
                                  ref.read(cartProvider.notifier).setCustomer(null, null);
                                },
                              )
                            else
                              Icon(Icons.arrow_drop_down,
                                  size: 20, color: Colors.grey.shade500),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  // Cart Items List
                  Expanded(
                    child: cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_shopping_cart_outlined,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Cart is empty',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Scan a barcode or click products to begin sale',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: cart.items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = cart.items[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    // Item Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (item.variantName != null)
                                            Text(
                                              item.variantName!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          Text(
                                            currencyFmt.format(item.unitPrice),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          if (item.discount > 0)
                                            InkWell(
                                              onTap: () => LineDiscountDialog.show(context, item),
                                              child: Container(
                                                margin: const EdgeInsets.only(top: 2),
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.red.shade200),
                                                ),
                                                child: Text(
                                                  '-${item.discountType == "PERCENTAGE" ? "${item.discount.toStringAsFixed(0)}%" : currencyFmt.format(item.discount)}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            InkWell(
                                              onTap: () => LineDiscountDialog.show(context, item),
                                              child: Padding(
                                                padding: const EdgeInsets.only(top: 1.0),
                                                child: Text(
                                                  '+ Discount',
                                                  style: TextStyle(fontSize: 10, color: Colors.teal.shade700),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Quantity Stepper
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              ref
                                                  .read(cartProvider.notifier)
                                                  .decrementQuantity(item.variantId);
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              child: Icon(Icons.remove, size: 16),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              item.quantity.toStringAsFixed(
                                                  item.quantity % 1 == 0 ? 0 : 2),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              ref
                                                  .read(cartProvider.notifier)
                                                  .incrementQuantity(item.variantId);
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              child: Icon(Icons.add, size: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Line Total
                                    SizedBox(
                                      width: 75,
                                      child: Text(
                                        currencyFmt.format(item.lineTotal),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Remove Button
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                      onPressed: () {
                                        ref
                                            .read(cartProvider.notifier)
                                            .removeItem(item.variantId);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Financial Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summaryRow('Subtotal', currencyFmt.format(cart.subtotal)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    'Discount',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: cart.isEmpty ? null : _showDiscountDialog,
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '- ${currencyFmt.format(cart.discountTotal)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: cart.discountTotal > 0
                                    ? Colors.red.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _summaryRow(
                          'VAT / Tax (${cart.taxRate.toStringAsFixed(0)}%)',
                          '+ ${currencyFmt.format(cart.taxTotal)}',
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    'Delivery Fee',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => DeliveryChargeDialog.show(context),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+ ${currencyFmt.format(cart.deliveryCharge)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: cart.deliveryCharge > 0
                                    ? const Color(0xFF0F766E)
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(thickness: 1.5),
                        const SizedBox(height: 6),

                        // Grand Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Grand Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                currencyFmt.format(cart.grandTotal),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Pay Action Button
                        FilledButton(
                          onPressed: cart.isEmpty
                              ? null
                              : () {
                                  PaymentDialog.show(context).then((_) {
                                    ref.read(currentShiftProvider.notifier).loadCurrentShift();
                                  });
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Pay ${currencyFmt.format(cart.grandTotal)} (F4)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
