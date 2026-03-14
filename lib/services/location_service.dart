import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import 'auth_service.dart';
import 'offline_sync_service.dart';

class LocationService {
  LocationService({required this.apiBase});

  final String apiBase;

  Future<bool> sendOnce({
    Position? positionOverride,
    bool requireAlways = false,
  }) async {
    final isPerito = await AuthService.isPerito();
    if (!isPerito) {
      return false;
    }

    final ok = await _ensurePermissions(requireAlways: requireAlways);
    if (!ok) return false;

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      if (Platform.isIOS && requireAlways) {
        final accuracyStatus = await Geolocator.getLocationAccuracy();
        if (accuracyStatus == LocationAccuracyStatus.reduced) {
          return false;
        }
      }

      final pos =
          positionOverride ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 15),
          );

      final acc = pos.accuracy.isFinite ? pos.accuracy : 9999.0;
      if (acc > 150) {
        return false;
      }

      final age = DateTime.now().difference(pos.timestamp);
      if (age.inMinutes >= 2) {
        return false;
      }

      final payload = <String, dynamic>{
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': acc,
        if (pos.speed.isFinite && pos.speed >= 0) 'speed': pos.speed,
        if (pos.heading.isFinite) 'heading': pos.heading,
      };

      final result = await OfflineSyncService.submitJson(
        label: 'Ubicación',
        method: 'POST',
        uri: Uri.parse('$apiBase/location'),
        body: payload,
        successCodes: const <int>{200, 201},
        announceOnQueue: false,
      );

      return result.synced || result.queued;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensurePermissions({required bool requireAlways}) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (Platform.isIOS &&
        requireAlways &&
        permission != LocationPermission.always) {
      return false;
    }

    return true;
  }
}
