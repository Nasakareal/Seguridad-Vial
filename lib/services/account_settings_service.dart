import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AccountSettings {
  final bool receiveWazeAlerts;

  const AccountSettings({required this.receiveWazeAlerts});

  factory AccountSettings.fromJson(Map<String, dynamic> json) {
    final raw = json['receive_waze_alerts'];
    return AccountSettings(
      receiveWazeAlerts: raw == true || raw == 1 || raw?.toString() == '1',
    );
  }
}

class AccountSettingsService {
  static const Duration _timeout = Duration(seconds: 15);

  static Future<AccountSettings> fetch() async {
    final response = await http
        .get(
          Uri.parse('${AuthService.baseUrl}/account/settings'),
          headers: await _headers(),
        )
        .timeout(_timeout);

    return AccountSettings.fromJson(_decodeObject(response));
  }

  static Future<AccountSettings> updateWazeAlerts(bool enabled) async {
    final response = await http
        .put(
          Uri.parse('${AuthService.baseUrl}/account/settings'),
          headers: await _headers(jsonBody: true),
          body: jsonEncode(<String, dynamic>{'receive_waze_alerts': enabled}),
        )
        .timeout(_timeout);

    return AccountSettings.fromJson(_decodeObject(response));
  }

  static Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('La sesión terminó. Inicia sesión nuevamente.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (jsonBody) 'Content-Type': 'application/json',
    };
  }

  static Map<String, dynamic> _decodeObject(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map) {
        final raw = decoded['data'] is Map ? decoded['data'] : decoded;
        return Map<String, dynamic>.from(raw as Map);
      }
      throw Exception('El servidor no devolvió los ajustes de la cuenta.');
    }

    String? message;
    if (decoded is Map) {
      message = decoded['message']?.toString();
    }
    throw Exception(
      message?.trim().isNotEmpty == true
          ? message!.trim()
          : 'No se pudieron guardar los ajustes (${response.statusCode}).',
    );
  }
}
