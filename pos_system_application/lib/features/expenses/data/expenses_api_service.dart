import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/account_transfer.dart';
import '../domain/models/ap_aging_report.dart';
import '../domain/models/cash_flow_report.dart';
import '../domain/models/expense.dart';
import '../domain/models/expense_category.dart';
import '../domain/models/financial_account.dart';
import '../domain/models/recurring_expense.dart';

class ExpensesApiService {
  final ApiClient _apiClient;

  ExpensesApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  // =========================================================================
  // Expense Categories
  // =========================================================================
  Future<List<ExpenseCategoryModel>> getCategories({bool? isActive}) async {
    try {
      final qp = <String, dynamic>{};
      if (isActive != null) qp['is_active'] = isActive;

      final res = await _apiClient.dio.get('/expenses/categories', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => ExpenseCategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<ExpenseCategoryModel> createCategory({
    required String name,
    required String code,
    String? description,
    double monthlyBudget = 0.0,
    bool isActive = true,
  }) async {
    try {
      final data = {
        'name': name,
        'code': code,
        if (description != null) 'description': description,
        'monthly_budget': monthlyBudget,
        'is_active': isActive,
      };
      final res = await _apiClient.dio.post('/expenses/categories', data: data);
      return ExpenseCategoryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<ExpenseCategoryModel> updateCategory({
    required String categoryId,
    String? name,
    String? code,
    String? description,
    double? monthlyBudget,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (code != null) data['code'] = code;
      if (description != null) data['description'] = description;
      if (monthlyBudget != null) data['monthly_budget'] = monthlyBudget;
      if (isActive != null) data['is_active'] = isActive;

      final res = await _apiClient.dio.put('/expenses/categories/$categoryId', data: data);
      return ExpenseCategoryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // =========================================================================
  // Financial Accounts
  // =========================================================================
  Future<List<FinancialAccountModel>> getFinancialAccounts({
    String? branchId,
    bool? isActive,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (branchId != null) qp['branch_id'] = branchId;
      if (isActive != null) qp['is_active'] = isActive;

      final res = await _apiClient.dio.get('/financial-accounts', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => FinancialAccountModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<FinancialAccountModel> createFinancialAccount({
    String? branchId,
    required String accountName,
    required String accountType,
    String? accountNumber,
    String? bankName,
    double openingBalance = 0.0,
  }) async {
    try {
      final data = {
        if (branchId != null) 'branch_id': branchId,
        'account_name': accountName,
        'account_type': accountType,
        if (accountNumber != null) 'account_number': accountNumber,
        if (bankName != null) 'bank_name': bankName,
        'opening_balance': openingBalance,
      };
      final res = await _apiClient.dio.post('/financial-accounts', data: data);
      return FinancialAccountModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<AccountTransferModel> transferFunds({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? referenceNo,
    String? note,
  }) async {
    try {
      final data = {
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'amount': amount,
        if (referenceNo != null) 'reference_no': referenceNo,
        if (note != null) 'note': note,
      };
      final res = await _apiClient.dio.post('/financial-accounts/transfers', data: data);
      return AccountTransferModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<List<AccountTransferModel>> getTransfers({String? accountId, int limit = 50}) async {
    try {
      final qp = <String, dynamic>{'limit': limit};
      if (accountId != null) qp['account_id'] = accountId;

      final res = await _apiClient.dio.get('/financial-accounts/transfers', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => AccountTransferModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // =========================================================================
  // Recurring Expenses
  // =========================================================================
  Future<List<RecurringExpenseModel>> getRecurringExpenses({
    String? branchId,
    bool? isActive,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (branchId != null) qp['branch_id'] = branchId;
      if (isActive != null) qp['is_active'] = isActive;

      final res = await _apiClient.dio.get('/expenses/recurring', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => RecurringExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
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
    try {
      final data = {
        if (branchId != null) 'branch_id': branchId,
        'category_id': categoryId,
        if (paymentAccountId != null) 'payment_account_id': paymentAccountId,
        'title': title,
        'amount': amount,
        'frequency': frequency,
        'next_due_date': nextDueDate.toIso8601String().substring(0, 10),
        'auto_post': autoPost,
      };
      final res = await _apiClient.dio.post('/expenses/recurring', data: data);
      return RecurringExpenseModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<List<ExpenseModel>> processDueRecurringExpenses({DateTime? asOfDate}) async {
    try {
      final qp = <String, dynamic>{};
      if (asOfDate != null) qp['as_of_date'] = asOfDate.toIso8601String().substring(0, 10);

      final res = await _apiClient.dio.post('/expenses/recurring/process', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // =========================================================================
  // Expense Records & Vouchers
  // =========================================================================
  Future<List<ExpenseModel>> getExpenses({
    String? branchId,
    String? categoryId,
    String? paymentAccountId,
    String? approvalStatus,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final qp = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (branchId != null) qp['branch_id'] = branchId;
      if (categoryId != null) qp['category_id'] = categoryId;
      if (paymentAccountId != null) qp['payment_account_id'] = paymentAccountId;
      if (approvalStatus != null) qp['approval_status'] = approvalStatus;
      if (startDate != null) qp['start_date'] = startDate.toIso8601String();
      if (endDate != null) qp['end_date'] = endDate.toIso8601String();
      if (search != null && search.isNotEmpty) qp['search'] = search;

      final res = await _apiClient.dio.get('/expenses', queryParameters: qp);
      final list = res.data as List<dynamic>;
      return list.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
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
    try {
      final data = {
        if (branchId != null) 'branch_id': branchId,
        if (category != null) 'category': category,
        if (categoryId != null) 'category_id': categoryId,
        'amount': amount,
        if (note != null) 'note': note,
        if (paymentAccountId != null) 'payment_account_id': paymentAccountId,
        'payment_method': paymentMethod,
        if (payee != null) 'payee': payee,
        if (receiptReference != null) 'receipt_reference': receiptReference,
        'tax_deductible': taxDeductible,
      };
      final res = await _apiClient.dio.post('/expenses', data: data);
      return ExpenseModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<ExpenseModel> approveExpense({
    required String expenseId,
    required String action, // APPROVED or REJECTED
    String? note,
  }) async {
    try {
      final data = {
        'action': action,
        if (note != null) 'note': note,
      };
      final res = await _apiClient.dio.post('/expenses/$expenseId/approve', data: data);
      return ExpenseModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  // =========================================================================
  // Financial Reports
  // =========================================================================
  Future<CashFlowReportModel> getCashFlowReport({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (startDate != null) qp['start_date'] = startDate.toIso8601String().substring(0, 10);
      if (endDate != null) qp['end_date'] = endDate.toIso8601String().substring(0, 10);
      if (branchId != null) qp['branch_id'] = branchId;

      final res = await _apiClient.dio.get('/financial-accounts/reports/cash-flow', queryParameters: qp);
      return CashFlowReportModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }

  Future<APAgeingReportModel> getAPAgeingReport({DateTime? asOfDate}) async {
    try {
      final qp = <String, dynamic>{};
      if (asOfDate != null) qp['as_of_date'] = asOfDate.toIso8601String().substring(0, 10);

      final res = await _apiClient.dio.get('/financial-accounts/reports/ap-aging', queryParameters: qp);
      return APAgeingReportModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _apiClient.handleDioError(e);
    }
  }
}

