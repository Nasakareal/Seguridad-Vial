import 'dart:async';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_service.dart';
import 'location_service.dart';
import 'location_flag_service.dart';
import 'tracking_guard_constants.dart';
import 'tracking_guard_notification_service.dart';

class TrackingTaskHandler extends TaskHandler {
  TrackingTaskHandler(this.apiBase);

  final String apiBase;
  static const String panicButtonId = 'panic_symbolic';
  static const String panicPressedAtKey = 'panic_symbolic_pressed_at';

  bool _sending = false;
  DateTime? _lastSentAt;
  bool? _enabledByCommander;
  DateTime? _enabledByCommanderCheckedAt;

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

  Future<bool> _canShareLocationNow() async {
    final checkedAt = _enabledByCommanderCheckedAt;
    if (checkedAt != null &&
        DateTime.now().difference(checkedAt) < const Duration(seconds: 45) &&
        _enabledByCommander != null) {
      return _enabledByCommander!;
    }

    try {
      final enabled = await LocationFlagService.isEnabledForMe();
      _enabledByCommander = enabled;
      _enabledByCommanderCheckedAt = DateTime.now();
      return enabled;
    } catch (_) {
      return _enabledByCommander ?? false;
    }
  }

  Future<void> _sendLocationOnce() async {
    if (_sending) return;
    _sending = true;

    try {
      final isPerito = await AuthService.isPerito();
      if (!isPerito) return;

      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;

      final canShare = await _canShareLocationNow();
      if (!canShare) return;

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

  Future<void> _refreshGuardPresence() async {
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: trackingGuardNotificationTitle,
        notificationText: trackingGuardNotificationText,
      );
    } catch (_) {}

    try {
      await TrackingGuardNotificationService.show();
    } catch (_) {}
  }

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    unawaited(_refreshGuardPresence());
    unawaited(_sendLocationOnce());
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    unawaited(_refreshGuardPresence());
    unawaited(_sendLocationOnce());
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    unawaited(TrackingGuardNotificationService.cancel());
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id != panicButtonId) return;

    FlutterForegroundTask.saveData(
      key: panicPressedAtKey,
      value: DateTime.now().toIso8601String(),
    );
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(
    TrackingTaskHandler(AuthService.baseUrl),
  );
}
