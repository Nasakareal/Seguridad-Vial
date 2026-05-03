import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'auth_service.dart';

class PuestaUnidad {
  final int id;
  final String nombre;

  const PuestaUnidad({required this.id, required this.nombre});
}

class PuestasDisposicionService {
  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('${AuthService.baseUrl}$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  Future<List<Map<String, dynamic>>> index({int? anio}) async {
    final response = await http.get(
      _uri('/puestas-disposicion', anio == null ? null : {'anio': anio}),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final rawItems = decoded is List
        ? decoded
        : (decoded is Map ? decoded['data'] : null);

    if (rawItems is! List) return <Map<String, dynamic>>[];

    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> show(int id) async {
    final response = await http.get(
      _uri('/puestas-disposicion/$id'),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> store({
    required Map<String, String> fields,
    File? archivoPuesta,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/puestas-disposicion'));
    request.headers.addAll(await _headers());
    request.fields.addAll(fields);

    if (archivoPuesta != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'archivo_puesta',
          archivoPuesta.path,
          filename: p.basename(archivoPuesta.path),
        ),
      );
    }

    if (kDebugMode) {
      debugPrint(
        'Puestas API POST ${request.url} fields=${request.fields.keys.join(',')} file=${archivoPuesta != null}',
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (kDebugMode) {
      debugPrint(
        'Puestas API response ${response.statusCode}: ${response.body}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<List<PuestaUnidad>> unidadesParaCrear() async {
    final unidadId = await AuthService.getUnidadId();
    if (unidadId != null && unidadId > 0) {
      return <PuestaUnidad>[
        PuestaUnidad(id: unidadId, nombre: _fallbackUnidadNombre(unidadId)),
      ];
    }

    return const <PuestaUnidad>[
      PuestaUnidad(id: 1, nombre: 'SINIESTROS'),
      PuestaUnidad(id: 2, nombre: 'DELEGACIONES'),
      PuestaUnidad(id: 3, nombre: 'SEGURIDAD VIAL'),
      PuestaUnidad(id: 4, nombre: 'PROTECCION A CARRETERAS'),
      PuestaUnidad(id: 5, nombre: 'PROTECCION A VIALIDADES URBANAS'),
      PuestaUnidad(id: 6, nombre: 'FOMENTO A LA CULTURA VIAL'),
    ];
  }

  String _fallbackUnidadNombre(int id) {
    switch (id) {
      case 1:
        return 'SINIESTROS';
      case 2:
        return 'DELEGACIONES';
      case 3:
        return 'SEGURIDAD VIAL';
      case 4:
        return 'PROTECCION A CARRETERAS';
      case 5:
        return 'PROTECCION A VIALIDADES URBANAS';
      case 6:
        return 'FOMENTO A LA CULTURA VIAL';
      default:
        return 'UNIDAD $id';
    }
  }
}
