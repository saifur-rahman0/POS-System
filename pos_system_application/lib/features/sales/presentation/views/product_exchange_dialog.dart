import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/uuid_generator.dart';
import '../../../catalog/domain/models/product.dart';
import '../../../catalog/domain/models/product_variant.dart';
import '../../../catalog/presentation/controllers/catalog_providers.dart';
import '../../../checkout/domain/models/checkout_request.dart';
import '../../../checkout/domain/models/exchange.dart';
import '../../../checkout/domain/models/payment_tender.dart';
import '../../../checkout/presentation/controllers/cart_controller.dart';
import '../../../checkout/presentation/views/receipt_dialog.dart';
import '../../data/sales_api_service.dart';
import '../../domain/models/sale_returnable_item.dart';

class _ReplacementEntry {
  final ProductModel product;
  final ProductVariantModel variant;
  double quantity;

  _ReplacementEntry({
    required this.product,
    required this.variant,
    this.quantity = 1.0,
  });

  double get lineTotal => quantity * variant.sellingPrice;
}

class ProductExchangeDialog extends ConsumerStatefulWidget {
  final String saleId;
  final String receiptNo;
  final VoidCallback onExchangeSuccess;

  const ProductExchangeDialog({
    super.key,
    required this.saleId,
    required this.receiptNo,
    required this.onExchangeSuccess,
  });

  @override
  ConsumerState<ProductExchangeDialog> createState() =>
      _ProductExchangeDialogState();
}

class _ProductExchangeDialogState extends ConsumerState<ProductExchangeDialog> {
  bool _isLoadingReturnables = true;
  String? _loadError;
  List<SaleReturnableItemModel> _returnableItems = [];
  final Map<String, double> _selectedReturns = {}; // saleItemId -> qty
  final TextEditingController _returnReasonController =
      TextEditingController(text: 'Product exchange');

  // Replacement items
  final List<_ReplacementEntry> _replacementItems = [];
  final TextEditingController _searchProductController =
      TextEditingController();
  List<ProductModel> _searchResults = [];
  bool _isSearching = false;

