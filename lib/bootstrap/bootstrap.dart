import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/material.dart';

import '../core/globals.dart';
import '../core/platform_support.dart';
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

      if (_shouldIgnoreRuntimeFlutterError(
        message: msg,
        exception: details.exception,
        stack: details.stack,
        library: details.library,
        contextDescription: details.context?.toDescription(),
      )) {
        return;
      }

      final st = details.stack ?? StackTrace.current;
      FlutterError.presentError(details);
      reportAppIssue('FLUTTER ERROR: $msg\n\n$st');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (_shouldIgnoreRuntimeFlutterError(
        message: error.toString(),
        exception: error,
        stack: stack,
      )) {
        return true;
      }
      reportAppIssue('UNCAUGHT: $error\n\n$stack');
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

    if (supportsPushMessaging) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    if (supportsLocalNotifications) {
      onStep('Inicializando notificaciones locales...');
      await initLocalNotifications().timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw Exception('TIMEOUT: initLocalNotifications tardó demasiado.'),
      );
    } else if (isDesktopTestPlatform) {
      onStep('Modo prueba desktop: notificaciones desactivadas.');
    }

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
    reportBootFatal('$e\n\n$st');
    return false;
  }
}

bool _shouldIgnoreRuntimeFlutterError({
  required String message,
  Object? exception,
  StackTrace? stack,
  String? library,
  String? contextDescription,
}) {
  if (_isIgnorableNetworkImageFailure(
    message: message,
    exception: exception,
    stack: stack,
    library: library,
    contextDescription: contextDescription,
  )) {
    return true;
  }

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

bool _isIgnorableNetworkImageFailure({
  required String message,
  Object? exception,
  StackTrace? stack,
  String? library,
  String? contextDescription,
}) {
  final msg = message.toLowerCase();
  final stackText = (stack?.toString() ?? '').toLowerCase();
  final libraryText = (library ?? '').toLowerCase();
  final contextText = (contextDescription ?? '').toLowerCase();

  final looksLikeImagePipeline =
      exception is NetworkImageLoadException ||
      libraryText.contains('image resource service') ||
      contextText.contains('resolving an image codec') ||
      contextText.contains('image provider') ||
      msg.contains('networkimage') ||
      stackText.contains('_network_image_io.dart') ||
      stackText.contains('networkimage._loadasync') ||
      stackText.contains('image_stream.dart');

  if (!looksLikeImagePipeline) return false;

  if (exception is NetworkImageLoadException) {
    return exception.statusCode >= 400;
  }

  return msg.contains('http request failed') ||
      msg.contains('statuscode: 404') ||
      msg.contains('statuscode: 403') ||
      msg.contains('statuscode: 500') ||
      msg.contains('statuscode: 502') ||
      msg.contains('statuscode: 503') ||
      msg.contains('failed host lookup') ||
      msg.contains('clientexception') ||
      msg.contains('httpexception') ||
      msg.contains('socketexception') ||
      msg.contains('handshakeexception') ||
      msg.contains('connection closed') ||
      msg.contains('connection reset') ||
      msg.contains('connection abort') ||
      msg.contains('timed out');
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
