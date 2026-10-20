import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../appointments/presentation/widgets/appointment_tile.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';

/// Faculty landing: greeting, "Available now" toggle, today/pending stats
/// and today's schedule. Data comes from live Firestore streams.
class FacultyHomeScreen extends ConsumerWidget {
  const FacultyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Sign in to continue.')));
    }
    final profile = ref.watch(userDocProvider(uid));
    final today = ref.watch(facultyDayAppointmentsProvider(
        (facultyId: uid, dateKey: dateKey(DateTime.now()))));
    final pending = ref.watch(facultyPendingRequestsProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Home'),
        actions: [
          IconButton(
            tooltip: 'Booking settings',
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => context.push(RouteNames.facultySettings),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(RouteNames.profile),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userDocProvider(uid));
          ref.invalidate(facultyDayAppointmentsProvider(
              (facultyId: uid, dateKey: dateKey(DateTime.now()))));
          ref.invalidate(facultyPendingRequestsProvider(uid));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _Header(profile: profile),
            _AvailableNowCard(uid: uid, profile: profile),
            _StatsRow(today: today, pending: pending),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Today · ${DateFormat('EEE, MMM d').format(DateTime.now())}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700),
              ),
            ),
            _TodayList(today: today, uid: uid),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final AsyncValue<AppUser?> profile;

  @override
  Widget build(BuildContext context) {
    return profile.when(
      loading: () => const ListTile(
          title: Text('Welcome'), subtitle: Text('Loading profile…')),
      error: (_, __) =>
          const ListTile(title: Text('Welcome back')),
      data: (user) => ListTile(
        leading: CircleAvatar(
          backgroundImage:
              user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
          child: user?.photoUrl == null
              ? Text(user?.name.isNotEmpty == true
                  ? user!.name[0].toUpperCase()
                  : '?')
              : null,
        ),
        title: Text('Hello, ${user?.name ?? 'Faculty'}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(user?.department ?? ''),
      ),
    );
  }
}

class _AvailableNowCard extends ConsumerStatefulWidget {
  const _AvailableNowCard({required this.uid, required this.profile});
  final String uid;
  final AsyncValue<AppUser?> profile;

  @override
  ConsumerState<_AvailableNowCard> createState() =>
      _AvailableNowCardState();
}

class _AvailableNowCardState extends ConsumerState<_AvailableNowCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final available =
        widget.profile.valueOrNull?.isAvailableNow == true;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: available
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: SwitchListTile(
        title: const Text('Available now',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(available
            ? 'Students see you as free for walk-ins.'
            : 'Turn on when you can take walk-ins.'),
        value: available,
        onChanged: _busy
            ? null
            : (v) async {
                setState(() => _busy = true);
                try {
                  await ref
                      .read(usersRepositoryProvider)
                      .setAvailableNow(widget.uid, v);
                } catch (e) {
                  if (context.mounted) {
                    context.showSnack('Could not update: $e',
                        isError: true);
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.today, required this.pending});
  final AsyncValue<List<Appointment>> today;
  final AsyncValue<List<Appointment>> pending;

  @override
  Widget build(BuildContext context) {
    int todayCount = today.valueOrNull?.length ?? 0;
    int pendingCount = pending.valueOrNull?.length ?? 0;
    int approved = today.valueOrNull
            ?.where((a) => a.status == AppointmentStatus.approved)
            .length ??
        0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _StatCard(
              label: "Today's meetings",
              value: '$todayCount',
              icon: Icons.today_outlined),
          const SizedBox(width: 8),
          _StatCard(
              label: 'Pending requests',
              value: '$pendingCount',
              icon: Icons.inbox_outlined,
              onTap: () => context.go(RouteNames.facultyInbox)),
          const SizedBox(width: 8),
          _StatCard(
              label: 'Approved today',
              value: '$approved',
              icon: Icons.check_circle_outline),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
    if (onTap == null) return Expanded(child: card);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _TodayList extends ConsumerWidget {
  const _TodayList({required this.today, required this.uid});
  final AsyncValue<List<Appointment>> today;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return today.when(
      loading: () => const Column(
        children: [
          SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()))
        ],
      ),
      error: (e, _) => ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(facultyDayAppointmentsProvider(
            (facultyId: uid, dateKey: dateKey(DateTime.now())))),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            title: 'Nothing scheduled today',
            subtitle:
                'New student requests will appear here in real time.',
          );
        }
        return Column(
          children: [
            for (final a in items)
              AppointmentTile(
                  appointment: a,
                  counterpartRole: 'student',
                  onTap: () => context
                      .push(RouteNames.facultyRequest(a.id))),
          ],
        );
      },
    );
  }
}
