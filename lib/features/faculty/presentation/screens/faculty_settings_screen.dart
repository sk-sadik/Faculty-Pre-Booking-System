import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';

/// Booking preferences: max meetings per day and buffer between meetings.
/// Account-level settings (theme, sign out) live on the shared profile page.
class FacultySettingsScreen extends ConsumerStatefulWidget {
  const FacultySettingsScreen({super.key});

  @override
  ConsumerState<FacultySettingsScreen> createState() =>
      _FacultySettingsScreenState();
}

class _FacultySettingsScreenState
    extends ConsumerState<FacultySettingsScreen> {
  int _maxPerDay = 8;
  int _buffer = 10;
  bool _loaded = false;
  bool _busy = false;

  static const _bufferOptions = [0, 5, 10, 15, 20, 30];

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Sign in to continue.')));
    }
    final profile = ref.watch(userDocProvider(uid));
    final user = profile.valueOrNull;
    if (user != null && !_loaded) {
      _maxPerDay = user.effectiveMaxPerDay;
      _buffer = user.effectiveBufferMinutes;
      _loaded = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Booking settings')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily capacity',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                        'Once this many meetings are booked, students see no more slots that day.'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Fewer per day',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _maxPerDay > 1
                              ? () => setState(() => _maxPerDay--)
                              : null,
                        ),
                        Expanded(
                          child: Text('$_maxPerDay per day',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge),
                        ),
                        IconButton(
                          tooltip: 'More per day',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _maxPerDay < 30
                              ? () => setState(() => _maxPerDay++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buffer between meetings',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                        'Slots too close to another meeting are hidden from students.'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _bufferOptions
                          .map((b) => ChoiceChip(
                                label: Text(b == 0 ? 'None' : '$b min'),
                                selected: _buffer == b,
                                onSelected: (_) =>
                                    setState(() => _buffer = b),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await ref
                            .read(usersRepositoryProvider)
                            .updateBookingSettings(uid,
                                maxPerDay: _maxPerDay,
                                bufferMinutes: _buffer);
                        ref.invalidate(userDocProvider(uid));
                        if (context.mounted) {
                          context.showSnack('Settings saved.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          context.showSnack('Could not save: $e',
                              isError: true);
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Save settings'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_outline),
              label: const Text('Account & appearance'),
              onPressed: () => context.push(RouteNames.profile),
            ),
          ],
        ),
      ),
    );
  }
}
