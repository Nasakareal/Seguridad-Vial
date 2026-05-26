import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'delegacion_distance_service.dart';

const double _targetAccuracyMeters = 5.0;
const double _goodEnoughAccuracyMeters = 10.0;
const Duration _minimumRefinementDuration = Duration(seconds: 3);
const Duration _manualCaptureTimeout = Duration(seconds: 10);
const Duration _fallbackPositionTimeout = Duration(seconds: 5);

class GeoResult {
  final double? lat;
  final double? lng;
  final double? accuracyMeters;
  final String? calidadGeo;
  final String? notaGeo;
  final String? fuenteUbicacion;

  const GeoResult({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    required this.calidadGeo,
    required this.notaGeo,
    required this.fuenteUbicacion,
  });

  bool get hasRecommendedAccuracy =>
      accuracyMeters != null && accuracyMeters! <= _targetAccuracyMeters;

  bool get hasLowAccuracy =>
      accuracyMeters != null && accuracyMeters! > _goodEnoughAccuracyMeters;

  String get captureSummary {
    final acc = accuracyMeters;
    if (acc == null || !acc.isFinite || acc.isNaN) {
      return notaGeo?.trim().isNotEmpty == true
          ? notaGeo!.trim()
          : 'Ubicacion capturada.';
    }

    final meters = acc.toStringAsFixed(2);
    if (acc <= _targetAccuracyMeters) {
      return 'Ubicacion capturada con precision GPS de $meters m.';
    }

    if (acc <= _goodEnoughAccuracyMeters) {
      return 'Ubicacion capturada con precision GPS aceptable de $meters m.';
    }

    return 'Ubicacion capturada con precision GPS baja de $meters m. Si necesitas mayor exactitud, intenta de nuevo en un area abierta.';
  }
}

class GeoService {
  static Future<GeoResult> getCurrent() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GeoResult(
          lat: null,
          lng: null,
          accuracyMeters: null,
          calidadGeo: 'OFF',
          notaGeo: 'GPS desactivado',
          fuenteUbicacion: null,
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const GeoResult(
          lat: null,
          lng: null,
          accuracyMeters: null,
          calidadGeo: 'DENIED',
          notaGeo: 'Permiso de ubicación denegado',
          fuenteUbicacion: null,
        );
      }

      await _maybeRequestPreciseAccuracy();

      final pos = await _getBestPosition();

      final acc = pos.accuracy;
      final calidad = acc.isFinite ? acc.toStringAsFixed(2) : null;
      await DelegacionDistanceService.recordLocalMileagePoint(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyMeters: acc,
        capturedAt: pos.timestamp,
      );

      return GeoResult(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyMeters: acc.isFinite && !acc.isNaN ? acc : null,
        calidadGeo: calidad,
        notaGeo: 'ACC:${calidad ?? ''}',
        fuenteUbicacion: 'GPS_APP',
      );
    } catch (e) {
      return GeoResult(
        lat: null,
        lng: null,
        accuracyMeters: null,
        calidadGeo: 'ERR',
        notaGeo: 'Error al inicializar ubicación: $e',
        fuenteUbicacion: null,
      );
    }
  }

  static Future<void> _maybeRequestPreciseAccuracy() async {
    try {
      final accuracyStatus = await Geolocator.getLocationAccuracy();
      if (accuracyStatus == LocationAccuracyStatus.reduced) {
        await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: 'FullAccuracy',
        );
      }
    } catch (_) {}
  }

  static Future<Position> _getBestPosition() async {
    try {
      final streamed = await _collectBestStreamPosition();
      if (streamed != null) return streamed;
    } catch (streamError, streamStackTrace) {
      try {
        return await _getSinglePosition();
      } catch (_) {}

      Error.throwWithStackTrace(streamError, streamStackTrace);
    }

    return _getSinglePosition();
  }

  static Future<Position> _getSinglePosition() {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
      timeLimit: _fallbackPositionTimeout,
    );
  }

  static Future<Position?> _collectBestStreamPosition({Position? seed}) {
    final completer = Completer<Position?>();
    var best = seed;
    Timer? timer;
    Timer? goodEnoughTimer;
    StreamSubscription<Position>? subscription;

    void completeWithBest() {
      if (completer.isCompleted) return;
      completer.complete(best);
      timer?.cancel();
      goodEnoughTimer?.cancel();
      subscription?.cancel();
    }

    void completeWithError(Object error, StackTrace stackTrace) {
      if (best != null) {
        completeWithBest();
        return;
      }

      if (completer.isCompleted) return;
      timer?.cancel();
      goodEnoughTimer?.cancel();
      subscription?.cancel();
      completer.completeError(error, stackTrace);
    }

    timer = Timer(_manualCaptureTimeout, completeWithBest);
    goodEnoughTimer = Timer(_minimumRefinementDuration, () {
      if (_hasGoodEnoughAccuracy(best)) completeWithBest();
    });
    subscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            timeLimit: _manualCaptureTimeout,
          ),
        ).listen(
          (position) {
            best = _betterPosition(best, position);
            if (_hasTargetAccuracy(best)) completeWithBest();
          },
          onError: completeWithError,
          onDone: completeWithBest,
          cancelOnError: false,
        );

    return completer.future;
  }

  static Position _betterPosition(Position? current, Position candidate) {
    if (current == null) return candidate;

    final currentAccuracy = _normalizedAccuracy(current);
    final candidateAccuracy = _normalizedAccuracy(candidate);
    if (candidateAccuracy < currentAccuracy) return candidate;

    if (candidateAccuracy == currentAccuracy &&
        candidate.timestamp.isAfter(current.timestamp)) {
      return candidate;
    }

    return current;
  }

  static bool _hasTargetAccuracy(Position? position) {
    if (position == null) return false;
    return _normalizedAccuracy(position) <= _targetAccuracyMeters;
  }

  static bool _hasGoodEnoughAccuracy(Position? position) {
    if (position == null) return false;
    return _normalizedAccuracy(position) <= _goodEnoughAccuracyMeters;
  }

  static double _normalizedAccuracy(Position position) {
    final accuracy = position.accuracy;
    return accuracy.isFinite && !accuracy.isNaN ? accuracy : double.infinity;
  }
}
