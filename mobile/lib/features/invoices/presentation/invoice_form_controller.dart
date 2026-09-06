import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/money/invoice_calculator.dart';
import '../../../core/money/money_format.dart';
import '../../../core/money/tax_mode.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/page_response.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../settings/presentation/app_data_controller.dart';
import '../data/catalog_repository.dart';
import '../data/invoice_repository.dart';
import '../domain/currency.dart';
import '../domain/customer.dart';
import '../domain/item.dart';
import 'widgets/barcode_scanner_sheet.dart';

/// One editable line, with the text controllers its two fields are bound to.
///
/// Quantity and unit price live in the controllers rather than in `Rx` values because a text field
/// is the source of truth while it is being typed into; parsing on read keeps the two from ever
/// disagreeing about what the user has entered.
class InvoiceLineEditor {
  InvoiceLineEditor({
    required this.item,
    required Decimal quantity,
    required Decimal unitPrice,
    required int minorUnits,
  })  : quantityController = TextEditingController(text: _trimTrailingZeros(quantity)),
        priceController = TextEditingController(text: unitPrice.toStringAsFixed(minorUnits));

  final Item item;
  final TextEditingController quantityController;
  final TextEditingController priceController;

  /// The tax rate is read-only and comes from the catalogue; a client cannot choose its own.
  Decimal get taxRate => item.taxRate;

  Decimal get quantity => MoneyFormat.tryParse(quantityController.text) ?? Decimal.zero;

  Decimal get unitPrice => MoneyFormat.tryParse(priceController.text) ?? Decimal.zero;

  String? get quantityError {
    final parsed = MoneyFormat.tryParse(quantityController.text);
    if (parsed == null) {
      return 'Enter a number';
    }
    return parsed <= Decimal.zero ? 'Must be more than 0' : null;
  }

  String? get priceError {
    final parsed = MoneyFormat.tryParse(priceController.text);
    if (parsed == null) {
      return 'Enter a number';
    }
    return parsed < Decimal.zero ? 'Cannot be negative' : null;
  }

  bool get isValid => quantityError == null && priceError == null;

  /// Re-prices the line, for when the invoice currency changes under it.
  void setUnitPrice(Decimal price, int minorUnits) =>
      priceController.text = price.toStringAsFixed(minorUnits);

  void setQuantity(Decimal value) =>
      quantityController.text = _trimTrailingZeros(value);

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
  }

  /// `2.000` reads better as `2` in an input the user is about to edit.
  static String _trimTrailingZeros(Decimal value) {
    final text = value.toString();
    if (!text.contains('.')) {
      return text;
    }
    final trimmed = text.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}

/// Create and edit, in one controller because they are the same form.
///
/// The totals footer is a **preview**: it is computed on the device with the same formulas and the
/// same rounding as the server, purely so the figures move as the user types. What gets stored is
/// whatever the server computes when the invoice is saved, and the Details screen shows that.
class InvoiceFormController extends GetxController {
  InvoiceFormController({
    required InvoiceRepository invoiceRepository,
    required CatalogRepository catalogRepository,
    required AppDataController appDataController,
    this.editingInvoiceId,
  })  : _invoices = invoiceRepository,
        _catalog = catalogRepository,
        _appData = appDataController;

  final InvoiceRepository _invoices;
  final CatalogRepository _catalog;
  final AppDataController _appData;

  /// Null when creating; the invoice being rewritten when editing.
  final int? editingInvoiceId;

  final TextEditingController notesController = TextEditingController();
  final TextEditingController exchangeRateController = TextEditingController();

  final RxBool loading = false.obs;
  final RxBool saving = false.obs;
  final RxnString loadError = RxnString();

  final Rxn<Customer> customer = Rxn<Customer>();
  final Rx<DateTime> issueDate = DateTime.now().obs;
  final RxString currencyCode = ''.obs;
  final Rx<TaxMode> taxMode = TaxMode.exclusive.obs;
  final RxList<InvoiceLineEditor> lines = <InvoiceLineEditor>[].obs;

  /// Bumped whenever anything that affects the totals changes, so the footer recomputes.
  final Rxn<CalculatedInvoice> preview = Rxn<CalculatedInvoice>();

