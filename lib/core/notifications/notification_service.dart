import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

/// Background handler: re-initializes Firebase in the isolate and no-ops
/// (payloads land in the tray via FCM; tapping opens the app).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Background Firebase init skipped: $e');
  }
  debugPrint('Background message: ${message.messageId}');
}

/// Central push setup: permissions, FCM token access, foreground display
/// via flutter_local_notifications, background handler registration.
/// Call [init] once at startup (guarded, safe to call in tests where
/// Firebase is absent — failures are swallowed with a debug print).
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'appointments',
    'Appointment updates',
    description: 'Approvals, rejections, reschedules and reminders.',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      await _local.initialize(
        const InitializationSettings(
            android: android, iOS: darwin, macOS: darwin),
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen(_showForeground);
      _initialized = true;
    } catch (e) {
      debugPrint('Push init skipped (no Firebase config?): $e');
    }
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    try {
      await _local.show(
        n.hashCode,
        n.title ?? 'Faculty Pre-Booking',
        n.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data['appointmentId'] as String?,
      );
    } catch (e) {
      debugPrint('Local notification failed: $e');
    }
  }

  static Future<String?> token() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
      return null;
    }
  }

  static Stream<String> get onTokenRefresh {
    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (_) {
      return const Stream.empty();
    }
  }
}
