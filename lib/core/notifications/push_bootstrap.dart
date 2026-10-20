import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/users/presentation/providers/users_providers.dart';
import 'notification_service.dart';

/// Mounted above the app: initializes push once, then keeps
/// `users/{uid}.fcmToken` fresh whenever the session or token changes.
/// All failures are silent — push is best-effort on top of the
/// Firestore notification inbox.
class PushBootstrap extends ConsumerStatefulWidget {
  const PushBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PushBootstrap> createState() => _PushBootstrapState();
}

class _PushBootstrapState extends ConsumerState<PushBootstrap> {
  StreamSubscription<String>? _refreshSub;

  @override
  void initState() {
    super.initState();
    _boot();
    ref.listenManual(
      authStateProvider,
      (prev, next) {
        final uid = next.valueOrNull?.uid;
        if (uid != null && prev?.valueOrNull?.uid != uid) {
          unawaited(_saveToken(uid));
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> _boot() async {
    await NotificationService.init();
    _refreshSub?.cancel();
    _refreshSub = NotificationService.onTokenRefresh.listen((t) {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) unawaited(_saveToken(uid, known: t));
    });
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    // Auth may still be resolving; the listener above catches sign-in.
    if (uid != null) unawaited(_saveToken(uid));
  }

  Future<void> _saveToken(String uid, {String? known}) async {
    try {
      final token = known ?? await NotificationService.token();
      if (token == null || token.isEmpty) return;
      await ref.read(usersRepositoryProvider).updateFcmToken(uid, token);
    } catch (_) {
      // Offline / permission denied: inbox still works.
    }
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
