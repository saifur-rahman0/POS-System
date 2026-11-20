import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme.dart';
import '../../../../core/widgets/stat_strip.dart';
import '../controllers/purchasing_controller.dart';
import 'create_purchase_order_dialog.dart';
import 'purchase_order_detail_dialog.dart';
import 'supplier_form_dialog.dart';

class PurchasingScreen extends ConsumerStatefulWidget {
  const PurchasingScreen({super.key});

  @override
  ConsumerState<PurchasingScreen> createState() => _PurchasingScreenState();
}

class _PurchasingScreenState extends ConsumerState<PurchasingScreen> {
  final TextEditingController _supplierSearchController = TextEditingController();
  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
  final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void dispose() {
    _supplierSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Column(
          children: [
            // Top Tab Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Color(0xFF0F766E),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFF0F766E),
                    indicatorWeight: 3,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    tabs: [
                      Tab(
                        icon: Icon(Icons.receipt_long, size: 20),
                        text: 'Purchase Orders',
                      ),
                      Tab(
                        icon: Icon(Icons.local_shipping, size: 20),
                        text: 'Suppliers Directory',
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(purchasesControllerProvider.notifier).refresh();
                          ref.read(suppliersControllerProvider.notifier).refresh();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  _buildOrdersTab(),
                  _buildSuppliersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: PURCHASE ORDERS
  // ---------------------------------------------------------------------------
  Widget _buildOrdersTab() {
    final state = ref.watch(purchasesControllerProvider);
    final notifier = ref.read(purchasesControllerProvider.notifier);
    final paginated = state.paginated;
    final orders = paginated?.items ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header & action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Purchase Orders & Goods Inward',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage purchase orders, stock receiving, variant cost updates, and vendor payments',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                key: const Key('create_purchase_order_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => CreatePurchaseOrderDialog.show(context),
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Create Purchase Order'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Premium Purchasing Stats Strip
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: StatStrip(
              items: [
                StatStripItem(
                  label: 'TOTAL PURCHASE ORDERS',
                  value: '${orders.length}',
                  numericValue: orders.length,
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.accentTeal,
                ),
                StatStripItem(
                  label: 'TOTAL PROCUREMENT COST',
                  value: currencyFmt.format(orders.fold<double>(0.0, (acc, o) => acc + o.total)),
                  numericValue: orders.fold<double>(0.0, (acc, o) => acc + o.total),
                  prefix: '৳ ',
                  decimalDigits: 2,
                  icon: Icons.payments_outlined,
                  color: AppColors.accentPurple,
                ),
                StatStripItem(
                  label: 'DISBURSED TO SUPPLIERS',
                  value: currencyFmt.format(orders.fold<double>(0.0, (acc, o) => acc + o.paidTotal)),
                  numericValue: orders.fold<double>(0.0, (acc, o) => acc + o.paidTotal),
                  prefix: '৳ ',
                  decimalDigits: 2,
                  icon: Icons.check_circle_outline,
                  color: AppColors.accentGreen,
                ),
                StatStripItem(
                  label: 'OUTSTANDING AP DUE',
                  value: currencyFmt.format(orders.fold<double>(0.0, (acc, o) => acc + o.dueBalance)),
                  numericValue: orders.fold<double>(0.0, (acc, o) => acc + o.dueBalance),
                  prefix: '৳ ',
                  decimalDigits: 2,
                  icon: Icons.pending_actions_rounded,
                  color: orders.fold<double>(0.0, (acc, o) => acc + o.dueBalance) > 0 ? AppColors.accentRose : AppColors.accentTeal,
                  badge: orders.fold<double>(0.0, (acc, o) => acc + o.dueBalance) > 0 ? 'DUE' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filter bar (Status filters)
          Row(
            children: [
              FilterChip(
                label: const Text('All Orders'),
                selected: state.statusFilter == null,
                onSelected: (_) => notifier.filterByStatus(null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Ordered (Pending Receipt)'),
                selected: state.statusFilter == 'ORDERED',
                onSelected: (_) => notifier.filterByStatus('ORDERED'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Received'),
                selected: state.statusFilter == 'RECEIVED',
                onSelected: (_) => notifier.filterByStatus('RECEIVED'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Orders Data Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                'No purchase orders found',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => CreatePurchaseOrderDialog.show(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Create First Purchase Order'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor:
                                        WidgetStateProperty.all(Colors.grey.shade50),
                                    columns: const [
                                      DataColumn(label: Text('PO Number')),
                                      DataColumn(label: Text('Supplier')),
                                      DataColumn(label: Text('Date Created')),
                                      DataColumn(label: Text('Items')),
                                      DataColumn(label: Text('Total (৳)')),
                                      DataColumn(label: Text('Paid (৳)')),
                                      DataColumn(label: Text('Due (৳)')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: orders.map((po) {
                                      final isOrdered = po.status == 'ORDERED';
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(po.referenceNo,
                                              style: const TextStyle(fontWeight: FontWeight.w600))),
                                          DataCell(Text(po.supplierName ?? '-')),
                                          DataCell(Text(dateFmt.format(po.createdAt))),
                                          DataCell(Text('${po.items.length}')),
                                          DataCell(Text(currencyFmt.format(po.totalAmount),
                                              style: const TextStyle(fontWeight: FontWeight.w600))),
                                          DataCell(Text(currencyFmt.format(po.paidAmount),
                                              style: const TextStyle(color: Colors.green))),
                                          DataCell(Text(
                                            currencyFmt.format(po.dueAmount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: po.dueAmount > 0 ? Colors.red : Colors.grey,
                                            ),
                                          )),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isOrdered
                                                    ? Colors.amber.shade50
                                                    : Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isOrdered
                                                      ? Colors.amber.shade300
                                                      : Colors.green.shade300,
                                                ),
                                              ),
                                              child: Text(
                                                po.status,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isOrdered
                                                      ? Colors.amber.shade900
                                                      : Colors.green.shade800,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.visibility_outlined, size: 20),
                                                  tooltip: 'View / Receive Order',
                                                  onPressed: () =>
                                                      PurchaseOrderDetailDialog.show(context, po),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),

                            // Footer Pagination
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border:
                                    Border(top: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Page ${paginated?.page ?? 1} of ${paginated?.totalPages ?? 1} (Total: ${paginated?.total ?? 0} orders)',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: (paginated != null && paginated.page > 1)
                                            ? () => notifier.loadPurchases(page: paginated.page - 1)
                                            : null,
                                        child: const Text('Previous'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: (paginated != null &&
                                                paginated.page < paginated.totalPages)
                                            ? () => notifier.loadPurchases(page: paginated.page + 1)
                                            : null,
                                        child: const Text('Next'),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: SUPPLIERS
  // ---------------------------------------------------------------------------
  Widget _buildSuppliersTab() {
    final state = ref.watch(suppliersControllerProvider);
    final notifier = ref.read(suppliersControllerProvider.notifier);
    final paginated = state.paginated;
    final suppliers = paginated?.items ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header & action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suppliers Directory',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Directory of wholesale suppliers, vendors, contact details, and financial balances',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                key: const Key('add_supplier_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => SupplierFormDialog.show(context),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Supplier'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _supplierSearchController,
              decoration: InputDecoration(
                hintText: 'Search suppliers by name or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _supplierSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _supplierSearchController.clear();
                          notifier.search('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) => notifier.search(val),
            ),
          ),
          const SizedBox(height: 16),

          // Suppliers Data Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : suppliers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store_outlined,
                                  size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _supplierSearchController.text.isEmpty
                                    ? 'No suppliers registered'
                                    : 'No suppliers match "${_supplierSearchController.text}"',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => SupplierFormDialog.show(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Supplier'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor:
                                        WidgetStateProperty.all(Colors.grey.shade50),
                                    columns: const [
                                      DataColumn(label: Text('Supplier Name')),
                                      DataColumn(label: Text('Contact Person')),
                                      DataColumn(label: Text('Phone')),
                                      DataColumn(label: Text('Email')),
                                      DataColumn(label: Text('Total Purchased')),
                                      DataColumn(label: Text('Total Paid')),
                                      DataColumn(label: Text('Outstanding Due')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: suppliers.map((sup) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(sup.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600))),
                                          DataCell(Text(sup.contactPerson ?? '-')),
                                          DataCell(Text(sup.phone ?? '-')),
                                          DataCell(Text(sup.email ?? '-')),
                                          DataCell(Text(currencyFmt.format(sup.totalPurchased))),
                                          DataCell(Text(currencyFmt.format(sup.totalPaid),
                                              style: const TextStyle(color: Colors.green))),
                                          DataCell(Text(
                                            currencyFmt.format(sup.outstandingBalance),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: sup.outstandingBalance > 0
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                          )),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: sup.isActive
                                                    ? Colors.green.shade50
                                                    : Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: sup.isActive
                                                      ? Colors.green.shade300
                                                      : Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Text(
                                                sup.isActive ? 'Active' : 'Inactive',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: sup.isActive
                                                      ? Colors.green.shade800
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 20),
                                              tooltip: 'Edit Supplier',
                                              onPressed: () =>
                                                  SupplierFormDialog.show(context, supplier: sup),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),

                            // Footer Pagination
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border:
                                    Border(top: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Page ${paginated?.page ?? 1} of ${paginated?.totalPages ?? 1} (Total: ${paginated?.total ?? 0} suppliers)',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: (paginated != null && paginated.page > 1)
                                            ? () =>
                                                notifier.loadSuppliers(page: paginated.page - 1)
                                            : null,
                                        child: const Text('Previous'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: (paginated != null &&
                                                paginated.page < paginated.totalPages)
                                            ? () =>
                                                notifier.loadSuppliers(page: paginated.page + 1)
                                            : null,
                                        child: const Text('Next'),
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
        ],
      ),
    );
  }
}
