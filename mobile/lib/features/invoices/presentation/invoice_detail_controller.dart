import 'package:get/get.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/presentation/session_controller.dart';
import '../../settings/presentation/app_data_controller.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice.dart';

/// One invoice, and the two state changes that can be made to it.
///
/// The `can…` getters below decide which buttons appear. They combine the invoice's status with
/// the caller's role, and they are a convenience only: the server checks both again, so a client
/// that got them wrong would be refused rather than obeyed.
class InvoiceDetailController extends GetxController {
  InvoiceDetailController({
    required this.invoiceId,
    required InvoiceRepository invoiceRepository,
    required SessionController sessionController,
    required AppDataController appDataController,
  })  : _invoices = invoiceRepository,
        _session = sessionController,
        _appData = appDataController;

  final int invoiceId;
  final InvoiceRepository _invoices;
  final SessionController _session;
  final AppDataController _appData;

  final Rxn<Invoice> invoice = Rxn<Invoice>();
  final RxBool loading = false.obs;
  final RxBool acting = false.obs;
  final RxnString error = RxnString();

  @override
  void onInit() {
    super.onInit();
    _appData.ensureLoaded();
    load();
  }

  /// Whether the invoice may be edited, and by this caller.
  bool get canEdit => invoice.value?.status.isEditable ?? false;

  /// SALES may approve as well as ADMIN — it is the one write beyond drafts that role has.
  bool get canApprove => invoice.value?.status.canApprove ?? false;

  /// Cancelling is an administrator action.
  bool get canCancel => (invoice.value?.status.canCancel ?? false) && _session.isAdmin;

  /// True when the invoice could be cancelled but this caller may not — used to explain the
  /// absence of the button rather than leave the user wondering.
  bool get cancelHiddenByRole =>
      (invoice.value?.status.canCancel ?? false) && !_session.isAdmin;

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      invoice.value = await _invoices.byId(invoiceId);
    } on ApiException catch (failure) {
      error.value = failure.message;
    } finally {
      loading.value = false;
    }
  }

  /// Approves the invoice, after which it can no longer be edited.
  Future<void> approve() => _act(
        () => _invoices.approve(
          id: invoiceId,
          version: invoice.value!.version,
        ),
        successMessage: 'Invoice approved.',
      );

  /// Cancels the invoice. The record is kept; only its status changes.
  Future<void> cancel({String? reason}) => _act(
        () => _invoices.cancel(
          id: invoiceId,
          version: invoice.value!.version,
          reason: reason,
        ),
        successMessage: 'Invoice cancelled.',
      );

  /// Runs a state change, translating the failures the user can act on.
  Future<void> _act(
    Future<Invoice> Function() action, {
    required String successMessage,
  }) async {
    if (invoice.value == null || acting.value) {
      return;
    }
    acting.value = true;
    try {
      invoice.value = await action();
      AppSnackbar.success(successMessage);
    } on ApiException catch (failure) {
      if (failure.isStaleVersion) {
        // Someone else changed the invoice while this screen was open. Reload so the user is
        // looking at the truth before deciding what to do, and say so plainly.
        await load();
        AppSnackbar.failure(
          'This invoice was changed by someone else, so nothing was applied. '
          'The latest version is now shown.',
        );
      } else {
        AppSnackbar.failure(failure.message);
      }
    } finally {
      acting.value = false;
    }
  }

  /// The decimal places the invoice's currency is quoted in.
  int get minorUnits => invoice.value?.currencyMinorUnits ?? 2;

  /// The decimal places the base currency is quoted in, for the converted total.
  int get baseMinorUnits {
    final code = invoice.value?.baseCurrencyCode;
    return code == null ? 2 : _appData.minorUnitsOf(code);
  }

  /// The symbol for the base currency.
  String get baseSymbol {
    final code = invoice.value?.baseCurrencyCode;
    return code == null ? '' : _appData.symbolOf(code);
  }
}
