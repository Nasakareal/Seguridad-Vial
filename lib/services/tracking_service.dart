import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/location_disclosure_dialog.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'tracking_guard_constants.dart';
import 'tracking_guard_notification_service.dart';
import 'tracking_task.dart';

class TrackingService {
  static const String notificationTitle = trackingGuardNotificationTitle;
  static const String notificationText = trackingGuardNotificationText;
  static bool _starting = false;
  static Timer? _iosTimer;
  static bool _iosRunning = false;
  static StreamSubscription<Position>? _iosSub;

  static const String _apiBase = 'https://seguridadvial-mich.com/api';

  static Position? _lastGood;
  static DateTime? _lastGoodAt;

  static Future<bool> startAfterConsent(BuildContext context) async {
    return await startWithDisclosure(context);
  }

  static Future<bool> ensureAndroidPersistentGuard() async {
    if (!Platform.isAndroid) return false;

    try {
      final logged = await AuthService.isLoggedIn();
      if (!logged) return false;

      final isPerito = await AuthService.isPerito();
      if (!isPerito) return false;

      final accepted = await LocationDisclosure.isAccepted();
      if (!accepted) return false;

      if (!await Geolocator.isLocationServiceEnabled()) {
        return false;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) {
        return false;
      }

      try {
        final notifPermission =
            await FlutterForegroundTask.checkNotificationPermission();
        if (notifPermission != NotificationPermission.granted) {
          return false;
        }
      } catch (_) {}

      final running = await isRunning();
      if (running) {
        await TrackingGuardNotificationService.show();
        return true;
      }

      await FlutterForegroundTask.startService(
        notificationTitle: notificationTitle,
        notificationText: notificationText,
        callback: startCallback,
      );
      await TrackingGuardNotificationService.show();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isRunning() async {
    if (Platform.isAndroid) {
      try {
        return await FlutterForegroundTask.isRunningService;
      } catch (_) {
        return false;
      }
    }

    return _iosRunning;
  }

  static Future<bool> startWithDisclosure(BuildContext context) async {
    if (_starting) return true;
    _starting = true;

    try {
      final isPerito = await AuthService.isPerito();
      if (!isPerito) return false;

      final accepted = await LocationDisclosure.isAccepted();
      if (!context.mounted) return false;

      if (!accepted) {
        final ok = await LocationDisclosure.show(context);
        if (!ok || !context.mounted) return false;
      }

      final okPerms = await _ensureTrackingRequirements(context);
      if (!okPerms) return false;

      if (Platform.isAndroid) {
        final running = await isRunning();
        if (running) {
          await TrackingGuardNotificationService.show();
          return true;
        }

        await FlutterForegroundTask.startService(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          callback: startCallback,
        );
        await TrackingGuardNotificationService.show();
        return true;
      }

      return await _startIosStream(requireAlways: true);
    } catch (_) {
      return false;
    } finally {
      _starting = false;
    }
  }

  static Future<bool> start() async {
    if (_starting) return true;
    _starting = true;

    try {
      final isPerito = await AuthService.isPerito();
      if (!isPerito) return false;

      if (Platform.isAndroid) {
        final running = await isRunning();
        if (running) {
          await TrackingGuardNotificationService.show();
          return true;
        }

        await FlutterForegroundTask.startService(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          callback: startCallback,
        );
        await TrackingGuardNotificationService.show();
        return true;
      }

      return await _startIosStream(requireAlways: true);
    } catch (_) {
      return false;
    } finally {
      _starting = false;
    }
  }

  static Future<void> stop() async {
    try {
      if (Platform.isAndroid) {
        final running = await isRunning();
        await TrackingGuardNotificationService.cancel();
        if (!running) return;
        await FlutterForegroundTask.stopService();
        return;
      }

      await _iosSub?.cancel();
      _iosSub = null;

      _iosTimer?.cancel();
      _iosTimer = null;

      _iosRunning = false;
      _lastGood = null;
      _lastGoodAt = null;
    } catch (_) {}
  }

  static Future<bool> _startIosStream({required bool requireAlways}) async {
    if (_iosRunning) return true;

    final ls = LocationService(apiBase: _apiBase);

    await _maybeRequestPreciseAccuracy();

    try {
      await _sendOnceIfGood(ls, requireAlways: requireAlways);
    } catch (_) {}

    _iosRunning = true;

    final settings = AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
      activityType: ActivityType.automotiveNavigation,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    );

    await _iosSub?.cancel();
    _iosSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) async {
        try {
          await _handlePosition(ls, pos, requireAlways: requireAlways);
        } catch (_) {}
      },
      onError: (_) {},
      cancelOnError: false,
    );

