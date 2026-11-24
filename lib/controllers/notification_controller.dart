
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:elora_school/services/notification_data_service.dart';
import 'package:flutter/foundation.dart';

class NotificationController extends GetxController {
  final hasUnreadNotification = false.obs;

  @override
  void onInit() {
    super.onInit();

    refreshUnreadStatus();

    FirebaseMessaging.onMessage.listen((message) {
      refreshUnreadStatus();
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      refreshUnreadStatus();
    });
  }

  Future<void> refreshUnreadStatus() async {
    try {
      final notifications =
          await NotificationDataService.instance.list();

      hasUnreadNotification.value = notifications.any(
        (notification) => notification['is_read'] == false,
      );
    } catch (e) {
      debugPrint('Gagal memeriksa notifikasi: $e');
    }
  }
}
