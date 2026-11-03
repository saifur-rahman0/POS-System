import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/customer.dart';
import '../controllers/customer_controller.dart';
import 'customer_form_dialog.dart';

class CustomerSelectionDialog extends ConsumerStatefulWidget {
  final String? currentCustomerId;

  const CustomerSelectionDialog({super.key, this.currentCustomerId});

  static Future<CustomerModel?> show(BuildContext context, {String? currentCustomerId}) {
    return showDialog<CustomerModel?>(
      context: context,
      builder: (_) => CustomerSelectionDialog(currentCustomerId: currentCustomerId),
    );
  }

  @override
  ConsumerState<CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends ConsumerState<CustomerSelectionDialog> {
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
    final customers = state.paginated?.items ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_search_outlined, color: Color(0xFF0F766E), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Select Customer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search + Add Button Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone...',
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
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (val) => notifier.search(val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                    onPressed: () async {
                      final newCust = await CustomerFormDialog.show(context);
                      if (newCust != null && context.mounted) {
                        Navigator.of(context).pop(newCust);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Walk-in option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_off_outlined, size: 20, color: Colors.grey),
                ),
                title: const Text(
                  'Walk-in Customer (General / Anonymous)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: const Text(
                  'Cash/Card immediate sale only, no store credit allowed',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: widget.currentCustomerId == null
                    ? const Icon(Icons.check_circle, color: Color(0xFF0F766E))
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                onTap: () {
                  // Returning null indicates Walk-in customer
                  Navigator.of(context).pop(null);
                },
              ),
              const Divider(height: 20),

              // Customer List
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : customers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'No registered customers found'
                                      : 'No customers match "${_searchController.text}"',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: customers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final c = customers[index];
                              final isSelected = c.id == widget.currentCustomerId;

                              return InkWell(
                                onTap: () => Navigator.of(context).pop(c),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0F766E).withValues(alpha: 0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF0F766E)
                                          : Colors.grey.shade200,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(0xFF0F766E)
                                            .withValues(alpha: 0.15),
                                        child: Text(
                                          c.name.isNotEmpty
                                              ? c.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Color(0xFF0F766E),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    c.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isSelected) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.check_circle,
                                                      color: Color(0xFF0F766E), size: 16),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              c.phone ?? 'No phone',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Financial metrics badges
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (c.dueBalance > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.red.shade200),
                                              ),
                                              child: Text(
                                                'Due: ${currencyFmt.format(c.dueBalance)}',
                                                style: TextStyle(
                                                  color: Colors.red.shade800,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              'No Dues',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Avail Credit: ${currencyFmt.format(c.availableCredit)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

