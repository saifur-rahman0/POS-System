import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/expenses_controller.dart';
import '../controllers/financial_accounts_controller.dart';

class ExpenseFormDialog extends ConsumerStatefulWidget {
  const ExpenseFormDialog({super.key});

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _payeeController = TextEditingController();
  final _refController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedAccountId;
  String _selectedMethod = 'CASH';
  bool _taxDeductible = true;
  bool _isSubmitting = false;
  double _currentAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {
        _currentAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _refController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final amount = double.parse(_amountController.text.trim());
      await ref.read(expensesListProvider.notifier).createExpense(
        categoryId: _selectedCategoryId,
        paymentAccountId: _selectedAccountId,
        amount: amount,
        paymentMethod: _selectedMethod,
        payee: _payeeController.text.trim().isEmpty ? null : _payeeController.text.trim(),
        receiptReference: _refController.text.trim().isEmpty ? null : _refController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        taxDeductible: _taxDeductible,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              amount > 5000
                  ? 'Expense voucher created and submitted for supervisor approval.'
                  : 'Expense recorded and payment voucher confirmed.',
            ),
            backgroundColor: amount > 5000 ? Colors.amber.shade900 : const Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record expense: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final accountsAsync = ref.watch(financialAccountsProvider);
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, color: Color(0xFF0F766E), size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Record Expense Voucher',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
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

                // Form Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Category Dropdown
                        categoriesAsync.when(
                          data: (categories) {
                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedCategoryId,
                              decoration: const InputDecoration(
                                labelText: 'Expense Category *',
                                prefixIcon: Icon(Icons.category_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat.id,
                                  child: Text('${cat.name} (${cat.code})'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedCategoryId = val),
                              validator: (val) => val == null ? 'Please select a category' : null,
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error loading categories: $e', style: const TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(height: 16),

                        // Amount
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount (BDT) *',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Enter expense amount';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
                            return null;
                          },
                        ),

                        // Approval Warning Banner if > 5000
                        if (_currentAmount > 5000) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined, color: Colors.amber.shade900),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Payouts over ৳ 5,000 require manager approval before balance deduction.',
                                    style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Payment Account
                        accountsAsync.when(
                          data: (accounts) {
                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedAccountId,
                              decoration: const InputDecoration(
                                labelText: 'Payment / Disbursement Account',
                                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: accounts.map((acc) {
                                return DropdownMenuItem<String>(
                                  value: acc.id,
                                  child: Text('${acc.accountName} (${acc.typeDisplayName} - ${currencyFmt.format(acc.currentBalance)})'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedAccountId = val),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error loading accounts: $e', style: const TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(height: 16),

                        // Payment Method
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            prefixIcon: Icon(Icons.payments_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                            DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer / Cheque')),
                            DropdownMenuItem(value: 'BKASH', child: Text('bKash Merchant')),
                            DropdownMenuItem(value: 'NAGAD', child: Text('Nagad Merchant')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMethod = val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Payee & Receipt Ref
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _payeeController,
                                decoration: const InputDecoration(
                                  labelText: 'Payee / Vendor',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _refController,
                                decoration: const InputDecoration(
                                  labelText: 'Bill / Memo Ref #',
                                  prefixIcon: Icon(Icons.tag),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Note
                        TextFormField(
                          controller: _noteController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Purpose / Notes',
                            prefixIcon: Icon(Icons.notes),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tax Deductible
                        CheckboxListTile(
                          title: const Text('Tax Deductible Business Expense'),
                          subtitle: const Text('Include in deductible operational expense audits'),
                          value: _taxDeductible,
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF0F766E),
                          onChanged: (val) => setState(() => _taxDeductible = val ?? true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_currentAmount > 5000 ? 'Submit for Approval' : 'Record Payout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
