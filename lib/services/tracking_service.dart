import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/location_disclosure_dialog.dart';
import 'tracking_task.dart';
import 'location_service.dart'; // <- asegúrate que exista
// Si tu LocationService requiere apiBase, pásalo como lo uses en tu proyecto.

class TrackingService {
  static bool _starting = false;

  // iOS: timer simple en foreground
  static Timer? _iosTimer;
  static bool _iosRunning = false;

  // Ajusta esto a tu base URL real (o pásalo por constructor si ya lo tienes)
  static const String _apiBase = 'https://seguridadvial-mich.com/api';

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

      // ANDROID -> servicio en segundo plano
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

      // IOS -> loop en foreground (app abierta)
      return await _startIosForegroundLoop();
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

      return await _startIosForegroundLoop();
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

      // iOS
      _iosTimer?.cancel();
      _iosTimer = null;
      _iosRunning = false;
    } catch (_) {}
  }

  static Future<bool> _startIosForegroundLoop() async {
    if (_iosRunning) return true;

    // manda 1 vez inmediato
    final ls = LocationService(apiBase: _apiBase);
    await ls.sendOnce();

    _iosRunning = true;
    _iosTimer?.cancel();
    _iosTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        await ls.sendOnce();
      } catch (_) {}
    });

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

    // ANDROID: exigir ALWAYS
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

    // iOS: con whileInUse es suficiente para foreground loop
    return true;
  }
}