  /// True once the user has changed something, so leaving can warn them.
  final RxBool dirty = false.obs;

  int _version = 0;

  bool get isEditing => editingInvoiceId != null;

  String get title => isEditing ? 'Edit invoice' : 'New invoice';

  /// The invoice currency is the base currency, so the rate is fixed at 1 and not editable.
  bool get isBaseCurrency => currencyCode.value == _appData.settings.value?.baseCurrencyCode;

  /// Every currency the invoice may be issued in, for the dropdown.
  List<Currency> get currencies => _appData.currencies;

  int get minorUnits => _appData.minorUnitsOf(currencyCode.value);

  String get currencySymbol => _appData.symbolOf(currencyCode.value);

  String get baseCurrencyCode => _appData.settings.value?.baseCurrencyCode ?? '';

  int get baseMinorUnits => _appData.minorUnitsOf(baseCurrencyCode);

  String get baseCurrencySymbol => _appData.symbolOf(baseCurrencyCode);

  Decimal get exchangeRate =>
      MoneyFormat.tryParse(exchangeRateController.text) ?? Decimal.one;

  @override
  void onInit() {
    super.onInit();
    unawaited(_bootstrap());
  }

  @override
  void onClose() {
    for (final line in lines) {
      line.dispose();
    }
    notesController.dispose();
    exchangeRateController.dispose();
    super.onClose();
  }

  Future<void> _bootstrap() async {
    loading.value = true;
    loadError.value = null;

    try {
      await _appData.ensureLoaded();
      if (_appData.error.value != null) {
        loadError.value = _appData.error.value;
        return;
      }

      if (isEditing) {
        await _loadExisting();
      } else {
        _applyDefaults();
      }
    } finally {
      loading.value = false;
      _recomputePreview();
    }
  }

  void _applyDefaults() {
    final settings = _appData.settings.value;
    currencyCode.value = settings?.defaultCurrencyCode ?? baseCurrencyCode;
    taxMode.value = settings?.defaultTaxMode ?? TaxMode.exclusive;
    issueDate.value = DateTime.now();
    _applySuggestedRate();
  }

  Future<void> _loadExisting() async {
    try {
      final invoice = await _invoices.byId(editingInvoiceId!);

      if (!invoice.status.isEditable) {
        // Reachable only if the invoice changed between the Details screen offering Edit and this
        // screen loading it. Refusing here is friendlier than letting the user fill in a form the
        // server is certain to reject.
        loadError.value =
            'This invoice is ${invoice.status.label.toLowerCase()} and can no longer be edited.';
        return;
      }

      _version = invoice.version;
      currencyCode.value = invoice.currencyCode;
      taxMode.value = invoice.taxMode;
      issueDate.value = invoice.issueDate;
      notesController.text = invoice.notes ?? '';
      exchangeRateController.text = MoneyFormat.exchangeRate(invoice.exchangeRate);
      customer.value = Customer(id: invoice.customerId, name: invoice.customerName);

      final units = _appData.minorUnitsOf(invoice.currencyCode);
      lines.assignAll(invoice.lines.map((line) => InvoiceLineEditor(
            item: Item(
              id: line.itemId,
              sku: '',
              barcode: line.barcode,
              name: line.itemName,
              unitPrice: line.unitPrice,
              currencyCode: invoice.currencyCode,
              taxRate: line.taxRate,
            ),
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            minorUnits: units,
          )));
      dirty.value = false;
    } on ApiException catch (failure) {
      loadError.value = failure.message;
    }
  }

  // -------------------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------------------

  void setCustomer(Customer value) {
    customer.value = value;
    _markDirty();
  }

  void setIssueDate(DateTime value) {
    issueDate.value = value;
    _markDirty();
  }

  void setTaxMode(TaxMode value) {
    if (taxMode.value == value) {
      return;
    }
    taxMode.value = value;
    _markDirty();
    _recomputePreview();
  }

