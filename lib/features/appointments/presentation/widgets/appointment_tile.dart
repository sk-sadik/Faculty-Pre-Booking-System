import 'package:flutter/material.dart';

import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/appointment.dart';

/// Shared appointment row used by faculty home/calendar and (Phase D)
/// student lists. Shows purpose, counterpart, slot and status.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    super.key,
    required this.appointment,
    this.counterpartRole = 'student',
    this.onTap,
  });

  final Appointment appointment;

  /// Whose name to show: 'student' (faculty view) or 'faculty' (student view).
  final String counterpartRole;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final other = counterpartRole == 'faculty'
        ? appointment.facultyName
        : appointment.studentName;
    String when;
    try {
      final d = parseDateKey(appointment.date);
      when =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · ${appointment.startTime}–${appointment.endTime}';
    } catch (_) {
      when = '${appointment.startTime}–${appointment.endTime}';
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(other.isEmpty ? '?' : other[0].toUpperCase()),
        ),
        title: Text(appointment.purpose,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$when\n$other',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: StatusChip(status: appointment.status.value),
      ),
    );
  }
}
