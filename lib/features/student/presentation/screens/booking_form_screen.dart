import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../appointments/presentation/providers/slot_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';

/// Booking form for a pre-selected slot. Re-checks that the slot is still
/// free before confirming; conflicts surface as friendly messages.
class BookingFormScreen extends ConsumerStatefulWidget {
  const BookingFormScreen({
    super.key,
    required this.facultyId,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  final String facultyId;
  final String date;
  final String startTime;
  final String endTime;

  @override
  ConsumerState<BookingFormScreen> createState() =>
      _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  final _form = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _purpose.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      context.showSnack('Sign in to book.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final student =
          await ref.read(userDocProvider(uid).future);
      final faculty =
          await ref.read(userDocProvider(widget.facultyId).future);
      if (student == null || student.name.isEmpty) {
        throw Exception('Your profile is incomplete.');
      }
      final id = await ref
          .read(appointmentRepositoryProvider)
          .bookAppointment(
            studentId: uid,
            studentName: student.name,
            facultyId: widget.facultyId,
            facultyName: faculty?.name ?? 'Faculty',
            date: widget.date,
            startTime: widget.startTime,
            endTime: widget.endTime,
            purpose: _purpose.text.trim(),
            note: _note.text.trim().isEmpty
                ? null
                : _note.text.trim(),
          );
      if (mounted) context.go(RouteNames.bookingConfirmed(id));
    } catch (e) {
      if (!mounted) return;
      final msg = e
          .toString()
          .replaceFirst('BookingConflict: ', '')
          .replaceFirst('Exception: ', '');
      context.showSnack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final faculty = ref.watch(userDocProvider(widget.facultyId));
    final freshness = ref.watch(freeSlotsProvider(
        (facultyId: widget.facultyId, dateKey: widget.date)));
    // If the slot list loaded and no longer contains our slot, someone
    // took it — block confirmation instead of failing at checkout.
    final stillFree = freshness.whenOrNull(
          data: (slots) {
            try {
              final s = _toMinutes(widget.startTime);
              final e = _toMinutes(widget.endTime);
              return slots.any(
                  (x) => x.startMinutes == s && x.endMinutes == e);
            } catch (_) {
              return false;
            }
          },
        ) ??
        true;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm booking')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(
                            Icons.event_available_outlined),
                        title: Text(
                            faculty.valueOrNull?.name ?? 'Faculty',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${widget.date} · ${widget.startTime}–${widget.endTime}'),
                      ),
                    ),
                    if (!stillFree)
                      Card(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer,
                        child: const ListTile(
                          leading: Icon(Icons.warning_amber_outlined),
                          title: Text(
                              'This slot was just taken. Go back and pick another time.'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Purpose / topic',
                      hint: 'e.g. Doubts in Chapter 4',
                      controller: _purpose,
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Purpose is required';
                        }
                        if (v.trim().length < 3) {
                          return 'Describe your topic briefly';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Note (optional)',
                      hint: 'Anything the faculty should know',
                      controller: _note,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: (_busy || !stillFree) ? null : _confirm,
                      style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(52)),
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white),
                            )
                          : const Text('Confirm booking'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _toMinutes(String hm) {
    final p = hm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
}