  /// Changes the invoice currency and re-prices every line into it.
  ///
  /// Re-pricing is the whole point of the multi-currency feature being usable: switching an invoice
  /// from ILS to USD and leaving the shekel figures in place would produce a document that is
  /// silently wrong. Each line is re-derived from its catalogue price at the new rate, and the user
  /// can still override any of them.
  void setCurrency(String code) {
    if (currencyCode.value == code) {
      return;
    }
    currencyCode.value = code;
    _applySuggestedRate();
    _repriceAllLines();
    _markDirty();
    _recomputePreview();
  }

  void onExchangeRateChanged(String _) {
    _markDirty();
    _recomputePreview();
  }

  /// Re-prices the lines after the user edits the rate by hand.
  void repriceForCurrentRate() {
    _repriceAllLines();
    _recomputePreview();
  }

  void _applySuggestedRate() {
    if (isBaseCurrency) {
      exchangeRateController.text = MoneyFormat.exchangeRate(Decimal.one);
      return;
    }
    final suggested = _appData.suggestedRateFor(currencyCode.value);
    exchangeRateController.text =
        MoneyFormat.exchangeRate(suggested ?? Decimal.one);
  }

  /// Converts a catalogue price into the invoice's currency.
  ///
  /// Goes via the base currency, so it is correct even for an item priced in something other than
  /// the base: `price × rate(item currency) ÷ rate(invoice currency)`.
  Decimal priceInInvoiceCurrency(Item item) {
    final invoiceRate = exchangeRate;
    if (invoiceRate <= Decimal.zero) {
      return item.unitPrice;
    }

    final itemRate = item.currencyCode == baseCurrencyCode
        ? Decimal.one
        : (_appData.suggestedRateFor(item.currencyCode) ?? Decimal.one);

    if (item.currencyCode == currencyCode.value) {
      return item.unitPrice;
    }

    final inBase = item.unitPrice * itemRate;
    return (inBase / invoiceRate)
        .toDecimal(scaleOnInfinitePrecision: minorUnits + 8)
        .round(scale: minorUnits);
  }

  void _repriceAllLines() {
    final units = minorUnits;
    for (final line in lines) {
      line.setUnitPrice(priceInInvoiceCurrency(line.item), units);
    }
  }

  // -------------------------------------------------------------------------------------
  // Lines
  // -------------------------------------------------------------------------------------

  /// Adds an item, or bumps the quantity if it is already on the invoice.
  ///
  /// Returns the resulting quantity so the caller can say what happened.
  Decimal addItem(Item item, {Decimal? quantity}) {
    final increment = quantity ?? Decimal.one;
    final existingIndex = lines.indexWhere((line) => line.item.id == item.id);

    if (existingIndex != -1) {
      final existing = lines[existingIndex];
      final updated = existing.quantity + increment;
      existing.setQuantity(updated);
      lines.refresh();
      _markDirty();
      _recomputePreview();
      return updated;
    }

    lines.add(InvoiceLineEditor(
      item: item,
      quantity: increment,
      unitPrice: priceInInvoiceCurrency(item),
      minorUnits: minorUnits,
    ));
    _markDirty();
    _recomputePreview();
    return increment;
  }

  void removeLineAt(int index) {
    if (index < 0 || index >= lines.length) {
      return;
    }
    lines.removeAt(index).dispose();
    _markDirty();
    _recomputePreview();
  }

  /// Puts a removed line back, for the undo action on the swipe-to-remove snackbar.
  void restoreLine(int index, Item item, Decimal quantity, Decimal unitPrice) {
    final editor = InvoiceLineEditor(
      item: item,
      quantity: quantity,
      unitPrice: unitPrice,
      minorUnits: minorUnits,
    );
    lines.insert(index.clamp(0, lines.length), editor);
    _recomputePreview();
  }

  void onLineFieldChanged() {
    _markDirty();
    _recomputePreview();
  }

  /// Looks a scanned code up and applies it.
  Future<ScanOutcome> handleScannedBarcode(String barcode) async {
    try {
      final item = await _catalog.itemByBarcode(barcode);
      final alreadyPresent = lines.any((line) => line.item.id == item.id);
      final quantity = addItem(item);

      return ScanOutcome.added(
        alreadyPresent
            ? '${item.name} — quantity now ${InvoiceLineEditor._trimTrailingZeros(quantity)}'
            : 'Added ${item.name}',
      );
    } on ApiException catch (failure) {
      if (failure.isNotFound) {
        return ScanOutcome.rejected('$barcode is not in the catalogue');
      }
      return ScanOutcome.rejected(failure.message);
    }
  }

