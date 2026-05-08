import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/constancia_manejo.dart';
import 'auth_service.dart';

class ConstanciasManejoService {
  static String get _base => '${AuthService.baseUrl}/constancias-manejo';

  static Future<Map<String, String>> authHeaders({bool json = true}) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesion invalida. Vuelve a iniciar sesion.');
    }

    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String cleanExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Ocurrio un error inesperado.';
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  static String parseQrToken(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments
          .map((segment) => Uri.decodeComponent(segment).trim())
          .where((segment) => segment.isNotEmpty)
          .toList();
      final validarIndex = segments.indexWhere(
        (segment) => segment.toLowerCase() == 'validar',
      );
      if (validarIndex >= 0 && validarIndex + 1 < segments.length) {
        return _cleanToken(segments[validarIndex + 1]);
      }

      final qrIndex = segments.indexWhere(
        (segment) => segment.toLowerCase() == 'qr',
      );
      if (qrIndex >= 0 && qrIndex + 1 < segments.length) {
        return _cleanToken(segments[qrIndex + 1]);
      }
    }

    final uuid = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ).firstMatch(value);
    if (uuid != null) return uuid.group(0)!.toLowerCase();

    if (value.toUpperCase().startsWith('SV-CONSTANCIA:')) {
      return _cleanToken(value.split(':').last);
    }

    return _cleanToken(value);
  }

  static String parseWrittenExamToken(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments
          .map((segment) => Uri.decodeComponent(segment).trim())
          .where((segment) => segment.isNotEmpty)
          .toList();
      final index = segments.indexWhere(
        (segment) => segment.toLowerCase() == 'examen-escrito',
      );
      if (index >= 0 && index + 1 < segments.length) {
        return _cleanToken(segments[index + 1]);
      }
    }

    if (value.toUpperCase().startsWith('SV-EXAMEN-MANEJO:')) {
      return _cleanToken(value.split(':').last);
    }

    return '';
  }

  static String parseExamRequestToken(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments
          .map((segment) => Uri.decodeComponent(segment).trim())
          .where((segment) => segment.isNotEmpty)
          .toList();
      for (final marker in const ['examen', 'examen-escrito']) {
        final index = segments.indexWhere(
          (segment) => segment.toLowerCase() == marker,
        );
        if (index >= 0 && index + 1 < segments.length) {
          return _cleanToken(segments[index + 1]);
        }
      }
    }

    if (value.toUpperCase().startsWith('SV-EXAMEN-MANEJO:')) {
      return _cleanToken(value.split(':').last);
    }

    return '';
  }

  static Future<ConstanciaManejo> buscarPorQr(String rawOrToken) async {
    final token = parseQrToken(rawOrToken);
    if (token.isEmpty) {
      throw Exception('El QR no contiene una constancia valida.');
    }

    final resp = await http
        .get(
          Uri.parse('$_base/qr/${Uri.encodeComponent(token)}'),
          headers: await authHeaders(json: false),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeConstancia(resp);
  }

  static Future<ConstanciaManejo> buscarExamenEscritoPorQr(
    String rawOrToken,
  ) async {
    final token = parseWrittenExamToken(rawOrToken);
    if (token.isEmpty) {
      throw Exception('El QR no contiene un examen escrito valido.');
    }

    final resp = await http
        .get(
          Uri.parse('$_base/examen-escrito/${Uri.encodeComponent(token)}'),
          headers: await authHeaders(json: false),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeConstancia(resp);
  }

  static Future<ConstanciaExamenSolicitud> buscarExamenPorQr(
    String rawOrToken,
  ) async {
    final token = parseExamRequestToken(rawOrToken);
    if (token.isEmpty) {
      throw Exception('El QR no contiene un examen valido.');
    }

    final resp = await http
        .get(
          Uri.parse('$_base/examenes/qr/${Uri.encodeComponent(token)}'),
          headers: await authHeaders(json: false),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeExamenSolicitud(resp);
  }

  static Future<ConstanciaManejo> fetch(int id) async {
    final resp = await http
        .get(Uri.parse('$_base/$id'), headers: await authHeaders(json: false))
        .timeout(const Duration(seconds: 15));

    return _decodeConstancia(resp);
  }

  static Future<ConstanciasManejoPage> index({
    String? estatus,
    String? buscar,
    int page = 1,
    int perPage = 25,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if ((estatus ?? '').trim().isNotEmpty) 'estatus': estatus!.trim(),
      if ((buscar ?? '').trim().isNotEmpty) 'buscar': buscar!.trim(),
    };

    final uri = Uri.parse(_base).replace(queryParameters: query);
    final resp = await http
        .get(uri, headers: await authHeaders(json: false))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    final list = raw['data'];
    final items = list is List
        ? list
              .whereType<Map>()
              .map(
                (item) =>
                    ConstanciaManejo.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <ConstanciaManejo>[];
    final pagination = raw['pagination'] is Map
        ? Map<String, dynamic>.from(raw['pagination'] as Map)
        : <String, dynamic>{};

    return ConstanciasManejoPage(
      items: items,
      currentPage: _readInt(pagination['current_page']) ?? page,
      lastPage: _readInt(pagination['last_page']) ?? page,
      total: _readInt(pagination['total']) ?? items.length,
    );
  }

  static Future<List<ConstanciaModulo>> modulos() async {
    final resp = await http
        .get(
          Uri.parse('$_base/modulos'),
          headers: await authHeaders(json: false),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    final data = raw is Map<String, dynamic> ? raw['data'] : null;
    if (data is! List) return const <ConstanciaModulo>[];

    return data
        .whereType<Map>()
        .map(
          (item) => ConstanciaModulo.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.id > 0)
        .toList();
  }

  static Future<ConstanciasManejoCreateResult> crearLote({
    required int moduloId,
    required int cantidad,
  }) async {
    final resp = await http
        .post(
          Uri.parse(_base),
          headers: await authHeaders(),
          body: jsonEncode(<String, dynamic>{
            'modulo_id': moduloId,
            'cantidad': cantidad,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    final data = raw['data'];
    final constancias = data is List
        ? data
              .whereType<Map>()
              .map(
                (item) =>
                    ConstanciaManejo.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <ConstanciaManejo>[];
    final ids = raw['ids'] is List
        ? (raw['ids'] as List)
              .map((item) => _readInt(item))
              .whereType<int>()
              .toList()
        : constancias.map((item) => item.id).toList();

    return ConstanciasManejoCreateResult(
      constancias: constancias,
      ids: ids,
      urlImprimirLote: (raw['url_imprimir_lote'] ?? '').toString().trim(),
      message: (raw['message'] ?? 'Constancias generadas.').toString(),
    );
  }

  static Future<ConstanciaExamenSolicitud> crearExamen({
    required int moduloId,
    required String nombreSolicitante,
    required String sexo,
    required String tipoLicencia,
    required String modalidad,
    String? curp,
    String? telefono,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/examenes'),
          headers: await authHeaders(),
          body: jsonEncode(<String, dynamic>{
            'modulo_id': moduloId,
            'nombre_solicitante': nombreSolicitante.trim(),
            'sexo': sexo.trim(),
            'curp': curp?.trim(),
            'telefono': telefono?.trim(),
            'tipo_licencia': tipoLicencia.trim(),
            'modalidad': modalidad.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    return _decodeExamenSolicitud(resp);
  }

  static Future<ConstanciaManejo> generarAcceso({
    required int id,
    required String nombreSolicitante,
    required String sexo,
    required String tipoLicencia,
    String? curp,
    String? telefono,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/$id/generar-acceso'),
          headers: await authHeaders(),
          body: jsonEncode(<String, dynamic>{
            'nombre_solicitante': nombreSolicitante.trim(),
            'sexo': sexo.trim(),
            'curp': curp?.trim(),
            'telefono': telefono?.trim(),
            'tipo_licencia': tipoLicencia.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeConstancia(resp);
  }

  static Future<ConstanciaManejo> generarExamenEscrito({
    required int id,
    required String nombreSolicitante,
    required String sexo,
    required String tipoLicencia,
    String? curp,
    String? telefono,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/$id/generar-examen-escrito'),
          headers: await authHeaders(),
          body: jsonEncode(<String, dynamic>{
            'nombre_solicitante': nombreSolicitante.trim(),
            'sexo': sexo.trim(),
            'curp': curp?.trim(),
            'telefono': telefono?.trim(),
            'tipo_licencia': tipoLicencia.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeConstancia(resp);
  }

  static Future<Uint8List> fetchAccessQrImage(
    ConstanciaManejo constancia,
  ) async {
    final embedded = _decodeEmbeddedQr(constancia.qrExamenBase64);
    if (embedded != null) return embedded;

    final url = constancia.urlExamenQr?.trim() ?? '';
    if (url.isEmpty) {
      throw Exception('La constancia no tiene QR temporal disponible.');
    }

    final resp = await http
        .get(Uri.parse(url), headers: await authHeaders(json: false))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    return resp.bodyBytes;
  }

  static Future<Uint8List> fetchWrittenExamQrImage(
    ConstanciaManejo constancia,
  ) async {
    final embedded = _decodeEmbeddedQr(constancia.qrExamenEscritoBase64);
    if (embedded != null) return embedded;

    final url = constancia.urlExamenEscritoQr?.trim() ?? '';
    if (url.isEmpty) {
      throw Exception('La constancia no tiene QR de examen escrito.');
    }

    final resp = await http
        .get(Uri.parse(url), headers: await authHeaders(json: false))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    return resp.bodyBytes;
  }

  static Future<Uint8List> fetchExamRequestQrImage(
    ConstanciaExamenSolicitud solicitud,
  ) async {
    final embedded = _decodeEmbeddedQr(solicitud.qrExamenBase64);
    if (embedded != null) return embedded;

    final url = solicitud.urlExamenQr?.trim() ?? '';
    if (url.isEmpty) {
      throw Exception('El examen no tiene QR disponible.');
    }

    final resp = await http
        .get(Uri.parse(url), headers: await authHeaders(json: false))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    return resp.bodyBytes;
  }

  static Uint8List? _decodeEmbeddedQr(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    final base64Part = value.contains(',')
        ? value.substring(value.indexOf(',') + 1)
        : value;

    try {
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  static Future<ConstanciaManejo> cancelarAcceso(int id) async {
    final resp = await http
        .post(
          Uri.parse('$_base/$id/cancelar-acceso'),
          headers: await authHeaders(),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeConstancia(resp);
  }

  static Future<ConstanciaManejo> capturarImpreso({
    required int id,
    required String nombreSolicitante,
    required String sexo,
    required String tipoLicencia,
    required int totalPreguntas,
    required int aciertos,
    required int errores,
    required double calificacion,
    String? curp,
    String? telefono,
    String? observaciones,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/$id/capturar-impreso'),
          headers: await authHeaders(),
          body: jsonEncode(<String, dynamic>{
            'nombre_solicitante': nombreSolicitante.trim(),
            'sexo': sexo.trim(),
            'curp': curp?.trim(),
            'telefono': telefono?.trim(),
            'tipo_licencia': tipoLicencia.trim(),
            'total_preguntas': totalPreguntas,
            'aciertos': aciertos,
            'errores': errores,
            'calificacion': calificacion,
            'observaciones': observaciones?.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeConstancia(resp);
  }

  static Future<ConstanciaExamenSolicitud> capturarExamenSolicitudImpresa({
    required int id,
    required int totalPreguntas,
    required int aciertos,
    required int errores,
    String? observaciones,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/examenes/$id/capturar-impreso'),
          headers: await authHeaders(),
          body: jsonEncode(<String, dynamic>{
            'total_preguntas': totalPreguntas,
            'aciertos': aciertos,
            'errores': errores,
            'observaciones': observaciones?.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeExamenSolicitud(resp);
  }

  static Future<ConstanciaManejo> activarConExamen({
    required int examenId,
    String? constanciaQr,
    int? constanciaId,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/examenes/$examenId/activar-constancia'),
          headers: await authHeaders(),
          body: jsonEncode(<String, dynamic>{
            'constancia_qr': constanciaQr?.trim(),
            'constancia_id': constanciaId,
          }),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeConstancia(resp);
  }

  static Future<ConstanciaManejo> activar(int id) async {
    final resp = await http
        .post(Uri.parse('$_base/$id/activar'), headers: await authHeaders())
        .timeout(const Duration(seconds: 15));

    return _decodeConstancia(resp);
  }

  static ConstanciaManejo _decodeConstancia(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is Map<String, dynamic>) {
      final data = raw['constancia'] ?? raw['data'];
      if (data is Map) {
        return ConstanciaManejo.fromJson(Map<String, dynamic>.from(data));
      }
      if (raw.containsKey('id')) {
        return ConstanciaManejo.fromJson(raw);
      }
    }

    throw Exception('Respuesta invalida del servidor.');
  }

  static ConstanciaExamenSolicitud _decodeExamenSolicitud(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is Map<String, dynamic>) {
      final data = raw['examen'] ?? raw['data'];
      if (data is Map) {
        return ConstanciaExamenSolicitud.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      if (raw.containsKey('folio_examen')) {
        return ConstanciaExamenSolicitud.fromJson(raw);
      }
    }

    throw Exception('Respuesta invalida del servidor.');
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final errors = raw['errors'];
        if (errors is Map) {
          final messages = <String>[];
          errors.forEach((_, value) {
            if (value is List && value.isNotEmpty) {
              messages.add(value.first.toString());
            }
          });
          if (messages.isNotEmpty) return messages.join('\n');
        }

        final message = (raw['message'] ?? '').toString().trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static String _cleanToken(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
