import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/transfers_controller.dart';
import '../../domain/models/stock_transfer.dart';

class CrossBranchStockDialog extends ConsumerStatefulWidget {
  final String productVariantId;
  final String productName;

  const CrossBranchStockDialog({
    super.key,
    required this.productVariantId,
    required this.productName,
  });

  static Future<void> show(
    BuildContext context, {
    required String productVariantId,
    required String productName,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => CrossBranchStockDialog(
        productVariantId: productVariantId,
        productName: productName,
      ),
    );
  }

  @override
  ConsumerState<CrossBranchStockDialog> createState() =>
      _CrossBranchStockDialogState();
}

class _CrossBranchStockDialogState
    extends ConsumerState<CrossBranchStockDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  List<CrossBranchStockItemModel> _stockList = [];

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(transfersApiServiceProvider);
      final list =
          await apiService.getCrossBranchStock(widget.productVariantId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _stockList = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCompanyStock =
        _stockList.fold(0.0, (acc, item) => acc + item.quantityOnHand);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cross-Store Inventory',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.productName,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Expanded(
                  child: Center(
                    child: Text(
                      'Error: $_errorMessage',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              else ...[
                // Company total card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Total Network Stock:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${totalCompanyStock.toStringAsFixed(1)} units',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: _stockList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _stockList[index];
                      final isLow = item.quantityOnHand < 5.0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.isActive
                              ? const Color(0xFF0F766E).withValues(alpha: 0.1)
                              : Colors.grey.shade200,
                          child: Icon(
                            Icons.store,
                            color: item.isActive
                                ? const Color(0xFF0F766E)
                                : Colors.grey,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.branchName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: item.isActive ? null : Colors.grey,
                          ),
                        ),
                        subtitle: item.branchCode != null
                            ? Text('Code: ${item.branchCode}')
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLow
                                ? Colors.orange.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isLow
                                  ? Colors.orange.shade200
                                  : Colors.green.shade200,
                            ),
                          ),
                          child: Text(
                            '${item.quantityOnHand.toStringAsFixed(1)} in stock',
                            style: TextStyle(
                              color: isLow
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
