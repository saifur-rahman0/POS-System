import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/sync_api_service.dart';

final syncApiServiceProvider = Provider<SyncApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SyncApiService(apiClient: apiClient);
});

class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? statusMessage;
  final String? errorMessage;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.statusMessage,
    this.errorMessage,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? statusMessage,
    String? errorMessage,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final SyncApiService _apiService;

  SyncNotifier(this._apiService) : super(const SyncState());

  Future<bool> pullDeltas({String? branchId}) async {
    state = state.copyWith(isSyncing: true, errorMessage: null);
    try {
      final res = await _apiService.pullDeltas(
        since: state.lastSyncTime,
        branchId: branchId,
      );
      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: res.serverTime,
        statusMessage:
            'Synced ${res.productsCount} products, ${res.categoriesCount} categories, ${res.customersCount} customers',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSyncing: false, errorMessage: e.toString());
      return false;
    }
  }
}

final syncControllerProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final apiService = ref.watch(syncApiServiceProvider);
  return SyncNotifier(apiService);
});

