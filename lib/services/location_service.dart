// lib/services/location_service.dart
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class LocationService {
  LocationService({required this.apiBase});

  final String apiBase;

  Future<bool> sendOnce() async {
    final ok = await _ensurePermissions();
    if (!ok) return false;

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        print('LOC: sin token');
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

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

      print('LOC: ${res.statusCode} ${res.body}');

      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print('LOC EXCEPTION: $e');
      return false;
    }
  }

  Future<bool> _ensurePermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
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

    return true;
  }
}
