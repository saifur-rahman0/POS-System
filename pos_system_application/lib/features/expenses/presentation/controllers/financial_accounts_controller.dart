import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/account_transfer.dart';
import '../../domain/models/ap_aging_report.dart';
import '../../domain/models/cash_flow_report.dart';
import '../../domain/models/financial_account.dart';
import 'expenses_controller.dart';

// ============================================================================
// Financial Accounts State Notifier
// ============================================================================
class FinancialAccountsNotifier extends StateNotifier<AsyncValue<List<FinancialAccountModel>>> {
  final Ref _ref;

  FinancialAccountsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadAccounts();
  }

  Future<void> loadAccounts({String? branchId}) async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(expensesApiServiceProvider);
      final accounts = await api.getFinancialAccounts(branchId: branchId);
      state = AsyncValue.data(accounts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<FinancialAccountModel> createAccount({
    String? branchId,
    required String accountName,
    required String accountType,
    String? accountNumber,
    String? bankName,
    double openingBalance = 0.0,
  }) async {
    final api = _ref.read(expensesApiServiceProvider);
    final acc = await api.createFinancialAccount(
      branchId: branchId,
      accountName: accountName,
      accountType: accountType,
      accountNumber: accountNumber,
      bankName: bankName,
      openingBalance: openingBalance,
    );
    await loadAccounts();
    return acc;
  }

  Future<AccountTransferModel> transferFunds({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? referenceNo,
    String? note,
  }) async {
    final api = _ref.read(expensesApiServiceProvider);
    final trf = await api.transferFunds(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      referenceNo: referenceNo,
      note: note,
    );
    await loadAccounts();
    _ref.invalidate(accountTransfersProvider);
    _ref.invalidate(cashFlowReportProvider);
    return trf;
  }
}

final financialAccountsProvider =
    StateNotifierProvider<FinancialAccountsNotifier, AsyncValue<List<FinancialAccountModel>>>((ref) {
  return FinancialAccountsNotifier(ref);
});

// ============================================================================
// Account Transfers List Provider
// ============================================================================
final accountTransfersProvider = FutureProvider<List<AccountTransferModel>>((ref) async {
  final api = ref.watch(expensesApiServiceProvider);
  return api.getTransfers();
});

// ============================================================================
// Financial Reports Providers
// ============================================================================
final cashFlowReportProvider = FutureProvider.autoDispose<CashFlowReportModel>((ref) async {
  final api = ref.watch(expensesApiServiceProvider);
  final now = DateTime.now();
  final startDate = now.subtract(const Duration(days: 30));
  return api.getCashFlowReport(startDate: startDate, endDate: now);
});

final apAgingReportProvider = FutureProvider.autoDispose<APAgeingReportModel>((ref) async {
  final api = ref.watch(expensesApiServiceProvider);
  return api.getAPAgeingReport();
});

