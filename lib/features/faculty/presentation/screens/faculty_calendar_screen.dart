import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/utils/time_utils.dart' show dateKey;
import '../../../../core/widgets/empty_error_views.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../appointments/presentation/widgets/appointment_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Month calendar of all faculty appointments with a day agenda below.
class FacultyCalendarScreen extends ConsumerStatefulWidget {
  const FacultyCalendarScreen({super.key});

  @override
  ConsumerState<FacultyCalendarScreen> createState() =>
      _FacultyCalendarScreenState();
}

class _FacultyCalendarScreenState
    extends ConsumerState<FacultyCalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Sign in to continue.')));
    }
    final all = ref.watch(facultyAppointmentsProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: all.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () =>
                ref.invalidate(facultyAppointmentsProvider(uid))),
        data: (items) {
          List<Appointment> forDay(DateTime d) {
            final k = dateKey(d);
            return items.where((a) => a.date == k).toList();
          }

          final selected = forDay(_selected);
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(facultyAppointmentsProvider(uid)),
            child: ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: TableCalendar<Appointment>(
                    firstDay: DateTime.now()
                        .subtract(const Duration(days: 365)),
                    lastDay:
                        DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focused,
                    selectedDayPredicate: (d) => isSameDay(d, _selected),
                    eventLoader: forDay,
                    onDaySelected: (sel, foc) => setState(() {
                      _selected = sel;
                      _focused = foc;
                    }),
                    onPageChanged: (foc) =>
                        setState(() => _focused = foc),
                    calendarStyle: CalendarStyle(
                      markersMaxCount: 3,
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(140),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                        formatButtonVisible: false),
                  ),
                ),
                if (selected.isEmpty)
                  const EmptyState(
                    title: 'No meetings this day',
                    subtitle: 'Pick a highlighted date to see its agenda.',
                  )
                else
                  for (final a in selected)
                    AppointmentTile(
                        appointment: a, counterpartRole: 'student'),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
