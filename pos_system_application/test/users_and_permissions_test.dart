import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_client/core/network/api_client.dart';
import 'package:pos_client/features/auth/data/users_api_service.dart';
import 'package:pos_client/features/auth/domain/models/auth_user.dart';
import 'package:pos_client/features/auth/domain/models/staff_user_model.dart';
import 'package:pos_client/features/auth/presentation/controllers/auth_controller.dart';
import 'package:pos_client/features/auth/presentation/controllers/users_controller.dart';
import 'package:pos_client/features/auth/presentation/views/login_screen.dart';
import 'package:pos_client/features/shell/presentation/shell_screen.dart';

class FakeUsersApiService extends UsersApiService {
  FakeUsersApiService() : super(ApiClient());

  final List<StaffUserModel> _mockUsers = [
    const StaffUserModel(
      id: '00000000-0000-0000-0000-000000000003',
      username: 'admin',
      displayName: 'Stall Owner (Admin)',
      email: 'owner@pos.local',
      role: 'ADMIN',
      roleLabel: 'Stall Owner',
      permissions: ['*'],
    ),
    const StaffUserModel(
      id: '00000000-0000-0000-0000-000000000004',
      username: 'manager',
      displayName: 'Store Manager',
      email: 'manager@pos.local',
      role: 'MANAGER',
      roleLabel: 'Store Manager',
      permissions: ['pos:access', 'catalog:read', 'sales:read', 'reports:read'],
    ),
    const StaffUserModel(
      id: '00000000-0000-0000-0000-000000000001',
      username: 'dev_cashier',
      displayName: 'Counter Cashier',
      email: 'cashier@pos.local',
      role: 'CASHIER',
      roleLabel: 'Cashier',
      permissions: ['pos:access', 'customers:read'],
    ),
  ];

  @override
  Future<List<StaffUserModel>> getUsers() async {
    return List<StaffUserModel>.of(_mockUsers);
  }

  @override
  Future<StaffUserModel> createUser({
    required String username,
    required String password,
    required String displayName,
    String? email,
    String? phone,
    required String role,
  }) async {
    final created = StaffUserModel(
      id: 'new-id-123',
      username: username,
      displayName: displayName,
      email: email,
      phone: phone,
      role: role,
      roleLabel: role,
      permissions: role == 'ADMIN' ? ['*'] : ['pos:access'],
    );
    _mockUsers.add(created);
    return created;
  }

