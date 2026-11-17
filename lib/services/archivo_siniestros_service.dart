import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/archivo_siniestros/archivo_models.dart';

typedef ArchivoTokenProvider = Future<String?> Function();

class ArchivoSiniestrosService {
  final String baseUrl;
  final ArchivoTokenProvider tokenProvider;
  final http.Client _client;

  ArchivoSiniestrosService({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final args = <String, String>{};
    for (final item in (query ?? <String, dynamic>{}).entries) {
      final value = item.value;
      if (value != null && value.toString().trim().isNotEmpty) {
        args[item.key] = value.toString();
      }
    }
    return Uri.parse('$root/archivo-siniestros$path').replace(
      queryParameters: args.isEmpty ? null : args,
    );
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = (await tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const ArchivoApiException('Inicia sesión para utilizar el Archivo de Siniestros.');
    }
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return archivoMap(data);
    }
    final body = archivoMap(data);
    final errors = archivoMap(body['errors']);
    String? detail;
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) {
        detail = value.first.toString();
        break;
      }
      if (value is String && value.isNotEmpty) {
        detail = value;
        break;
      }
    }
    final message = detail ?? body['message']?.toString();
    throw ArchivoApiException(
      message ?? 'Error del servidor (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers.addAll(await _headers(json: body != null));
    if (body != null) request.body = jsonEncode(body);
    final stream = await _client.send(request);
    final response = await http.Response.fromStream(stream);
    return _decode(response);
  }

  Future<ArchivoPagina<ArchivoArea>> getAreas({int page = 1, int perPage = 100}) async {
    final json = await _request('GET', '/areas', query: {'page': page, 'per_page': perPage});
    return ArchivoPagina.parse(json, ArchivoArea.fromJson);
  }

  Future<ArchivoPagina<ArchivoAnaquel>> getAnaqueles({int page = 1, int perPage = 100, int? areaId}) async {
    final json = await _request('GET', '/anaqueles', query: {
      'page': page, 'per_page': perPage, 'area_id': areaId,
    });
    return ArchivoPagina.parse(json, ArchivoAnaquel.fromJson);
  }

  Future<ArchivoPagina<ArchivoBloque>> getBloques({int page = 1, int perPage = 100, int? anaquelId}) async {
    final json = await _request('GET', '/bloques', query: {
      'page': page, 'per_page': perPage, 'anaquel_id': anaquelId,
    });
    return ArchivoPagina.parse(json, ArchivoBloque.fromJson);
  }

  Future<List<ArchivoMapaArea>> getMapa({int? areaId}) async {
    final json = await _request('GET', '/mapa', query: {'area_id': areaId});
    return archivoMaps(json['data']).map(ArchivoMapaArea.fromJson).toList();
  }

  Future<ArchivoPagina<ArchivoLibro>> getLibros({
    String q = '', int? anio, String? estadoFisico,
    int page = 1, int perPage = 30,
  }) async {
    final json = await _request('GET', '/libros', query: {
      'q': q, 'anio': anio, 'estado_fisico': estadoFisico,
      'page': page, 'per_page': perPage,
    });
    return ArchivoPagina.parse(json, ArchivoLibro.fromJson);
  }

  Future<ArchivoLibro> getLibro(int id) async {
    final json = await _request('GET', '/libros/$id');
    return ArchivoLibro.fromJson(archivoMap(json['data']));
  }

  Future<ArchivoLibro> libroPorQr(String uuid) async {
    final json = await _request('GET', '/libros/qr/${Uri.encodeComponent(uuid)}');
    return ArchivoLibro.fromJson(archivoMap(json['data']));
  }

  Future<ArchivoBloque> bloquePorQr(String uuid) async {
    final json = await _request('GET', '/bloques/qr/${Uri.encodeComponent(uuid)}');
    return ArchivoBloque.fromJson(archivoMap(json['data']));
  }

  Future<ArchivoBloque> getBloque(int id) async {
    final json = await _request('GET', '/bloques/$id');
    return ArchivoBloque.fromJson(archivoMap(json['data']));
  }

  Future<ArchivoArea> saveArea(Map<String, dynamic> data, {int? id}) async {
    final json = await _request(id == null ? 'POST' : 'PUT', id == null ? '/areas' : '/areas/$id', body: data);
    return ArchivoArea.fromJson(archivoMap(json['data']));
  }

  Future<ArchivoAnaquel> saveAnaquel(Map<String, dynamic> data, {int? id}) async {
    final json = await _request(id == null ? 'POST' : 'PUT', id == null ? '/anaqueles' : '/anaqueles/$id', body: data);
    return ArchivoAnaquel.fromJson(archivoMap(json['data']));
  }

  Future<ArchivoBloque> saveBloque(Map<String, dynamic> data, {int? id}) async {
    final json = await _request(id == null ? 'POST' : 'PUT', id == null ? '/bloques' : '/bloques/$id', body: data);
    return ArchivoBloque.fromJson(archivoMap(json['data']));
  }

  Future<ArchivoLibro> saveLibro(Map<String, dynamic> data, {int? id}) async {
    final json = await _request(id == null ? 'POST' : 'PUT', id == null ? '/libros' : '/libros/$id', body: data);
    return ArchivoLibro.fromJson(archivoMap(json['data']));
  }

  Future<ArchivoLibro> asignarDestino(int id, int bloqueId, {int? posicion}) async {
    final json = await _request('POST', '/libros/$id/asignar-destino', body: {
      'bloque_destino_id': bloqueId, 'posicion_destino': posicion,
    });
    return ArchivoLibro.fromJson(archivoMap(json['data']));
  }

  Future<void> confirmar(int id, String qr, {int? posicion}) async {
    await _request('POST', '/libros/$id/confirmar-ubicacion', body: {
      'bloque_qr_uuid': qr, 'posicion': posicion,
    });
  }

  Future<void> retirar(int id, int areaId, String motivo) async {
    await _request('POST', '/libros/$id/retirar', body: {
      'area_destino_id': areaId, 'motivo': motivo,
    });
  }

  Future<void> devolver(int id, String qr, {int? posicion}) async {
    await _request('POST', '/libros/$id/devolver', body: {
      'bloque_qr_uuid': qr, 'posicion': posicion,
    });
  }

  Future<void> reubicar(int id, int bloqueId, String qr, {int? posicion}) async {
    await _request('POST', '/libros/$id/reubicar', body: {
      'bloque_destino_id': bloqueId,
      'bloque_qr_uuid': qr,
      'posicion': posicion,
    });
  }

  Future<ArchivoPagina<ArchivoFolio>> getFolios(int libroId, {int page = 1}) async {
    final json = await _request('GET', '/libros/$libroId/folios', query: {'page': page, 'per_page': 100});
    return ArchivoPagina.parse(json, ArchivoFolio.fromJson);
  }

  Future<void> crearFolio(int libroId, Map<String, dynamic> data) async {
    await _request('POST', '/libros/$libroId/folios', body: data);
  }

  Future<ArchivoPagina<ArchivoDocumento>> getDocumentos(int libroId, {int page = 1}) async {
    final json = await _request('GET', '/libros/$libroId/documentos', query: {'page': page, 'per_page': 100});
    return ArchivoPagina.parse(json, ArchivoDocumento.fromJson);
  }

  Future<void> subirDocumento({
    required int libroId,
    required String ruta,
    required String nombre,
    required int paginaInicio,
    required int paginaFin,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/libros/$libroId/documentos'));
    request.headers.addAll(await _headers());
    request.fields.addAll({
      'nombre': nombre,
      'pagina_inicio': '$paginaInicio',
      'pagina_fin': '$paginaFin',
    });
    request.files.add(await http.MultipartFile.fromPath('archivo', ruta));
    final stream = await _client.send(request);
    _decode(await http.Response.fromStream(stream));
  }

  Future<Uint8List> descargarDocumento(int libroId, int documentoId) async {
    final response = await _client.get(
      _uri('/libros/$libroId/documentos/$documentoId'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
      throw const ArchivoApiException('No fue posible abrir el documento.');
    }
    return response.bodyBytes;
  }

  Future<ArchivoPagina<ArchivoMovimiento>> getMovimientos(int libroId, {int page = 1}) async {
    final json = await _request('GET', '/libros/$libroId/movimientos', query: {'page': page, 'per_page': 100});
    return ArchivoPagina.parse(json, ArchivoMovimiento.fromJson);
  }

  void close() => _client.close();
}

class ArchivoApiException implements Exception {
  final String message;
  final int? statusCode;
  const ArchivoApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
