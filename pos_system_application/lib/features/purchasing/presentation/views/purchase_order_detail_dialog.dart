import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../catalog/domain/models/product.dart';
import '../../../catalog/domain/models/product_variant.dart';
import '../../../catalog/presentation/views/barcode_print_dialog.dart';
import '../../domain/models/purchase_order.dart';
import '../controllers/purchasing_controller.dart';

class PurchaseOrderDetailDialog extends ConsumerStatefulWidget {
  final PurchaseOrderModel purchaseOrder;

  const PurchaseOrderDetailDialog({super.key, required this.purchaseOrder});

  static Future<void> show(BuildContext context, PurchaseOrderModel order) {
    return showDialog<void>(
      context: context,
      builder: (_) => PurchaseOrderDetailDialog(purchaseOrder: order),
    );
  }

  @override
  ConsumerState<PurchaseOrderDetailDialog> createState() =>
      _PurchaseOrderDetailDialogState();
}

class _PurchaseOrderDetailDialogState
    extends ConsumerState<PurchaseOrderDetailDialog> {
  late PurchaseOrderModel _order;
  bool _isReceiving = false;
  bool _isPaying = false;
  String? _actionError;

  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
  final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _order = widget.purchaseOrder;
  }

  Future<void> _receiveGoods() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Goods Receiving'),
        content: Text(
          'Receive all line items for order "${_order.referenceNo}"?\n\n'
          'This will:\n'
          '• Increment stock on hand in the warehouse/branch\n'
          '• Update cost prices for the received product variants\n'
          '• Append an immutable audit trail entry to stock movements',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Receive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isReceiving = true;
      _actionError = null;
    });

    try {
      final updated = await ref
          .read(purchasesControllerProvider.notifier)
          .receivePurchaseOrder(_order.id);

      if (mounted) {
        setState(() {
          _order = updated;
          _isReceiving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Goods received and stock balances successfully updated!'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReceiving = false;
          _actionError = e.toString();
        });
      }
    }
  }

  Future<void> _showPaymentDialog() async {
    final amountController =
        TextEditingController(text: _order.dueAmount.toStringAsFixed(2));
    final refController = TextEditingController();
    String selectedMethod = 'CASH';
    String? paymentError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Disburse Payment — ${_order.referenceNo}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (paymentError != null) ...[
                  Text(
                    paymentError!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Outstanding Due: ${currencyFmt.format(_order.dueAmount)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount (৳)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: selectedMethod,
                  items: const [
                    DropdownMenuItem(
                        value: 'CASH', child: Text('Cash (Debits Drawer)')),
                    DropdownMenuItem(
                        value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                    DropdownMenuItem(
                        value: 'BKASH', child: Text('bKash / MFS')),
                  ],
                  onChanged: (v) => setModalState(() => selectedMethod = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: refController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Ref # (Optional)',
                    hintText: 'e.g. Bank Slip or TrxID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: _isPaying
                  ? null
                  : () async {
                      final amt =
                          double.tryParse(amountController.text.trim()) ?? 0.0;
                      if (amt <= 0) {
                        setModalState(() =>
                            paymentError = 'Amount must be greater than 0');
                        return;
                      }
                      if (amt > _order.dueAmount) {
                        setModalState(() => paymentError =
                            'Amount cannot exceed outstanding due (${currencyFmt.format(_order.dueAmount)})');
                        return;
                      }

                      setState(() => _isPaying = true);
                      try {
                        await ref
                            .read(purchasesControllerProvider.notifier)
                            .addPayment(
                              _order.id,
                              amount: amt,
                              method: selectedMethod,
                              reference: refController.text.trim().isNotEmpty
                                  ? refController.text.trim()
                                  : null,
                            );

                        if (ctx.mounted) Navigator.of(ctx).pop();

                        // Refresh orders
                        ref
                            .read(purchasesControllerProvider.notifier)
                            .refresh();

                        setState(() {
                          _order = _order.copyWith(
                            paidTotal: _order.paidTotal + amt,
                            dueBalance: (_order.dueBalance - amt)
                                .clamp(0.0, double.infinity),
                          );
                          _isPaying = false;
                        });
                      } catch (e) {
                        setState(() => _isPaying = false);
                        setModalState(() => paymentError = e.toString());
                      }
                    },
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOrdered = _order.status == 'ORDERED';
    final hasDue = _order.dueAmount > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
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
                      const Icon(Icons.receipt_long,
                          color: Color(0xFF0F766E), size: 26),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order ${_order.referenceNo}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          if (_order.supplierName != null)
                            Text(
                              'Supplier: ${_order.supplierName}',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOrdered
                              ? Colors.amber.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOrdered
                                ? Colors.amber.shade400
                                : Colors.green.shade400,
                          ),
                        ),
                        child: Text(
                          _order.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOrdered
                                ? Colors.amber.shade900
                                : Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_actionError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _actionError!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Info Row (Dates & Notes)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Created At',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(dateFmt.format(_order.createdAt),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if (_order.notes != null && _order.notes!.isNotEmpty)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notes',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Text(_order.notes!,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Line Items
              const Text(
                'Purchased Items',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(Colors.grey.shade50),
                        columns: const [
                          DataColumn(label: Text('Item / Product')),
                          DataColumn(label: Text('SKU')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Unit Cost')),
                          DataColumn(label: Text('Subtotal')),
                        ],
                        rows: _order.items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.productName ?? 'Product',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500))),
                              DataCell(Text(item.sku ?? '-')),
                              DataCell(Text(item.quantity.toStringAsFixed(2))),
                              DataCell(Text(currencyFmt.format(item.unitCost))),
                              DataCell(
                                Text(
                                  currencyFmt.format(item.subtotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Financial Summary Cards
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Total Amount',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(currencyFmt.format(_order.totalAmount),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Discount',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(currencyFmt.format(_order.discount),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Paid Amount',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(currencyFmt.format(_order.paidAmount),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Due Balance',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          currencyFmt.format(_order.dueAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                _order.dueAmount > 0 ? Colors.red : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  if (hasDue) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _showPaymentDialog,
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Add Payment'),
                    ),
                  ],
                  if (_order.status == 'RECEIVED') ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                      ),
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text('Print Item Barcodes'),
                      onPressed: () {
                        final batchProds = _order.items.map((item) {
                          return ProductModel(
                            id: item.productVariantId,
                            businessId: _order.businessId,
                            sku: item.sku ?? 'SKU-${item.id.substring(0, 6)}',
                            name: item.productName ?? 'Product',
                            productType: 'standard',
                            taxRate: 0.0,
                            hasVariants: false,
                            isActive: true,
                            primaryVariant: ProductVariantModel(
                              id: item.productVariantId,
                              productId: item.productVariantId,
                              sku: item.sku,
                              name: item.variantName ?? 'Standard',
                              costPrice: item.unitCost,
                              sellingPrice: item.unitCost * 1.25,
                              trackStock: true,
                              isActive: true,
                            ),
                          );
                        }).toList();

                        final quantities = <String, int>{};
                        for (final item in _order.items) {
                          quantities[item.productVariantId] =
                              item.quantity.round().clamp(1, 9999);
                        }

                        BarcodePrintDialog.show(
                          context,
                          batchProducts: batchProds,
                          quantities: quantities,
                        );
                      },
                    ),
                  ],
                  if (isOrdered) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: _isReceiving ? null : _receiveGoods,
                      icon: _isReceiving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.inventory_2, size: 18),
                      label: const Text('Receive Goods & Update Stock'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
