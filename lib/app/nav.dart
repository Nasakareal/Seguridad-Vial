import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/globals.dart';
import '../core/platform_support.dart';
import '../bootstrap/push_handlers.dart';

class PushNavBinder extends StatefulWidget {
  final Widget child;
  const PushNavBinder({super.key, required this.child});

  @override
  State<PushNavBinder> createState() => _PushNavBinderState();
}

class _PushNavBinderState extends State<PushNavBinder> {
  StreamSubscription<RemoteMessage>? _subOnMessage;
  StreamSubscription<RemoteMessage>? _subOnOpen;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      flushPendingPushTap();
    });

    if (!supportsPushMessaging) {
      return;
    }

    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg == null) return;
      final data = msg.data.map((k, v) => MapEntry(k.toString(), v));
      handlePushTap(data);
    });

    _subOnMessage = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) async {
      try {
        final n = message.notification;
        final title = n?.title ?? 'Aviso';
        final body = n?.body ?? '';
        final payload = payloadFromData(
          message.data.map((k, v) => MapEntry(k.toString(), v)),
        );

        if (supportsLocalNotifications) {
          await localNotifications.show(
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title,
            body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'SV_ALERTAS',
                'Alertas de Hechos',
                channelDescription:
                    'Notificaciones de 48h / 72h y recordatorios',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: payload,
          );
        }
      } catch (e, st) {
        reportAppIssue('onMessage ERROR: $e\n\n$st');
      }
    });

    _subOnOpen = FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage message,
    ) {
      try {
        final data = message.data.map((k, v) => MapEntry(k.toString(), v));
        handlePushTap(data);
      } catch (e, st) {
        reportAppIssue('onMessageOpenedApp ERROR: $e\n\n$st');
      }
    });
  }

  @override
  void dispose() {
    _subOnMessage?.cancel();
    _subOnOpen?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
