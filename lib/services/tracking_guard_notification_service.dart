import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../bootstrap/local_notifications.dart';
import '../core/globals.dart';

class TrackingGuardNotificationService {
  static const int notificationId = 900001;

  static Future<void> show() async {
    if (!Platform.isAndroid) return;

    final android = AndroidNotificationDetails(
      svGuardiaChannel.id,
      svGuardiaChannel.name,
      channelDescription: svGuardiaChannel.description,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      channelShowBadge: false,
      additionalFlags: Int32List.fromList(const [2, 32]),
    );

    final details = NotificationDetails(android: android);

    await localNotifications.show(
      notificationId,
      'Seguridad Vial activa',
      'Guardia activa en segundo plano. No cierres esta protección.',
      details,
    );
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await localNotifications.cancel(notificationId);
  }
}
