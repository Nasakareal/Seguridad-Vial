import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/location_disclosure_dialog.dart';
import 'tracking_task.dart';

class TrackingService {
  static bool _starting = false;

  static Future<bool> startWithDisclosure(BuildContext context) async {
    if (!Platform.isAndroid) return false;

    if (_starting) return true;
    _starting = true;

    try {
      final running = await FlutterForegroundTask.isRunningService;
      if (running) return true;

      final accepted = await LocationDisclosure.isAccepted();
      if (!accepted) {
        final ok = await LocationDisclosure.show(context);
        if (!ok) return false;
      }

      final okPerms = await _ensurePermissionsAlways(context);
      if (!okPerms) return false;

      await FlutterForegroundTask.startService(
        notificationTitle: 'Seguridad Vial',
        notificationText: 'Enviando ubicación…',
        callback: startCallback,
      );

      return true;
    } catch (_) {
      return false;
    } finally {
      _starting = false;
    }
  }

  static Future<bool> start() async {
    if (!Platform.isAndroid) return false;

    if (_starting) return true;
    _starting = true;

    try {
      final running = await FlutterForegroundTask.isRunningService;
      if (running) return true;

      await FlutterForegroundTask.startService(
        notificationTitle: 'Seguridad Vial',
        notificationText: 'Enviando ubicación…',
        callback: startCallback,
      );

      return true;
    } catch (_) {
      return false;
    } finally {
      _starting = false;
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;

    try {
      final running = await FlutterForegroundTask.isRunningService;
      if (!running) return;
      await FlutterForegroundTask.stopService();
    } catch (_) {}
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

    return true;
  }
}
