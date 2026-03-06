import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/material.dart';

import '../core/globals.dart';
import '../firebase_options.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';

import 'local_notifications.dart';
import 'lifecycle_observer.dart';
import 'push_handlers.dart';

Future<bool> bootstrapApp({required void Function(String step) onStep}) async {
  try {
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();

      if (msg.contains('A RenderFlex overflowed by')) {
        FlutterError.presentError(details);
        return;
      }

      final st = details.stack ?? StackTrace.current;
      bootFatal.value = 'FLUTTER ERROR: $msg\n\n$st';
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      bootFatal.value = 'UNCAUGHT: $error\n\n$stack';
      return true;
    };

    onStep('Inicializando Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () =>
          throw Exception('TIMEOUT: Firebase.initializeApp tardó demasiado.'),
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    onStep('Inicializando notificaciones locales...');
    await initLocalNotifications().timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw Exception('TIMEOUT: initLocalNotifications tardó demasiado.'),
    );

    AppLifecycleObserver.ensureInstalled();

    onStep('Validando sesión...');
    final logged = await AuthService.isLoggedIn().timeout(
      const Duration(seconds: 12),
      onTimeout: () =>
          throw Exception('TIMEOUT: AuthService.isLoggedIn tardó demasiado.'),
    );

    unawaited(_setupPushNonBlocking(logged: logged));

    onStep('Inicializando servicio de ubicación...');
    if (Platform.isAndroid) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'seguridad_vial_tracking',
          channelName: 'Seguimiento de patrullas',
          channelDescription:
              'Envía la ubicación de la patrulla mientras el servicio esté activo',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: const ForegroundTaskOptions(
          interval: 10000,
          isOnceEvent: false,
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    }

    return true;
  } catch (e, st) {
    bootFatal.value = '$e\n\n$st';
    return false;
  }
}

Future<void> _setupPushNonBlocking({required bool logged}) async {
  try {
    await PushService.ensurePermissions();
  } catch (_) {}

  try {
    PushService.listenTokenRefresh();
  } catch (_) {}

  if (logged) {
    try {
      await PushService.registerDeviceToken(reason: 'app_start');
    } catch (_) {}
  }
}
