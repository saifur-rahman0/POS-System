import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/users_api_service.dart';
import '../../domain/models/staff_user_model.dart';

class UsersState {
  final List<StaffUserModel> users;
  final bool isLoading;
  final String? errorMessage;

  const UsersState({
    this.users = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  UsersState copyWith({
    List<StaffUserModel>? users,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final usersApiServiceProvider = Provider<UsersApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return UsersApiService(client);
});

class UsersController extends StateNotifier<UsersState> {
  final UsersApiService _apiService;

  UsersController(this._apiService) : super(const UsersState());

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _apiService.getUsers();
      state = state.copyWith(
        users: list,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> createStaffUser({
    required String username,
    required String password,
    required String displayName,
    String? email,
    String? phone,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final created = await _apiService.createUser(
        username: username,
        password: password,
        displayName: displayName,
        email: email,
        phone: phone,
        role: role,
      );
      state = state.copyWith(
        users: [...state.users, created],
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> updateStaffUser({
    required String userId,
    String? displayName,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _apiService.updateUser(
        userId: userId,
        displayName: displayName,
        email: email,
        phone: phone,
        role: role,
        isActive: isActive,
      );
      state = state.copyWith(
        users: state.users.map((u) => u.id == userId ? updated : u).toList(),
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await _apiService.changePassword(
        userId: userId,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> toggleUserStatus(String userId, bool currentStatus) async {
    return updateStaffUser(userId: userId, isActive: !currentStatus);
  }
}

final usersControllerProvider =
    StateNotifierProvider<UsersController, UsersState>((ref) {
  final apiService = ref.watch(usersApiServiceProvider);
  return UsersController(apiService);
});
