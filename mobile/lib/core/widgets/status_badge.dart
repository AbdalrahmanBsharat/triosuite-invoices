import 'package:flutter/material.dart';

import '../../features/invoices/domain/invoice.dart';
import '../theme/app_theme.dart';

/// The coloured pill that says whether an invoice is a draft, approved or cancelled.
///
/// Colour alone never carries the meaning: the label is always present, so the badge still reads
/// correctly for someone who cannot distinguish the three colours.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.large = false});

  final InvoiceStatus status;

  /// Slightly bigger, for the detail screen's header.
  final bool large;

  static Color colorFor(InvoiceStatus status) => switch (status) {
        InvoiceStatus.draft => AppTheme.draftColor,
        InvoiceStatus.approved => AppTheme.approvedColor,
        InvoiceStatus.cancelled => AppTheme.cancelledColor,
      };

  static IconData iconFor(InvoiceStatus status) => switch (status) {
        InvoiceStatus.draft => Icons.edit_note,
        InvoiceStatus.approved => Icons.lock_outline,
        InvoiceStatus.cancelled => Icons.block,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 9,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(status), size: large ? 16 : 13, color: color),
          SizedBox(width: large ? 6 : 4),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: large ? 13 : 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
