import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/transfers_api_service.dart';
import '../../domain/models/stock_transfer.dart';

final transfersApiServiceProvider = Provider<TransfersApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TransfersApiService(apiClient: apiClient);
});

class TransfersState {
  final bool isLoading;
  final List<StockTransferModel> transfers;
  final String? filterStatus;
  final String? errorMessage;

  const TransfersState({
    this.isLoading = false,
    this.transfers = const [],
    this.filterStatus,
    this.errorMessage,
  });

  TransfersState copyWith({
    bool? isLoading,
    List<StockTransferModel>? transfers,
    String? filterStatus,
    String? errorMessage,
  }) {
    return TransfersState(
      isLoading: isLoading ?? this.isLoading,
      transfers: transfers ?? this.transfers,
      filterStatus: filterStatus ?? this.filterStatus,
      errorMessage: errorMessage,
    );
  }
}

class TransfersNotifier extends StateNotifier<TransfersState> {
  final TransfersApiService _apiService;

  TransfersNotifier(this._apiService)
      : super(const TransfersState(isLoading: true)) {
    loadTransfers();
  }

  Future<void> loadTransfers({String? status}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, filterStatus: status);
    try {
      final list = await _apiService.listTransfers(status: status);
      state = state.copyWith(isLoading: false, transfers: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createTransfer({
    required String sourceBranchId,
    required String destinationBranchId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final created = await _apiService.createTransfer(
        sourceBranchId: sourceBranchId,
        destinationBranchId: destinationBranchId,
        items: items,
        notes: notes,
      );
      state = state.copyWith(transfers: [created, ...state.transfers]);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> sendTransfer(String transferId) async {
    try {
      final updated = await _apiService.sendTransfer(transferId);
      state = state.copyWith(
        transfers: state.transfers.map((t) => t.id == transferId ? updated : t).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> receiveTransfer(String transferId) async {
    try {
      final updated = await _apiService.receiveTransfer(transferId);
      state = state.copyWith(
        transfers: state.transfers.map((t) => t.id == transferId ? updated : t).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> cancelTransfer(String transferId) async {
    try {
      final updated = await _apiService.cancelTransfer(transferId);
      state = state.copyWith(
        transfers: state.transfers.map((t) => t.id == transferId ? updated : t).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final transfersListProvider =
    StateNotifierProvider<TransfersNotifier, TransfersState>((ref) {
  final apiService = ref.watch(transfersApiServiceProvider);
  return TransfersNotifier(apiService);
});