  // -------------------------------------------------------------------------------------
  // Preview
  // -------------------------------------------------------------------------------------

  void _recomputePreview() {
    final valid = lines.where((line) => line.isValid).toList(growable: false);

    preview.value = InvoiceCalculator.invoice(
      lines: valid
          .map((line) => LineInput(
                quantity: line.quantity,
                unitPrice: line.unitPrice,
                taxRate: line.taxRate,
              ))
          .toList(growable: false),
      taxMode: taxMode.value,
      currencyMinorUnits: minorUnits,
      exchangeRate: exchangeRate,
      baseCurrencyMinorUnits: baseMinorUnits,
    );
  }

  void _markDirty() => dirty.value = true;

  // -------------------------------------------------------------------------------------
  // Save
  // -------------------------------------------------------------------------------------

  /// What is stopping the invoice being saved, or null when nothing is.
  String? get blockingProblem {
    if (customer.value == null) {
      return 'Choose a customer';
    }
    if (exchangeRate <= Decimal.zero) {
      return 'The exchange rate must be more than 0';
    }
    if (lines.any((line) => !line.isValid)) {
      return 'Fix the highlighted line';
    }
    if (lines.length > 200) {
      return 'An invoice cannot have more than 200 lines';
    }
    return null;
  }

  bool get canSave => blockingProblem == null && !saving.value;

  /// Saves the draft and opens its Details screen.
  Future<void> save() async {
    final problem = blockingProblem;
    if (problem != null) {
      AppSnackbar.failure(problem);
      return;
    }
    if (saving.value) {
      return;
    }

    saving.value = true;
    try {
      final draft = InvoiceDraft(
        customerId: customer.value!.id,
        currencyCode: currencyCode.value,
        exchangeRate: exchangeRate,
        taxMode: taxMode.value,
        issueDate: issueDate.value,
        notes: notesController.text,
        lines: lines
            .map((line) => InvoiceLineDraft(
                  itemId: line.item.id,
                  quantity: line.quantity,
                  unitPrice: line.unitPrice,
                ))
            .toList(growable: false),
      );

      final saved = isEditing
          ? await _invoices.update(
              id: editingInvoiceId!,
              version: _version,
              draft: draft,
            )
          : await _invoices.create(draft);

      dirty.value = false;
      AppSnackbar.success(
        isEditing ? 'Invoice ${saved.invoiceNumber} updated.' : 'Created ${saved.invoiceNumber}.',
      );
      // offNamed rather than toNamed: going "back" from Details should reach the list, not a form
      // whose contents have already been saved.
      await Get.offNamed<void>(AppRoutes.invoiceDetailFor(saved.id));
    } on ApiException catch (failure) {
      _reportSaveFailure(failure);
    } finally {
      saving.value = false;
    }
  }

  void _reportSaveFailure(ApiException failure) {
    if (failure.isStaleVersion) {
      AppSnackbar.failure(
        'Someone else changed this invoice while you were editing it. '
        'Nothing was saved — reopen it to see the current version.',
      );
      return;
    }
    if (failure.code == ApiErrorCode.invoiceNotEditable) {
      AppSnackbar.failure(
        'This invoice is no longer a draft, so it cannot be changed. Nothing was saved.',
      );
      return;
    }
    if (failure.fieldErrors.isNotEmpty) {
      final first = failure.fieldErrors.first;
      AppSnackbar.failure('${first.field}: ${first.message}');
      return;
    }
    AppSnackbar.failure(failure.message);
  }

  // -------------------------------------------------------------------------------------
  // Pickers
  // -------------------------------------------------------------------------------------

  Future<PageResponse<Customer>> searchCustomers(String search, int page) =>
      _catalog.customers(search: search, page: page);

  Future<PageResponse<Item>> searchItems(String search, int page) =>
      _catalog.items(search: search, page: page);
}
