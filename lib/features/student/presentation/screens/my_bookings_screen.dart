import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../appointments/presentation/widgets/appointment_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// My Bookings with status tabs. Detail + cancel/answer actions arrive in
/// Phase E; rows are informational until then.
class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  static const _tabs = [
    (label: 'Pending', statuses: [AppointmentStatus.pending]),
    (label: 'Approved', statuses: [AppointmentStatus.approved]),
    (
      label: 'Rescheduled',
      statuses: [AppointmentStatus.rescheduled]
    ),
    (label: 'Rejected', statuses: [AppointmentStatus.rejected]),
    (
      label: 'Completed',
      // Past visits: completed + faculty-marked no-shows.
      statuses: [AppointmentStatus.completed, AppointmentStatus.noShow]
    ),
    (label: 'Cancelled', statuses: [AppointmentStatus.cancelled]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Sign in to continue.')));
    }
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My bookings'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final t in _tabs) Tab(text: t.label)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final t in _tabs) _TabList(uid: uid, statuses: t.statuses),
          ],
        ),
      ),
    );
  }
}

class _TabList extends ConsumerWidget {
  const _TabList({required this.uid, required this.statuses});
  final String uid;
  final List<AppointmentStatus> statuses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(studentAppointmentsProvider(uid));
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(studentAppointmentsProvider(uid)),
      child: bookings.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ListView(children: [
          ErrorState(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(studentAppointmentsProvider(uid)))
        ]),
        data: (items) {
          final filtered = items
              .where((a) => statuses.contains(a.status))
              .toList();
          if (filtered.isEmpty) {
            return ListView(children: const [
              EmptyState(
                title: 'Nothing here',
                subtitle:
                    'Bookings with this status will appear in this tab.',
              )
            ]);
          }
          return ListView.builder(
            itemCount: filtered.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, i) => AppointmentTile(
                appointment: filtered[i],
                counterpartRole: 'faculty',
                onTap: () => context.push(
                    RouteNames.studentBooking(filtered[i].id))),
          );
        },
      ),
    );
  }
}
