import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../expenses/presentation/controllers/expenses_controller.dart';
import '../../../expenses/presentation/controllers/financial_accounts_controller.dart';
import '../../../purchasing/presentation/controllers/purchasing_controller.dart';
import '../../domain/models/pos_transaction.dart';
import 'sales_history_controller.dart';

// ============================================================================
// Filter Notifier
// ============================================================================
class TransactionFilterNotifier extends StateNotifier<TransactionFilterState> {
  TransactionFilterNotifier() : super(const TransactionFilterState());

  void setTypeFilter(PosTransactionType? type) {
    if (type == null) {
      state = state.copyWith(clearTypeFilter: true);
    } else {
      state = state.copyWith(typeFilter: type);
    }
  }

  void setDirectionFilter(TransactionDirection? dir) {
    if (dir == null) {
      state = state.copyWith(clearDirectionFilter: true);
    } else {
      state = state.copyWith(directionFilter: dir);
    }
  }

  void setPaymentMethodFilter(String method) {
    state = state.copyWith(paymentMethodFilter: method);
  }

  void setDateFilter(TransactionDateFilter filter, {DateTimeRange? customRange}) {
    if (customRange != null) {
      state = state.copyWith(
        dateFilter: filter,
        customDateRange: customRange,
      );
    } else {
      state = state.copyWith(
        dateFilter: filter,
        clearCustomDateRange: true,
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void resetFilters() {
    state = const TransactionFilterState();
  }
}

final transactionFilterProvider =
    StateNotifierProvider<TransactionFilterNotifier, TransactionFilterState>((ref) {
  return TransactionFilterNotifier();
});

// ============================================================================
// All Transactions Master Aggregator
// ============================================================================
final allTransactionsProvider = Provider<AsyncValue<List<PosTransactionModel>>>((ref) {
  final salesAsync = ref.watch(salesListProvider);
  final purchasesState = ref.watch(purchasesControllerProvider);
  final expensesAsync = ref.watch(expensesListProvider);
  final transfersAsync = ref.watch(accountTransfersProvider);

  // If initial load of sales is loading and others haven't loaded yet
  if (salesAsync.isLoading &&
      purchasesState.isLoading &&
      expensesAsync.isLoading &&
      transfersAsync.isLoading) {
    return const AsyncValue.loading();
  }

  final List<PosTransactionModel> merged = [];

  // 1. Sales
  final sales = salesAsync.valueOrNull?.items ?? [];
  for (final s in sales) {
    merged.add(PosTransactionModel.fromSaleSummary(s));

    // Also extract customer payment if paid
    if (s.paidTotal > 0 && s.status.toUpperCase() == 'COMPLETED') {
      merged.add(PosTransactionModel(
        id: 'PAY-SALE-${s.id}',
        type: PosTransactionType.payment,
        direction: TransactionDirection.inflow,
        referenceNo: 'PAY-${s.receiptNo}',
        partyName: (s.customerName != null && s.customerName!.trim().isNotEmpty)
            ? 'Customer: ${s.customerName}'
            : 'Walk-in Collection',
        amount: s.paidTotal,
        paidAmount: s.paidTotal,
        paymentMethod: 'CASH / TENDER',
        status: 'CONFIRMED',
        timestamp: s.createdAt,
        itemCount: 1,
        note: 'Customer tender collection for ${s.receiptNo}',
      ));
    }
  }

  // 2. Purchases & Purchase Payments
  final purchases = purchasesState.paginated?.items ?? [];
  for (final p in purchases) {
    merged.add(PosTransactionModel.fromPurchaseOrder(p));

    // Extract individual payments made for this PO
    for (final pay in p.payments) {
      merged.add(PosTransactionModel.fromPurchasePayment(
        pay,
        referenceNo: p.referenceNo,
        supplierName: p.supplierName,
      ));
    }
  }

  // 3. Expenses
  final expenses = expensesAsync.valueOrNull ?? [];
  for (final e in expenses) {
    merged.add(PosTransactionModel.fromExpense(e));
  }

  // 4. Account Transfers
  final transfers = transfersAsync.valueOrNull ?? [];
  for (final t in transfers) {
    merged.add(PosTransactionModel.fromTransfer(t));
  }

  // Sort chronological descending (newest first)
  merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return AsyncValue.data(merged);
});

// ============================================================================
// Filtered Transactions Provider
// ============================================================================
final filteredTransactionsProvider = Provider<List<PosTransactionModel>>((ref) {
  final allTxns = ref.watch(allTransactionsProvider).valueOrNull ?? [];
  final filter = ref.watch(transactionFilterProvider);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final last7DaysStart = todayStart.subtract(const Duration(days: 7));
  final thisMonthStart = DateTime(now.year, now.month, 1);

  return allTxns.where((txn) {
    // 1. Filter by Type
    if (filter.typeFilter != null && txn.type != filter.typeFilter) {
      return false;
    }

    // 2. Filter by Direction
    if (filter.directionFilter != null && txn.direction != filter.directionFilter) {
      return false;
    }

    // 3. Filter by Payment Method
    if (filter.paymentMethodFilter != 'ALL') {
      final method = txn.paymentMethod.toUpperCase();
      final filterMethod = filter.paymentMethodFilter.toUpperCase();
      if (!method.contains(filterMethod)) {
        return false;
      }
    }

    // 4. Filter by Date
    if (filter.customDateRange != null) {
      final start = filter.customDateRange!.start;
      final end = filter.customDateRange!.end.add(const Duration(days: 1));
      if (txn.timestamp.isBefore(start) || txn.timestamp.isAfter(end)) {
        return false;
      }
    } else {
      switch (filter.dateFilter) {
        case TransactionDateFilter.today:
          if (txn.timestamp.isBefore(todayStart)) return false;
          break;
        case TransactionDateFilter.yesterday:
          if (txn.timestamp.isBefore(yesterdayStart) ||
              txn.timestamp.isAfter(todayStart)) {
            return false;
          }
          break;
        case TransactionDateFilter.last7Days:
          if (txn.timestamp.isBefore(last7DaysStart)) return false;
          break;
        case TransactionDateFilter.thisMonth:
          if (txn.timestamp.isBefore(thisMonthStart)) return false;
          break;
        case TransactionDateFilter.allTime:
          break;
      }
    }

    // 5. Filter by Search Query
    if (filter.searchQuery.trim().isNotEmpty) {
      final q = filter.searchQuery.toLowerCase().trim();
      final refMatch = txn.referenceNo.toLowerCase().contains(q);
      final partyMatch = txn.partyName.toLowerCase().contains(q);
      final methodMatch = txn.paymentMethod.toLowerCase().contains(q);
      final noteMatch = txn.note?.toLowerCase().contains(q) ?? false;
      if (!refMatch && !partyMatch && !methodMatch && !noteMatch) {
        return false;
      }
    }

    return true;
  }).toList();
});

// ============================================================================
// Aggregated KPIs Provider
// ============================================================================
final transactionKpisProvider = Provider<TransactionKpis>((ref) {
  final txns = ref.watch(filteredTransactionsProvider);
  return TransactionKpis.fromTransactions(txns);
});

// ============================================================================
// Transactions Hub Controller (Actions & Utilities)
// ============================================================================
class TransactionsHubController {
  final Ref _ref;

  TransactionsHubController(this._ref);

  void refreshAll() {
    _ref.invalidate(salesListProvider);
    _ref.read(purchasesControllerProvider.notifier).refresh();
    _ref.read(expensesListProvider.notifier).loadExpenses();
    _ref.invalidate(accountTransfersProvider);
  }

  /// Generate CSV string for export
  String generateCsv(List<PosTransactionModel> txns) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln(
        'Transaction ID,Type,Direction,Reference No,Party / Name,Amount,Paid Amount,Due Amount,Payment Method,Status,Date,Note');

    for (final t in txns) {
      final dateStr = t.timestamp.toIso8601String();
      final partyClean = t.partyName.replaceAll('"', '""');
      final noteClean = (t.note ?? '').replaceAll('"', '""');
      final refClean = t.referenceNo.replaceAll('"', '""');

      buffer.writeln(
          '"${t.id}","${t.type.label}","${t.direction.label}","$refClean","$partyClean",${t.amount.toStringAsFixed(2)},${(t.paidAmount ?? 0).toStringAsFixed(2)},${(t.dueAmount ?? 0).toStringAsFixed(2)},"${t.paymentMethod}","${t.status}","$dateStr","$noteClean"');
    }

    return buffer.toString();
  }
}

final transactionsHubControllerProvider = Provider<TransactionsHubController>((ref) {
  return TransactionsHubController(ref);
});

