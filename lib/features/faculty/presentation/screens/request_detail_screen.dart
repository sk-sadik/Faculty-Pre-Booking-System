import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/repositories/appointment_repository.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../appointments/presentation/providers/slot_providers.dart';

/// Faculty view of one appointment with every allowed action:
/// approve / reject (reason required) / propose new time / complete /
/// no-show / cancel. Writes go through the repository, which validates
/// transitions and notifies the student.
class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.appointmentId});
  final String appointmentId;

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState
    extends ConsumerState<RequestDetailScreen> {
  bool _busy = false;
  bool _proposing = false;
  DateTime _newDay = DateTime.now().add(const Duration(days: 1));
  int? _newStart;
  int? _newEnd;

  Future<void> _run(Future<void> Function() call, String okMsg) async {
    setState(() => _busy = true);
    try {
      await call();
      if (mounted) context.showSnack(okMsg);
    } catch (e) {
      if (!mounted) return;
      context.showSnack(
          e.toString().replaceFirst('BookingConflict: ', ''),
          isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            hintText: 'e.g. Out of station that week',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Back')),
          FilledButton(
              onPressed: () =>
                  Navigator.of(c).pop(ctrl.text.trim()),
              child: const Text('Reject')),
        ],
      ),
    ).then((v) {
      ctrl.dispose();
      return v;
    });
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
      appBar: AppBar(title: const Text('Request')),
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
                title: 'Request not found',
                subtitle: 'It may have been removed.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(appointment: a),
              const SizedBox(height: 12),
              if (_proposing && a.status == AppointmentStatus.approved)
                _ProposeCard(
                  appointment: a,
                  day: _newDay,
                  newStart: _newStart,
                  newEnd: _newEnd,
                  busy: _busy,
                  onDay: (d) => setState(() {
                    _newDay = d;
                    _newStart = null;
                    _newEnd = null;
                  }),
                  onSlot: (s, e) => setState(() {
                    _newStart = s;
                    _newEnd = e;
                  }),
                  onCancel: () =>
                      setState(() => _proposing = false),
                  onSend: () => _run(
                    () => repo.proposeReschedule(
                      appointmentId: a.id,
                      proposedDate: dateKey(_newDay),
                      proposedStartTime: formatHm(_newStart!),
                      proposedEndTime: formatHm(_newEnd!),
                    ),
                    'New time proposed. The student has been notified.',
                  ),
                )
              else
                _Actions(
                  appointment: a,
                  busy: _busy,
                  onApprove: a.status == AppointmentStatus.pending
                      ? () => _run(
                            () => repo.updateStatus(
                              appointmentId: a.id,
                              to: AppointmentStatus.approved,
                              notification: StatusNotification(
                                userId: a.studentId,
                                title: 'Request approved',
                                body:
                                    '${a.facultyName} approved your meeting on ${a.date} at ${a.startTime}.',
                                type: 'approved',
                              ),
                            ),
                            'Request approved.',
                          )
                      : null,
                  onReject: a.status == AppointmentStatus.pending
                      ? () async {
                          final reason = await _askReason();
                          if (reason == null || reason.isEmpty) {
                            if (context.mounted) {
                              context.showSnack(
                                  'A reason is required to reject.',
                                  isError: true);
                            }
                            return;
                          }
                          await _run(
                            () => repo.updateStatus(
                              appointmentId: a.id,
                              to: AppointmentStatus.rejected,
                              rejectionReason: reason,
                              notification: StatusNotification(
                                userId: a.studentId,
                                title: 'Request rejected',
                                body:
                                    '${a.facultyName} could not meet: $reason',
                                type: 'rejected',
                              ),
                            ),
                            'Request rejected.',
                          );
                        }
                      : null,
                  onPropose: a.status == AppointmentStatus.approved
                      ? () => setState(() => _proposing = true)
                      : null,
                  onComplete: a.status == AppointmentStatus.approved
                      ? () => _run(
                            () => repo.updateStatus(
                              appointmentId: a.id,
                              to: AppointmentStatus.completed,
                              notification: StatusNotification(
                                userId: a.studentId,
                                title: 'Meeting completed',
                                body:
                                    'Your meeting with ${a.facultyName} on ${a.date} was marked completed.',
                                type: 'completed',
                              ),
                            ),
                            'Marked completed.',
                          )
                      : null,
                  onNoShow: a.status == AppointmentStatus.approved
                      ? () async {
                          if (!await _askConfirm('Mark as no-show?',
                              '${a.studentName} did not turn up on ${a.date} at ${a.startTime}.')) {
                            return;
                          }
                          await _run(
                            () => repo.updateStatus(
                              appointmentId: a.id,
                              to: AppointmentStatus.noShow,
                              notification: StatusNotification(
                                userId: a.studentId,
                                title: 'Marked as no-show',
                                body:
                                    'You were marked as not attending the meeting on ${a.date} at ${a.startTime}.',
                                type: 'no_show',
                              ),
                            ),
                            'Marked as no-show.',
                          );
                        }
                      : null,
                  onCancel: a.status == AppointmentStatus.approved
                      ? () async {
                          if (!await _askConfirm('Cancel meeting?',
                              'The student will be notified.')) {
                            return;
                          }
                          await _run(
                            () => repo.updateStatus(
                              appointmentId: a.id,
                              to: AppointmentStatus.cancelled,
                              notification: StatusNotification(
                                userId: a.studentId,
                                title: 'Meeting cancelled',
                                body:
                                    '${a.facultyName} cancelled your meeting on ${a.date} at ${a.startTime}.',
                                type: 'cancelled',
                              ),
                            ),
                            'Meeting cancelled.',
                          );
                        }
                      : null,
                  onWithdraw:
                      a.status == AppointmentStatus.rescheduled
                          ? () => _run(
                                () => repo.updateStatus(
                                  appointmentId: a.id,
                                  to: AppointmentStatus.cancelled,
                                  notification: StatusNotification(
                                    userId: a.studentId,
                                    title: 'Proposal withdrawn',
                                    body:
                                        '${a.facultyName} withdrew the proposed time. The request was cancelled.',
                                    type: 'cancelled',
                                  ),
                                ),
                                'Proposal withdrawn.',
                              )
                          : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Summary header for the request.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.appointment});
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
                    child: Text(a.studentName.isEmpty
                        ? '?'
                        : a.studentName[0].toUpperCase())),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(a.studentName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      Text('${a.date} · ${a.startTime}–${a.endTime}'),
                    ],
                  ),
                ),
                StatusChip(status: a.status.value),
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
              Text('Note',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .outline,
                      fontSize: 12)),
              Text(a.note!),
            ],
            if (a.status == AppointmentStatus.rescheduled) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withAlpha(120),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    'Proposed: ${a.proposedDate} at ${a.proposedStartTime}–${a.proposedEndTime} — waiting on the student.'),
              ),
            ],
            if (a.status == AppointmentStatus.rejected &&
                a.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Text('Rejection reason: ${a.rejectionReason}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.appointment,
    required this.busy,
    this.onApprove,
    this.onReject,
    this.onPropose,
    this.onComplete,
    this.onNoShow,
    this.onCancel,
    this.onWithdraw,
  });

  final Appointment appointment;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onPropose;
  final VoidCallback? onComplete;
  final VoidCallback? onNoShow;
  final VoidCallback? onCancel;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, VoidCallback? fn,
        {bool tonal = false, bool destructive = false}) {
      const onlySize = ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)));
      final Widget button;
      if (destructive) {
        button = FilledButton(
          onPressed: busy ? null : fn,
          style: FilledButton.styleFrom(
            backgroundColor:
                Theme.of(context).colorScheme.error,
            foregroundColor:
                Theme.of(context).colorScheme.onError,
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(label),
        );
      } else if (tonal) {
        button = FilledButton.tonal(
          onPressed: busy ? null : fn,
          style: onlySize,
          child: Text(label),
        );
      } else {
        button = FilledButton(
          onPressed: busy ? null : fn,
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48)),
          child: Text(label),
        );
      }
      return SizedBox(width: double.infinity, child: button);
    }

    final buttons = <Widget>[];
    if (onApprove != null) {
      buttons.add(btn('Approve', onApprove));
      buttons.add(const SizedBox(height: 8));
    }
    if (onReject != null) {
      buttons.add(btn('Reject with reason', onReject, tonal: true));
      buttons.add(const SizedBox(height: 8));
    }
    if (onPropose != null) {
      buttons.add(btn('Propose a new time', onPropose, tonal: true));
      buttons.add(const SizedBox(height: 8));
    }
    if (onComplete != null) {
      buttons.add(btn('Mark completed', onComplete));
      buttons.add(const SizedBox(height: 8));
    }
    if (onNoShow != null) {
      buttons.add(btn('Mark no-show', onNoShow, tonal: true));
      buttons.add(const SizedBox(height: 8));
    }
    if (onCancel != null) {
      buttons.add(btn('Cancel meeting', onCancel, destructive: true));
      buttons.add(const SizedBox(height: 8));
    }
    if (onWithdraw != null) {
      buttons.add(btn('Withdraw proposal', onWithdraw, destructive: true));
      buttons.add(const SizedBox(height: 8));
    }
    if (buttons.isEmpty) {
      return const Text(
          'No actions available — this request is closed.',
          textAlign: TextAlign.center);
    }
    if (busy) {
      buttons.add(const Center(child: CircularProgressIndicator()));
    }
    return Column(children: buttons);
  }
}

