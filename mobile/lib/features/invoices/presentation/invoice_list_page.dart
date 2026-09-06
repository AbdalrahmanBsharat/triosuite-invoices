import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money_format.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/invoice.dart';
import 'invoice_list_controller.dart';

/// The app's home: every invoice, filtered by status and searchable by number or customer.
///
/// Cancelled invoices are listed like any other — nothing is hidden — which is why the status chips
/// include a Cancelled filter rather than an "include cancelled" toggle.
class InvoiceListPage extends GetView<InvoiceListController> {
  const InvoiceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed<void>(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              _SearchField(controller: controller),
              _StatusFilterBar(controller: controller),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed<void>(AppRoutes.invoiceForm),
        icon: const Icon(Icons.add),
        label: const Text('New invoice'),
      ),
      body: Obx(() {
        final isFiltered =
            controller.statusFilter.value != null || controller.searchTerm.value.isNotEmpty;

        return AsyncStateView(
          isLoading: controller.loading.value,
          isEmpty: controller.invoices.isEmpty,
          error: controller.error.value,
          onRetry: controller.reload,
          emptyIcon: isFiltered ? Icons.search_off : Icons.receipt_long_outlined,
          emptyTitle: isFiltered ? 'No matching invoices' : 'No invoices yet',
          emptyMessage: isFiltered
              ? 'Try a different search term, or clear the status filter.'
              : 'Tap “New invoice” to create the first one.',
          emptyAction: isFiltered
              ? TextButton.icon(
                  onPressed: () {
                    controller.clearSearch();
                    controller.setStatusFilter(null);
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear filters'),
                )
              : null,
          child: RefreshIndicator(
            onRefresh: controller.refreshQuietly,
            child: ListView.separated(
              controller: controller.scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: controller.invoices.length + (controller.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= controller.invoices.length) {
                  return const _LoadingMoreRow();
                }
                final invoice = controller.invoices[index];
                return _InvoiceRow(
                  invoice: invoice,
                  symbol: controller.symbolOf(invoice.currencyCode),
                  minorUnits: controller.minorUnitsOf(invoice.currencyCode),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final InvoiceListController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: controller.searchController,
        onChanged: controller.onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by number or customer',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: Obx(
            () => controller.searchTerm.value.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: controller.clearSearch,
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear search',
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.controller});

  final InvoiceListController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Obx(() {
        final selected = controller.statusFilter.value;

        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _chip(context, label: 'All', isSelected: selected == null, status: null),
            for (final status in InvoiceStatus.values)
              _chip(
                context,
                label: status.label,
                isSelected: selected == status,
                status: status,
              ),
          ],
        );
      }),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required InvoiceStatus? status,
  }) {
    final accent = status == null ? null : StatusBadge.colorFor(status);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => controller.setStatusFilter(status),
        avatar: accent == null
            ? null
            : Icon(StatusBadge.iconFor(status!), size: 16, color: accent),
        selectedColor: accent?.withValues(alpha: 0.18),
        checkmarkColor: accent,
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.symbol,
    required this.minorUnits,
  });

  final InvoiceSummary invoice;
  final String symbol;
  final int minorUnits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(Intl.getCurrentLocale());

    return Card(
      child: InkWell(
        onTap: () => Get.toNamed<void>(AppRoutes.invoiceDetailFor(invoice.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.invoiceNumber,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  StatusBadge(status: invoice.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                invoice.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      dateFormat.format(invoice.issueDate),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    MoneyFormat.amount(
                      invoice.grandTotal,
                      symbol: symbol,
                      minorUnits: minorUnits,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingMoreRow extends StatelessWidget {
  const _LoadingMoreRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
