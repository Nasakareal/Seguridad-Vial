// lib/services/tracking_service.dart
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'tracking_task.dart';

class TrackingService {
  static bool _starting = false;

  static Future<bool> start() async {
    final ok = await _ensurePermissions();
    if (!ok) return false;

    if (_starting) return true;
    _starting = true;

    try {
      final running = await FlutterForegroundTask.isRunningService;
      if (running) {
        _starting = false;
        return true;
      }

      await FlutterForegroundTask.startService(
        notificationTitle: 'Seguridad Vial',
        notificationText: 'Enviando ubicación…',
        callback: startCallback,
      );

      _starting = false;
      return true;
    } catch (e) {
      _starting = false;
      print('TRACKING start EXCEPTION: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      final running = await FlutterForegroundTask.isRunningService;
      if (!running) return;

      await FlutterForegroundTask.stopService();
    } catch (e) {
      // ignore: avoid_print
      print('TRACKING stop EXCEPTION: $e');
    }
  }

  static Future<bool> _ensurePermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      print('TRACKING: GPS apagado');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('TRACKING: permiso ubicación denegado');
      return false;
    }

    if (Platform.isAndroid) {
      // Si en el futuro queremos exigir ALWAYS:
      // if (permission != LocationPermission.always) return false;
    }

    return true;
  }
}
