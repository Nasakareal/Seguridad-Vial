// lib/services/location_service.dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class LocationService {
  LocationService({required this.apiBase});

  final String apiBase;

  Future<bool> sendOnce({
    Position? positionOverride,
    bool requireAlways = false,
  }) async {
    final ok = await _ensurePermissions(requireAlways: requireAlways);
    if (!ok) return false;

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        print('LOC: sin token');
        return false;
      }

      final pos =
          positionOverride ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 15),
          );

      final acc = pos.accuracy.isFinite ? pos.accuracy : 9999.0;
      if (acc > 150) {
        print('LOC: accuracy muy mala ($acc), no se envía');
        return false;
      }

      if (pos.timestamp != null) {
        final age = DateTime.now().difference(pos.timestamp!);
        if (age.inMinutes >= 2) {
          print('LOC: posición vieja (${age.inSeconds}s)');
          return false;
        }
      }

      final payload = <String, dynamic>{
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': acc,
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

      print('LOC: ${res.statusCode} ${res.body}');
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print('LOC EXCEPTION: $e');
      return false;
    }
  }

  Future<bool> _ensurePermissions({required bool requireAlways}) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      // ignore: avoid_print
      print('LOC: GPS apagado');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('LOC: permiso denegado');
      return false;
    }

    if (Platform.isIOS &&
        requireAlways &&
        permission != LocationPermission.always) {
      print(
        'LOC: iOS requiere ALWAYS (modo servicio), pero está en: $permission',
      );
      return false;
    }

    return true;
  }
}
