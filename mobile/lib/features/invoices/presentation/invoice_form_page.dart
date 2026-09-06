import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/invoice_calculator.dart';
import '../../../core/money/money_format.dart';
import '../../../core/money/tax_mode.dart';
import '../../../core/widgets/async_state_view.dart';
import '../domain/customer.dart';
import '../domain/item.dart';
import 'invoice_form_controller.dart';
import 'widgets/barcode_scanner_sheet.dart';
import 'widgets/confirm_dialogs.dart';
import 'widgets/search_picker_sheet.dart';

/// Create a new invoice, or rewrite a draft.
///
/// One screen for both, because they are the same form — editing simply arrives with the fields
/// already filled in and sends the invoice's `version` along with the save.
class InvoiceFormPage extends GetView<InvoiceFormController> {
  const InvoiceFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (!controller.dirty.value || await ConfirmDialogs.discardChanges()) {
          Get.back<void>();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(controller.title)),
        body: Obx(() {
          return AsyncStateView(
            isLoading: controller.loading.value,
            isEmpty: false,
            error: controller.loadError.value,
            onRetry: () async => Get.back<void>(),
            child: const _FormBody(),
          );
        }),
        bottomNavigationBar: Obx(
          () => controller.loading.value || controller.loadError.value != null
              ? const SizedBox.shrink()
              : const _TotalsFooter(),
        ),
      ),
    );
  }
}

class _FormBody extends GetView<InvoiceFormController> {
  const _FormBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: const [
        _HeaderCard(),
        SizedBox(height: 16),
        _LinesCard(),
      ],
    );
  }
}

class _HeaderCard extends GetView<InvoiceFormController> {
  const _HeaderCard();

