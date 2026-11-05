import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/expenses_controller.dart';
import '../controllers/financial_accounts_controller.dart';
import 'expense_form_dialog.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0 = Vouchers, 1 = Categories & Budgets, 2 = Recurring Schedules
  String? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewCategoryDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final budgetController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Expense Category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category Name *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Category Code (e.g. RENT, UTIL) *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monthly Budget (BDT)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final budget = double.tryParse(budgetController.text.trim()) ?? 0.0;
              await ref.read(expenseCategoriesProvider.notifier).createCategory(
                name: nameController.text.trim(),
                code: codeController.text.trim(),
                description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                monthlyBudget: budget,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save Category'),
          ),
        ],
      ),
    );
  }

  void _showNewRecurringDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String? categoryId;
    String? accountId;
    String frequency = 'MONTHLY';
    DateTime nextDueDate = DateTime.now();
    bool autoPost = true;

    final categoriesAsync = ref.read(expenseCategoriesProvider);
    final accountsAsync = ref.read(financialAccountsProvider);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Schedule Recurring Expense'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title / Commitment *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  categoriesAsync.maybeWhen(
                    data: (cats) => DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                      items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setDialogState(() => categoryId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (BDT) *', border: OutlineInputBorder()),
                    validator: (v) => v == null || double.tryParse(v.trim()) == null ? 'Valid amount required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: const InputDecoration(labelText: 'Frequency *', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                      DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                      DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                      DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
                      DropdownMenuItem(value: 'ANNUAL', child: Text('Annual')),
                    ],
                    onChanged: (v) => setDialogState(() => frequency = v ?? 'MONTHLY'),
                  ),
                  const SizedBox(height: 12),
                  accountsAsync.maybeWhen(
                    data: (accs) => DropdownButtonFormField<String>(
                      initialValue: accountId,
                      decoration: const InputDecoration(labelText: 'Payment Account (Optional)', border: OutlineInputBorder()),
                      items: accs.map((a) => DropdownMenuItem(value: a.id, child: Text(a.accountName))).toList(),
                      onChanged: (v) => setDialogState(() => accountId = v),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Auto-post when due'),
                    subtitle: const Text('Automatically generate expense voucher'),
                    value: autoPost,
                    activeThumbColor: const Color(0xFF0F766E),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setDialogState(() => autoPost = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final amt = double.parse(amountController.text.trim());
                await ref.read(recurringExpensesProvider.notifier).createRecurringExpense(
                  categoryId: categoryId!,
                  paymentAccountId: accountId,
                  title: titleController.text.trim(),
                  amount: amt,
                  frequency: frequency,
                  nextDueDate: nextDueDate,
                  autoPost: autoPost,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Create Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesListProvider);
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final recurringAsync = ref.watch(recurringExpensesProvider);

    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header & Tab Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expense Management',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedTab == 0
                            ? 'Vouchers, disbursements & manager approvals'
                            : _selectedTab == 1
                                ? 'Category limits & monthly budget tracking'
                                : 'Recurring operational overhead commitments',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (_selectedTab == 0)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const ExpenseFormDialog(),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Record Expense'),
                      )
                    else if (_selectedTab == 1)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _showNewCategoryDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('New Category'),
                      )
                    else
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F766E),
                              side: const BorderSide(color: Color(0xFF0F766E)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () async {
                              final generated = await ref.read(recurringExpensesProvider.notifier).processDueRecurring();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Processed recurring runner: ${generated.length} vouchers generated.'),
                                    backgroundColor: const Color(0xFF0F766E),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Run Due Now'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: _showNewRecurringDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Schedule Recurring'),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab bar switcher
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(0, 'Expense Vouchers', Icons.receipt_long),
                  ),
                  Expanded(
                    child: _buildTabButton(1, 'Category Budgets', Icons.pie_chart_outline),
                  ),
                  Expanded(
                    child: _buildTabButton(2, 'Recurring Schedules', Icons.schedule),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab 0: Expense Vouchers
            if (_selectedTab == 0) ...[
              // Filter & Search bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by voucher #, payee, or category...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (term) {
                        final current = ref.read(expensesListProvider.notifier).currentFilter;
                        ref.read(expensesListProvider.notifier).loadExpenses(
                          filter: current.copyWith(search: term),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: _statusFilter,
                    hint: const Text('All Statuses'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Statuses')),
                      DropdownMenuItem(value: 'PENDING_APPROVAL', child: Text('Pending Approval')),
                      DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                    ],
                    onChanged: (val) {
                      setState(() => _statusFilter = val);
                      final current = ref.read(expensesListProvider.notifier).currentFilter;
                      ref.read(expensesListProvider.notifier).loadExpenses(
                        filter: current.copyWith(approvalStatus: val),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vouchers Table
              Expanded(
                child: expensesAsync.when(
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return const Center(child: Text('No expense records found.'));
                    }

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        itemCount: expenses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final exp = expenses[idx];
                          final isPending = exp.isPendingApproval;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPending
                                  ? Colors.amber.shade100
                                  : exp.isApproved
                                      ? const Color(0xFFE6FFFA)
                                      : Colors.red.shade100,
                              child: Icon(
                                isPending
                                    ? Icons.hourglass_top
                                    : exp.isApproved
                                        ? Icons.check
                                        : Icons.close,
                                color: isPending
                                    ? Colors.amber.shade900
                                    : exp.isApproved
                                        ? const Color(0xFF0F766E)
                                        : Colors.red.shade900,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  exp.voucherNo ?? 'EXP-VOUCHER',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? Colors.amber.shade50
                                        : exp.isApproved
                                            ? const Color(0xFFE6FFFA)
                                            : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isPending
                                          ? Colors.amber.shade300
                                          : exp.isApproved
                                              ? const Color(0xFF0F766E).withAlpha(80)
                                              : Colors.red.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    exp.approvalStatus,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPending
                                          ? Colors.amber.shade900
                                          : exp.isApproved
                                              ? const Color(0xFF0F766E)
                                              : Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Category: ${exp.category} • Payee: ${exp.payee ?? "General"} • ${dateFmt.format(exp.createdAt)}'
                              '${exp.note != null ? " • Note: ${exp.note}" : ""}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currencyFmt.format(exp.amount),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                if (isPending) ...[
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F766E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: () async {
                                      await ref.read(expensesListProvider.notifier).approveOrReject(
                                        expenseId: exp.id,
                                        action: 'APPROVED',
                                      );
                                    },
                                    child: const Text('Approve'),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      side: BorderSide(color: Colors.red.shade300),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: () async {
                                      await ref.read(expensesListProvider.notifier).approveOrReject(
                                        expenseId: exp.id,
                                        action: 'REJECTED',
                                      );
                                    },
                                    child: const Text('Reject'),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading expenses: $e')),
                ),
              ),
            ]

            // Tab 1: Category Budgets
            else if (_selectedTab == 1) ...[
              Expanded(
                child: categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Center(child: Text('No categories created yet.'));
                    }

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, idx) {
                        final cat = categories[idx];
                        final utilization = cat.budgetUtilization;
                        final isOver = cat.isOverBudget;

                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isOver ? Colors.red.shade300 : Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cat.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(cat.code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Spent: ${currencyFmt.format(cat.currentMonthSpent)}',
                                            style: const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Budget: ${currencyFmt.format(cat.monthlyBudget)}',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: utilization.clamp(0.0, 1.0),
                                        backgroundColor: Colors.grey.shade200,
                                        color: isOver ? Colors.red.shade700 : const Color(0xFF0F766E),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cat.monthlyBudget > 0 ? '${(utilization * 100).toStringAsFixed(1)}% utilized' : 'No budget set',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isOver ? Colors.red.shade800 : Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isOver)
                                      Row(
                                        children: [
                                          Icon(Icons.warning_amber, size: 16, color: Colors.red.shade700),
                                          const SizedBox(width: 4),
                                          Text('Over Budget', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading categories: $e')),
                ),
              ),
            ]

            // Tab 2: Recurring Schedules
            else if (_selectedTab == 2) ...[
              Expanded(
                child: recurringAsync.when(
                  data: (schedules) {
                    if (schedules.isEmpty) {
                      return const Center(child: Text('No recurring schedules configured.'));
                    }

                    final dateOnlyFmt = DateFormat('dd MMM yyyy');

                    return ListView.separated(
                      itemCount: schedules.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final rec = schedules[idx];
                        final isDue = rec.isDueTodayOrOverdue;

                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDue ? Colors.amber.shade300 : Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDue ? Colors.amber.shade100 : const Color(0xFFE6FFFA),
                              child: Icon(Icons.repeat, color: isDue ? Colors.amber.shade900 : const Color(0xFF0F766E)),
                            ),
                            title: Text(rec.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Category: ${rec.categoryName ?? "General"} • Frequency: ${rec.frequency} • Next Due: ${dateOnlyFmt.format(rec.nextDueDate)}'
                              '${rec.autoPost ? " • [Auto-Post Enabled]" : ""}',
                            ),
                            trailing: Text(
                              currencyFmt.format(rec.amount),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading recurring schedules: $e')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