    return true;
  }

  static Future<void> _handlePosition(
    LocationService ls,
    Position pos, {
    required bool requireAlways,
  }) async {
    if (pos.accuracy.isNaN || pos.accuracy > 150) return;

    final age = DateTime.now().difference(pos.timestamp);
    if (age.inMinutes >= 2) return;

    if (_lastGood != null && _lastGoodAt != null) {
      final meters = Geolocator.distanceBetween(
        _lastGood!.latitude,
        _lastGood!.longitude,
        pos.latitude,
        pos.longitude,
      );

      final dt = DateTime.now().difference(_lastGoodAt!).inSeconds;
      if (dt <= 20 && meters > 2000) return;
    }

    _lastGood = pos;
    _lastGoodAt = DateTime.now();

    await ls.sendOnce(positionOverride: pos, requireAlways: requireAlways);
  }

  static Future<bool> _sendOnceIfGood(
    LocationService ls, {
    required bool requireAlways,
  }) async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
      timeLimit: const Duration(seconds: 12),
    );

    await _handlePosition(ls, pos, requireAlways: requireAlways);
    return true;
  }

  static Future<bool> _ensureTrackingRequirements(BuildContext context) async {
    final locationEnabled = await _ensureLocationServicesEnabled(context);
    if (!locationEnabled) return false;
    if (!context.mounted) return false;

    final permissionOk = await _ensurePermissionsAlways(context);
    if (!permissionOk) return false;
    if (!context.mounted) return false;

    final preciseOk = await _ensurePreciseAccuracy(context);
    if (!preciseOk) return false;
    if (!context.mounted) return false;

    final notifOk = await _ensureNotificationPermission(context);
    if (!notifOk) return false;
    if (!context.mounted) return false;

    final batteryOk = await _ensureBatteryOptimizationExemption(context);
    if (!batteryOk) return false;

    return true;
  }

  static Future<bool> _ensureLocationServicesEnabled(
    BuildContext context,
  ) async {
    while (!await Geolocator.isLocationServiceEnabled()) {
      if (!context.mounted) return false;

      await _showBlockingSettingsDialog(
        context,
        title: 'Activar ubicacion del dispositivo',
        content:
            'Para compartir la ubicacion de la patrulla, la ubicacion del dispositivo debe permanecer encendida.',
      );

      final enabled = await _openLocationSettingsAndAwaitEnabled();
      if (!enabled && !context.mounted) return false;
    }

    return true;
  }

  static Future<bool> _ensurePermissionsAlways(BuildContext context) async {
    var permission = await Geolocator.checkPermission();

    while (true) {
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always) {
        return true;
      }

      if (!context.mounted) return false;

      await _showAlwaysPermissionDialog(context);
      permission = await _openAppSettingsAndAwaitPermission();
    }
  }

  static Future<bool> _ensurePreciseAccuracy(BuildContext context) async {
    if (!Platform.isIOS) return true;

    await _maybeRequestPreciseAccuracy();

    while (true) {
      final accuracyStatus = await _safeGetLocationAccuracy();
      if (accuracyStatus == LocationAccuracyStatus.precise) {
        return true;
      }

      if (!context.mounted) return false;

      await _showBlockingSettingsDialog(
        context,
        title: 'Activar ubicacion precisa',
        content:
            'Para seguir mostrando patrullas con exactitud en iPhone, activa Ajustes > Seguridad Vial > Ubicacion > Ubicacion precisa.',
      );

      final updated = await _openAppSettingsAndAwaitAccuracy();
      if (updated == LocationAccuracyStatus.precise) {
        return true;
      }
    }
  }

  static Future<bool> _ensureBatteryOptimizationExemption(
    BuildContext context,
  ) async {
    if (!Platform.isAndroid) return true;

    while (true) {
      try {
        if (await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          return true;
        }
      } catch (_) {
        return true;
      }

      if (!context.mounted) return false;

      await _showBlockingSettingsDialog(
        context,
        title: 'Permitir segundo plano',
        content:
            'Para que Android no detenga el rastreo en segundo plano, permite que esta app se ejecute sin restricciones de bateria.',
      );

      try {
        final granted =
            await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        if (granted) {
          return true;
        }
      } catch (_) {}

      final grantedFromSettings =
          await _openIgnoreBatteryOptimizationSettingsAndAwait();
      if (grantedFromSettings) {
        return true;
      }
    }
  }

  static Future<bool> _ensureNotificationPermission(
    BuildContext context,
  ) async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status == NotificationPermission.granted) {
        return true;
      }

      if (!context.mounted) return false;

      await _showBlockingSettingsDialog(
        context,
        title: 'Permitir notificaciones',
        content:
            'Para mantener el servicio en segundo plano y recibir alertas, Android debe permitir notificaciones para esta app.',
        actionLabel: 'Continuar',
      );

      final requested =
          await FlutterForegroundTask.requestNotificationPermission();
      return requested == NotificationPermission.granted;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _showAlwaysPermissionDialog(BuildContext context) async {
    final title = Platform.isIOS
        ? 'Permitir Siempre'
        : 'Permitir todo el tiempo';
    final content = Platform.isIOS
        ? 'Para enviar ubicacion en segundo plano en iPhone, cambia el permiso a Siempre y deja activa Ubicacion precisa.'
        : 'Para enviar ubicacion en segundo plano, activa Permisos > Ubicacion > Permitir todo el tiempo.';

    await _showBlockingSettingsDialog(context, title: title, content: content);
  }

  static Future<void> _showBlockingSettingsDialog(
    BuildContext context, {
    required String title,
    required String content,
    String actionLabel = 'Abrir ajustes',
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  static Future<LocationPermission> _openAppSettingsAndAwaitPermission() {
    return _openSettingsAndAwait<LocationPermission>(
      openSettings: Geolocator.openAppSettings,
      evaluator: Geolocator.checkPermission,
      fallback: LocationPermission.denied,
    );
  }

  static Future<LocationAccuracyStatus> _openAppSettingsAndAwaitAccuracy() {
    return _openSettingsAndAwait<LocationAccuracyStatus>(
      openSettings: Geolocator.openAppSettings,
      evaluator: _safeGetLocationAccuracy,
      fallback: LocationAccuracyStatus.reduced,
    );
  }

  static Future<bool> _openLocationSettingsAndAwaitEnabled() {
    return _openSettingsAndAwait<bool>(
      openSettings: Geolocator.openLocationSettings,
      evaluator: Geolocator.isLocationServiceEnabled,
      fallback: false,
    );
  }

  static Future<bool> _openIgnoreBatteryOptimizationSettingsAndAwait() {
    return _openSettingsAndAwait<bool>(
      openSettings: FlutterForegroundTask.openIgnoreBatteryOptimizationSettings,
      evaluator: () => FlutterForegroundTask.isIgnoringBatteryOptimizations,
      fallback: false,
    );
  }

  static Future<T> _openSettingsAndAwait<T>({
    required Future<bool> Function() openSettings,
    required Future<T> Function() evaluator,
    required T fallback,
  }) async {
    AppLifecycleListener? listener;

    try {
      final completer = Completer<T>();
      listener = AppLifecycleListener(
        onResume: () {
          unawaited(
            _completeSettingsCheck(
              completer,
              evaluator: evaluator,
              fallback: fallback,
            ),
          );
        },
      );

      final opened = await openSettings();
      if (!opened) {
        return await _safeEvaluate(evaluator, fallback);
      }

      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () async {
          return await _safeEvaluate(evaluator, fallback);
        },
      );
    } catch (_) {
      return fallback;
    } finally {
      listener?.dispose();
    }
  }

  static Future<void> _completeSettingsCheck<T>(
    Completer<T> completer, {
    required Future<T> Function() evaluator,
    required T fallback,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (completer.isCompleted) return;
    completer.complete(await _safeEvaluate(evaluator, fallback));
  }

  static Future<T> _safeEvaluate<T>(
    Future<T> Function() evaluator,
    T fallback,
  ) async {
    try {
      return await evaluator();
    } catch (_) {
      return fallback;
    }
  }

  static Future<LocationAccuracyStatus> _safeGetLocationAccuracy() async {
    try {
      return await Geolocator.getLocationAccuracy();
    } catch (_) {
      return LocationAccuracyStatus.reduced;
    }
  }

  static Future<void> _maybeRequestPreciseAccuracy() async {
    if (!Platform.isIOS) return;

    try {
      final accuracyStatus = await Geolocator.getLocationAccuracy();
      if (accuracyStatus == LocationAccuracyStatus.reduced) {
        await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: 'FullAccuracy',
        );
      }
    } catch (_) {}
  }
}
