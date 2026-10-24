import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../appointments/presentation/widgets/appointment_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';

/// Student landing: greeting, next approved visit, quick stats and
/// shortcuts. All data is live from Firestore.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Sign in to continue.')));
    }
    final profile = ref.watch(userDocProvider(uid));
    final bookings = ref.watch(studentAppointmentsProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Profile & settings',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(RouteNames.profile),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userDocProvider(uid));
          ref.invalidate(studentAppointmentsProvider(uid));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            profile.when(
              loading: () => const ListTile(
                  title: Text('Welcome'),
                  subtitle: Text('Loading profile…')),
              error: (_, _) =>
                  const ListTile(title: Text('Welcome back')),
              data: (user) => ListTile(
                leading: CircleAvatar(
                    child: Text(user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : '?')),
                title: Text('Hello, ${user?.name ?? 'Student'}',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    Text('${user?.department ?? ''} · ${user?.year ?? ''} year'),
              ),
            ),
            _NextVisit(bookings: bookings),
            _Stats(bookings: bookings),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Quick actions',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Find faculty'),
                      onPressed: () =>
                          context.go(RouteNames.studentDirectory),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.event_note_outlined),
                      label: const Text('My bookings'),
                      onPressed: () =>
                          context.go(RouteNames.studentBookings),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Upcoming approved visits',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            _UpcomingList(bookings: bookings),
          ],
        ),
      ),
    );
  }
}

/// The next approved meeting (today or later), if any.
class _NextVisit extends StatelessWidget {
  const _NextVisit({required this.bookings});
  final AsyncValue<List<Appointment>> bookings;

  @override
  Widget build(BuildContext context) {
    final items = bookings.valueOrNull;
    if (items == null) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final today = dateKey(DateTime.now());
    final next = items
        .where((a) =>
            a.status == AppointmentStatus.approved &&
            a.date.compareTo(today) >= 0)
        .toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.startTime.compareTo(b.startTime);
      });
    if (next.isEmpty) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          leading: Icon(Icons.event_available_outlined),
          title: Text('No upcoming visits'),
          subtitle: Text('Browse faculty and book your first meeting.'),
        ),
      );
    }
    final a = next.first;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.event_available),
        title: Text('${a.facultyName} · ${a.startTime}–${a.endTime}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${a.date} · ${a.purpose}'),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.bookings});
  final AsyncValue<List<Appointment>> bookings;

  @override
  Widget build(BuildContext context) {
    final items = bookings.valueOrNull ?? const <Appointment>[];
    int count(AppointmentStatus s) =>
        items.where((a) => a.status == s).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _Stat(
              label: 'Pending',
              value: '${count(AppointmentStatus.pending)}',
              icon: Icons.hourglass_top_outlined),
          const SizedBox(width: 8),
          _Stat(
              label: 'Approved',
              value: '${count(AppointmentStatus.approved)}',
              icon: Icons.check_circle_outline),
          const SizedBox(width: 8),
          _Stat(
              label: 'Completed',
              value: '${count(AppointmentStatus.completed)}',
              icon: Icons.task_alt_outlined),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon,
                  color: Theme.of(context).colorScheme.primary,
                  semanticLabel: label),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingList extends ConsumerWidget {
  const _UpcomingList({required this.bookings});
  final AsyncValue<List<Appointment>> bookings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return bookings.when(
      loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (items) {
        final upcoming = items
            .where((a) =>
                (a.status == AppointmentStatus.approved ||
                    a.status == AppointmentStatus.pending) &&
                a.date.compareTo(dateKey(DateTime.now())) >= 0)
            .toList()
          ..sort((a, b) {
            final c = a.date.compareTo(b.date);
            return c != 0 ? c : a.startTime.compareTo(b.startTime);
          });
        if (upcoming.isEmpty) {
          return const EmptyState(
            title: 'Nothing upcoming',
            subtitle: 'Approved visits will show up here.',
          );
        }
        return Column(
          children: [
            for (final a in upcoming.take(3))
              AppointmentTile(
                  appointment: a,
                  counterpartRole: 'faculty',
                  onTap: () =>
                      context.push(RouteNames.studentBooking(a.id))),
          ],
        );
      },
    );
  }
}
