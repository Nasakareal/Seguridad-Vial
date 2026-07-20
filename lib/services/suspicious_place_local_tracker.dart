import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'offline_sync_service.dart';

typedef SuspiciousPlaceEventSender =
    Future<OfflineActionResult> Function(
      Map<String, dynamic> body,
      String requestId,
      String? dependsOnRequestId,
    );

class SuspiciousPlaceLocalTracker {
  static const String placeKey = 'gruas-munoz';
  static const String placeName = 'Grúas Muñoz';
  static const double latitude = 19.6603522;
  static const double longitude = -101.2373983;
  static const double entryRadiusMeters = 120;
  static const double exitRadiusMeters = 180;
  static const double maxAccuracyMeters = 100;
  static const Duration dwellTime = Duration(minutes: 5);
  static const Duration maxSampleGap = Duration(minutes: 3);

  static const String _stateKey = 'suspicious_place_local_visit_v1';

  static Future<String> processPosition({
    required double lat,
    required double lng,
    required double accuracyMeters,
    required DateTime capturedAt,
    required String apiBase,
    SuspiciousPlaceEventSender? eventSender,
  }) async {
    if (!accuracyMeters.isFinite || accuracyMeters > maxAccuracyMeters) {
      return 'ignored_accuracy';
    }

    final ownerKey = await AuthService.getSessionOwnerKey();
    if (ownerKey == null || ownerKey.isEmpty) return 'ignored_session';

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    var state = _readState(prefs);

    if (state != null && state.ownerKey != ownerKey) {
      await prefs.remove(_stateKey);
      state = null;
    }

    final capturedUtc = capturedAt.toUtc();
    final sender =
        eventSender ??
        (body, requestId, dependsOnRequestId) => OfflineSyncService.submitJson(
          label: 'Evento de permanencia',
          method: 'POST',
          uri: Uri.parse('$apiBase/suspicious-place-events'),
          body: body,
          requestId: requestId,
          dependsOnOperationId: dependsOnRequestId,
          successCodes: const <int>{200, 201},
          announceOnQueue: false,
        );

    if (state?.exitedAt != null) {
      return _retryCompletedVisit(prefs, state!, sender);
    }

    if (state != null && !capturedUtc.isAfter(state.lastSampleAt)) {
      return 'ignored_out_of_order';
    }

    if (state != null &&
        capturedUtc.difference(state.lastSampleAt) > maxSampleGap) {
      await prefs.remove(_stateKey);
      state = null;
    }

    final distance = _haversineMeters(latitude, longitude, lat, lng);

    if (state == null) {
      if (distance > entryRadiusMeters) return 'outside';

      state = _LocalVisitState(
        visitId: OfflineSyncService.newClientUuid(),
        ownerKey: ownerKey,
        enteredAt: capturedUtc,
        lastInsideAt: capturedUtc,
        lastInsideLat: lat,
        lastInsideLng: lng,
        lastInsideAccuracyMeters: accuracyMeters,
        lastSampleAt: capturedUtc,
        entrySubmitted: false,
      );
      await _saveState(prefs, state);
      return 'entered';
    }

    if (distance < exitRadiusMeters) {
      state = state.copyWith(
        lastInsideAt: distance <= entryRadiusMeters
            ? capturedUtc
            : state.lastInsideAt,
        lastInsideLat: distance <= entryRadiusMeters
            ? lat
            : state.lastInsideLat,
        lastInsideLng: distance <= entryRadiusMeters
            ? lng
            : state.lastInsideLng,
        lastInsideAccuracyMeters: distance <= entryRadiusMeters
            ? accuracyMeters
            : state.lastInsideAccuracyMeters,
        lastSampleAt: capturedUtc,
      );

      if (!state.entrySubmitted &&
          capturedUtc.difference(state.enteredAt) >= dwellTime) {
        final submitted = await _submitEntry(
          state,
          lat: lat,
          lng: lng,
          accuracyMeters: accuracyMeters,
          occurredAt: capturedUtc,
          sender: sender,
        );
        if (submitted) {
          state = state.copyWith(entrySubmitted: true);
        }
      }

      await _saveState(prefs, state);
      return state.entrySubmitted ? 'dwell_submitted' : 'monitoring';
    }

    final durationSeconds = capturedUtc.difference(state.enteredAt).inSeconds;
    if (durationSeconds < dwellTime.inSeconds) {
      await prefs.remove(_stateKey);
      return 'passed_without_dwell';
    }

    state = state.copyWith(
      lastSampleAt: capturedUtc,
      exitedAt: capturedUtc,
      exitLat: lat,
      exitLng: lng,
      exitAccuracyMeters: accuracyMeters,
      durationSeconds: durationSeconds,
    );
    await _saveState(prefs, state);

    if (!state.entrySubmitted) {
      final entrySubmitted = await _submitEntry(
        state,
        lat: state.lastInsideLat,
        lng: state.lastInsideLng,
        accuracyMeters: state.lastInsideAccuracyMeters,
        occurredAt: state.enteredAt.add(dwellTime),
        sender: sender,
      );
      if (!entrySubmitted) return 'entry_pending';

      state = state.copyWith(entrySubmitted: true);
      await _saveState(prefs, state);
    }

    return _retryCompletedVisit(prefs, state, sender);
  }

