import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM BACKGROUND: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'elora_notifications';
  static const String _channelName = 'ELORA Notifications';
  static const String _channelDesc = 'Notifikasi dari ELORA School';
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    debugPrint('FCM permission: ${settings.authorizationStatus}');
    const initSettings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _localNotif.initialize(initSettings, onDidReceiveNotificationResponse: (details) {
      debugPrint('Notification tapped: ${details.payload}');
    });
    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(_channelId, _channelName, description: _channelDesc, importance: Importance.high);
      await _localNotif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    }
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    await saveTokenToSupabase();
    _fcm.onTokenRefresh.listen((_) => saveTokenToSupabase());
    _initialized = true;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotif.show(message.hashCode, notification.title, notification.body,
      NotificationDetails(android: AndroidNotificationDetails(_channelId, _channelName,
        channelDescription: _channelDesc, importance: Importance.high, priority: Priority.high,
        icon: '@mipmap/ic_launcher')),
      payload: jsonEncode(message.data));
  }

  Future<void> saveTokenToSupabase() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      final token = await _fcm.getToken();
      if (user == null || token == null || token.isEmpty) return;
      await SupabaseService.client.from('fcm_tokens').upsert({
        'token': token, 'user_id': user.id, 'device_platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      debugPrint('FCM TOKEN SAVE ERROR: $e');
    }
  }

  Future<void> onLogin() => saveTokenToSupabase();
}
