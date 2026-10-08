import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/globals.dart';

class WazeNotificationService {
  WazeNotificationService._();

  static const String channelId = 'waze_alertas_v1';
  static const String channelName = 'Alertas de Waze';
  static const String channelDescription =
      'Choques y cierres viales reportados por Waze';
  static const String androidGroupKey = 'mx.gob.morelia.seguridad_vial.WAZE';
  static const String appleThreadIdentifier = 'alertas_waze';
  static const int groupSummaryId = 19002001;

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static bool esWaze(RemoteMessage message) {
    final type = (message.data['type'] ?? '').toString().toUpperCase();
    return type == 'WAZE_ACCIDENT' || type == 'WAZE_ROAD_CLOSED';
  }

  static Future<void> mostrar(RemoteMessage message) async {
    if (!esWaze(message)) return;

    await _asegurarCanal();

    final type = (message.data['type'] ?? '').toString().toUpperCase();
    final titulo =
        _texto(message.data['push_title']) ??
        message.notification?.title ??
        (type == 'WAZE_ROAD_CLOSED'
            ? 'Waze: Cierre reportado'
            : 'Waze: Choque reportado');
    final cuerpo =
        _texto(message.data['push_body']) ??
        message.notification?.body ??
        (type == 'WAZE_ROAD_CLOSED'
            ? 'Se reportó un cierre vial.'
            : 'Se reportó un choque.');

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        groupKey: androidGroupKey,
        groupAlertBehavior: GroupAlertBehavior.children,
        category: AndroidNotificationCategory.navigation,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(
          cuerpo,
          contentTitle: titulo,
          summaryText: 'Alerta de Waze',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: appleThreadIdentifier,
      ),
    );

    await localNotifications.show(
      _notificationId(message),
      titulo,
      cuerpo,
      details,
      payload: jsonEncode(message.data),
    );
    await _mostrarResumenGrupo();
  }

  static Future<void> _asegurarCanal() async {
    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(channel);
  }

  static Future<void> _mostrarResumenGrupo() {
    return localNotifications.show(
      groupSummaryId,
      'Alertas de Waze',
      'Choques y cierres reportados',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          groupKey: androidGroupKey,
          setAsGroupSummary: true,
          groupAlertBehavior: GroupAlertBehavior.children,
          playSound: false,
          enableVibration: false,
          onlyAlertOnce: true,
          autoCancel: true,
        ),
      ),
    );
  }

  static int _notificationId(RemoteMessage message) {
    final source = _texto(message.data['waze_uuid']) ?? message.messageId;
    if (source == null || source.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    }
    return source.hashCode.abs().remainder(2147483647);
  }

  static String? _texto(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
