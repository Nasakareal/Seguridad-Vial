// lib/services/tracking_task.dart
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class TrackingTaskHandler extends TaskHandler {
  TrackingTaskHandler(this.apiBase);

  final String apiBase;

  bool _sending = false;
  DateTime? _lastSentAt;

  /// Límites (ajústalos si quieres):
  /// - mínimo: nunca mandes más rápido que esto (evita spam)
  static const Duration kMinInterval = Duration(seconds: 12);

  /// - si está parado: manda cada 45s
  static const Duration kStillInterval = Duration(seconds: 45);

  /// - si va lento: manda cada 25s
  static const Duration kSlowInterval = Duration(seconds: 25);

  /// - si va en movimiento: manda cada 15s
  static const Duration kMoveInterval = Duration(seconds: 15);

  Duration _intervalForSpeed(double speedMps) {
    if (speedMps.isFinite == false || speedMps < 0) return kSlowInterval;
    if (speedMps <= 0.5) return kStillInterval;
    if (speedMps <= 2.0) return kSlowInterval;
    return kMoveInterval;
  }

  bool _shouldSendNow(Duration wanted) {
    final last = _lastSentAt;
    if (last == null) return true;

    final elapsed = DateTime.now().difference(last);

    if (elapsed < kMinInterval) return false;

    if (elapsed < wanted) return false;

    return true;
  }

  Future<void> _sendLocationOnce() async {
    if (_sending) return;
    _sending = true;

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        print('TRACKING: sin token (no envio)');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final wantedInterval = _intervalForSpeed(pos.speed);

      if (!_shouldSendNow(wantedInterval)) {
        print('TRACKING: throttle (skip). speed=${pos.speed}');
        return;
      }

      final payload = <String, dynamic>{
        'lat': pos.latitude,
        'lng': pos.longitude,
        if (pos.accuracy.isFinite) 'accuracy': pos.accuracy,
        if (pos.speed.isFinite && pos.speed >= 0) 'speed': pos.speed,
        if (pos.heading.isFinite) 'heading': pos.heading,
      };

      final res = await http
          .post(
            Uri.parse('$apiBase/location'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      _lastSentAt = DateTime.now();

      print('TRACKING: ${res.statusCode} ${res.body}');
    } catch (e) {
      print('TRACKING EXCEPTION: $e');
    } finally {
      _sending = false;
    }
  }

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    print('TRACKING onStart: $timestamp');
    _sendLocationOnce();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    print('TRACKING onRepeatEvent: $timestamp');
    _sendLocationOnce();
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    print('TRACKING onDestroy: $timestamp');
  }

  @override
  void onNotificationPressed() {
    print('TRACKING onNotificationPressed');
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(
    TrackingTaskHandler('https://seguridadvial-mich.com/api'),
  );
}
