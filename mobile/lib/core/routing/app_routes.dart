/// Every route in the app.
///
/// The assessment caps the app at five screens, so there are exactly five entries here and exactly
/// five `GetPage`s in `app_pages.dart` — a constraint that is trivial to verify by reading either
/// file.
///
/// Everything else the app does is a modal inside one of these: the barcode scanner, the item and
/// customer pickers, the approve and cancel confirmations and the cancellation-reason prompt are
/// all bottom sheets or dialogs. The start-up connectivity check is an overlay on the first screen,
/// not a route.
abstract final class AppRoutes {
  const AppRoutes._();

  /// Username and password. The only screen reachable without a session.
  static const String login = '/login';

  /// The invoice list — the app's home.
  static const String invoices = '/invoices';

  /// Create, and — with an `invoiceId` argument — edit. One screen, two modes, because editing a
  /// draft is the same form with the fields already filled in.
  static const String invoiceForm = '/invoices/new';

  /// A single invoice in full.
  static const String invoiceDetail = '/invoices/:id';

  /// Server-side defaults, exchange rates and the app's own preferences.
  static const String settings = '/settings';

  /// The concrete path for one invoice, e.g. `/invoices/42`.
  static String invoiceDetailFor(int id) => '/invoices/$id';

  /// Argument key used to put the form into edit mode.
  static const String editInvoiceIdArgument = 'invoiceId';
}
