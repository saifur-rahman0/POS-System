import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/financial_accounts_controller.dart';
import '../../domain/models/financial_account.dart';

class AccountTransferDialog extends ConsumerStatefulWidget {
  const AccountTransferDialog({super.key});

  @override
  ConsumerState<AccountTransferDialog> createState() => _AccountTransferDialogState();
}

class _AccountTransferDialogState extends ConsumerState<AccountTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _noteController = TextEditingController();

  String? _fromAccountId;
  String? _toAccountId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<FinancialAccountModel> accounts) async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and destination accounts must be different'), backgroundColor: Colors.red),
      );
      return;
    }

    final fromAcc = accounts.firstWhere((a) => a.id == _fromAccountId);
    final amount = double.parse(_amountController.text.trim());
    if (amount > fromAcc.currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance in ${fromAcc.accountName} (Available: ৳${fromAcc.currentBalance.toStringAsFixed(2)})'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(financialAccountsProvider.notifier).transferFunds(
        fromAccountId: _fromAccountId!,
        toAccountId: _toAccountId!,
        amount: amount,
        referenceNo: _refController.text.trim().isEmpty ? null : _refController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer executed successfully with atomic balance update.'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(financialAccountsProvider);
    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: accountsAsync.when(
            data: (accounts) {
              final activeAccounts = accounts.where((a) => a.isActive).toList();

              return Form(
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
                              Icon(Icons.swap_horiz, color: Color(0xFF0F766E), size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Inter-Account Transfer',
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

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // From Account
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _fromAccountId,
                              decoration: const InputDecoration(
                                labelText: 'Transfer From (Source Account) *',
                                prefixIcon: Icon(Icons.arrow_upward, color: Colors.red),
                                border: OutlineInputBorder(),
                              ),
                              items: activeAccounts.map((acc) {
                                return DropdownMenuItem<String>(
                                  value: acc.id,
                                  child: Text('${acc.accountName} (${currencyFmt.format(acc.currentBalance)})'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _fromAccountId = val),
                              validator: (val) => val == null ? 'Select source account' : null,
                            ),
                            const SizedBox(height: 16),

                            // To Account
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _toAccountId,
                              decoration: const InputDecoration(
                                labelText: 'Transfer To (Destination Account) *',
                                prefixIcon: Icon(Icons.arrow_downward, color: Color(0xFF0F766E)),
                                border: OutlineInputBorder(),
                              ),
                              items: activeAccounts.map((acc) {
                                return DropdownMenuItem<String>(
                                  value: acc.id,
                                  child: Text('${acc.accountName} (${currencyFmt.format(acc.currentBalance)})'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _toAccountId = val),
                              validator: (val) => val == null ? 'Select destination account' : null,
                            ),
                            const SizedBox(height: 16),

                            // Amount
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Transfer Amount (BDT) *',
                                prefixIcon: Icon(Icons.attach_money),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Enter transfer amount';
                                final parsed = double.tryParse(val.trim());
                                if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Reference
                            TextFormField(
                              controller: _refController,
                              decoration: const InputDecoration(
                                labelText: 'Bank Slip / Cheque / Ref # (Optional)',
                                prefixIcon: Icon(Icons.tag),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Note
                            TextFormField(
                              controller: _noteController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Transfer Note / Reason',
                                prefixIcon: Icon(Icons.notes),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions
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
                          onPressed: _isSubmitting ? null : () => _submit(accounts),
                          icon: _isSubmitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.swap_horiz),
                          label: const Text('Execute Transfer'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading accounts: $e')),
          ),
        ),
      ),
    );
  }
}
