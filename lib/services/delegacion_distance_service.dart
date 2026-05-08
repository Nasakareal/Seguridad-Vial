import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class DelegacionCoords {
  const DelegacionCoords({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class DelegacionDistanceService {
  static const String kilometrosRecorridosField = 'km_recorridos';
  static const Duration maxIdleBeforeDelegacionOrigin = Duration(hours: 24);
  static const Duration maxIdleBeforeLocalMileageReset = Duration(hours: 24);
  static const Duration maxLocalMileageSegmentGap = Duration(hours: 2);
  static const double maxAcceptedLocalMileageAccuracyMeters = 150.0;
  static const double minLocalMileageSegmentMeters = 15.0;
  static const double maxLocalMileageSegmentSpeedMps = 60.0;
  static const double maxLocalMileageKmPerCapture = 500.0;
  static const double _earthRadiusKm = 6371.0088;
  static const String _lastCapturePrefix = 'delegacion_last_capture_v1_';
  static const String _localMileagePrefix = 'local_capture_mileage_v1_';

  static Future<String?> localMileageForCaptureKmField({
    required double? lat,
    required double? lng,
    double? accuracyMeters,
    DateTime? capturedAt,
  }) async {
    final totalKm = await recordLocalMileagePoint(
      lat: lat,
      lng: lng,
      accuracyMeters: accuracyMeters,
      capturedAt: capturedAt,
    );
    if (totalKm == null) return null;

    return totalKm.clamp(0.0, maxLocalMileageKmPerCapture).toStringAsFixed(2);
  }

  static Future<double?> recordLocalMileagePoint({
    required double? lat,
    required double? lng,
    double? accuracyMeters,
    DateTime? capturedAt,
  }) async {
    if (!_validCoords(lat, lng)) return null;
    if (!_acceptableAccuracy(accuracyMeters)) {
      final current = await _loadLocalMileage();
      return current?.totalKm;
    }

    final key = await _localMileageKey();
    if (key == null) return null;

    final currentAt = (capturedAt ?? DateTime.now()).toUtc();
    final currentPoint = _LocalMileagePoint(
      lat: lat!,
      lng: lng!,
      capturedAt: currentAt,
    );

    final previous = await _loadLocalMileage();
    final next = _nextLocalMileageState(previous, currentPoint);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(next.toJson()));
    return next.totalKm;
  }

  static Future<void> resetLocalMileageAfterCapture({
    required double? lat,
    required double? lng,
    DateTime? capturedAt,
  }) async {
    final key = await _localMileageKey();
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (!_validCoords(lat, lng)) {
      await prefs.remove(key);
      return;
    }

    final point = _LocalMileagePoint(
      lat: lat!,
      lng: lng!,
      capturedAt: (capturedAt ?? DateTime.now()).toUtc(),
    );
    final state = _LocalMileageState(
      totalKm: 0,
      lastPoint: point,
      startedAt: point.capturedAt,
      locked: false,
    );
    await prefs.setString(key, jsonEncode(state.toJson()));
  }

  static Future<String?> distanceForNextCaptureKmField({
    required double? lat,
    required double? lng,
    DateTime? now,
  }) async {
    final distance = await distanceForNextCaptureKm(
      lat: lat,
      lng: lng,
      now: now,
    );
    return distance?.toStringAsFixed(2);
  }

  static Future<double?> distanceForNextCaptureKm({
    required double? lat,
    required double? lng,
    DateTime? now,
  }) async {
    if (!_validCoords(lat, lng)) return null;

    final origin = await originForNextCapture(now: now);
    if (origin == null) return null;

    return distanceKm(origin.lat, origin.lng, lat!, lng!);
  }

  static Future<DelegacionCoords?> originForNextCapture({DateTime? now}) async {
    final lastCapture = await _loadLastCapture();
    final current = (now ?? DateTime.now()).toUtc();

    if (lastCapture != null &&
        current.difference(lastCapture.capturedAt.toUtc()) <
            maxIdleBeforeDelegacionOrigin) {
      return DelegacionCoords(lat: lastCapture.lat, lng: lastCapture.lng);
    }

    return currentDelegacionCoords();
  }

  static Future<void> markCaptureSubmitted({
    required double? lat,
    required double? lng,
    DateTime? capturedAt,
  }) async {
    if (!_validCoords(lat, lng)) return;

    await resetLocalMileageAfterCapture(
      lat: lat,
      lng: lng,
      capturedAt: capturedAt,
    );

    final key = await _lastCaptureKey();
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    final point = _LastCapturePoint(
      lat: lat!,
      lng: lng!,
      capturedAt: (capturedAt ?? DateTime.now()).toUtc(),
    );
    await prefs.setString(key, jsonEncode(point.toJson()));
  }

  static Future<void> clearLocalCaptureState() async {
    final key = await _lastCaptureKey();
    final prefs = await SharedPreferences.getInstance();
    if (key != null) {
      await prefs.remove(key);
    }

    final mileageKey = await _localMileageKey();
    if (mileageKey != null) {
      await prefs.remove(mileageKey);
    }
  }

  static Future<String?> distanceFromCurrentDelegacionKmField({
    required double? lat,
    required double? lng,
  }) async {
    final distance = await distanceFromCurrentDelegacionKm(lat: lat, lng: lng);
    return distance?.toStringAsFixed(2);
  }

  static Future<double?> distanceFromCurrentDelegacionKm({
    required double? lat,
    required double? lng,
  }) async {
    if (!_validCoords(lat, lng)) return null;

    final origin = await currentDelegacionCoords();
    if (origin == null) return null;

    return distanceKm(origin.lat, origin.lng, lat!, lng!);
  }

  static Future<DelegacionCoords?> currentDelegacionCoords() async {
    final payload = await AuthService.getCurrentUserPayload(refresh: false);
    final storedCoords = coordsFromPayload(payload);
    if (storedCoords != null) return storedCoords;

    final refreshedPayload = await AuthService.getCurrentUserPayload(
      refresh: true,
    );
    return coordsFromPayload(refreshedPayload);
  }

  static DelegacionCoords? coordsFromPayload(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) return null;

    for (final candidate in _coordCandidates(payload)) {
      final coords = _coordsFromValue(candidate);
      if (coords != null) return coords;
    }

    return null;
  }

  static double distanceKm(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) {
    final dLat = _degToRad(toLat - fromLat);
    final dLng = _degToRad(toLng - fromLng);
    final lat1 = _degToRad(fromLat);
    final lat2 = _degToRad(toLat);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final clamped = a.clamp(0.0, 1.0);
    final c = 2 * math.atan2(math.sqrt(clamped), math.sqrt(1 - clamped));

    return _earthRadiusKm * c;
  }

  static List<dynamic> _coordCandidates(Map<String, dynamic> payload) {
    final candidates = <dynamic>[
      payload['delegacion'],
      payload['delegacion_meta'],
      payload['delegacionMeta'],
      payload['delegacion_principal'],
      payload['delegacionPrincipal'],
      payload['destacamento'],
      payload['destacamento_meta'],
      payload['destacamentoMeta'],
      payload['destacamento_principal'],
      payload['destacamentoPrincipal'],
      payload,
    ];

    final user = _asMap(payload['user']);
    if (user != null) {
      candidates
        ..add(user['delegacion'])
        ..add(user['destacamento'])
        ..add(user);
    }

    final userMeta = _asMap(payload['user_meta']);
    if (userMeta != null) {
      candidates
        ..add(userMeta['delegacion'])
        ..add(userMeta['destacamento'])
        ..add(userMeta);
    }

    final delegaciones = payload['delegaciones'];
    if (delegaciones is Iterable) {
      final items = delegaciones.toList();
      candidates.addAll(
        items.where((item) {
          final map = _asMap(item);
          if (map == null) return false;
          final pivot = _asMap(map['pivot']);
          return _truthy(map['principal']) || _truthy(pivot?['principal']);
        }),
      );
      candidates.addAll(items);
    }

    final destacamentos = payload['destacamentos'];
    if (destacamentos is Iterable) {
      final items = destacamentos.toList();
      candidates.addAll(
        items.where((item) {
          final map = _asMap(item);
          if (map == null) return false;
          final pivot = _asMap(map['pivot']);
          return _truthy(map['principal']) || _truthy(pivot?['principal']);
        }),
      );
      candidates.addAll(items);
    }

    return candidates;
  }

  static DelegacionCoords? _coordsFromValue(dynamic value) {
    final map = _asMap(value);
    if (map == null) return null;

    final lat = _firstDouble(map, const [
      'lat',
      'latitude',
      'latitud',
      'delegacion_lat',
      'delegacion_latitud',
    ]);
    final lng = _firstDouble(map, const [
      'lng',
      'lon',
      'long',
      'longitude',
      'longitud',
      'delegacion_lng',
      'delegacion_longitud',
    ]);

    if (!_validCoords(lat, lng)) return null;
    return DelegacionCoords(lat: lat!, lng: lng!);
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static double? _firstDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final parsed = _parseDouble(map[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    final text = value.toString().trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static bool _validCoords(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  static bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'si' || text == 'sí';
  }

  static Future<_LastCapturePoint?> _loadLastCapture() async {
    final key = await _lastCaptureKey();
    if (key == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      final map = _asMap(decoded);
      if (map == null) return null;
      return _LastCapturePoint.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _lastCaptureKey() async {
    final ownerKey = (await AuthService.getSessionOwnerKey())?.trim() ?? '';
    if (ownerKey.isEmpty) return null;
    return '$_lastCapturePrefix$ownerKey';
  }

  static Future<String?> _localMileageKey() async {
    final ownerKey = (await AuthService.getSessionOwnerKey())?.trim() ?? '';
    if (ownerKey.isEmpty) return null;
    return '$_localMileagePrefix$ownerKey';
  }

  static Future<_LocalMileageState?> _loadLocalMileage() async {
    final key = await _localMileageKey();
    if (key == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      final map = _asMap(decoded);
      if (map == null) return null;
      return _LocalMileageState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static _LocalMileageState _nextLocalMileageState(
    _LocalMileageState? previous,
    _LocalMileagePoint current,
  ) {
    if (previous == null) {
      return _LocalMileageState(
        totalKm: 0,
        lastPoint: current,
        startedAt: current.capturedAt,
        locked: false,
      );
    }

    if (previous.locked) return previous;

    final gap = current.capturedAt.difference(previous.lastPoint.capturedAt);
    if (gap.isNegative || gap >= maxIdleBeforeLocalMileageReset) {
      return _LocalMileageState(
        totalKm: 0,
        lastPoint: current,
        startedAt: current.capturedAt,
        locked: false,
      );
    }

    final segmentKm = distanceKm(
      previous.lastPoint.lat,
      previous.lastPoint.lng,
      current.lat,
      current.lng,
    );
    final segmentMeters = segmentKm * 1000;

    if (segmentMeters < minLocalMileageSegmentMeters ||
        gap > maxLocalMileageSegmentGap ||
        _looksLikeImpossibleSegment(segmentMeters, gap)) {
      return previous.copyWith(lastPoint: current);
    }

    final total = previous.totalKm + segmentKm;
    if (total >= maxLocalMileageKmPerCapture) {
      return previous.copyWith(
        totalKm: maxLocalMileageKmPerCapture,
        lastPoint: current,
        locked: true,
      );
    }

    return previous.copyWith(totalKm: total, lastPoint: current);
  }

  static bool _acceptableAccuracy(double? accuracyMeters) {
    if (accuracyMeters == null) return true;
    if (accuracyMeters.isNaN || !accuracyMeters.isFinite) return false;
    return accuracyMeters <= maxAcceptedLocalMileageAccuracyMeters;
  }

  static bool _looksLikeImpossibleSegment(double meters, Duration gap) {
    final seconds = gap.inMilliseconds / 1000.0;
    if (seconds <= 0) return meters > minLocalMileageSegmentMeters;
    return meters / seconds > maxLocalMileageSegmentSpeedMps;
  }

  static double _degToRad(double degrees) => degrees * math.pi / 180;
}

class _LastCapturePoint {
  const _LastCapturePoint({
    required this.lat,
    required this.lng,
    required this.capturedAt,
  });

  final double lat;
  final double lng;
  final DateTime capturedAt;

  factory _LastCapturePoint.fromJson(Map<String, dynamic> json) {
    final lat = DelegacionDistanceService._parseDouble(json['lat']);
    final lng = DelegacionDistanceService._parseDouble(json['lng']);
    final capturedAt = DateTime.tryParse(
      (json['captured_at'] ?? '').toString(),
    )?.toUtc();

    if (!DelegacionDistanceService._validCoords(lat, lng) ||
        capturedAt == null) {
      throw const FormatException('Invalid capture point');
    }

    return _LastCapturePoint(lat: lat!, lng: lng!, capturedAt: capturedAt);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lat': lat,
    'lng': lng,
    'captured_at': capturedAt.toUtc().toIso8601String(),
  };
}

class _LocalMileagePoint {
  const _LocalMileagePoint({
    required this.lat,
    required this.lng,
    required this.capturedAt,
  });

  final double lat;
  final double lng;
  final DateTime capturedAt;

  factory _LocalMileagePoint.fromJson(Map<String, dynamic> json) {
    final lat = DelegacionDistanceService._parseDouble(json['lat']);
    final lng = DelegacionDistanceService._parseDouble(json['lng']);
    final capturedAt = DateTime.tryParse(
      (json['captured_at'] ?? '').toString(),
    )?.toUtc();

    if (!DelegacionDistanceService._validCoords(lat, lng) ||
        capturedAt == null) {
      throw const FormatException('Invalid local mileage point');
    }

    return _LocalMileagePoint(lat: lat!, lng: lng!, capturedAt: capturedAt);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lat': lat,
    'lng': lng,
    'captured_at': capturedAt.toUtc().toIso8601String(),
  };
}

class _LocalMileageState {
  const _LocalMileageState({
    required this.totalKm,
    required this.lastPoint,
    required this.startedAt,
    required this.locked,
  });

  final double totalKm;
  final _LocalMileagePoint lastPoint;
  final DateTime startedAt;
  final bool locked;

  factory _LocalMileageState.fromJson(Map<String, dynamic> json) {
    final totalKm =
        DelegacionDistanceService._parseDouble(json['total_km']) ?? 0;
    final lastPointRaw = DelegacionDistanceService._asMap(json['last_point']);
    if (lastPointRaw == null) {
      throw const FormatException('Invalid local mileage state');
    }

    final startedAt =
        DateTime.tryParse((json['started_at'] ?? '').toString())?.toUtc() ??
        _LocalMileagePoint.fromJson(lastPointRaw).capturedAt;

    return _LocalMileageState(
      totalKm: totalKm
          .clamp(0.0, DelegacionDistanceService.maxLocalMileageKmPerCapture)
          .toDouble(),
      lastPoint: _LocalMileagePoint.fromJson(lastPointRaw),
      startedAt: startedAt,
      locked: DelegacionDistanceService._truthy(json['locked']),
    );
  }

  _LocalMileageState copyWith({
    double? totalKm,
    _LocalMileagePoint? lastPoint,
    DateTime? startedAt,
    bool? locked,
  }) {
    return _LocalMileageState(
      totalKm: totalKm ?? this.totalKm,
      lastPoint: lastPoint ?? this.lastPoint,
      startedAt: startedAt ?? this.startedAt,
      locked: locked ?? this.locked,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total_km': totalKm,
    'last_point': lastPoint.toJson(),
    'started_at': startedAt.toUtc().toIso8601String(),
    'locked': locked,
  };
}
