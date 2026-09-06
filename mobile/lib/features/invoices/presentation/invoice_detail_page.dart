import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money_format.dart';
import '../../../core/money/tax_mode.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/invoice.dart';
import 'invoice_detail_controller.dart';
import 'widgets/confirm_dialogs.dart';

/// One invoice in full: header, lines, totals and the audit trail.
///
/// Which actions appear is driven entirely by the invoice's status and the caller's role. An
/// approved invoice shows a lock and offers no edit affordance at all — not a disabled one — so
/// there is nothing to tap and be refused.
class InvoiceDetailPage extends GetView<InvoiceDetailController> {
  const InvoiceDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.invoice.value?.invoiceNumber ?? 'Invoice')),
        actions: [
          Obx(() => controller.loading.value
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: controller.load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload',
                )),
        ],
      ),
      body: Obx(() {
        final invoice = controller.invoice.value;

        return AsyncStateView(
          isLoading: controller.loading.value && invoice == null,
          isEmpty: false,
          error: controller.error.value,
          onRetry: controller.load,
          child: invoice == null
              ? const SizedBox.shrink()
              : _Body(invoice: invoice, controller: controller),
        );
      }),
      bottomNavigationBar: Obx(() {
        final invoice = controller.invoice.value;
        if (invoice == null) {
          return const SizedBox.shrink();
        }
        return _ActionBar(invoice: invoice, controller: controller);
      }),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.invoice, required this.controller});

  final Invoice invoice;
  final InvoiceDetailController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _HeaderCard(invoice: invoice),
          const SizedBox(height: 16),
          _LinesCard(invoice: invoice),
          const SizedBox(height: 16),
          _TotalsCard(invoice: invoice, controller: controller),
          const SizedBox(height: 16),
          _AuditCard(invoice: invoice),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMMd(Intl.getCurrentLocale());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    invoice.invoiceNumber,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                StatusBadge(status: invoice.status, large: true),
              ],
            ),
            if (invoice.status == InvoiceStatus.approved) ...[
              const SizedBox(height: 12),
              _Notice(
                icon: Icons.lock_outline,
                color: StatusBadge.colorFor(InvoiceStatus.approved),
                text: 'Approved and locked. Its contents can no longer be changed.',
              ),
            ],
            if (invoice.status == InvoiceStatus.cancelled) ...[
              const SizedBox(height: 12),
              _Notice(
                icon: Icons.block,
                color: StatusBadge.colorFor(InvoiceStatus.cancelled),
                text: 'Cancelled. Kept as a record; read-only for ever.',
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            _Field(label: 'Customer', value: invoice.customerName),
            _Field(label: 'Issue date', value: dateFormat.format(invoice.issueDate)),
            _Field(
              label: 'Currency',
              value: invoice.showsBaseCurrencyTotal
                  ? '${invoice.currencyCode} · 1 ${invoice.currencyCode} = '
                      '${MoneyFormat.exchangeRate(invoice.exchangeRate)} '
                      '${invoice.baseCurrencyCode}'
                  : '${invoice.currencyCode} (base currency)',
            ),
            _Field(
              label: 'Tax mode',
              value: '${invoice.taxMode.label} — ${invoice.taxMode.description}',
            ),
            if (invoice.notes != null && invoice.notes!.isNotEmpty)
              _Field(label: 'Notes', value: invoice.notes!),
          ],
        ),
      ),
    );
  }
}

