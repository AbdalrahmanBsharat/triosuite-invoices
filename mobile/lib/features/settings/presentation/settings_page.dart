import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/money/tax_mode.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/api_address_sheet.dart';
import '../../../core/widgets/async_state_view.dart';
import 'settings_controller.dart';

/// Company defaults, exchange rates, and this device's own preferences.
class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.loading && controller.currencies.isEmpty,
          isEmpty: false,
          error: controller.loadError,
          onRetry: controller.refreshAll,
          child: RefreshIndicator(
            onRefresh: controller.refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: const [
                _ServerSection(),
                SizedBox(height: 16),
                _ExchangeRatesSection(),
                SizedBox(height: 16),
                _AppSection(),
                SizedBox(height: 16),
                _AccountSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ServerSection extends GetView<SettingsController> {
  const _ServerSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final editable = controller.isAdmin;

      return _SectionCard(
        title: 'Invoicing defaults',
        subtitle: editable
            ? 'Applies to every user of this system.'
            : 'Set by an administrator. Shown here for reference.',
        trailing: editable
            ? null
            : Tooltip(
                message: 'Only an administrator can change these',
                child: Icon(Icons.lock_outline,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
              ),
        children: [
          DropdownButtonFormField<String>(
            initialValue: controller.baseCurrencyCode.value.isEmpty
                ? null
                : controller.baseCurrencyCode.value,
            decoration: const InputDecoration(
              labelText: 'Base currency',
              helperText: 'Every invoice also reports its total in this currency',
            ),
            items: [
              for (final currency in controller.currencies)
                DropdownMenuItem(
                  value: currency.code,
                  child: Text('${currency.code} — ${currency.name}'),
                ),
            ],
            onChanged: editable
                ? (code) {
                    if (code != null) {
                      controller.setBaseCurrency(code);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: controller.defaultCurrencyCode.value.isEmpty
                ? null
                : controller.defaultCurrencyCode.value,
            decoration: const InputDecoration(
              labelText: 'Default currency',
              helperText: 'Pre-selected on a new invoice',
            ),
            items: [
              for (final currency in controller.currencies)
                DropdownMenuItem(
                  value: currency.code,
                  child: Text('${currency.code} — ${currency.name}'),
                ),
            ],
            onChanged: editable
                ? (code) {
                    if (code != null) {
                      controller.setDefaultCurrency(code);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 14),
          Text('Default tax mode', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          SegmentedButton<TaxMode>(
            segments: [
              for (final mode in TaxMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {controller.defaultTaxMode.value},
            onSelectionChanged: editable
                ? (selection) => controller.setDefaultTaxMode(selection.first)
                : null,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller.taxRateController,
            enabled: editable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(
              labelText: 'Default tax rate',
              suffixText: '%',
              helperText: 'Used when an item carries no rate of its own',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller.prefixController,
            enabled: editable,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Invoice number prefix',
              helperText: 'The INV in INV-2026-000001',
            ),
          ),
          if (editable) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: controller.saving.value ? null : controller.saveSettings,
              icon: controller.saving.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save defaults'),
            ),
          ],
        ],
      );
    });
  }
}

class _ExchangeRatesSection extends GetView<SettingsController> {
  const _ExchangeRatesSection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final base = controller.baseCurrencyCode.value;

      return _SectionCard(
        title: 'Exchange rates',
        subtitle: base.isEmpty
            ? 'Suggested when a new invoice is created.'
            : 'How many $base one unit is worth. Suggested on new invoices; invoices already '
                'issued keep the rate they were saved with.',
        children: [
          for (final currency in controller.currencies)
            _ExchangeRateRow(
              currencyCode: currency.code,
              currencyName: currency.name,
              isBase: currency.code == base,
            ),
        ],
      );
    });
  }
}

class _ExchangeRateRow extends StatefulWidget {
  const _ExchangeRateRow({
    required this.currencyCode,
    required this.currencyName,
    required this.isBase,
  });

  final String currencyCode;
  final String currencyName;
  final bool isBase;

  @override
  State<_ExchangeRateRow> createState() => _ExchangeRateRowState();
}

class _ExchangeRateRowState extends State<_ExchangeRateRow> {
  final SettingsController _controller = Get.find<SettingsController>();
  late final TextEditingController _rateController;

  @override
  void initState() {
    super.initState();
    _rateController =
        TextEditingController(text: _controller.rateTextFor(widget.currencyCode));
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editable = _controller.isAdmin && !widget.isBase;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.currencyCode, style: theme.textTheme.titleSmall),
                if (widget.isBase)
                  Text(
                    'base',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: _rateController,
              enabled: editable,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                isDense: true,
                labelText: widget.currencyName,
                suffixIcon: widget.isBase ? const Icon(Icons.lock_outline, size: 18) : null,
              ),
            ),
          ),
          if (editable) ...[
            const SizedBox(width: 8),
            Obx(() {
              final busy = _controller.savingRateFor.value == widget.currencyCode;
              return IconButton(
                onPressed: busy
                    ? null
                    : () => _controller.saveExchangeRate(
                          widget.currencyCode,
                          _rateController.text,
                        ),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.check),
                tooltip: 'Save the ${widget.currencyCode} rate',
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _AppSection extends GetView<SettingsController> {
  const _AppSection();

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return _SectionCard(
      title: 'This device',
      subtitle: 'Preferences stored on this phone only.',
      children: [
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dns_outlined),
            title: const Text('API address'),
            subtitle: Text(controller.apiBaseUrl),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ApiAddressSheet.show(onChanged: controller.refreshAll),
          ),
        ),
        const Divider(height: 1),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Appearance'),
            subtitle: Text(themeController.labelFor(themeController.mode.value)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context, themeController),
          ),
        ),
        const Divider(height: 1),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('App version'),
            subtitle: Text(
              controller.appVersion.value.isEmpty ? '—' : controller.appVersion.value,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTheme(BuildContext context, ThemeController themeController) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Obx(
          () => RadioGroup<ThemeMode>(
            groupValue: themeController.mode.value,
            onChanged: (chosen) async {
              if (chosen != null) {
                await themeController.setMode(chosen);
              }
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: mode,
                    title: Text(themeController.labelFor(mode)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSection extends GetView<SettingsController> {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      title: 'Account',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.person_outline, color: theme.colorScheme.onPrimaryContainer),
          ),
          title: Text(controller.signedInAs),
          subtitle: Text('${controller.signedInUsername} · ${controller.roleLabel}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.signOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
