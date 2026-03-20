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
import '../services/offline_sync_service.dart';
import '../services/tracking_service.dart';
import '../services/tracking_task.dart';

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

      if (_shouldIgnoreRuntimeFlutterError(msg)) {
        return;
      }

      final st = details.stack ?? StackTrace.current;
      bootFatal.value = 'FLUTTER ERROR: $msg\n\n$st';
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (_shouldIgnoreRuntimeFlutterError(error.toString())) {
        return true;
      }
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
          isSticky: true,
          buttons: const [
            NotificationButton(
              id: TrackingTaskHandler.panicButtonId,
              text: 'PANICO',
            ),
          ],
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: const ForegroundTaskOptions(
          interval: 10000,
          isOnceEvent: false,
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    }

    onStep('Preparando modo offline...');
    await OfflineSyncService.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception(
        'TIMEOUT: OfflineSyncService.initialize tardó demasiado.',
      ),
    );

    onStep('Validando sesión...');
    final logged = await AuthService.isLoggedIn().timeout(
      const Duration(seconds: 12),
      onTimeout: () =>
          throw Exception('TIMEOUT: AuthService.isLoggedIn tardó demasiado.'),
    );

    unawaited(_setupPushNonBlocking(logged: logged));

    if (logged) {
      unawaited(OfflineSyncService.flushPending());
      unawaited(TrackingService.ensureAndroidPersistentGuard());
    }

    return true;
  } catch (e, st) {
    bootFatal.value = '$e\n\n$st';
    return false;
  }
}

bool _shouldIgnoreRuntimeFlutterError(String message) {
  final msg = message.toLowerCase();
  final isOpenStreetMapTile =
      msg.contains('tile.openstreetmap.org') ||
      msg.contains('openstreetmap.org/');
  if (!isOpenStreetMapTile) return false;

  return msg.contains('connection attempt cancelled') ||
      msg.contains('clientexception') ||
      msg.contains('clientexception with socketexception') ||
      msg.contains('connection closed before full header was received') ||
      msg.contains('connection closed') ||
      msg.contains('connection abort') ||
      msg.contains('software caused connection abort') ||
      msg.contains('connection reset by peer') ||
      msg.contains('failed host lookup') ||
      msg.contains('handshakeexception') ||
      msg.contains('timed out') ||
      msg.contains('httpexception') ||
      msg.contains('socketexception');
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
