import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_notification.dart';

/// Firestore serialization for `notifications/{id}`.
class NotificationModel extends AppNotification {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.body,
    required super.type,
    required super.isRead,
    super.appointmentId,
    super.createdAt,
  });

  factory NotificationModel.fromMap(
      String id, Map<String, dynamic> map) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) created = raw.toDate();
    if (raw is String) created = DateTime.tryParse(raw);
    return NotificationModel(
      id: id,
      userId: (map['userId'] as String? ?? ''),
      title: (map['title'] as String? ?? ''),
      body: (map['body'] as String? ?? ''),
      type: (map['type'] as String? ?? 'info'),
      isRead: map['isRead'] as bool? ?? false,
      appointmentId: map['appointmentId'] as String?,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMapForCreate() => {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        if (appointmentId != null) 'appointmentId': appointmentId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
