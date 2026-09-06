import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:triosuite_invoices/core/network/api_client.dart';
import 'package:triosuite_invoices/core/network/api_exception.dart';
import 'package:triosuite_invoices/core/routing/app_routes.dart';
import 'package:triosuite_invoices/core/storage/secure_store.dart';
import 'package:triosuite_invoices/core/theme/app_theme.dart';
import 'package:triosuite_invoices/features/auth/data/auth_repository.dart';
import 'package:triosuite_invoices/features/auth/domain/app_user.dart';
import 'package:triosuite_invoices/features/auth/domain/token_pair.dart';
import 'package:triosuite_invoices/features/auth/presentation/login_page.dart';
import 'package:triosuite_invoices/features/auth/presentation/session_controller.dart';

/// Keeps tokens in a map instead of the Android Keystore.
class _InMemoryStore extends SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> readAccessToken() async => _values['access'];

  @override
  Future<String?> readRefreshToken() async => _values['refresh'];

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _values['access'] = accessToken;
    _values['refresh'] = refreshToken;
  }

  @override
  Future<void> clearTokens() async => _values.clear();

  @override
  Future<String?> readBaseUrlOverride() async => null;

  @override
  Future<ThemeMode> readThemeMode() async => ThemeMode.light;
}

/// Answers the start-up health probe without a network.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.store, {required super.baseUrl});

  bool healthy = true;

  @override
  Future<bool> checkHealth({String? baseUrlOverride}) async => healthy;
}

/// Fails or succeeds on command, so both login paths can be driven from a test.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(super.api);

  ApiException? failure;
  int loginCalls = 0;
  String? lastUsername;
  String? lastPassword;

  @override
  Future<TokenPair> login({required String username, required String password}) async {
    loginCalls++;
    lastUsername = username;
    lastPassword = password;
    if (failure != null) {
      throw failure!;
    }
    return const TokenPair(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresInSeconds: 1800,
      user: AppUser(id: 1, username: 'admin', fullName: 'System Administrator', role: UserRole.admin),
    );
  }

  @override
  Future<AppUser> me() async => const AppUser(
        id: 1,
        username: 'admin',
        fullName: 'System Administrator',
        role: UserRole.admin,
      );
}

void main() {
  late _InMemoryStore store;
  late _FakeApiClient api;
  late _FakeAuthRepository auth;
  late SessionController session;

  setUp(() {
    store = _InMemoryStore();
    api = _FakeApiClient(store, baseUrl: 'http://localhost:8080');
    auth = _FakeAuthRepository(api);
    session = SessionController(
      authRepository: auth,
      secureStore: store,
      apiClient: api,
    );
    Get.put<SessionController>(session);
  });

  tearDown(Get.reset);

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      getPages: [
        GetPage<void>(name: AppRoutes.login, page: () => const LoginPage()),
        // A successful sign-in replaces this screen with the invoice list. That screen needs a
        // backend, so it is stubbed: what is under test here is that the navigation happens, not
        // what it lands on.
        GetPage<void>(
          name: AppRoutes.invoices,
          page: () => const Scaffold(body: Center(child: Text('Invoice list'))),
        ),
      ],
    ));
    await tester.pump();
  }

  testWidgets('shows the connecting state until the server answers', (tester) async {
    await pumpLogin(tester);

    // bootstrap() has not run, so the controller is still in its initial phase.
    expect(find.text('Connecting to server…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsNothing);
  });

  testWidgets('offers a retry when the server cannot be reached', (tester) async {
    api.healthy = false;
    await pumpLogin(tester);

    await session.bootstrap();
    await tester.pump();

    expect(find.text("Can't reach the server"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Change API address'), findsOneWidget);
  });

  testWidgets('shows the form once the server has answered', (tester) async {
    await pumpLogin(tester);
    await session.bootstrap();
    await tester.pump();

    expect(find.text('Triosuite Invoices'), findsOneWidget);
    expect(find.byKey(const Key('login_username')), findsOneWidget);
    expect(find.byKey(const Key('login_password')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);

    // There is no registration endpoint, so the app must not imply there is one.
    expect(find.textContaining('Sign up'), findsNothing);
    expect(find.textContaining('Create account'), findsNothing);
    expect(find.textContaining('Register'), findsNothing);
  });

  testWidgets('rejects an empty form without calling the API', (tester) async {
    await pumpLogin(tester);
    await session.bootstrap();
    await tester.pump();

    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('Enter your username'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(auth.loginCalls, 0, reason: 'validation must run before any request');
  });

  testWidgets('the password is obscured, and the toggle reveals it', (tester) async {
    await pumpLogin(tester);
    await session.bootstrap();
    await tester.pump();

    EditableText passwordField() => tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('login_password')),
            matching: find.byType(EditableText),
          ),
        );

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byKey(const Key('login_toggle_password')));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);

    await tester.tap(find.byKey(const Key('login_toggle_password')));
    await tester.pump();
    expect(passwordField().obscureText, isTrue);
  });

  testWidgets('shows the server message when the credentials are refused', (tester) async {
    auth.failure = ApiException(
      code: ApiErrorCode.unauthorized,
      message: 'Incorrect username or password',
      status: 401,
    );

    await pumpLogin(tester);
    await session.bootstrap();
    await tester.pump();

    await tester.enterText(find.byKey(const Key('login_username')), 'admin');
    await tester.enterText(find.byKey(const Key('login_password')), 'wrong');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(auth.loginCalls, 1);
    expect(find.byKey(const Key('login_error')), findsOneWidget);
    expect(find.text('Incorrect username or password'), findsOneWidget);
  });

  testWidgets('trims the username and stores the tokens on success', (tester) async {
    await pumpLogin(tester);
    await session.bootstrap();
    await tester.pump();

    await tester.enterText(find.byKey(const Key('login_username')), '  admin  ');
    await tester.enterText(find.byKey(const Key('login_password')), 'Admin#2026');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(auth.lastUsername, 'admin', reason: 'stray whitespace must not reach the API');
    expect(auth.lastPassword, 'Admin#2026', reason: 'the password is sent exactly as typed');
    expect(await store.readAccessToken(), 'access');
    expect(await store.readRefreshToken(), 'refresh');
    expect(session.isSignedIn, isTrue);
    expect(session.isAdmin, isTrue);
    expect(find.text('Invoice list'), findsOneWidget,
        reason: 'a successful sign-in replaces the login screen with the list');
  });
}
