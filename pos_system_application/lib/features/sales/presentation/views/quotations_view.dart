import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../checkout/domain/models/cart_item.dart';
import '../../../checkout/domain/models/payment_tender.dart';
import '../../../checkout/domain/models/quotation.dart';
import '../../../checkout/presentation/controllers/cart_controller.dart';
import '../../../checkout/presentation/views/receipt_dialog.dart';
import '../controllers/quotations_controller.dart';

class QuotationsView extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToPos;

  const QuotationsView({super.key, this.onSwitchToPos});

  @override
  ConsumerState<QuotationsView> createState() => _QuotationsViewState();
}

class _QuotationsViewState extends ConsumerState<QuotationsView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
  final dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(quotationsProvider.notifier).loadQuotations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFF0F766E);
      case 'CONVERTED':
        return Colors.green.shade700;
      case 'EXPIRED':
        return Colors.amber.shade800;
      case 'CANCELLED':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  void _showQuotationDetail(QuotationModel q) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.quotationNumber,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Customer: ${q.customerName ?? 'Walk-in'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(q.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(q.status).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                q.status,
                style: TextStyle(
                  color: _getStatusColor(q.status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date: ${dateFmt.format(q.createdAt)}'),
                    Text(
                      'Valid Until: ${q.validUntil != null ? dateFmt.format(q.validUntil!) : "No expiry"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: q.isExpired ? Colors.red : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                const Text(
                  'Quotation Items',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...q.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.productName} (${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} × ${currencyFmt.format(item.unitPrice)})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          currencyFmt.format(item.lineTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                _detailRow('Subtotal', currencyFmt.format(q.subtotal)),
                if (q.discountTotal > 0)
                  _detailRow('Discounts', '- ${currencyFmt.format(q.discountTotal)}',
                      color: Colors.red.shade700),
                _detailRow('VAT / Tax', '+ ${currencyFmt.format(q.taxTotal)}'),
                if (q.deliveryCharge > 0)
                  _detailRow('Delivery Fee', '+ ${currencyFmt.format(q.deliveryCharge)}'),
                const Divider(height: 16),
                _detailRow(
                  'Grand Total',
                  currencyFmt.format(q.grandTotal),
                  isBold: true,
                  fontSize: 16,
                  color: const Color(0xFF0F766E),
                ),
                if (q.notes != null && q.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Notes / Terms:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    q.notes!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (q.status == 'PENDING')
            FilledButton.icon(
              icon: const Icon(Icons.shopping_cart_checkout, size: 16),
              label: const Text('Load to POS Cart'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
              ),
              onPressed: () {
                _loadQuotationToCart(q);
                Navigator.of(ctx).pop();
              },
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _loadQuotationToCart(QuotationModel q) {
    final cartItems = q.items.map((it) {
      return CartItemModel(
        variantId: it.productVariantId,
        productId: it.productVariantId,
        productName: it.productName,
        sku: it.sku,
        unitPrice: it.unitPrice,
        unitCost: 0.0,
        quantity: it.quantity,
        discount: it.discount,
        discountType: it.discountType,
        trackStock: true,
      );
    }).toList();

    ref.read(cartProvider.notifier).restoreCart(
          items: cartItems,
          cartDiscount: 0.0,
          deliveryCharge: q.deliveryCharge,
          taxRate: q.discountedSubtotal > 0
              ? (q.taxTotal / q.discountedSubtotal) * 100.0
              : 5.0,
          customerId: q.customerId,
          customerName: q.customerName,
          notes: 'Converted from Quotation ${q.quotationNumber}',
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Quotation ${q.quotationNumber} loaded into POS Cart ready for checkout.',
        ),
        backgroundColor: const Color(0xFF0F766E),
        duration: const Duration(seconds: 3),
      ),
    );

    widget.onSwitchToPos?.call();
  }

  void _showDirectConvertDialog(QuotationModel q) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Convert Quotation ${q.quotationNumber}'),
        content: Text(
          'Confirm instant conversion of this quotation to an active sale of ${currencyFmt.format(q.grandTotal)} settled in CASH?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final sale = await ref
                  .read(quotationsProvider.notifier)
                  .convertQuotation(
                    q.id,
                    payments: [
                      PaymentTenderInput(method: 'CASH', amount: q.grandTotal)
                    ],
                  );
              if (sale != null && mounted) {
                ReceiptDialog.show(context, sale);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
            child: const Text('Convert & Settle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quotationsProvider);
    final search = _searchController.text.trim().toLowerCase();

    final filteredList = state.quotations.where((q) {
      if (_selectedStatus != 'ALL' &&
          q.status.toUpperCase() != _selectedStatus) {
        return false;
      }
      if (search.isNotEmpty) {
        final matchesNum = q.quotationNumber.toLowerCase().contains(search);
        final matchesCust =
            (q.customerName ?? '').toLowerCase().contains(search);
        return matchesNum || matchesCust;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter and Search Header
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Search Field
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search quotation # or customer...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),

                // Status Chips
                Wrap(
                  spacing: 8,
                  children: [
                    'ALL',
                    'PENDING',
                    'CONVERTED',
                    'EXPIRED',
                    'CANCELLED'
                  ].map((status) {
                    final isSel = _selectedStatus == status;
                    return ChoiceChip(
                      label: Text(status),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() {
                          _selectedStatus = status;
                        });
                      },
                    );
                  }).toList(),
                ),

                const Spacer(),

                IconButton.filledTonal(
                  tooltip: 'Refresh Quotations',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.read(quotationsProvider.notifier).loadQuotations(),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // List Content Area
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.errorMessage != null
                    ? Center(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.request_quote_outlined,
                                  size: 56,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No quotations found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final q = filteredList[idx];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(q.status)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.request_quote_outlined,
                                    color: _getStatusColor(q.status),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      q.quotationNumber,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(q.status)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        q.status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(q.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Customer: ${q.customerName ?? 'Walk-in'} • Created: ${dateFmt.format(q.createdAt)} • Valid until: ${q.validUntil != null ? dateFmt.format(q.validUntil!) : "No expiry"} • ${q.items.length} items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currencyFmt.format(q.grandTotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 20,
                                      ),
                                      tooltip: 'View Details',
                                      onPressed: () => _showQuotationDetail(q),
                                    ),
                                    if (q.status == 'PENDING') ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.shopping_cart_checkout,
                                          size: 20,
                                          color: Color(0xFF0F766E),
                                        ),
                                        tooltip: 'Load into POS Cart',
                                        onPressed: () =>
                                            _loadQuotationToCart(q),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 20,
                                          color: Colors.green,
                                        ),
                                        tooltip: 'Direct Convert & Settle',
                                        onPressed: () =>
                                            _showDirectConvertDialog(q),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () => _showQuotationDetail(q),
                              );
                            },
                          ),
          ),
        ),
      ],
    );
  }
}