class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invoice.lines.length == 1 ? '1 line' : '${invoice.lines.length} lines',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            if (invoice.lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'This draft has no lines yet. It cannot be approved until it has at least one.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              for (final line in invoice.lines)
                _LineRow(line: line, invoice: invoice),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.invoice});

  final InvoiceLine line;
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minorUnits = invoice.currencyMinorUnits;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${line.lineNo}.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.itemName, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${MoneyFormat.plain(line.quantity, minorUnits: 3)} × '
                      '${MoneyFormat.plain(line.unitPrice, minorUnits: minorUnits)}'
                      '  ·  tax ${MoneyFormat.taxRate(line.taxRate)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (line.barcode != null)
                      Text(
                        line.barcode!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                MoneyFormat.plain(line.grossAmount, minorUnits: minorUnits),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.invoice, required this.controller});

  final Invoice invoice;
  final InvoiceDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minorUnits = invoice.currencyMinorUnits;
    final symbol = invoice.currencySymbol;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _TotalRow(
              label: 'Subtotal',
              value: MoneyFormat.amount(invoice.subtotal,
                  symbol: symbol, minorUnits: minorUnits),
            ),
            _TotalRow(
              label: 'Tax',
              value: MoneyFormat.amount(invoice.taxTotal,
                  symbol: symbol, minorUnits: minorUnits),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            _TotalRow(
              label: 'Total',
              value: MoneyFormat.amount(invoice.grandTotal,
                  symbol: symbol, minorUnits: minorUnits),
              emphasise: true,
            ),
            if (invoice.showsBaseCurrencyTotal) ...[
              const SizedBox(height: 6),
              _TotalRow(
                label: 'Total in ${invoice.baseCurrencyCode}',
                value: MoneyFormat.amount(
                  invoice.grandTotalBase,
                  symbol: controller.baseSymbol,
                  minorUnits: controller.baseMinorUnits,
                ),
                subdued: true,
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _explainTax(invoice),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One sentence explaining how these figures came about, so nobody has to guess whether the
  /// prices already contained the tax.
  static String _explainTax(Invoice invoice) {
    final zeroTax = invoice.taxTotal == Decimal.zero;
    if (zeroTax) {
      return 'No tax on this invoice — every line is zero-rated.';
    }
    return invoice.taxMode == TaxMode.exclusive
        ? 'Unit prices are net; tax was added on top of each line.'
        : 'Unit prices already included tax; the net amount was extracted from each line.';
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
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
        ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    final color = subdued ? theme.colorScheme.onSurfaceVariant : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style?.copyWith(color: color))),
          Text(
            value,
            style: style?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stampFormat = DateFormat.yMMMd(Intl.getCurrentLocale()).add_jm();

    String stamp(String? who, DateTime? when) {
      if (who == null && when == null) {
        return '—';
      }
      final at = when == null ? '' : ' · ${stampFormat.format(when.toLocal())}';
      return '${who ?? 'Unknown'}$at';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audit trail', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _Field(label: 'Created', value: stamp(invoice.createdBy, invoice.createdAt)),
            if (invoice.approvedAt != null || invoice.approvedBy != null)
              _Field(label: 'Approved', value: stamp(invoice.approvedBy, invoice.approvedAt)),
            if (invoice.cancelledAt != null || invoice.cancelledBy != null)
              _Field(
                label: 'Cancelled',
                value: stamp(invoice.cancelledBy, invoice.cancelledAt),
              ),
            if (invoice.cancellationReason != null)
              _Field(label: 'Reason', value: invoice.cancellationReason!),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.invoice, required this.controller});

  final Invoice invoice;
  final InvoiceDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit = controller.canEdit;
    final canApprove = controller.canApprove;
    final canCancel = controller.canCancel;

    if (!canEdit && !canApprove && !canCancel) {
      if (!controller.cancelHiddenByRole) {
        return const SizedBox.shrink();
      }
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          'Only an administrator can cancel an invoice.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Obx(() {
        final busy = controller.acting.value;

        return Row(
          children: [
            if (canEdit)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => Get.toNamed<void>(
                            AppRoutes.invoiceForm,
                            arguments: {AppRoutes.editInvoiceIdArgument: invoice.id},
                          ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
            if (canEdit && (canApprove || canCancel)) const SizedBox(width: 10),
            if (canCancel)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final reason = await ConfirmDialogs.cancel(
                            invoiceNumber: invoice.invoiceNumber,
                          );
                          if (reason != null) {
                            await controller.cancel(reason: reason);
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                  ),
                  icon: const Icon(Icons.block),
                  label: const Text('Cancel'),
                ),
              ),
            if (canCancel && canApprove) const SizedBox(width: 10),
            if (canApprove)
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final confirmed = await ConfirmDialogs.approve(
                            invoiceNumber: invoice.invoiceNumber,
                          );
                          if (confirmed) {
                            await controller.approve();
                          }
                        },
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
