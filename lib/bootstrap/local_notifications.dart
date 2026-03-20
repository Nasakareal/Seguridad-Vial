import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/globals.dart';
import '../core/safe_payload.dart';
import 'push_handlers.dart';

const AndroidNotificationChannel svAlertasChannel = AndroidNotificationChannel(
  'SV_ALERTAS',
  'Alertas de Hechos',
  description: 'Notificaciones de 48h / 72h y recordatorios',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

const AndroidNotificationChannel svGuardiaChannel = AndroidNotificationChannel(
  'SV_GUARDIA',
  'Guardia en segundo plano',
  description: 'Mantiene visible la guardia activa y el botón de pánico',
  importance: Importance.low,
  playSound: false,
  enableVibration: false,
);

Future<void> initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse resp) {
      final data = safeDecodePayload(resp.payload);
      if (data.isNotEmpty) handlePushTap(data);
    },
  );

  final androidPlugin = localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(svAlertasChannel);
    await androidPlugin.createNotificationChannel(svGuardiaChannel);
  }
}
