import 'package:get/get.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/invoices/data/catalog_repository.dart';
import '../../features/invoices/data/invoice_repository.dart';
import '../../features/invoices/presentation/invoice_detail_controller.dart';
import '../../features/invoices/presentation/invoice_detail_page.dart';
import '../../features/invoices/presentation/invoice_form_controller.dart';
import '../../features/invoices/presentation/invoice_form_page.dart';
import '../../features/invoices/presentation/invoice_list_controller.dart';
import '../../features/invoices/presentation/invoice_list_page.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/presentation/app_data_controller.dart';
import '../../features/settings/presentation/settings_controller.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../network/api_client.dart';
import 'app_routes.dart';

/// The route table — **exactly five pages**, as the assessment requires.
///
/// Order matters: `/invoices/new` is registered before `/invoices/:id` so the literal path wins
/// over the parameter pattern. Screen controllers are created by a binding when their route is
/// pushed and disposed when it is popped, which keeps a half-filled invoice form from surviving in
/// memory after the user has walked away from it.
abstract final class AppPages {
  const AppPages._();

  static final List<GetPage<dynamic>> pages = [
    GetPage<void>(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: AppRoutes.invoices,
      page: () => const InvoiceListPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => InvoiceListController(
              invoiceRepository: Get.find<InvoiceRepository>(),
              appDataController: Get.find<AppDataController>(),
            ));
      }),
    ),
    GetPage<void>(
      name: AppRoutes.invoiceForm,
      page: () => const InvoiceFormPage(),
      binding: BindingsBuilder(() {
        // Present only when the Details screen asked for edit mode; absent when creating.
        final arguments = Get.arguments;
        final editingId = arguments is Map<String, dynamic>
            ? arguments[AppRoutes.editInvoiceIdArgument] as int?
            : null;

        Get.lazyPut(() => InvoiceFormController(
              invoiceRepository: Get.find<InvoiceRepository>(),
              catalogRepository: Get.find<CatalogRepository>(),
              appDataController: Get.find<AppDataController>(),
              editingInvoiceId: editingId,
            ));
      }),
    ),
    GetPage<void>(
      name: AppRoutes.invoiceDetail,
      page: () => const InvoiceDetailPage(),
      binding: BindingsBuilder(() {
        final id = int.tryParse(Get.parameters['id'] ?? '') ?? 0;
        Get.lazyPut(() => InvoiceDetailController(
              invoiceId: id,
              invoiceRepository: Get.find<InvoiceRepository>(),
              sessionController: Get.find<SessionController>(),
              appDataController: Get.find<AppDataController>(),
            ));
      }),
    ),
    GetPage<void>(
      name: AppRoutes.settings,
      page: () => const SettingsPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => SettingsController(
              settingsRepository: Get.find<SettingsRepository>(),
              catalogRepository: Get.find<CatalogRepository>(),
              appDataController: Get.find<AppDataController>(),
              sessionController: Get.find<SessionController>(),
              apiClient: Get.find<ApiClient>(),
            ));
      }),
    ),
  ];
}
