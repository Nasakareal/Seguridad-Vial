import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'auth_service.dart';

class DictamenesService {
  static const String _baseUrl = 'https://seguridadvial-mich.com/api';

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await AuthService.getToken();

    final h = <String, String>{'Authorization': 'Bearer $token'};

    if (json) {
      h['Accept'] = 'application/json';
      h['Content-Type'] = 'application/json';
    }

    return h;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));
  }

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    try {
      final body = json.decode(res.body);
      throw Exception(body['message'] ?? 'Error ${res.statusCode}');
    } catch (_) {
      throw Exception('Error ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> index({int? anio}) async {
    final res = await http.get(
      _uri('/dictamenes', anio != null ? {'anio': anio} : null),
      headers: await _headers(),
    );

    _throwIfError(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> buscar({String? q, int? anio}) async {
    final query = <String, dynamic>{};

    if (q != null && q.trim().isNotEmpty) query['q'] = q.trim();
    if (anio != null) query['anio'] = anio;

    final res = await http.get(
      _uri('/dictamenes/buscar', query),
      headers: await _headers(),
    );

    _throwIfError(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> show(int dictamenId) async {
    final res = await http.get(
      _uri('/dictamenes/$dictamenId'),
      headers: await _headers(),
    );

    _throwIfError(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> store({
    required String nombrePolicia,
    required String nombreMp,
    File? archivoPdf,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/dictamenes'));

    request.headers.addAll(await _headers(json: false));

    request.fields['nombre_policia'] = nombrePolicia;
    request.fields['nombre_mp'] = nombreMp;

    if (archivoPdf != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'archivo_dictamen',
          archivoPdf.path,
          filename: p.basename(archivoPdf.path),
        ),
      );
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    _throwIfError(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update({
    required int dictamenId,
    required int numeroDictamen,
    required int anio,
    required String nombrePolicia,
    required String nombreMp,
    required String area,
    File? archivoPdf,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/dictamenes/$dictamenId'),
    );

    request.headers.addAll(await _headers(json: false));
    request.fields['_method'] = 'PUT';

    request.fields['numero_dictamen'] = numeroDictamen.toString();
    request.fields['anio'] = anio.toString();
    request.fields['nombre_policia'] = nombrePolicia;
    request.fields['nombre_mp'] = nombreMp;
    request.fields['area'] = area;

    if (archivoPdf != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'archivo_dictamen',
          archivoPdf.path,
          filename: p.basename(archivoPdf.path),
        ),
      );
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    _throwIfError(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> destroy(int dictamenId) async {
    final res = await http.delete(
      _uri('/dictamenes/$dictamenId'),
      headers: await _headers(),
    );

    _throwIfError(res);
  }
}
