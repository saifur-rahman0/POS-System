import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../checkout/domain/models/sale_receipt.dart';
import '../../../checkout/presentation/views/receipt_dialog.dart';
import '../../data/sales_api_service.dart';
import '../../domain/models/sale_return.dart';
import 'return_dialog.dart';

class SaleDetailDrawer extends ConsumerStatefulWidget {
  final String saleId;
  final VoidCallback onStateChanged;

  const SaleDetailDrawer({
    super.key,
    required this.saleId,
    required this.onStateChanged,
  });

  static void show(BuildContext context, String saleId, VoidCallback onStateChanged) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sale Details',
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            child: SizedBox(
              width: 520,
              height: double.infinity,
              child: SaleDetailDrawer(
                saleId: saleId,
                onStateChanged: onStateChanged,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<SaleDetailDrawer> createState() => _SaleDetailDrawerState();
}

class _SaleDetailDrawerState extends ConsumerState<SaleDetailDrawer> {
  bool _isLoading = true;
  String? _errorMessage;
  SaleReceiptModel? _sale;
  List<SaleReturnModel> _returns = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(salesApiServiceProvider);
      final sale = await api.getSaleDetail(widget.saleId);
      final returns = await api.getSaleReturns(widget.saleId);
      if (mounted) {
        setState(() {
          _sale = sale;
          _returns = returns;
          _isLoading = false;
        });
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF0F766E);
      case 'PARTIALLY_REFUNDED':
        return Colors.amber.shade800;
      case 'REFUNDED':
        return Colors.indigo;
      case 'VOIDED':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Future<void> _confirmVoidSale() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Sale Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voiding this sale will cancel all payment tenders and restore inventory back to stock balances. This action is immutable.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Void Reason *',
                hintText: 'e.g. Cashier error, duplicate billing',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Confirm Void'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(salesApiServiceProvider)
            .voidSale(widget.saleId, reason: reasonController.text.trim());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Sale voided and inventory restored successfully.'),
          ),
        );
        widget.onStateChanged();
        _loadDetails();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text('Failed to void sale: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sale != null ? _sale!.receiptNo : 'Sale Details',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (_sale != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateFmt.format(_sale!.createdAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_sale != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_sale!.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(_sale!.status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _sale!.status,
                      style: TextStyle(
                        color: _getStatusColor(_sale!.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
          ),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadDetails,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _sale == null
                        ? const Center(child: Text('Sale not found'))
                        : ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              // Customer & Cashier Card
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Customer: ${_sale!.customerName ?? "Walk-in Customer"}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.badge_outlined,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Cashier ID: ${_sale!.cashierId.substring(0, 8)}...',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Items Table
                              const Text(
                                'Line Items',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              ..._sale!.items.map((item) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
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
                                            Text(
                                              '${item.quantity.toStringAsFixed(0)} × ${currencyFmt.format(item.unitPrice)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        currencyFmt.format(item.lineTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),

                              // Financials Breakdown
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    _buildSummaryRow(
                                      'Subtotal',
                                      currencyFmt.format(_sale!.financials.subtotal),
                                    ),
                                    if (_sale!.financials.discountTotal > 0)
                                      _buildSummaryRow(
                                        'Discount',
                                        '- ${currencyFmt.format(_sale!.financials.discountTotal)}',
                                        color: Colors.red,
                                      ),
                                    if (_sale!.financials.taxTotal > 0)
                                      _buildSummaryRow(
                                        'Tax / VAT',
                                        currencyFmt.format(_sale!.financials.taxTotal),
                                      ),
                                    const Divider(height: 16),
                                    _buildSummaryRow(
                                      'Grand Total',
                                      currencyFmt.format(_sale!.financials.grandTotal),
                                      isBold: true,
                                    ),
                                    _buildSummaryRow(
                                      'Paid Amount',
                                      currencyFmt.format(_sale!.financials.paidTotal),
                                    ),
                                    if (_sale!.financials.changeAmount > 0)
                                      _buildSummaryRow(
                                        'Change Returned',
                                        currencyFmt.format(_sale!.financials.changeAmount),
                                        color: const Color(0xFF0F766E),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Payment Tenders
                              const Text(
                                'Payment Methods',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _sale!.payments.map((p) {
                                  return Chip(
                                    avatar: Icon(
                                      p.method == 'CASH'
                                          ? Icons.payments_outlined
                                          : Icons.credit_card,
                                      size: 16,
                                      color: const Color(0xFF0F766E),
                                    ),
                                    label: Text(
                                      '${p.method}: ${currencyFmt.format(p.amount)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              // Return History Section
                              if (_returns.isNotEmpty) ...[
                                const Text(
                                  'Return & Refund History',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.indigo,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._returns.map((ret) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.indigo.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              ret.returnNo,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.indigo,
                                              ),
                                            ),
                                            Text(
                                              '- ${currencyFmt.format(ret.refundTotal)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${dateFmt.format(ret.createdAt)}${ret.reason != null ? " • Reason: ${ret.reason}" : ""}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
          ),

          // Bottom Action Bar
          if (_sale != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Reprint Receipt'),
                      onPressed: () {
                        ReceiptDialog.show(context, _sale!);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_sale!.status != 'VOIDED' && _sale!.status != 'REFUNDED') ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                        ),
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: const Text('Return / Refund'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => ReturnDialog(
                              saleId: _sale!.id,
                              receiptNo: _sale!.receiptNo,
                              onReturnSuccess: () {
                                widget.onStateChanged();
                                _loadDetails();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Void Sale',
                      icon: const Icon(Icons.block, color: Colors.red),
                      onPressed: _confirmVoidSale,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
