import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'SV_ALERTAS',
    'Alertas de Hechos',
    description: 'Notificaciones de 48h / 72h y recordatorios',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
}
