import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Color-coded status chip reused by appointments/notifications later.
/// Already complete in Phase 1 so later phases just import it.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;

  Color _color() {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.pending;
      case 'approved':
        return AppColors.approved;
      case 'rejected':
        return AppColors.rejected;
      case 'rescheduled':
        return AppColors.rescheduled;
      case 'cancelled':
        return AppColors.cancelled;
      case 'completed':
        return AppColors.completed;
      case 'no_show':
      case 'no-show':
        return AppColors.noShow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Chip(
      label: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            color: c, fontSize: 11, fontWeight: FontWeight.w700),
      ),
      backgroundColor: c.withAlpha(28),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
