import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_provider.dart';
import '../../data/auth_api_service.dart';
import '../../domain/models/auth_user.dart';

enum AuthStatus {
  authenticated,
  unauthenticated,
  loading,
  error,
}

class AuthState {
  final AuthStatus status;
  final AuthUserModel? user;
  final BusinessInfoModel? business;
  final String? token;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.business,
    this.token,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    AuthUserModel? user,
    BusinessInfoModel? business,
    String? token,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      business: business ?? this.business,
      token: token ?? this.token,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthApiService(client);
});

class AuthController extends StateNotifier<AuthState> {
  final AuthApiService _apiService;
  final Ref _ref;

  static const _defaultDevUser = AuthUserModel(
    id: '00000000-0000-0000-0000-000000000003',
    username: 'admin',
    displayName: 'Stall Owner (Admin)',
    email: 'owner@pos.local',
    isActive: true,
    role: 'ADMIN',
    permissions: ['*'],
  );

  static const _defaultDevBusiness = BusinessInfoModel(
    id: '00000000-0000-0000-0000-000000000001',
    name: 'Retail POS Store',
    currency: 'BDT',
    timezone: 'Asia/Dhaka',
  );

  AuthController(this._apiService, this._ref)
      : super(const AuthState(
          status: AuthStatus.authenticated,
          user: _defaultDevUser,
          business: _defaultDevBusiness,
          token: 'dev-token',
        ));

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final res = await _apiService.login(username: username, password: password);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: res.user,
        business: res.business,
        token: res.accessToken,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String password,
    required String displayName,
    String? email,
    String? phone,
    String? businessName,
    String? currency,
    String? timezone,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final res = await _apiService.register(
        username: username,
        password: password,
        displayName: displayName,
        email: email,
        phone: phone,
        businessName: businessName,
        currency: currency,
        timezone: timezone,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: res.user,
        business: res.business,
        token: res.accessToken,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void quickDevLogin() {
    switchDemoRole('CASHIER');
  }

  void switchDemoRole(String role) {
    AuthUserModel user;
    switch (role.toUpperCase()) {
      case 'ADMIN':
      case 'OWNER':
        user = const AuthUserModel(
          id: '00000000-0000-0000-0000-000000000003',
          username: 'admin',
          displayName: 'Stall Owner (Admin)',
          email: 'owner@pos.local',
          isActive: true,
          role: 'ADMIN',
          permissions: ['*'],
        );
        break;
      case 'MANAGER':
        user = const AuthUserModel(
          id: '00000000-0000-0000-0000-000000000004',
          username: 'manager',
          displayName: 'Store Manager',
          email: 'manager@pos.local',
          isActive: true,
          role: 'MANAGER',
          permissions: [
            'pos:access', 'pos:discount:custom', 'pos:price_override', 'pos:void_sale',
            'catalog:read', 'catalog:write', 'inventory:read', 'inventory:write', 'inventory:adjust',
            'purchasing:read', 'purchasing:write', 'sales:read', 'sales:refund',
            'shifts:manage', 'expenses:read', 'expenses:write', 'accounting:read',
            'customers:read', 'customers:write', 'transfers:read', 'transfers:write',
            'reports:read', 'settings:read',
          ],
        );
        break;
      case 'STOCK_KEEPER':
      case 'STOCK':
        user = const AuthUserModel(
          id: '00000000-0000-0000-0000-000000000005',
          username: 'stock_keeper',
          displayName: 'Warehouse & Stock Keeper',
          email: 'stock@pos.local',
          isActive: true,
          role: 'STOCK_KEEPER',
          permissions: [
            'catalog:read', 'catalog:write', 'inventory:read', 'inventory:write', 'inventory:adjust',
            'purchasing:read', 'purchasing:write', 'transfers:read', 'transfers:write',
          ],
        );
        break;
      case 'CASHIER':
      default:
        user = const AuthUserModel(
          id: '00000000-0000-0000-0000-000000000001',
          username: 'dev_cashier',
          displayName: 'Counter Cashier',
          email: 'cashier@pos.local',
          isActive: true,
          role: 'CASHIER',
          permissions: [
            'pos:access', 'pos:discount:custom', 'sales:read', 'shifts:manage',
            'customers:read', 'customers:write',
          ],
        );
        break;
    }
    _ref.read(apiClientProvider).setAuthToken('dev-token');
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
      business: _defaultDevBusiness,
      token: 'dev-token',
    );
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    await _apiService.logout();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      user: null,
      business: null,
      token: null,
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final apiService = ref.watch(authApiServiceProvider);
  return AuthController(apiService, ref);
});
