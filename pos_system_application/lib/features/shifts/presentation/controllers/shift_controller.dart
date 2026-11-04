import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/shifts_api_service.dart';
import '../../domain/models/paginated_shifts.dart';
import '../../domain/models/register_shift.dart';
import '../../domain/models/z_report.dart';

final shiftsApiServiceProvider = Provider<ShiftsApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ShiftsApiService(apiClient: apiClient);
});

class CurrentShiftNotifier extends StateNotifier<AsyncValue<RegisterShiftModel?>> {
  final ShiftsApiService _apiService;

  CurrentShiftNotifier(this._apiService, [RegisterShiftModel? initialShift])
      : super(initialShift != null ? AsyncValue.data(initialShift) : const AsyncValue.loading()) {
    if (initialShift == null) {
      loadCurrentShift();
    }
  }

  Future<void> loadCurrentShift({String? branchId}) async {
    state = const AsyncValue.loading();
    try {
      final shift = await _apiService.getCurrentShift(branchId: branchId);
      state = AsyncValue.data(shift);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<RegisterShiftModel> openShift({
    required double openingCash,
    String? notes,
    String? branchId,
    String? deviceId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final shift = await _apiService.openShift(
        openingCash: openingCash,
        notes: notes,
        branchId: branchId,
        deviceId: deviceId,
      );
      state = AsyncValue.data(shift);
      return shift;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<ShiftCashTransactionModel> recordCashIn({
    String? shiftId,
    required double amount,
    required String reason,
    String? notes,
  }) async {
    final targetId = shiftId ?? state.value?.id;
    if (targetId == null) {
      throw Exception('No active shift open');
    }

    final tx = await _apiService.recordCashIn(
      shiftId: targetId,
      amount: amount,
      reason: reason,
      notes: notes,
    );
    // Reload updated drawer balance
    await loadCurrentShift();
    return tx;
  }

  Future<ShiftCashTransactionModel> recordCashOut({
    String? shiftId,
    required double amount,
    required String reason,
    String? notes,
  }) async {
    final targetId = shiftId ?? state.value?.id;
    if (targetId == null) {
      throw Exception('No active shift open');
    }

    final tx = await _apiService.recordCashOut(
      shiftId: targetId,
      amount: amount,
      reason: reason,
      notes: notes,
    );
    // Reload updated drawer balance
    await loadCurrentShift();
    return tx;
  }

  Future<RegisterShiftModel> closeShift({
    String? shiftId,
    required double closingCashCounted,
    String? notes,
    Map<String, int> denominations = const {},
  }) async {
    final targetId = shiftId ?? state.value?.id;
    if (targetId == null) {
      throw Exception('No active shift open to close');
    }

    try {
      final closedShift = await _apiService.closeShift(
        shiftId: targetId,
        closingCashCounted: closingCashCounted,
        notes: notes,
        denominations: denominations,
      );
      // State is now null because no active open shift exists
      state = const AsyncValue.data(null);
      return closedShift;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final currentShiftProvider =
    StateNotifierProvider<CurrentShiftNotifier, AsyncValue<RegisterShiftModel?>>((ref) {
  final apiService = ref.watch(shiftsApiServiceProvider);
  return CurrentShiftNotifier(apiService);
});

// Shift History State
class ShiftHistoryState {
  final bool isLoading;
  final String? errorMessage;
  final PaginatedShiftsModel? paginated;
  final int currentPage;

  const ShiftHistoryState({
    this.isLoading = false,
    this.errorMessage,
    this.paginated,
    this.currentPage = 1,
  });

  ShiftHistoryState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    PaginatedShiftsModel? paginated,
    int? currentPage,
  }) {
    return ShiftHistoryState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      paginated: paginated ?? this.paginated,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class ShiftHistoryNotifier extends StateNotifier<ShiftHistoryState> {
  final ShiftsApiService _apiService;

  ShiftHistoryNotifier(this._apiService) : super(const ShiftHistoryState()) {
    loadShifts();
  }

  Future<void> loadShifts({int page = 1, int pageSize = 20, String? status}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _apiService.listShifts(
        page: page,
        pageSize: pageSize,
        status: status,
      );
      state = state.copyWith(
        isLoading: false,
        paginated: res,
        currentPage: page,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<ZReportModel> fetchZReport(String shiftId) async {
    return await _apiService.getZReport(shiftId: shiftId);
  }
}

final shiftHistoryProvider =
    StateNotifierProvider<ShiftHistoryNotifier, ShiftHistoryState>((ref) {
  final apiService = ref.watch(shiftsApiServiceProvider);
  return ShiftHistoryNotifier(apiService);
});
