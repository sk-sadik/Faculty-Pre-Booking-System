import '../entities/app_notification.dart';

abstract class NotificationsRepository {
  Stream<List<AppNotification>> watchNotifications(String userId);
  Stream<int> watchUnreadCount(String userId);

  Future<String> send({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? appointmentId,
  });

  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
}
