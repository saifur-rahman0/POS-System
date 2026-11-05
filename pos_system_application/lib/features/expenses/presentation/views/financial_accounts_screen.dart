import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/financial_accounts_controller.dart';
import 'account_transfer_dialog.dart';

class FinancialAccountsScreen extends ConsumerWidget {
  const FinancialAccountsScreen({super.key});

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final bankController = TextEditingController();
    final balanceController = TextEditingController();
    String accountType = 'BANK';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Create Financial Account'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Account Name *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: accountType,
                    decoration: const InputDecoration(labelText: 'Account Type *', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'SAFE', child: Text('Store Safe / Vault')),
                      DropdownMenuItem(value: 'CASH_DRAWER', child: Text('Cash Drawer')),
                      DropdownMenuItem(value: 'BANK', child: Text('Commercial Bank Account')),
                      DropdownMenuItem(value: 'MOBILE_WALLET', child: Text('Mobile Wallet (bKash/Nagad)')),
                      DropdownMenuItem(value: 'PETTY_CASH', child: Text('Petty Cash')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => accountType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (accountType == 'BANK') ...[
                    TextFormField(
                      controller: bankController,
                      decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: numberController,
                      decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Opening Balance (BDT)', border: OutlineInputBorder()),
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
                final opBalance = double.tryParse(balanceController.text.trim()) ?? 0.0;
                await ref.read(financialAccountsProvider.notifier).createAccount(
                  accountName: nameController.text.trim(),
                  accountType: accountType,
                  bankName: bankController.text.trim().isEmpty ? null : bankController.text.trim(),
                  accountNumber: numberController.text.trim().isEmpty ? null : numberController.text.trim(),
                  openingBalance: opBalance,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save Account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(financialAccountsProvider);
    final apAgingAsync = ref.watch(apAgingReportProvider);
    final cashFlowAsync = ref.watch(cashFlowReportProvider);
    final transfersAsync = ref.watch(transfersListProvider);

    final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Screen Header & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Accounts & Treasury',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Liquidity management, inter-account transfers, cash flow, and AP aging',
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const AccountTransferDialog(),
                        );
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Transfer Funds'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => _showAddAccountDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('New Account'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Financial Accounts Grid
            accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No financial accounts set up yet.')),
                    ),
                  );
                }

                final totalLiquidity = accounts.fold<double>(0.0, (sum, a) => sum + a.currentBalance);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Total Liquidity Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F766E).withAlpha(40), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Liquid Capital', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                currencyFmt.format(totalLiquidity),
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${accounts.length} Active Accounts',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Accounts Cards
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: accounts.map((acc) {
                        return SizedBox(
                          width: 280,
                          child: Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F766E).withAlpha(25),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          acc.typeDisplayName,
                                          style: const TextStyle(
                                            color: Color(0xFF0F766E),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        acc.accountType == 'SAFE'
                                            ? Icons.lock
                                            : acc.accountType == 'BANK'
                                                ? Icons.account_balance
                                                : Icons.account_balance_wallet,
                                        size: 20,
                                        color: Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    acc.accountName,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (acc.bankName != null || acc.accountNumber != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${acc.bankName ?? ''} ${acc.accountNumber != null ? '• ${acc.accountNumber}' : ''}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                  const Divider(height: 20),
                                  Text(
                                    currencyFmt.format(acc.currentBalance),
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading accounts: $e')),
            ),
            const SizedBox(height: 32),

            // AP Aging Breakdown Section
            const Text(
              'Accounts Payable (AP) Aging Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            apAgingAsync.when(
              data: (report) {
                return Row(
                  children: report.buckets.map((b) {
                    final isOverdue = b.bucketName.contains('61') || b.bucketName.contains('90');
                    return Expanded(
                      child: Card(
                        elevation: 0,
                        color: isOverdue ? Colors.red.shade50 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isOverdue ? Colors.red.shade200 : Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.bucketName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isOverdue ? Colors.red.shade800 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currencyFmt.format(b.totalAmount),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isOverdue ? Colors.red.shade900 : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${b.count} Pending Invoices',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading AP Aging: $e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 32),

            // Cash Flow Summary Section
            const Text(
              '30-Day Cash Flow Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            cashFlowAsync.when(
              data: (cf) {
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Cash Inflows (Sales)', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(currencyFmt.format(cf.totalCashIn), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.shade300),
                        Column(
                          children: [
                            Text('Cash Outflows (Expenses & POs)', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(currencyFmt.format(cf.totalCashOut), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('Net Cash Flow', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                              currencyFmt.format(cf.netCashFlow),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: cf.netCashFlow >= 0 ? const Color(0xFF0F766E) : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading cash flow: $e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 32),

            // Recent Transfer Audit History
            const Text(
              'Recent Inter-Account Transfers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            transfersAsync.when(
              data: (transfers) {
                if (transfers.isEmpty) {
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: Text('No transfers recorded yet.')),
                    ),
                  );
                }

                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transfers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final t = transfers[idx];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE6FFFA),
                          child: Icon(Icons.swap_horiz, color: Color(0xFF0F766E)),
                        ),
                        title: Text(
                          '${t.fromAccountName ?? "Account"} ➔ ${t.toAccountName ?? "Account"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Ref: ${t.referenceNo ?? "N/A"} • ${dateFmt.format(t.transferDate)} ${t.note != null ? "• ${t.note}" : ""}',
                        ),
                        trailing: Text(
                          currencyFmt.format(t.amount),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading transfers: $e', style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
