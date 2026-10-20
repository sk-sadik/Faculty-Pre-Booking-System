import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/appointment.dart';
import '../providers/appointment_providers.dart';

/// Student view of one booking: status tracking steps, details, cancel
/// (2-hour cutoff enforced) and accept/decline for faculty proposals.
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.appointmentId});
  final String appointmentId;

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState
    extends ConsumerState<BookingDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() call, String okMsg) async {
    setState(() => _busy = true);
    try {
      await call();
      if (mounted) context.showSnack(okMsg);
    } catch (e) {
      if (!mounted) return;
      context.showSnack(
          e
              .toString()
              .replaceFirst('BookingConflict: ', '')
              .replaceFirst('AppointmentRuleViolation: ', ''),
          isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _askConfirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Back')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Confirm')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final appt =
        ref.watch(appointmentDetailProvider(widget.appointmentId));
    final repo = ref.watch(appointmentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: appt.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(
                appointmentDetailProvider(widget.appointmentId))),
        data: (a) {
          if (a == null) {
            return const EmptyState(
                title: 'Booking not found',
                subtitle: 'It may have been removed.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TrackingSteps(status: a.status),
              const SizedBox(height: 12),
              _DetailsCard(appointment: a),
              const SizedBox(height: 12),
              if (a.status == AppointmentStatus.rescheduled)
                _ProposalCard(
                  appointment: a,
                  busy: _busy,
                  onAccept: () => _run(
                    () => repo.respondReschedule(
                        appointmentId: a.id, accept: true),
                    'New time accepted. The faculty has been notified.',
                  ),
                  onDecline: () async {
                    if (!await _askConfirm('Decline proposed time?',
                        'The booking will be cancelled.')) {
                      return;
                    }
                    await _run(
                      () => repo.respondReschedule(
                          appointmentId: a.id, accept: false),
                      'Proposal declined.',
                    );
                  },
                ),
              if (a.status == AppointmentStatus.pending ||
                  a.status == AppointmentStatus.approved)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!await _askConfirm(
                                'Cancel booking?',
                                'Cancellation is allowed up to 2 hours before the meeting.')) {
                              return;
                            }
                            await _run(
                              () => repo.cancelAsStudent(
                                  appointmentId: a.id,
                                  now: DateTime.now()),
                              'Booking cancelled.',
                            );
                          },
                    style: const ButtonStyle(
                        minimumSize: WidgetStatePropertyAll(
                            Size.fromHeight(48))),
                    child: const Text('Cancel booking'),
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child:
                      Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 3-step tracker: Requested → Confirmed → Done, with terminal states
/// (rejected/cancelled/no-show) shown as an ended track.
class _TrackingSteps extends StatelessWidget {
  const _TrackingSteps({required this.status});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final ended = status == AppointmentStatus.rejected ||
        status == AppointmentStatus.cancelled ||
        status == AppointmentStatus.noShow;
    final confirmed = status == AppointmentStatus.approved ||
        status == AppointmentStatus.rescheduled ||
        status == AppointmentStatus.completed;
    final done = status == AppointmentStatus.completed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _Dot(done: true, icon: Icons.send_outlined),
                _Line(
                    done: confirmed || ended,
                    ended: ended && !confirmed),
                _Dot(
                    done: confirmed,
                    icon: Icons.check_outlined),
                _Line(done: done, ended: false),
                _Dot(done: done, icon: Icons.task_alt_outlined),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Requested'),
                Text('Confirmed'),
                Text('Done'),
              ],
            ),
            const SizedBox(height: 8),
            StatusChip(status: status.value),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.icon});
  final bool done;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 16,
      backgroundColor:
          done ? scheme.primary : scheme.surfaceContainerHighest,
      child: Icon(icon,
          size: 16,
          color: done
              ? scheme.onPrimary
              : scheme.onSurfaceVariant),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.done, required this.ended});
  final bool done;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: done
              ? scheme.primary
              : ended
                  ? scheme.error
                  : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                    child: Text(a.facultyName.isEmpty
                        ? '?'
                        : a.facultyName[0].toUpperCase())),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(a.facultyName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      Text('${a.date} · ${a.startTime}–${a.endTime}'),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Purpose',
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.outline,
                    fontSize: 12)),
            Text(a.purpose,
                style:
                    const TextStyle(fontWeight: FontWeight.w600)),
            if (a.note != null && a.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Your note',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .outline,
                      fontSize: 12)),
              Text(a.note!),
            ],
            if (a.status == AppointmentStatus.rejected &&
                a.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withAlpha(120),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    'The faculty could not meet: ${a.rejectionReason}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.appointment,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final Appointment appointment;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New time proposed',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                '${appointment.facultyName} suggested ${appointment.proposedDate} at ${appointment.proposedStartTime}–${appointment.proposedEndTime}.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : onAccept,
              child: const Text('Accept new time'),
            ),
            TextButton(
              onPressed: busy ? null : onDecline,
              child: const Text('Decline (cancels booking)'),
            ),
          ],
        ),
      ),
    );
  }
}
