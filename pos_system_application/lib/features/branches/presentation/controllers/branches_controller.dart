import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/branches_api_service.dart';
import '../../domain/models/branch.dart';

final branchesApiServiceProvider = Provider<BranchesApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BranchesApiService(apiClient: apiClient);
});

class BranchesState {
  final bool isLoading;
  final List<BranchModel> branches;
  final String? errorMessage;

  const BranchesState({
    this.isLoading = false,
    this.branches = const [],
    this.errorMessage,
  });

  BranchesState copyWith({
    bool? isLoading,
    List<BranchModel>? branches,
    String? errorMessage,
  }) {
    return BranchesState(
      isLoading: isLoading ?? this.isLoading,
      branches: branches ?? this.branches,
      errorMessage: errorMessage,
    );
  }
}

class BranchesNotifier extends StateNotifier<BranchesState> {
  final BranchesApiService _apiService;
  final Ref _ref;

  BranchesNotifier(this._apiService, this._ref)
      : super(const BranchesState(isLoading: true)) {
    loadBranches();
  }

  Future<void> loadBranches() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _apiService.getBranches();
      state = state.copyWith(isLoading: false, branches: list);

      // If active branch is not set, initialize to the first active branch
      final active = _ref.read(activeBranchProvider);
      if (active == null && list.isNotEmpty) {
        final defaultBranch = list.firstWhere(
          (b) => b.isActive,
          orElse: () => list.first,
        );
        _ref.read(activeBranchProvider.notifier).state = defaultBranch;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createBranch({
    required String name,
    String? code,
    String? address,
    String? phone,
    bool isActive = true,
  }) async {
    try {
      final created = await _apiService.createBranch(
        name: name,
        code: code,
        address: address,
        phone: phone,
        isActive: isActive,
      );
      state = state.copyWith(branches: [created, ...state.branches]);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateBranch(
    String branchId, {
    String? name,
    String? code,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    try {
      final updated = await _apiService.updateBranch(
        branchId,
        name: name,
        code: code,
        address: address,
        phone: phone,
        isActive: isActive,
      );
      state = state.copyWith(
        branches: state.branches.map((b) => b.id == branchId ? updated : b).toList(),
      );

      // If this was active branch, update active branch as well
      final active = _ref.read(activeBranchProvider);
      if (active?.id == branchId) {
        _ref.read(activeBranchProvider.notifier).state = updated;
      }

      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final branchesListProvider =
    StateNotifierProvider<BranchesNotifier, BranchesState>((ref) {
  final apiService = ref.watch(branchesApiServiceProvider);
  return BranchesNotifier(apiService, ref);
});

final activeBranchProvider = StateProvider<BranchModel?>((ref) => null);

