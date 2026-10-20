import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/push_bootstrap.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initResult = await _initFirebase();
  runApp(ProviderScope(child: FacultyPreBookingApp(initResult: initResult)));
}

/// Result of Firebase bootstrap so the UI can explain setup failures
/// (e.g. "No Firebase App '[DEFAULT]' has been created") instead of crashing.
class FirebaseInitResult {
  const FirebaseInitResult({required this.ok, this.message});
  final bool ok;
  final String? message;
}

Future<FirebaseInitResult> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return const FirebaseInitResult(ok: true);
  } catch (e) {
    // Second chance: plain init (covers some test / re-init paths).
    try {
      await Firebase.initializeApp();
      return const FirebaseInitResult(ok: true);
    } catch (_) {
      debugPrint('Firebase init failed: $e');
      return FirebaseInitResult(ok: false, message: e.toString());
    }
  }
}

class FacultyPreBookingApp extends ConsumerWidget {
  const FacultyPreBookingApp({super.key, required this.initResult});

  final FirebaseInitResult initResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!initResult.ok) {
      return MaterialApp(
        title: 'Faculty Pre-Booking',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: FirebaseSetupErrorScreen(details: initResult.message),
      );
    }

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return PushBootstrap(
      child: MaterialApp.router(
        title: 'Faculty Pre-Booking',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}

/// Shown when Firebase could not be initialized (most commonly:
/// `flutterfire configure` has not been run yet, or google-services.json
/// is missing). Gives actionable steps instead of a red screen.
class FirebaseSetupErrorScreen extends StatelessWidget {
  const FirebaseSetupErrorScreen({super.key, this.details});
  final String? details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup required')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.error,
                    semanticLabel: 'Firebase not configured'),
                const SizedBox(height: 16),
                Text('Firebase is not configured',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'The app could not connect to Firebase. This usually means '
                  '"flutterfire configure" has not been run for this machine, '
                  'or the platform config files are missing.',
                ),
                const SizedBox(height: 16),
                Text('Steps to fix',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const _Step(
                    n: '1',
                    text:
                        'dart pub global activate flutterfire_cli'),
                const _Step(
                    n: '2',
                    text:
                        'flutterfire configure --project=<your-project-id>\n(this regenerates lib/firebase_options.dart)'),
                const _Step(
                    n: '3',
                    text:
                        'Android: place google-services.json in android/app/ (see README).'),
                const _Step(
                    n: '4',
                    text: 'flutter pub get, then flutter run'),
                if (details != null) ...[
                  const SizedBox(height: 16),
                  Text('Technical details',
                      style:
                          Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withAlpha(120),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(details!,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              radius: 12,
              child: Text(n, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
