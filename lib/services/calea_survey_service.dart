import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class CaleaSurveyService {
  static String get _base => '${AuthService.baseUrl}/calea-encuestas';

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await AuthService.getToken();
      if ((token ?? '').isEmpty) throw Exception('Sesión inválida.');
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<List<Map<String, dynamic>>> active() async =>
      _list(_data(await _send('GET', '$_base/activas')));
  static Future<List<Map<String, dynamic>>> managed() async =>
      _list(_data(await _send('GET', '$_base/administrar')));
  static Future<List<Map<String, dynamic>>> results(int surveyId) async =>
      _list(_data(await _send('GET', '$_base/$surveyId/resultados')));
  static Future<Map<String, dynamic>> catalogs() async =>
      _map(_data(await _send('GET', '$_base/catalogos')));
  static Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      _map(_data(await _send('POST', _base, body: body)));
  static Future<Map<String, dynamic>> start(int id) async =>
      _map(_data(await _send('POST', '$_base/$id/iniciar')));
  static Future<Map<String, dynamic>> attempt(
    String uuid, {
    bool public = false,
  }) async => _map(
    _data(
      await _send(
        'GET',
        '$_base${public ? '/public' : ''}/intentos/$uuid',
        auth: !public,
      ),
    ),
  );
  static Future<void> answer(
    String uuid,
    Map<String, dynamic> answer, {
    bool public = false,
  }) async => _send(
    'PUT',
    '$_base${public ? '/public' : ''}/intentos/$uuid/respuesta',
    body: answer,
    auth: !public,
  );
  static Future<Map<String, dynamic>> finish(
    String uuid, {
    bool public = false,
  }) async => _map(
    _data(
      await _send(
        'POST',
        '$_base${public ? '/public' : ''}/intentos/$uuid/finalizar',
        auth: !public,
      ),
    ),
  );
  static Future<void> cancel(String uuid, {bool public = false}) async => _send(
    'POST',
    '$_base${public ? '/public' : ''}/intentos/$uuid/cancelar',
    auth: !public,
  );
  static Future<Map<String, dynamic>> publicSurvey(String code) async => _map(
    _data(await _send('GET', '$_base/public/${code.trim()}', auth: false)),
  );
  static Future<Map<String, dynamic>> publicStart(
    String code,
    Map<String, dynamic> identity,
  ) async => _map(
    _data(
      await _send(
        'POST',
        '$_base/public/${code.trim()}/iniciar',
        body: identity,
        auth: false,
      ),
    ),
  );
  static Future<void> reauthorize(
    int surveyId,
    int userId, {
    String? reason,
  }) async => _send(
    'POST',
    '$_base/$surveyId/usuarios/$userId/reautorizar',
    body: {'motivo': reason},
  );

  static Future<Map<String, dynamic>> _send(
    String method,
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse(url);
    final headers = await _headers(auth: auth);
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'POST' => await http.post(uri, headers: headers, body: encoded),
      'PUT' => await http.put(uri, headers: headers, body: encoded),
      _ => await http.get(uri, headers: headers),
    };
    Map<String, dynamic> json = {};
    try {
      json = _map(jsonDecode(utf8.decode(response.bodyBytes)));
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (json['message'] ?? 'Error HTTP ${response.statusCode}').toString(),
      );
    }
    return json;
  }

  static dynamic _data(Map<String, dynamic> json) => json['data'] ?? json;
  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];
  static String clean(Object e) =>
      e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}