  static Future<String> _retryCompletedVisit(
    SharedPreferences prefs,
    _LocalVisitState state,
    SuspiciousPlaceEventSender sender,
  ) async {
    if (!state.entrySubmitted) {
      final submitted = await _submitEntry(
        state,
        lat: state.lastInsideLat,
        lng: state.lastInsideLng,
        accuracyMeters: state.lastInsideAccuracyMeters,
        occurredAt: state.enteredAt.add(dwellTime),
        sender: sender,
      );
      if (!submitted) return 'entry_pending';
      state = state.copyWith(entrySubmitted: true);
      await _saveState(prefs, state);
    }

    try {
      final result = await sender(
        _eventBody(
          state,
          eventType: 'exit',
          occurredAt: state.exitedAt!,
          durationSeconds: state.durationSeconds!,
          lat: state.exitLat!,
          lng: state.exitLng!,
          accuracyMeters: state.exitAccuracyMeters!,
        ),
        _exitRequestId(state),
        _entryRequestId(state),
      );

      if (result.synced || result.queued) {
        await prefs.remove(_stateKey);
        return result.queued ? 'exit_queued' : 'exit_synced';
      }
    } catch (_) {}

    return 'exit_pending';
  }

  static Future<bool> _submitEntry(
    _LocalVisitState state, {
    required double lat,
    required double lng,
    required double accuracyMeters,
    required DateTime occurredAt,
    required SuspiciousPlaceEventSender sender,
  }) async {
    try {
      final result = await sender(
        _eventBody(
          state,
          eventType: 'dwell',
          occurredAt: occurredAt,
          durationSeconds: dwellTime.inSeconds,
          lat: lat,
          lng: lng,
          accuracyMeters: accuracyMeters,
        ),
        _entryRequestId(state),
        null,
      );
      return result.synced || result.queued;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _eventBody(
    _LocalVisitState state, {
    required String eventType,
    required DateTime occurredAt,
    required int durationSeconds,
    required double lat,
    required double lng,
    required double accuracyMeters,
  }) {
    return <String, dynamic>{
      'visit_id': state.visitId,
      'event_type': eventType,
      'place_key': placeKey,
      'entered_at': state.enteredAt.toIso8601String(),
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracyMeters,
    };
  }

  static String _entryRequestId(_LocalVisitState state) =>
      'suspicious_${state.visitId}_dwell';

  static String _exitRequestId(_LocalVisitState state) =>
      'suspicious_${state.visitId}_exit';

  static _LocalVisitState? _readState(SharedPreferences prefs) {
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return _LocalVisitState.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveState(
    SharedPreferences prefs,
    _LocalVisitState state,
  ) => prefs.setString(_stateKey, jsonEncode(state.toJson()));

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371008.8;
    final latDelta = _toRadians(lat2 - lat1);
    final lngDelta = _toRadians(lng2 - lng1);
    final a =
        math.pow(math.sin(latDelta / 2), 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(lngDelta / 2), 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

class _LocalVisitState {
  final String visitId;
  final String ownerKey;
  final DateTime enteredAt;
  final DateTime lastInsideAt;
  final double lastInsideLat;
  final double lastInsideLng;
  final double lastInsideAccuracyMeters;
  final DateTime lastSampleAt;
  final bool entrySubmitted;
  final DateTime? exitedAt;
  final double? exitLat;
  final double? exitLng;
  final double? exitAccuracyMeters;
  final int? durationSeconds;

  const _LocalVisitState({
    required this.visitId,
    required this.ownerKey,
    required this.enteredAt,
    required this.lastInsideAt,
    required this.lastInsideLat,
    required this.lastInsideLng,
    required this.lastInsideAccuracyMeters,
    required this.lastSampleAt,
    required this.entrySubmitted,
    this.exitedAt,
    this.exitLat,
    this.exitLng,
    this.exitAccuracyMeters,
    this.durationSeconds,
  });

  _LocalVisitState copyWith({
    DateTime? lastInsideAt,
    double? lastInsideLat,
    double? lastInsideLng,
    double? lastInsideAccuracyMeters,
    DateTime? lastSampleAt,
    bool? entrySubmitted,
    DateTime? exitedAt,
    double? exitLat,
    double? exitLng,
    double? exitAccuracyMeters,
    int? durationSeconds,
  }) {
    return _LocalVisitState(
      visitId: visitId,
      ownerKey: ownerKey,
      enteredAt: enteredAt,
      lastInsideAt: lastInsideAt ?? this.lastInsideAt,
      lastInsideLat: lastInsideLat ?? this.lastInsideLat,
      lastInsideLng: lastInsideLng ?? this.lastInsideLng,
      lastInsideAccuracyMeters:
          lastInsideAccuracyMeters ?? this.lastInsideAccuracyMeters,
      lastSampleAt: lastSampleAt ?? this.lastSampleAt,
      entrySubmitted: entrySubmitted ?? this.entrySubmitted,
      exitedAt: exitedAt ?? this.exitedAt,
      exitLat: exitLat ?? this.exitLat,
      exitLng: exitLng ?? this.exitLng,
      exitAccuracyMeters: exitAccuracyMeters ?? this.exitAccuracyMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  factory _LocalVisitState.fromJson(Map<String, dynamic> json) {
    return _LocalVisitState(
      visitId: json['visit_id'].toString(),
      ownerKey: json['owner_key'].toString(),
      enteredAt: DateTime.parse(json['entered_at'].toString()).toUtc(),
      lastInsideAt: DateTime.parse(json['last_inside_at'].toString()).toUtc(),
      lastInsideLat: (json['last_inside_lat'] as num).toDouble(),
      lastInsideLng: (json['last_inside_lng'] as num).toDouble(),
      lastInsideAccuracyMeters: (json['last_inside_accuracy'] as num)
          .toDouble(),
      lastSampleAt: DateTime.parse(json['last_sample_at'].toString()).toUtc(),
      entrySubmitted: json['entry_submitted'] == true,
      exitedAt: json['exited_at'] == null
          ? null
          : DateTime.parse(json['exited_at'].toString()).toUtc(),
      exitLat: (json['exit_lat'] as num?)?.toDouble(),
      exitLng: (json['exit_lng'] as num?)?.toDouble(),
      exitAccuracyMeters: (json['exit_accuracy'] as num?)?.toDouble(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'visit_id': visitId,
    'owner_key': ownerKey,
    'entered_at': enteredAt.toIso8601String(),
    'last_inside_at': lastInsideAt.toIso8601String(),
    'last_inside_lat': lastInsideLat,
    'last_inside_lng': lastInsideLng,
    'last_inside_accuracy': lastInsideAccuracyMeters,
    'last_sample_at': lastSampleAt.toIso8601String(),
    'entry_submitted': entrySubmitted,
    'exited_at': exitedAt?.toIso8601String(),
    'exit_lat': exitLat,
    'exit_lng': exitLng,
    'exit_accuracy': exitAccuracyMeters,
    'duration_seconds': durationSeconds,
  };
}
