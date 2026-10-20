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

/// Faculty inbox: pending requests, proposals awaiting students, history.
class RequestsInboxScreen extends ConsumerWidget {
  const RequestsInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Sign in to continue.')));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Proposed'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _InboxTab(
                uid: uid,
                match: (s) => s == AppointmentStatus.pending,
                emptyTitle: 'No pending requests',
                emptySubtitle:
                    'New student booking requests will appear here.'),
            _InboxTab(
                uid: uid,
                match: (s) => s == AppointmentStatus.rescheduled,
                emptyTitle: 'No proposals waiting',
                emptySubtitle:
                    'Times you propose to students wait here for an answer.'),
            _InboxTab(
                uid: uid,
                match: (s) =>
                    s != AppointmentStatus.pending &&
                    s != AppointmentStatus.rescheduled,
                emptyTitle: 'No history yet',
                emptySubtitle:
                    'Approved, completed and closed requests show up here.'),
          ],
        ),
      ),
    );
  }
}

class _InboxTab extends ConsumerWidget {
  const _InboxTab({
    required this.uid,
    required this.match,
    required this.emptyTitle,
    required this.emptySubtitle,
  });
  final String uid;
  final bool Function(AppointmentStatus) match;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(facultyAppointmentsProvider(uid));
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(facultyAppointmentsProvider(uid)),
      child: inbox.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ListView(children: [
          ErrorState(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(facultyAppointmentsProvider(uid)))
        ]),
        data: (items) {
          final filtered =
              items.where((a) => match(a.status)).toList();
          if (filtered.isEmpty) {
            return ListView(children: [
              EmptyState(title: emptyTitle, subtitle: emptySubtitle)
            ]);
          }
          return ListView.builder(
            itemCount: filtered.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, i) => AppointmentTile(
              appointment: filtered[i],
              counterpartRole: 'student',
              onTap: () => context.push(
                  RouteNames.facultyRequest(filtered[i].id)),
            ),
          );
        },
      ),
    );
  }
}
