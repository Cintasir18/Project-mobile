import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/colors.dart';
import '../controllers/notification_controller.dart';
export 'elora_notification_button.dart';

class EloraNotificationButton extends StatelessWidget {
  final VoidCallback onTap;

  const EloraNotificationButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();

    return Obx(() {
      final hasUnread = controller.hasUnreadNotification.value;

      return Material(
        color: eloraPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
                if (hasUnread)
                  Positioned(
                    top: 8,
                    right: 9,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: eloraPrimary,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}