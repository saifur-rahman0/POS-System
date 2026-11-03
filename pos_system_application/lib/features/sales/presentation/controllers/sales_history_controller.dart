import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sales_api_service.dart';
import '../../domain/models/paginated_sales.dart';

enum SalesDateFilter {
  allTime('All Time'),
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 Days');

  final String label;
  const SalesDateFilter(this.label);
}

class SalesFilterState {
  final int page;
  final int pageSize;
  final String searchQuery;
  final String statusFilter; // 'ALL', 'COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED', 'VOIDED'
  final SalesDateFilter dateFilter;

  const SalesFilterState({
    this.page = 1,
    this.pageSize = 15,
    this.searchQuery = '',
    this.statusFilter = 'ALL',
    this.dateFilter = SalesDateFilter.allTime,
  });

  SalesFilterState copyWith({
    int? page,
    int? pageSize,
    String? searchQuery,
    String? statusFilter,
    SalesDateFilter? dateFilter,
  }) {
    return SalesFilterState(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }
}

class SalesFilterNotifier extends StateNotifier<SalesFilterState> {
  SalesFilterNotifier() : super(const SalesFilterState());

  void setSearchQuery(String query) {
    if (state.searchQuery != query) {
      state = state.copyWith(searchQuery: query, page: 1);
    }
  }

  void setStatusFilter(String status) {
    if (state.statusFilter != status) {
      state = state.copyWith(statusFilter: status, page: 1);
    }
  }

  void setDateFilter(SalesDateFilter filter) {
    if (state.dateFilter != filter) {
      state = state.copyWith(dateFilter: filter, page: 1);
    }
  }

  void setPage(int newPage) {
    if (newPage >= 1 && state.page != newPage) {
      state = state.copyWith(page: newPage);
    }
  }

  void reset() {
    state = const SalesFilterState();
  }
}

final salesFilterProvider =
    StateNotifierProvider<SalesFilterNotifier, SalesFilterState>((ref) {
  return SalesFilterNotifier();
});

final salesListProvider =
    FutureProvider.autoDispose<PaginatedSalesModel>((ref) async {
  final filter = ref.watch(salesFilterProvider);
  final apiService = ref.watch(salesApiServiceProvider);

  DateTime? startDate;
  DateTime? endDate;

  final now = DateTime.now();
  switch (filter.dateFilter) {
    case SalesDateFilter.today:
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case SalesDateFilter.yesterday:
      final yesterday = now.subtract(const Duration(days: 1));
      startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
      endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      break;
    case SalesDateFilter.last7Days:
      startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case SalesDateFilter.allTime:
      startDate = null;
      endDate = null;
      break;
  }

  return apiService.getSales(
    page: filter.page,
    pageSize: filter.pageSize,
    search: filter.searchQuery,
    status: filter.statusFilter,
    startDate: startDate,
    endDate: endDate,
  );
});