  Future<void> _pickCustomer() async {
    final chosen = await SearchPickerSheet.show<Customer>(
      title: 'Choose a customer',
      searchHint: 'Search by name, e-mail or phone',
      fetch: controller.searchCustomers,
      emptyMessage: 'No active customer matches that search.',
      rowBuilder: (context, customer, onPick) => ListTile(
        onTap: onPick,
        title: Text(customer.name),
        subtitle: customer.email == null && customer.phone == null
            ? null
            : Text([customer.email, customer.phone].whereType<String>().join('  ·  ')),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
    if (chosen != null) {
      controller.setCustomer(chosen);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: controller.issueDate.value,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Issue date',
    );
    if (chosen != null) {
      controller.setIssueDate(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMMd(Intl.getCurrentLocale());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              final customer = controller.customer.value;
              return InkWell(
                onTap: _pickCustomer,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Customer',
                    prefixIcon: Icon(Icons.business_outlined),
                    suffixIcon: Icon(Icons.chevron_right),
                  ),
                  child: Text(
                    customer?.name ?? 'Choose a customer',
                    style: customer == null
                        ? theme.textTheme.bodyLarge
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                        : theme.textTheme.bodyLarge,
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
            Obx(
              () => InkWell(
                onTap: () => _pickDate(context),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Issue date',
                    prefixIcon: Icon(Icons.event_outlined),
                    helperText: 'Its year decides which numbering sequence is used',
                  ),
                  child: Text(dateFormat.format(controller.issueDate.value)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const _CurrencyAndRate(),
            const SizedBox(height: 14),
            const _TaxModeSelector(),
            const SizedBox(height: 14),
            TextField(
              controller: controller.notesController,
              maxLines: 3,
              minLines: 2,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => controller.onLineFieldChanged(),
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyAndRate extends GetView<InvoiceFormController> {
  const _CurrencyAndRate();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final locked = controller.isBaseCurrency;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<String>(
                  initialValue: controller.currencyCode.value.isEmpty
                      ? null
                      : controller.currencyCode.value,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: [
                    for (final currency in controller.currencies)
                      DropdownMenuItem(
                        value: currency.code,
                        child: Text('${currency.code}  ${currency.symbol}'),
                      ),
                  ],
                  onChanged: (code) {
                    if (code != null) {
                      controller.setCurrency(code);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: TextField(
                  controller: controller.exchangeRateController,
                  enabled: !locked,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: controller.onExchangeRateChanged,
                  onEditingComplete: controller.repriceForCurrentRate,
                  decoration: InputDecoration(
                    labelText: 'Exchange rate',
                    prefixIcon: const Icon(Icons.swap_horiz),
                    suffixIcon: locked
                        ? const Icon(Icons.lock_outline, size: 18)
                        : IconButton(
                            onPressed: controller.repriceForCurrentRate,
                            icon: const Icon(Icons.published_with_changes, size: 20),
                            tooltip: 'Re-price the lines at this rate',
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            locked
                ? '${controller.currencyCode.value} is the base currency, so the rate is fixed at 1.'
                : '1 ${controller.currencyCode.value} = '
                    '${controller.exchangeRateController.text} ${controller.baseCurrencyCode}. '
                    'Pre-filled from the maintained rate; change it if this invoice was agreed at '
                    'a different one.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    });
  }
}

class _TaxModeSelector extends GetView<InvoiceFormController> {
  const _TaxModeSelector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TaxMode>(
            segments: [
              for (final mode in TaxMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {controller.taxMode.value},
            onSelectionChanged: (selection) => controller.setTaxMode(selection.first),
          ),
          const SizedBox(height: 6),
          Text(
            controller.taxMode.value.description,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LinesCard extends GetView<InvoiceFormController> {
  const _LinesCard();

  Future<void> _pickItem() async {
    final chosen = await SearchPickerSheet.show<Item>(
      title: 'Add an item',
      searchHint: 'Search by name, SKU or barcode',
      fetch: controller.searchItems,
      emptyMessage: 'No active item matches that search.',
      rowBuilder: (context, item, onPick) => ListTile(
        onTap: onPick,
        title: Text(item.name),
        subtitle: Text(
          '${item.sku}  ·  ${MoneyFormat.plain(item.unitPrice, minorUnits: 2)} '
          '${item.currencyCode}  ·  tax ${MoneyFormat.taxRate(item.taxRate)}',
        ),
        trailing: const Icon(Icons.add),
      ),
    );
    if (chosen != null) {
      controller.addItem(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => BarcodeScannerSheet.show(
                      onBarcode: controller.handleScannedBarcode,
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (controller.lines.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 36, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      Text('No lines yet', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Add an item from the catalogue, or scan a barcode. '
                        'A draft can be saved empty, but it cannot be approved until it has at '
                        'least one line.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < controller.lines.length; index++)
                    _LineTile(
                      key: ValueKey(
                        '${controller.lines[index].item.id}-$index',
                      ),
                      index: index,
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LineTile extends GetView<InvoiceFormController> {
  const _LineTile({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = controller.lines[index];
    final minorUnits = controller.minorUnits;

    final calculated = InvoiceCalculator.line(
      LineInput(
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        taxRate: line.taxRate,
      ),
      taxMode: controller.taxMode.value,
      minorUnits: minorUnits,
    );

    return Dismissible(
      key: ValueKey('line-${line.item.id}-$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) {
        final removedItem = line.item;
        final removedQuantity = line.quantity;
        final removedPrice = line.unitPrice;
        controller.removeLineAt(index);

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text('Removed ${removedItem.name}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => controller.restoreLine(
                index,
                removedItem,
                removedQuantity,
                removedPrice,
              ),
            ),
          ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.item.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  'tax ${MoneyFormat.taxRate(line.taxRate)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: line.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    onChanged: (_) => controller.onLineFieldChanged(),
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      errorText: line.quantityError,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: TextField(
                    controller: line.priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    onChanged: (_) => controller.onLineFieldChanged(),
                    decoration: InputDecoration(
                      labelText: 'Unit price',
                      isDense: true,
                      prefixText: '${controller.currencySymbol} ',
                      errorText: line.priceError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Line total  ${MoneyFormat.amount(
                  calculated.grossAmount,
                  symbol: controller.currencySymbol,
                  minorUnits: minorUnits,
                )}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
          ],
        ),
      ),
    );
  }
}

/// The sticky preview footer, and the Save button.
class _TotalsFooter extends GetView<InvoiceFormController> {
  const _TotalsFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final preview = controller.preview.value;
      final minorUnits = controller.minorUnits;
      final symbol = controller.currencySymbol;
      final problem = controller.blockingProblem;

      return Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Preview',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Computed on this device. The server recalculates every total when '
                        'the invoice is saved, and its figures are the ones stored.',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _PreviewRow(
                label: 'Subtotal',
                value: MoneyFormat.amount(
                  preview?.subtotal ?? Decimal.zero,
                  symbol: symbol,
                  minorUnits: minorUnits,
                ),
              ),
              _PreviewRow(
                label: 'Tax',
                value: MoneyFormat.amount(
                  preview?.taxTotal ?? Decimal.zero,
                  symbol: symbol,
                  minorUnits: minorUnits,
                ),
              ),
              _PreviewRow(
                label: 'Total',
                value: MoneyFormat.amount(
                  preview?.grandTotal ?? Decimal.zero,
                  symbol: symbol,
                  minorUnits: minorUnits,
                ),
                emphasise: true,
              ),
              if (!controller.isBaseCurrency)
                _PreviewRow(
                  label: 'In ${controller.baseCurrencyCode}',
                  value: MoneyFormat.amount(
                    preview?.grandTotalBase ?? Decimal.zero,
                    symbol: controller.baseCurrencySymbol,
                    minorUnits: controller.baseMinorUnits,
                  ),
                  subdued: true,
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: controller.canSave ? controller.save : null,
                icon: controller.saving.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(controller.isEditing ? 'Save changes' : 'Save draft'),
              ),
              if (problem != null) ...[
                const SizedBox(height: 6),
                Text(
                  problem,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.subdued = false,
  });

  final String label;
  final String value;
  final bool emphasise;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasise
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodySmall;
    final color = subdued ? theme.colorScheme.onSurfaceVariant : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style?.copyWith(color: color))),
          Text(value, style: style?.copyWith(color: color)),
        ],
      ),
    );
  }
}
