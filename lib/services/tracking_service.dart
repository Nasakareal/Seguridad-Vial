import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/location_disclosure_dialog.dart';
import 'tracking_task.dart';
import 'location_service.dart';

class TrackingService {
  static bool _starting = false;
  static Timer? _iosTimer;
  static bool _iosRunning = false;
  static StreamSubscription<Position>? _iosSub;

  static const String _apiBase = 'https://seguridadvial-mich.com/api';

  static Position? _lastGood;
  static DateTime? _lastGoodAt;

  static Future<bool> startWithDisclosure(BuildContext context) async {
    if (_starting) return true;
    _starting = true;

    try {
      final accepted = await LocationDisclosure.isAccepted();
      if (!accepted) {
        final ok = await LocationDisclosure.show(context);
        if (!ok) return false;
      }

      final okPerms = await _ensurePermissionsAlways(context);
      if (!okPerms) return false;

      if (Platform.isAndroid) {
        final running = await FlutterForegroundTask.isRunningService;
        if (running) return true;

        await FlutterForegroundTask.startService(
          notificationTitle: 'Seguridad Vial',
          notificationText: 'Enviando ubicación…',
          callback: startCallback,
        );
        return true;
      }

      return await _startIosStream();
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
      if (Platform.isAndroid) {
        final running = await FlutterForegroundTask.isRunningService;
        if (running) return true;

        await FlutterForegroundTask.startService(
          notificationTitle: 'Seguridad Vial',
          notificationText: 'Enviando ubicación…',
          callback: startCallback,
        );
        return true;
      }

      return await _startIosStream();
    } catch (_) {
      return false;
    } finally {
      _starting = false;
    }
  }

  static Future<void> stop() async {
    try {
      if (Platform.isAndroid) {
        final running = await FlutterForegroundTask.isRunningService;
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

  static Future<bool> _startIosStream() async {
    if (_iosRunning) return true;

    final ls = LocationService(apiBase: _apiBase);

    try {
      await _sendOnceIfGood(ls);
    } catch (_) {}

    _iosRunning = true;

    final settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    );

    await _iosSub?.cancel();
    _iosSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) async {
        try {
          await _handlePosition(ls, pos);
        } catch (_) {}
      },
      onError: (_) {},
      cancelOnError: false,
    );

    return true;
  }

  static Future<void> _handlePosition(LocationService ls, Position pos) async {
    if (pos.accuracy.isNaN || pos.accuracy > 150) return;

    if (pos.timestamp != null) {
      final age = DateTime.now().difference(pos.timestamp!);
      if (age.inMinutes >= 2) return;
    }

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

    await ls.sendOnce(positionOverride: pos, requireAlways: true);
  }

  static Future<bool> _sendOnceIfGood(LocationService ls) async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
      timeLimit: const Duration(seconds: 12),
    );

    await _handlePosition(ls, pos);
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

    if (Platform.isAndroid && permission != LocationPermission.always) {
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Permitir “todo el tiempo”'),
          content: const Text(
            'Para enviar ubicación en segundo plano y ver patrullas en tiempo real, activa: Permisos > Ubicación > Permitir todo el tiempo.',
          ),
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

      if (go != true) return false;

      await Geolocator.openAppSettings();

      permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) return false;
    }

    if (!Platform.isAndroid && permission != LocationPermission.always) {
      await Geolocator.openAppSettings();
      permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) return false;
    }

    return true;
  }
}