  @override
  Future<StaffUserModel> updateUser({
    required String userId,
    String? displayName,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
  }) async {
    final idx = _mockUsers.indexWhere((u) => u.id == userId);
    final old = _mockUsers[idx];
    final updated = StaffUserModel(
      id: old.id,
      username: old.username,
      displayName: displayName ?? old.displayName,
      email: email ?? old.email,
      phone: phone ?? old.phone,
      role: role ?? old.role,
      roleLabel: role ?? old.roleLabel,
      isActive: isActive ?? old.isActive,
      permissions: old.permissions,
    );
    _mockUsers[idx] = updated;
    return updated;
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String newPassword,
  }) async {}

  @override
  Future<void> deactivateUser(String userId) async {
    final idx = _mockUsers.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final old = _mockUsers[idx];
      _mockUsers[idx] = StaffUserModel(
        id: old.id,
        username: old.username,
        displayName: old.displayName,
        email: old.email,
        phone: old.phone,
        role: old.role,
        roleLabel: old.roleLabel,
        isActive: false,
        permissions: old.permissions,
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthUserModel Roles & Permissions Unit Tests', () {
    test('Admin role has unrestricted access', () {
      const admin = AuthUserModel(
        id: '1',
        username: 'admin',
        displayName: 'Owner',
        role: 'ADMIN',
        permissions: ['*'],
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.isManager, isTrue);
      expect(admin.canAccessSection('pos'), isTrue);
      expect(admin.canAccessSection('catalog'), isTrue);
      expect(admin.canAccessSection('purchasing'), isTrue);
      expect(admin.canAccessSection('sales'), isTrue);
      expect(admin.canAccessSection('reports'), isTrue);
      expect(admin.canAccessSection('settings'), isTrue);
      expect(admin.canAccessSection('users'), isTrue);
      expect(admin.roleDisplayName, equals('Stall Owner'));
    });

    test('Cashier role has restricted access', () {
      const cashier = AuthUserModel(
        id: '2',
        username: 'cashier1',
        displayName: 'John Cashier',
        role: 'CASHIER',
        permissions: ['pos:access', 'customers:read'],
      );

      expect(cashier.isAdmin, isFalse);
      expect(cashier.isManager, isFalse);
      expect(cashier.isCashier, isTrue);
      expect(cashier.canAccessSection('pos'), isTrue);
      expect(cashier.canAccessSection('customers'), isTrue);
      expect(cashier.canAccessSection('reports'), isFalse);
      expect(cashier.canAccessSection('settings'), isFalse);
      expect(cashier.canAccessSection('purchasing'), isFalse);
      expect(cashier.roleDisplayName, equals('Cashier'));
    });

    test('Stock keeper role has inventory & catalog access only', () {
      const stockKeeper = AuthUserModel(
        id: '3',
        username: 'stock1',
        displayName: 'Alex Stock',
        role: 'STOCK_KEEPER',
        permissions: ['catalog:read', 'inventory:read', 'purchasing:read', 'transfers:read'],
      );

      expect(stockKeeper.isAdmin, isFalse);
      expect(stockKeeper.isStockKeeper, isTrue);
      expect(stockKeeper.canAccessSection('catalog'), isTrue);
      expect(stockKeeper.canAccessSection('purchasing'), isTrue);
      expect(stockKeeper.canAccessSection('transfers'), isTrue);
      expect(stockKeeper.canAccessSection('pos'), isFalse);
      expect(stockKeeper.canAccessSection('sales'), isFalse);
      expect(stockKeeper.canAccessSection('reports'), isFalse);
      expect(stockKeeper.roleDisplayName, equals('Stock Keeper'));
    });
  });

  group('UsersController State & CRUD Tests', () {
    test('Load staff users, create new staff, and toggle status', () async {
      final fakeApi = FakeUsersApiService();
      final controller = UsersController(fakeApi);

      // Wait for initial load
      await controller.loadUsers();
      expect(controller.state.users.length, equals(3));
      expect(controller.state.users.first.username, equals('admin'));

      // Create new staff
      final success = await controller.createStaffUser(
        username: 'new_cashier',
        password: 'password123',
        displayName: 'New Cashier',
        role: 'CASHIER',
      );
      expect(success, isTrue);
      expect(controller.state.users.length, equals(4));

      // Toggle status
      final toggled = await controller.toggleUserStatus('new-id-123', true);
      expect(toggled, isTrue);
      final updated = controller.state.users.firstWhere((u) => u.id == 'new-id-123');
      expect(updated.isActive, isFalse);
    });
  });

  group('LoginScreen Quick Role Selector Widget Tests', () {
    testWidgets('Renders all 4 demo role chips and switches active role', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for quick demo chips
      expect(find.byKey(const Key('login_chip_owner')), findsOneWidget);
      expect(find.byKey(const Key('login_chip_manager')), findsOneWidget);
      expect(find.byKey(const Key('login_chip_cashier')), findsOneWidget);
      expect(find.byKey(const Key('login_chip_stock')), findsOneWidget);

      // Tap on Manager chip
      await tester.tap(find.byKey(const Key('login_chip_manager')));
      await tester.pumpAndSettle();

      // Username text controller updated to 'manager'
      expect(find.text('manager'), findsWidgets);
    });
  });

  group('ShellScreen Role Badge & Navigation Gating Tests', () {
    testWidgets('Admin sees full navigation destinations and role badge', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            usersApiServiceProvider.overrideWithValue(FakeUsersApiService()),
          ],
          child: const MaterialApp(
            home: ShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default user is Admin / Stall Owner
      expect(find.text('Stall Owner (Admin)'), findsWidgets);
      expect(find.text('POS Register'), findsOneWidget);
      expect(find.text('Catalog & Stock'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
