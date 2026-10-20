import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../models/notification_model.dart';

/// Firestore implementation backed by `notifications`.
class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  List<AppNotification> _decode(
      QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs
        .map((d) => NotificationModel.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) {
      final ac = a.createdAt;
      final bc = b.createdAt;
      if (ac == null && bc == null) return 0;
      if (ac == null) return 1;
      if (bc == null) return -1;
      return bc.compareTo(ac);
    });
    return list;
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(_decode);
  }

  @override
  Stream<int> watchUnreadCount(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  @override
  Future<String> send({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? appointmentId,
  }) async {
    final ref = await _col.add(NotificationModel(
      id: '',
      userId: userId,
      title: title,
      body: body,
      type: type,
      isRead: false,
      appointmentId: appointmentId,
    ).toMapForCreate());
    return ref.id;
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _col.doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
