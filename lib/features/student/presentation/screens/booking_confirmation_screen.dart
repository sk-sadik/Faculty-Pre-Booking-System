import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';

/// Post-booking confirmation: summary of the pending request with
/// shortcuts to bookings and the directory.
class BookingConfirmationScreen extends ConsumerWidget {
  const BookingConfirmationScreen(
      {super.key, required this.appointmentId});
  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appt = ref.watch(appointmentDetailProvider(appointmentId));
    return Scaffold(
      appBar: AppBar(
          title: const Text('Booking confirmation'),
          automaticallyImplyLeading: false),
      body: appt.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref
                .invalidate(appointmentDetailProvider(appointmentId))),
        data: (a) {
          if (a == null) {
            return const EmptyState(
                title: 'Booking not found',
                subtitle: 'It may still be syncing — check My bookings.');
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          semanticLabel: 'Booking requested'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Request sent!',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'The faculty member will approve, reject or propose a new time. You will be notified of every change.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _Row(
                                label: 'Faculty',
                                value: a.facultyName),
                            _Row(
                                label: 'Date', value: a.date),
                            _Row(
                                label: 'Time',
                                value:
                                    '${a.startTime}–${a.endTime}'),
                            _Row(
                                label: 'Purpose',
                                value: a.purpose),
                            if (a.note != null &&
                                a.note!.isNotEmpty)
                              _Row(label: 'Note', value: a.note!),
                            const SizedBox(height: 8),
                            StatusChip(status: a.status.value),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () =>
                          context.go(RouteNames.studentBookings),
                      style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(52)),
                      child: const Text('View my bookings'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          context.go(RouteNames.studentDirectory),
                      child: const Text('Book another meeting'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .outline))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
