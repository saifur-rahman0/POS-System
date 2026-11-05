import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/expenses_api_service.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../../domain/models/recurring_expense.dart';

final expensesApiServiceProvider = Provider<ExpensesApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ExpensesApiService(apiClient: apiClient);
});

// ============================================================================
// Expense Vouchers List Controller
// ============================================================================
class ExpensesFilterState {
  final String? branchId;
  final String? categoryId;
  final String? paymentAccountId;
  final String? approvalStatus;
  final String? search;

  const ExpensesFilterState({
    this.branchId,
    this.categoryId,
    this.paymentAccountId,
    this.approvalStatus,
    this.search,
  });

  ExpensesFilterState copyWith({
    String? branchId,
    String? categoryId,
    String? paymentAccountId,
    String? approvalStatus,
    String? search,
  }) {
    return ExpensesFilterState(
      branchId: branchId ?? this.branchId,
      categoryId: categoryId ?? this.categoryId,
      paymentAccountId: paymentAccountId ?? this.paymentAccountId,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      search: search ?? this.search,
    );
  }
}

class ExpensesListNotifier extends StateNotifier<AsyncValue<List<ExpenseModel>>> {
  final ExpensesApiService _apiService;
  ExpensesFilterState _filter = const ExpensesFilterState();

  ExpensesListNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  ExpensesFilterState get currentFilter => _filter;

  Future<void> loadExpenses({ExpensesFilterState? filter}) async {
    if (filter != null) _filter = filter;
    state = const AsyncValue.loading();
    try {
      final expenses = await _apiService.getExpenses(
        branchId: _filter.branchId,
        categoryId: _filter.categoryId,
        paymentAccountId: _filter.paymentAccountId,
        approvalStatus: _filter.approvalStatus,
        search: _filter.search,
      );
      state = AsyncValue.data(expenses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ExpenseModel> createExpense({
    String? branchId,
    String? category,
    String? categoryId,
    required double amount,
    String? note,
    String? paymentAccountId,
    String paymentMethod = 'CASH',
    String? payee,
    String? receiptReference,
    bool taxDeductible = true,
  }) async {
    final exp = await _apiService.createExpense(
      branchId: branchId,
      category: category,
      categoryId: categoryId,
      amount: amount,
      note: note,
      paymentAccountId: paymentAccountId,
      paymentMethod: paymentMethod,
      payee: payee,
      receiptReference: receiptReference,
      taxDeductible: taxDeductible,
    );
    await loadExpenses();
    return exp;
  }

  Future<ExpenseModel> approveOrReject({
    required String expenseId,
    required String action, // APPROVED or REJECTED
    String? note,
  }) async {
    final updated = await _apiService.approveExpense(
      expenseId: expenseId,
      action: action,
      note: note,
    );
    await loadExpenses();
    return updated;
  }
}

final expensesListProvider =
    StateNotifierProvider<ExpensesListNotifier, AsyncValue<List<ExpenseModel>>>((ref) {
  final apiService = ref.watch(expensesApiServiceProvider);
  return ExpensesListNotifier(apiService);
});

// ============================================================================
// Expense Categories Controller
// ============================================================================
class ExpenseCategoriesNotifier extends StateNotifier<AsyncValue<List<ExpenseCategoryModel>>> {
  final ExpensesApiService _apiService;

  ExpenseCategoriesNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = const AsyncValue.loading();
    try {
      final list = await _apiService.getCategories();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ExpenseCategoryModel> createCategory({
    required String name,
    required String code,
    String? description,
    double monthlyBudget = 0.0,
  }) async {
    final cat = await _apiService.createCategory(
      name: name,
      code: code,
      description: description,
      monthlyBudget: monthlyBudget,
    );
    await loadCategories();
    return cat;
  }

  Future<ExpenseCategoryModel> updateCategory({
    required String categoryId,
    String? name,
    String? code,
    String? description,
    double? monthlyBudget,
    bool? isActive,
  }) async {
    final cat = await _apiService.updateCategory(
      categoryId: categoryId,
      name: name,
      code: code,
      description: description,
      monthlyBudget: monthlyBudget,
      isActive: isActive,
    );
    await loadCategories();
    return cat;
  }
}

final expenseCategoriesProvider =
    StateNotifierProvider<ExpenseCategoriesNotifier, AsyncValue<List<ExpenseCategoryModel>>>((ref) {
  final apiService = ref.watch(expensesApiServiceProvider);
  return ExpenseCategoriesNotifier(apiService);
});

// ============================================================================
// Recurring Expenses Controller
// ============================================================================
class RecurringExpensesNotifier extends StateNotifier<AsyncValue<List<RecurringExpenseModel>>> {
  final ExpensesApiService _apiService;

  RecurringExpensesNotifier(this._apiService) : super(const AsyncValue.loading()) {
    loadRecurringExpenses();
  }

  Future<void> loadRecurringExpenses() async {
    state = const AsyncValue.loading();
    try {
      final list = await _apiService.getRecurringExpenses();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<RecurringExpenseModel> createRecurringExpense({
    String? branchId,
    required String categoryId,
    String? paymentAccountId,
    required String title,
    required double amount,
    required String frequency,
    required DateTime nextDueDate,
    bool autoPost = false,
  }) async {
    final item = await _apiService.createRecurringExpense(
      branchId: branchId,
      categoryId: categoryId,
      paymentAccountId: paymentAccountId,
      title: title,
      amount: amount,
      frequency: frequency,
      nextDueDate: nextDueDate,
      autoPost: autoPost,
    );
    await loadRecurringExpenses();
    return item;
  }

  Future<List<ExpenseModel>> processDueRecurring() async {
    final vouchers = await _apiService.processDueRecurringExpenses();
    await loadRecurringExpenses();
    return vouchers;
  }
}

final recurringExpensesProvider =
    StateNotifierProvider<RecurringExpensesNotifier, AsyncValue<List<RecurringExpenseModel>>>((ref) {
  final apiService = ref.watch(expensesApiServiceProvider);
  return RecurringExpensesNotifier(apiService);
});

