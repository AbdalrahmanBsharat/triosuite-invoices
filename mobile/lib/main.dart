import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_pages.dart';
import 'core/routing/app_routes.dart';
import 'core/storage/secure_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/invoices/data/catalog_repository.dart';
import 'features/invoices/data/invoice_repository.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/presentation/app_data_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Two things have to be read from storage before the first frame: the API address, so the very
  // first request goes to the right place, and the theme, so the app does not open in the wrong
  // one and then flip.
  final store = SecureStore();
  final baseUrl = await store.readBaseUrlOverride() ?? AppConfig.buildTimeBaseUrl;

  _registerDependencies(store, baseUrl);

  final themeController = Get.find<ThemeController>();
  await themeController.load();

  runApp(TriosuiteInvoicesApp(initialThemeMode: themeController.mode.value));
}

/// Wires up everything that outlives a single screen.
///
/// Screen controllers are not here — they are created by their route's binding and disposed when
/// the route is popped. What lives here is the HTTP client, the repositories that wrap it, the
/// session and the reference-data cache: all things that would be wasteful or wrong to rebuild on
/// every navigation.
void _registerDependencies(SecureStore store, String baseUrl) {
  Get
    ..put<SecureStore>(store, permanent: true)
    ..put<ApiClient>(ApiClient(store, baseUrl: baseUrl), permanent: true)
    ..put<ThemeController>(ThemeController(store), permanent: true);

  final api = Get.find<ApiClient>();

  Get
    ..put<AuthRepository>(AuthRepository(api), permanent: true)
    ..put<CatalogRepository>(CatalogRepository(api), permanent: true)
    ..put<InvoiceRepository>(InvoiceRepository(api), permanent: true)
    ..put<SettingsRepository>(SettingsRepository(api), permanent: true)
    ..put<SessionController>(
      SessionController(
        authRepository: Get.find<AuthRepository>(),
        secureStore: store,
        apiClient: api,
      ),
      permanent: true,
    )
    ..put<AppDataController>(
      AppDataController(
        settingsRepository: Get.find<SettingsRepository>(),
        catalogRepository: Get.find<CatalogRepository>(),
      ),
      permanent: true,
    );
}

class TriosuiteInvoicesApp extends StatefulWidget {
  const TriosuiteInvoicesApp({super.key, required this.initialThemeMode});

  final ThemeMode initialThemeMode;

  @override
  State<TriosuiteInvoicesApp> createState() => _TriosuiteInvoicesAppState();
}

class _TriosuiteInvoicesAppState extends State<TriosuiteInvoicesApp> {
  @override
  void initState() {
    super.initState();
    // Runs after the first frame so the "Connecting…" state is already on screen while the health
    // probe — which can take the better part of a minute against a sleeping free-tier host — is in
    // flight. If a stored session turns out to be valid, this replaces the login screen with the
    // invoice list before the user has done anything.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<SessionController>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Triosuite Invoices',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.initialThemeMode,
      initialRoute: AppRoutes.login,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
    );
  }
}