class _ProposeCard extends ConsumerWidget {
  const _ProposeCard({
    required this.appointment,
    required this.day,
    required this.newStart,
    required this.newEnd,
    required this.busy,
    required this.onDay,
    required this.onSlot,
    required this.onCancel,
    required this.onSend,
  });

  final Appointment appointment;
  final DateTime day;
  final int? newStart;
  final int? newEnd;
  final bool busy;
  final void Function(DateTime) onDay;
  final void Function(int, int) onSlot;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = dateKey(day);
    final slots = ref.watch(freeSlotsProvider(
        (facultyId: appointment.facultyId, dateKey: key)));
    final days =
        List.generate(14, (i) => DateTime.now().add(Duration(days: i)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Propose a new time',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final d = days[i];
                  final sel = d.year == day.year &&
                      d.month == day.month &&
                      d.day == day.day;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('${d.day}/${d.month}'),
                      selected: sel,
                      showCheckmark: false,
                      onSelected: (_) => onDay(d),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            slots.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator())),
              error: (e, _) => Text('Could not load slots: $e'),
              data: (items) {
                if (items.isEmpty) {
                  return const Text(
                      'No free slots this day — try another date.');
                }
                return Wrap(
                  spacing: 8,
                  children: [
                    for (final s in items)
                      ChoiceChip(
                        label: Text(s.label),
                        selected: newStart == s.startMinutes,
                        onSelected: (_) =>
                            onSlot(s.startMinutes, s.endMinutes),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  (busy || newStart == null) ? null : onSend,
              child: const Text('Send proposal'),
            ),
            TextButton(
                onPressed: busy ? null : onCancel,
                child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}
