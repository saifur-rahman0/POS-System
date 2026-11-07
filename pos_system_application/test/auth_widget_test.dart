import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/core/network/api_client.dart';
import 'package:pos_client/features/auth/data/auth_api_service.dart';
import 'package:pos_client/features/auth/domain/models/auth_user.dart';
import 'package:pos_client/features/auth/presentation/controllers/auth_controller.dart';
import 'package:pos_client/features/auth/presentation/views/login_screen.dart';
import 'package:pos_client/features/auth/presentation/views/register_screen.dart';

class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService() : super(ApiClient());

  @override
  Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    if (username == 'bad_user') {
      throw ApiException(message: 'Invalid credentials', statusCode: 401);
    }
    return const AuthResponseModel(
      accessToken: 'test-token-123',
      user: AuthUserModel(
        id: 'usr-1',
        username: 'test_user',
        displayName: 'Test User',
      ),
      business: BusinessInfoModel(
        id: 'biz-1',
        name: 'Test Business',
      ),
    );
  }

  @override
  Future<AuthResponseModel> register({
    required String username,
    required String password,
    required String displayName,
    String? email,
    String? phone,
    String? businessName,
    String? currency,
    String? timezone,
  }) async {
    return AuthResponseModel(
      accessToken: 'test-reg-token',
      user: AuthUserModel(
        id: 'usr-new',
        username: username,
        displayName: displayName,
        email: email,
      ),
      business: BusinessInfoModel(
        id: 'biz-new',
        name: businessName ?? 'Retail Store',
      ),
    );
  }

  @override
  Future<void> logout() async {}
}

void main() {
  group('Auth Domain Models & Serialization Tests', () {
    test('AuthUserModel serialization roundtrip', () {
      const model = AuthUserModel(
        id: 'usr-1',
        username: 'john_doe',
        displayName: 'John Doe',
        email: 'john@example.com',
        phone: '01700000000',
        isActive: true,
      );

      final json = model.toJson();
      final parsed = AuthUserModel.fromJson(json);

      expect(parsed.id, 'usr-1');
      expect(parsed.username, 'john_doe');
      expect(parsed.displayName, 'John Doe');
      expect(parsed.email, 'john@example.com');
      expect(parsed.phone, '01700000000');
      expect(parsed.isActive, isTrue);
    });

    test('BusinessInfoModel serialization roundtrip', () {
      const model = BusinessInfoModel(
        id: 'biz-1',
        name: 'Superstore Gulshan',
        currency: 'BDT',
        timezone: 'Asia/Dhaka',
      );

      final json = model.toJson();
      final parsed = BusinessInfoModel.fromJson(json);

      expect(parsed.id, 'biz-1');
      expect(parsed.name, 'Superstore Gulshan');
      expect(parsed.currency, 'BDT');
      expect(parsed.timezone, 'Asia/Dhaka');
    });

    test('AuthResponseModel fromJson parsing', () {
      final json = {
        'access_token': 'jwt.token.here',
        'token_type': 'bearer',
        'user': {
          'id': 'u-1',
          'username': 'admin',
          'display_name': 'Administrator',
          'is_active': true,
        },
        'business': {
          'id': 'b-1',
          'name': 'Mega Mall',
          'currency': 'BDT',
        },
      };

      final res = AuthResponseModel.fromJson(json);
      expect(res.accessToken, 'jwt.token.here');
      expect(res.user.username, 'admin');
      expect(res.business.name, 'Mega Mall');
    });
  });

  group('AuthController Unit Tests', () {
    test('Initial state is authenticated with dev cashier', () {
      final container = ProviderContainer(
        overrides: [
          authApiServiceProvider.overrideWithValue(FakeAuthApiService()),
        ],
      );

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.username, 'dev_cashier');
      expect(state.token, 'dev-token');
    });

    test('Logout transitions state to unauthenticated', () async {
      final container = ProviderContainer(
        overrides: [
          authApiServiceProvider.overrideWithValue(FakeAuthApiService()),
        ],
      );

      await container.read(authControllerProvider.notifier).logout();
      final state = container.read(authControllerProvider);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
      expect(state.token, isNull);
    });

    test('Quick dev login restores dev cashier', () async {
      final container = ProviderContainer(
        overrides: [
          authApiServiceProvider.overrideWithValue(FakeAuthApiService()),
        ],
      );

      await container.read(authControllerProvider.notifier).logout();
      expect(container.read(authControllerProvider).status, AuthStatus.unauthenticated);

      container.read(authControllerProvider.notifier).quickDevLogin();
      final state = container.read(authControllerProvider);

      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.username, 'dev_cashier');
    });

    test('Login with valid credentials succeeds', () async {
      final container = ProviderContainer(
        overrides: [
          authApiServiceProvider.overrideWithValue(FakeAuthApiService()),
        ],
      );

      final ok = await container
          .read(authControllerProvider.notifier)
          .login(username: 'test_user', password: 'password123');

      expect(ok, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.username, 'test_user');
      expect(state.token, 'test-token-123');
    });

    test('Login with invalid credentials fails and sets error', () async {
      final container = ProviderContainer(
        overrides: [
          authApiServiceProvider.overrideWithValue(FakeAuthApiService()),
        ],
      );

      final ok = await container
          .read(authControllerProvider.notifier)
          .login(username: 'bad_user', password: 'wrongpassword');

      expect(ok, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, contains('Invalid credentials'));
    });
  });

  group('Login & Register Screen Widget Tests', () {
    Widget createTestWidget({required Widget child}) {
      return ProviderScope(
        overrides: [
          authApiServiceProvider.overrideWithValue(FakeAuthApiService()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: child,
        ),
      );
    }

    testWidgets('LoginScreen renders fields, quick cashier button, and register link',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(createTestWidget(child: const LoginScreen()));
      await tester.pumpAndSettle();

      // Verify header and fields
      expect(find.text('Retail POS Terminal'), findsOneWidget);
      expect(find.byKey(const Key('login_username_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('quick_dev_login_button')), findsOneWidget);
      expect(find.byKey(const Key('go_to_register_button')), findsOneWidget);

      // Tap Register link to navigate to RegisterScreen
      await tester.tap(find.byKey(const Key('go_to_register_button')));
      await tester.pumpAndSettle();

      // Verify RegisterScreen is opened
      expect(find.byKey(const Key('register_business_name_field')), findsOneWidget);
      expect(find.byKey(const Key('register_display_name_field')), findsOneWidget);
      expect(find.byKey(const Key('register_username_field')), findsOneWidget);
      expect(find.byKey(const Key('register_password_field')), findsOneWidget);
      expect(find.byKey(const Key('register_confirm_password_field')), findsOneWidget);
      expect(find.byKey(const Key('register_submit_button')), findsOneWidget);
    });

    testWidgets('RegisterScreen validates required fields on empty submit',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(createTestWidget(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      // Submit empty form
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      // Verify validation error messages
      expect(find.text('Please enter store name'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Min 3 chars'), findsOneWidget);
    });
  });
}

