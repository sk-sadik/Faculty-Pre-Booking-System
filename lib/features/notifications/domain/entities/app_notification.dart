import 'package:equatable/equatable.dart';

/// An inbox item written on every booking status change (and on new
/// requests). Push delivery via FCM is layered on top in Phase F.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.appointmentId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;

  /// request | approved | rejected | rescheduled | cancelled | completed |
  /// no_show | info
  final String type;
  final bool isRead;
  final String? appointmentId;
  final DateTime? createdAt;

  @override
  List<Object?> get props =>
      [id, userId, title, body, type, isRead, appointmentId];
}
