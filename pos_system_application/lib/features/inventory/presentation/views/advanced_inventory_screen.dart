import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/advanced_inventory_controller.dart';
import 'batch_inward_dialog.dart';
import 'damaged_stock_dialog.dart';
import 'stock_count_session_dialog.dart';
import 'stock_reservation_dialog.dart';

class AdvancedInventoryScreen extends ConsumerStatefulWidget {
  const AdvancedInventoryScreen({super.key});

  @override
  ConsumerState<AdvancedInventoryScreen> createState() => _AdvancedInventoryScreenState();
}

class _AdvancedInventoryScreenState extends ConsumerState<AdvancedInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getExpiryColor(String? status) {
    switch (status) {
      case 'EXPIRED':
        return Colors.red;
      case 'EXPIRING_7_DAYS':
        return Colors.deepOrange;
      case 'EXPIRING_30_DAYS':
        return Colors.amber.shade800;
      case 'EXPIRING_60_DAYS':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Inventory Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_2), text: 'Batches & Expiry'),
            Tab(icon: Icon(Icons.fact_check), text: 'Physical Audits'),
            Tab(icon: Icon(Icons.remove_circle_outline), text: 'Damaged Stock'),
            Tab(icon: Icon(Icons.bookmark_added), text: 'Reservations'),
            Tab(icon: Icon(Icons.trending_up), text: 'Reorder & Valuation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBatchesTab(),
          _buildAuditsTab(),
          _buildDamagedTab(),
          _buildReservationsTab(),
          _buildReorderAndValuationTab(),
        ],
      ),
    );
  }

  // =========================================================================
  // Tab 1: Batches & Expiry
  // =========================================================================
  Widget _buildBatchesTab() {
    final batchesState = ref.watch(batchesListProvider);
    final alertsState = ref.watch(expiryAlertsProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Expiry Alert Banner
          alertsState.when(
            data: (alerts) {
              if (alerts.isEmpty) return const SizedBox.shrink();
              final critical = alerts.where((a) => a.urgency == 'CRITICAL_EXPIRED').length;
              final high = alerts.where((a) => a.urgency == 'HIGH_7_DAYS').length;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Expiry Alert: ${alerts.length} lots expiring soon ($critical expired, $high within 7 days). Inspect stock promptly.',
                        style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inventory Batches (FEFO Tracking)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Inward Batch'),
                onPressed: () {
                  showDialog(context: context, builder: (_) => const BatchInwardDialog());
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: batchesState.when(
              data: (batches) {
                if (batches.isEmpty) {
                  return const Center(child: Text('No batches registered yet. Click Inward Batch to add stock.'));
                }
                return ListView.separated(
                  itemCount: batches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final b = batches[idx];
                    final expiryColor = _getExpiryColor(b.expiryStatus);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: expiryColor.withAlpha(30),
                        child: Icon(Icons.inventory, color: expiryColor),
                      ),
                      title: Text(
                        '${b.productName ?? 'Variant'} - ${b.variantName ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Lot: ${b.batchNumber} | Exp: ${b.expiryDate?.toIso8601String().substring(0, 10) ?? 'N/A'} | Cost: BDT ${b.costPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: expiryColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: expiryColor),
                            ),
                            child: Text(
                              b.expiryStatus ?? 'GOOD',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: expiryColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${b.quantityOnHand.toStringAsFixed(1)} units',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Tab 2: Physical Audits
  // =========================================================================
  Widget _buildAuditsTab() {
    final countsState = ref.watch(stockCountsListProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Physical Inventory Audits',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Start Audit Session'),
                onPressed: () async {
                  final notesCtrl = TextEditingController();
                  final start = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Start Physical Count'),
                      content: TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Audit Session Notes',
                          hintText: 'e.g. End of Month Full Store Audit',
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create Session')),
                      ],
                    ),
                  );
                  if (start == true) {
                    final notifier = ref.read(stockCountsListProvider.notifier);
                    await notifier.createCount(notes: notesCtrl.text.trim());
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: countsState.when(
              data: (counts) {
                if (counts.isEmpty) {
                  return const Center(child: Text('No stock counts recorded. Click Start Audit Session to begin.'));
                }
                return ListView.separated(
                  itemCount: counts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final c = counts[idx];
                    final isCompleted = c.status == 'COMPLETED';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCompleted ? Colors.green.shade100 : Colors.indigo.shade100,
                        child: Icon(
                          isCompleted ? Icons.check : Icons.hourglass_top,
                          color: isCompleted ? Colors.green.shade800 : Colors.indigo.shade800,
                        ),
                      ),
                      title: Text(
                        'Audit Session: ${c.status}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Date: ${c.createdAt.toIso8601String().substring(0, 10)} | Lines: ${c.lines.length} | Notes: ${c.notes ?? 'None'}',
                      ),
                      trailing: FilledButton.tonal(
                        child: Text(isCompleted ? 'View Discrepancies' : 'Scan & Tally'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => StockCountSessionDialog(stockCount: c),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Tab 3: Damaged Stock
  // =========================================================================
  Widget _buildDamagedTab() {
    final damagedState = ref.watch(damagedStockListProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Damaged & Expired Stock Write-offs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Record Damaged'),
                onPressed: () {
                  showDialog(context: context, builder: (_) => const DamagedStockDialog());
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: damagedState.when(
              data: (records) {
                if (records.isEmpty) {
                  return const Center(child: Text('No damaged stock write-off records.'));
                }
                return ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final r = records[idx];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade100,
                        child: Icon(Icons.delete_forever, color: Colors.red.shade800),
                      ),
                      title: Text(
                        '${r.voucherNo}: ${r.productName ?? 'Product'} (${r.reason})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Deducted: ${r.quantity.toStringAsFixed(1)} units | Disposal: ${r.disposalMethod} | ${r.notes ?? ''}',
                      ),
                      trailing: Text(
                        'Loss: BDT ${r.totalLoss.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Tab 4: Stock Reservations
  // =========================================================================
  Widget _buildReservationsTab() {
    final reservationsState = ref.watch(stockReservationsListProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stock Reservations (Zero Overselling)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                icon: const Icon(Icons.bookmark_add),
                label: const Text('Hold Stock'),
                onPressed: () {
                  showDialog(context: context, builder: (_) => const StockReservationDialog());
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: reservationsState.when(
              data: (reservations) {
                if (reservations.isEmpty) {
                  return const Center(child: Text('No active reservations. Available stock equals stock on hand.'));
                }
                return ListView.separated(
                  itemCount: reservations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final res = reservations[idx];
                    final isActive = res.status == 'ACTIVE';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.teal.shade100 : Colors.grey.shade200,
                        child: Icon(
                          Icons.bookmark,
                          color: isActive ? Colors.teal.shade800 : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        '${res.productName ?? 'Variant'} - ${res.quantity.toStringAsFixed(1)} units',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Ref: ${res.referenceType} | Reserved Until: ${res.reservedUntil.toIso8601String().substring(0, 16)}',
                      ),
                      trailing: isActive
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Release'),
                              onPressed: () async {
                                final notifier = ref.read(stockReservationsListProvider.notifier);
                                await notifier.releaseReservation(res.id);
                              },
                            )
                          : Chip(label: Text(res.status)),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Tab 5: Reorder Suggestions & Multi-tier Valuation
  // =========================================================================
  Widget _buildReorderAndValuationTab() {
    final suggestionsState = ref.watch(reorderSuggestionsProvider);
    final valuationState = ref.watch(inventoryValuationProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Valuation Cards
          const Text(
            'Multi-Tier Inventory Valuation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          valuationState.when(
            data: (val) {
              return Row(
                children: [
                  Expanded(
                    child: _buildValCard(
                      'FIFO Valuation',
                      'BDT ${val.totalFifoValuation.toStringAsFixed(2)}',
                      'Batch lot cost based',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildValCard(
                      'WAC Valuation',
                      'BDT ${val.totalWacValuation.toStringAsFixed(2)}',
                      'Weighted average cost',
                      Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildValCard(
                      'Retail Value',
                      'BDT ${val.totalRetailValuation.toStringAsFixed(2)}',
                      'Potential revenue',
                      Colors.green,
                    ),
                  ),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Error loading valuation: $err', style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Automated Replenishment Suggestions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          suggestionsState.when(
            data: (sugs) {
              if (sugs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade800, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Healthy Stock Levels: No products currently below minimum stock thresholds.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sugs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final s = sugs[idx];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber.shade100,
                      child: Icon(Icons.add_shopping_cart, color: Colors.amber.shade900),
                    ),
                    title: Text(
                      '${s.productName} (${s.variantName})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Available: ${s.availableQuantity.toStringAsFixed(1)} | Min Threshold: ${s.minStockLevel.toStringAsFixed(1)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Order +${s.suggestedReorderQty.toStringAsFixed(1)} units',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Est. Cost: BDT ${s.estimatedTotalCost.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading suggestions: $err', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildValCard(String title, String amount, String subtitle, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
