import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/router/route_names.dart';
import '../providers/auth_providers.dart';

/// Shared Profile / Settings screen (Phase 1 scope):
/// shows signed-in profile, theme switcher, logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: profile.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(user == null || user.name.isEmpty
                      ? '?'
                      : user.name[0].toUpperCase()),
                ),
                title: Text(user?.name ?? 'No profile'),
                subtitle: Text(
                    '${user?.email ?? ''}\n${user?.role.name.toUpperCase() ?? ''}'),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                      title: Text('Appearance'),
                      leading: Icon(Icons.palette_outlined)),
                  RadioGroup<ThemeMode>(
                    groupValue: themeMode,
                    onChanged: (m) {
                      if (m != null) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setMode(m);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<ThemeMode>(
                            title: Text('System'), value: ThemeMode.system),
                        RadioListTile<ThemeMode>(
                            title: Text('Light'), value: ThemeMode.light),
                        RadioListTile<ThemeMode>(
                            title: Text('Dark'), value: ThemeMode.dark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () async {
                await ref
                    .read(authControllerProvider.notifier)
                    .signOut();
                if (context.mounted) context.go(RouteNames.login);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
