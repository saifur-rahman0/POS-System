import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/customer_controller.dart';
import 'collect_due_dialog.dart';
import 'customer_form_dialog.dart';
import 'customer_ledger_dialog.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersControllerProvider);
    final notifier = ref.read(customersControllerProvider.notifier);
    final paginated = state.paginated;
    final customers = paginated?.items ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Management & Store Credit',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage customer credit limits, outstanding dues, and collect repayments',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => notifier.refresh(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => CustomerFormDialog.show(context),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add Customer'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary KPI Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.people, color: Color(0xFF0F766E), size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Customers',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${paginated?.total ?? 0}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet,
                              color: Colors.red, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Outstanding Dues',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currencyFmt.format(paginated?.totalOutstandingDues ?? 0.0),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search customers by name or phone number...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
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

            // Customer Data Table
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
                    : customers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 56, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'No customers found'
                                      : 'No customers match "${_searchController.text}"',
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
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
                                      DataColumn(label: Text('Customer Name')),
                                      DataColumn(label: Text('Phone')),
                                      DataColumn(
                                          label: Text('Credit Limit', textAlign: TextAlign.right)),
                                      DataColumn(
                                          label: Text('Due Balance', textAlign: TextAlign.right)),
                                      DataColumn(
                                          label:
                                              Text('Available Credit', textAlign: TextAlign.right)),
                                      DataColumn(
                                          label: Text('Total Orders', textAlign: TextAlign.right)),
                                      DataColumn(label: Text('Actions', textAlign: TextAlign.center)),
                                    ],
                                    rows: customers.map((c) {
                                      final hasDue = c.dueBalance > 0;

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: const Color(0xFF0F766E)
                                                      .withValues(alpha: 0.15),
                                                  child: Text(
                                                    c.name.isNotEmpty
                                                        ? c.name[0].toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF0F766E),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  c.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(Text(c.phone ?? '—',
                                              style: const TextStyle(fontSize: 12))),
                                          DataCell(Text(
                                            currencyFmt.format(c.creditLimit),
                                            style: const TextStyle(fontSize: 12),
                                          )),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: hasDue
                                                    ? Colors.red.shade50
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(4),
                                                border: hasDue
                                                    ? Border.all(color: Colors.red.shade200)
                                                    : null,
                                              ),
                                              child: Text(
                                                currencyFmt.format(c.dueBalance),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      hasDue ? FontWeight.bold : FontWeight.normal,
                                                  color: hasDue ? Colors.red.shade800 : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(
                                            currencyFmt.format(c.availableCredit),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.teal.shade800,
                                            ),
                                          )),
                                          DataCell(Text(
                                            '${c.totalSalesCount}',
                                            style: const TextStyle(fontSize: 12),
                                          )),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (hasDue)
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF0F766E),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 10, vertical: 6),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize:
                                                          MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    icon: const Icon(Icons.payments_outlined,
                                                        size: 14),
                                                    label: const Text('Collect',
                                                        style: TextStyle(fontSize: 11)),
                                                    onPressed: () =>
                                                        CollectDueDialog.show(context, customer: c),
                                                  ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(Icons.history_edu, size: 18),
                                                  tooltip: 'Statement / Ledger',
                                                  onPressed: () =>
                                                      CustomerLedgerDialog.show(context, c),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                                  tooltip: 'Edit Profile',
                                                  onPressed: () => CustomerFormDialog.show(
                                                      context,
                                                      customer: c),
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

                              // Pagination Controls
                              if (paginated != null && paginated.totalPages > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Showing ${(paginated.page - 1) * paginated.pageSize + 1} - ${paginated.page * paginated.pageSize > paginated.total ? paginated.total : paginated.page * paginated.pageSize} of ${paginated.total} customers',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chevron_left),
                                            onPressed: paginated.page > 1
                                                ? () => notifier.loadCustomers(
                                                    page: paginated.page - 1)
                                                : null,
                                          ),
                                          Text(
                                            'Page ${paginated.page} of ${paginated.totalPages}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.chevron_right),
                                            onPressed: paginated.page < paginated.totalPages
                                                ? () => notifier.loadCustomers(
                                                    page: paginated.page + 1)
                                                : null,
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
      ),
    );
  }
}
