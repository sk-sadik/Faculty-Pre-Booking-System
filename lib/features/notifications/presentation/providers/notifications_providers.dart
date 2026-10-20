import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepositoryImpl(ref.watch(firestoreProvider));
});

/// Notification inbox for one user (newest first).
final userNotificationsProvider = StreamProvider.autoDispose
    .family<List<AppNotification>, String>((ref, userId) {
  return ref
      .watch(notificationsRepositoryProvider)
      .watchNotifications(userId);
});

/// Unread badge count for one user.
final unreadCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, userId) {
  return ref
      .watch(notificationsRepositoryProvider)
      .watchUnreadCount(userId);
});