  // Tender for net difference
  String _paymentMethod = 'CASH';
  bool _isSubmitting = false;
  String? _submitError;

  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _fetchReturnableItems();
  }

  @override
  void dispose() {
    _returnReasonController.dispose();
    _searchProductController.dispose();
    super.dispose();
  }

  Future<void> _fetchReturnableItems() async {
    try {
      final items = await ref
          .read(salesApiServiceProvider)
          .getReturnableItems(widget.saleId);
      if (mounted) {
        setState(() {
          _returnableItems = items;
          _isLoadingReturnables = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoadingReturnables = false;
        });
      }
    }
  }

  Future<void> _searchProducts(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final res = await ref.read(catalogApiServiceProvider).getProducts(
            search: clean,
            isActive: true,
            page: 1,
            limit: 10,
          );
      if (mounted) {
        setState(() {
          _searchResults = res.items;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _addReplacement(ProductModel product, ProductVariantModel variant) {
    setState(() {
      final existingIdx = _replacementItems.indexWhere(
        (it) => it.variant.id == variant.id,
      );
      if (existingIdx >= 0) {
        _replacementItems[existingIdx].quantity += 1.0;
      } else {
        _replacementItems.add(
          _ReplacementEntry(product: product, variant: variant, quantity: 1.0),
        );
      }
      _searchProductController.clear();
      _searchResults = [];
    });
  }

  double get _totalReturnValue {
    double total = 0.0;
    for (final it in _returnableItems) {
      final qty = _selectedReturns[it.saleItemId] ?? 0.0;
      total += (qty * it.unitPrice);
    }
    return total;
  }

  double get _totalReplacementValue {
    return _replacementItems.fold(0.0, (acc, it) => acc + it.lineTotal);
  }

  double get _netDifference => _totalReplacementValue - _totalReturnValue;

  Future<void> _submitExchange() async {
    final returnList = <ExchangeItemReturnInput>[];
    for (final it in _returnableItems) {
      final qty = _selectedReturns[it.saleItemId] ?? 0.0;
      if (qty > 0) {
        returnList.add(
          ExchangeItemReturnInput(
            originalSaleItemId: it.saleItemId,
            quantity: qty,
            refundAmount: qty * it.unitPrice,
            reason: _returnReasonController.text.trim(),
          ),
        );
      }
    }

    if (returnList.isEmpty) {
      setState(() {
        _submitError = 'Please select at least one item to return';
      });
      return;
    }

    if (_replacementItems.isEmpty) {
      setState(() {
        _submitError = 'Please select at least one replacement item';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final newItems = _replacementItems.map((r) {
      return CheckoutRequestItemModel(
        productVariantId: r.variant.id,
        quantity: r.quantity,
        unitPrice: r.variant.sellingPrice,
      );
    }).toList();

    // Prepare payments
    final payments = <PaymentTenderInput>[];
    final diff = _netDifference;
    if (diff > 0) {
      // Customer pays additional
      payments.add(PaymentTenderInput(method: _paymentMethod, amount: diff));
    } else if (diff < 0) {
      // Store refunds customer difference
      payments.add(
        PaymentTenderInput(method: _paymentMethod, amount: diff.abs()),
      );
    }

    final request = ExchangeRequestModel(
      idempotencyKey: generateUuidV4(),
      originalSaleId: widget.saleId,
      returnItems: returnList,
      newItems: newItems,
      payments: payments,
      notes: 'Exchange for receipt #${widget.receiptNo}',
    );

    try {
      final apiService = ref.read(checkoutApiServiceProvider);
      final result = await apiService.exchange(request);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onExchangeSuccess();

        _showExchangeSuccessDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitError = 'Exchange failed: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  void _showExchangeSuccessDialog(ExchangeResultModel result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF0F766E), size: 28),
            SizedBox(width: 10),
            Text('Exchange Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Return Order: ${result.returnNo}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Credited for Return: ${currencyFmt.format(result.returnTotal)}'),
            const SizedBox(height: 8),
            Text(
              'New Sale Receipt: ${result.newSale.receiptNo}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('New Total: ${currencyFmt.format(result.newSale.grandTotal)}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.netDifference > 0
                    ? 'Customer paid difference: ${currencyFmt.format(result.netDifference)}'
                    : result.netDifference < 0
                        ? 'Refund issued to customer: ${currencyFmt.format(result.netDifference.abs())}'
                        : 'Even exchange (no payment difference)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ReceiptDialog.show(context, result.newSale);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
            child: const Text('View New Receipt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 950, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: Color(0xFF0F766E),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Process Product Exchange',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Original Receipt: #${widget.receiptNo}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Dual Column Content: Left = Return Items, Right = Replacement Items
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ================= LEFT: RETURN ITEMS =================
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '1. Select Item(s) to Return',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Return: ${currencyFmt.format(_totalReturnValue)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Returnable Items List
                            Expanded(
                              child: _isLoadingReturnables
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : _loadError != null
                                      ? Center(
                                          child: Text(
                                            _loadError!,
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                        )
                                      : _returnableItems.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'No returnable items available for this sale.',
                                              ),
                                            )
                                          : ListView.separated(
                                              itemCount:
                                                  _returnableItems.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(height: 1),
                                              itemBuilder: (ctx, i) {
                                                final item =
                                                    _returnableItems[i];
                                                final currentQty =
                                                    _selectedReturns[
                                                            item.saleItemId] ??
                                                        0.0;

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 8.0,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              item.productName,
                                                              style:
                                                                  const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Unit: ${currencyFmt.format(item.unitPrice)} | Can return: ${item.quantityReturnable.toStringAsFixed(0)}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Stepper
                                                      Row(
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.remove_circle_outline,
                                                              size: 20,
                                                            ),
                                                            onPressed: currentQty >
                                                                    0
                                                                ? () {
                                                                    setState(() {
                                                                      _selectedReturns[item.saleItemId] =
                                                                          currentQty - 1.0;
                                                                    });
                                                                  }
                                                                : null,
                                                          ),
                                                          Text(
                                                            currentQty.toStringAsFixed(0),
                                                            style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.add_circle_outline,
                                                              size: 20,
                                                            ),
                                                            onPressed: currentQty <
                                                                    item.quantityReturnable
                                                                ? () {
                                                                    setState(() {
                                                                      _selectedReturns[item.saleItemId] =
                                                                          currentQty + 1.0;
                                                                    });
                                                                  }
                                                                : null,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // ================= RIGHT: REPLACEMENT ITEMS =================
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '2. Select Replacement Item(s)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'New: ${currencyFmt.format(_totalReplacementValue)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Search bar for replacement catalog
                            TextField(
                              controller: _searchProductController,
                              decoration: InputDecoration(
                                hintText: 'Search new product name or SKU...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _isSearching
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (val) => _searchProducts(val),
                            ),

                            // Search drop-down / results
                            if (_searchResults.isNotEmpty)
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 140),
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (ctx, idx) {
                                    final prod = _searchResults[idx];
                                    final v = prod.primaryVariant;
                                    if (v == null) return const SizedBox();
                                    return ListTile(
                                      dense: true,
                                      title: Text(prod.name),
                                      subtitle: Text(
                                        'Price: ${currencyFmt.format(v.sellingPrice)} | SKU: ${v.sku ?? prod.sku}',
                                      ),
                                      trailing: const Icon(
                                        Icons.add_circle,
                                        color: Color(0xFF0F766E),
                                      ),
                                      onTap: () => _addReplacement(prod, v),
                                    );
                                  },
                                ),
                              ),

                            const SizedBox(height: 8),

                            // Selected replacement items list
                            Expanded(
                              child: _replacementItems.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No replacement items selected yet. Use the search bar above to add products.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _replacementItems.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (ctx, idx) {
                                        final rep = _replacementItems[idx];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6.0,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      rep.product.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${rep.quantity.toStringAsFixed(0)} × ${currencyFmt.format(rep.variant.sellingPrice)}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    if (rep.quantity > 1) {
                                                      rep.quantity -= 1.0;
                                                    } else {
                                                      _replacementItems
                                                          .removeAt(idx);
                                                    }
                                                  });
                                                },
                                              ),
                                              Text(
                                                rep.quantity.toStringAsFixed(0),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    rep.quantity += 1.0;
                                                  });
                                                },
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                currencyFmt
                                                    .format(rep.lineTotal),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Bottom Settlement Breakdown Bar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Exchange Net Balance: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Text(
                                _netDifference > 0
                                    ? 'Customer Pays +${currencyFmt.format(_netDifference)}'
                                    : _netDifference < 0
                                        ? 'Refund to Customer ${currencyFmt.format(_netDifference.abs())}'
                                        : 'Even Exchange (৳0.00)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _netDifference > 0
                                      ? const Color(0xFF0F766E)
                                      : _netDifference < 0
                                          ? Colors.red.shade700
                                          : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          if (_netDifference != 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text(
                                  'Settlement Tender: ',
                                  style: TextStyle(fontSize: 12),
                                ),
                                DropdownButton<String>(
                                  value: _paymentMethod,
                                  isDense: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'CASH',
                                      child: Text('Cash'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'BKASH',
                                      child: Text('bKash'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'CARD',
                                      child: Text('Card'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'STORE_CREDIT',
                                      child: Text('Store Credit'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _paymentMethod = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (_submitError != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Text(
                          _submitError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),

                    OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submitExchange,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
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
                          : const Text(
                              'Complete Exchange',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

