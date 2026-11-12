import 'dart:async';

import 'package:flutter/services.dart';

enum PttHardwareEvent { down, up }

class PttService {
  PttService._();

  static const EventChannel _events = EventChannel(
    'seguridad_vial_app/ptt_events',
  );
  static const MethodChannel _recorder = MethodChannel(
    'seguridad_vial_app/ptt_recorder',
  );

  static Stream<PttHardwareEvent>? _eventStream;

  static Future<bool> isSupported() async {
    return await _recorder.invokeMethod<bool>('isSupported') ?? false;
  }

  static Stream<PttHardwareEvent> get events {
    return _eventStream ??= _events.receiveBroadcastStream().map((raw) {
      final data = raw is Map ? raw : const <dynamic, dynamic>{};
      return data['event'] == 'down'
          ? PttHardwareEvent.down
          : PttHardwareEvent.up;
    }).distinct();
  }

  static Future<String?> startRecording() {
    return _recorder.invokeMethod<String>('startRecording');
  }

  static Future<String?> stopRecording() {
    return _recorder.invokeMethod<String>('stopRecording');
  }

  static Future<void> cancelRecording() async {
    await _recorder.invokeMethod<bool>('cancelRecording');
  }
}
