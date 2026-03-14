import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/location_disclosure_dialog.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'tracking_task.dart';

class TrackingService {
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

      final okPerms = await _ensurePermissionsAlways(context);
      if (!okPerms) return false;

      if (Platform.isAndroid) {
        final running = await isRunning();
        if (running) return true;

        await FlutterForegroundTask.startService(
          notificationTitle: 'Seguridad Vial',
          notificationText: 'Enviando ubicacion...',
          callback: startCallback,
        );
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
        if (running) return true;

        await FlutterForegroundTask.startService(
          notificationTitle: 'Seguridad Vial',
          notificationText: 'Enviando ubicacion...',
          callback: startCallback,
        );
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
      showBackgroundLocationIndicator: false,
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

  static Future<bool> _ensurePermissionsAlways(BuildContext context) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (permission == LocationPermission.always) {
      await _maybeRequestPreciseAccuracy();
      return true;
    }

    if (!context.mounted) return false;

    final go = await _showAlwaysPermissionDialog(context);
    if (!go) return false;

    permission = await _openAppSettingsAndAwaitPermission();
    if (permission != LocationPermission.always) return false;

    await _maybeRequestPreciseAccuracy();
    return true;
  }

  static Future<bool> _showAlwaysPermissionDialog(BuildContext context) async {
    final title = Platform.isIOS
        ? 'Permitir Siempre'
        : 'Permitir todo el tiempo';
    final content = Platform.isIOS
        ? 'Para enviar ubicacion en segundo plano en iPhone, cambia el permiso a Siempre y deja activa Ubicacion precisa.'
        : 'Para enviar ubicacion en segundo plano, activa: Permisos > Ubicacion > Permitir todo el tiempo.';

    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );

    return go == true;
  }

  static Future<LocationPermission> _openAppSettingsAndAwaitPermission() async {
    AppLifecycleListener? listener;

    try {
      final completer = Completer<LocationPermission>();
      listener = AppLifecycleListener(
        onResume: () {
          unawaited(_completePermissionCheck(completer));
        },
      );

      final opened = await Geolocator.openAppSettings();
      if (!opened) {
        return await Geolocator.checkPermission();
      }

      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () async {
          return await Geolocator.checkPermission();
        },
      );
    } catch (_) {
      return LocationPermission.denied;
    } finally {
      listener?.dispose();
    }
  }

  static Future<void> _completePermissionCheck(
    Completer<LocationPermission> completer,
  ) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (completer.isCompleted) return;
      completer.complete(await Geolocator.checkPermission());
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(LocationPermission.denied);
      }
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
