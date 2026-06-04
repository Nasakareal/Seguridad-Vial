import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class LocationFlagService {
  static const String apiBase = 'https://seguridadvial-mich.com/api';

  static bool _toBool(dynamic v) {
    return v == true ||
        (v is num && v == 1) ||
        ('$v'.trim() == '1') ||
        ('$v'.trim().toLowerCase() == 'true');
  }

  static bool? _readBool(dynamic value) {
    if (value == null) return null;
    return _toBool(value);
  }

  static bool? _readTrackingAllowed(Map<dynamic, dynamic> source) {
    final direct = _readBool(source['location_tracking_allowed']);
    if (direct != null) return direct;

    final tracking = source['location_tracking'];
    if (tracking is Map) {
      final nested = _readBool(tracking['allowed']);
      if (nested != null) return nested;
    }

    for (final key in const <String>['user', 'user_meta', 'data']) {
      final nested = source[key];
      if (nested is Map) {
        final value = _readTrackingAllowed(nested);
        if (value != null) return value;
      }
    }

    return null;
  }

  static dynamic _readCompartirUbicacion(Map<dynamic, dynamic> source) {
    if (source['compartir_ubicacion'] != null) {
      return source['compartir_ubicacion'];
    }

    for (final key in const <String>['user', 'user_meta', 'data']) {
      final nested = source[key];
      if (nested is Map) {
        final value = _readCompartirUbicacion(nested);
        if (value != null) return value;
      }
    }

    return null;
  }

  static Future<bool> isEnabledForMe() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return false;

    final res = await http.get(
      Uri.parse('$apiBase/me'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (res.statusCode != 200) return false;

    final j = jsonDecode(res.body);

    if (j is Map) {
      final trackingAllowed = _readTrackingAllowed(j);
      if (trackingAllowed == false) return false;

      final compartir = _readCompartirUbicacion(j);
      if (compartir != null) {
        return _toBool(compartir) && (trackingAllowed ?? true);
      }
    }

    return false;
  }
}
