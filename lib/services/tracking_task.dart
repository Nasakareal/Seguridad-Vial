import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_service.dart';
import 'location_service.dart';

class TrackingTaskHandler extends TaskHandler {
  TrackingTaskHandler(this.apiBase);

  final String apiBase;

  bool _sending = false;
  DateTime? _lastSentAt;

  static const Duration kMinInterval = Duration(seconds: 12);
  static const Duration kStillInterval = Duration(seconds: 50);
  static const Duration kSlowInterval = Duration(seconds: 30);
  static const Duration kMoveInterval = Duration(seconds: 20);

  Duration _intervalForSpeed(double speedMps) {
    if (!speedMps.isFinite || speedMps < 0) return kSlowInterval;
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
      final isPerito = await AuthService.isPerito();
      if (!isPerito) return;

      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (pos.accuracy.isNaN || !pos.accuracy.isFinite || pos.accuracy > 150) {
        return;
      }

      final age = DateTime.now().difference(pos.timestamp);
      if (age.inMinutes >= 2) return;

      final wantedInterval = _intervalForSpeed(pos.speed);
      if (!_shouldSendNow(wantedInterval)) return;

      final sent = await LocationService(
        apiBase: apiBase,
      ).sendOnce(positionOverride: pos);

      if (sent) {
        _lastSentAt = DateTime.now();
      }
    } catch (_) {
    } finally {
      _sending = false;
    }
  }

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    _sendLocationOnce();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    _sendLocationOnce();
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onNotificationPressed() {}
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(
    TrackingTaskHandler(AuthService.baseUrl),
  );
}
