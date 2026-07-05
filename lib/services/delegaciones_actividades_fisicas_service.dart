import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/delegacion_actividad_fisica.dart';
import 'auth_service.dart';
import 'network_error_helper.dart';

class DelegacionesActividadesFisicasService {
  static const List<String> defaultTiposEjercicio = <String>[
    'ACTIVACION FISICA',
    'ACONDICIONAMIENTO FISICO',
    'CAMINATA',
    'CARRERA',
    'DEFENSA PERSONAL',
    'ENTRENAMIENTO FUNCIONAL',
    'FUTBOL',
    'BASQUETBOL',
  ];

  static String get _base =>
      '${AuthService.baseUrl}/delegaciones/actividades-fisicas';

  static Future<Map<String, String>> _headers({bool json = true}) async {
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

  static Future<bool> canUse({bool refresh = false}) {
    return AuthService.canUseDelegacionesActividadesFisicas(refresh: refresh);
  }

  static Future<DelegacionActividadFisicaPage> index({
    int page = 1,
    int perPage = 25,
    String? buscar,
    String? fechaInicio,
    String? fechaFin,
    String? tipoEjercicio,
    int? delegacionId,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if ((buscar ?? '').trim().isNotEmpty) 'buscar': buscar!.trim(),
      if ((fechaInicio ?? '').trim().isNotEmpty)
        'fecha_inicio': fechaInicio!.trim(),
      if ((fechaFin ?? '').trim().isNotEmpty) 'fecha_fin': fechaFin!.trim(),
      if ((tipoEjercicio ?? '').trim().isNotEmpty)
        'tipo_ejercicio': tipoEjercicio!.trim(),
      if (delegacionId != null && delegacionId > 0)
        'delegacion_id': delegacionId.toString(),
    };

    final resp = await http
        .get(
          Uri.parse(_base).replace(queryParameters: query),
          headers: await _headers(json: false),
        )
        .timeout(NetworkErrorHelper.interactiveRequestTimeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_backendError(resp));
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
                (item) => DelegacionActividadFisica.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <DelegacionActividadFisica>[];

    final pagination = raw['pagination'] is Map
        ? Map<String, dynamic>.from(raw['pagination'] as Map)
        : raw;

    return DelegacionActividadFisicaPage(
      items: items,
      currentPage: _readInt(pagination['current_page']) ?? page,
      lastPage: _readInt(pagination['last_page']) ?? page,
      total: _readInt(pagination['total']) ?? items.length,
    );
  }

  static Future<List<String>> tipos() async {
    final resp = await http
        .get(Uri.parse('$_base/tipos'), headers: await _headers(json: false))
        .timeout(NetworkErrorHelper.interactiveRequestTimeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_backendError(resp));
    }

    final raw = jsonDecode(resp.body);
    final data = raw is Map<String, dynamic> && raw['data'] is List
        ? raw['data'] as List
        : raw is List
        ? raw
        : const <dynamic>[];

    return <String>{
      ...defaultTiposEjercicio,
      ...data
          .map((item) => (item ?? '').toString().trim())
          .where((item) => item.isNotEmpty),
    }.toList()..sort();
  }

  static Future<DelegacionActividadFisica> store({
    int? delegacionId,
    required String fecha,
    required String hora,
    required String tipoEjercicio,
    required int elementosParticipantes,
    required File foto,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_base));
    request.headers.addAll(await _headers(json: false));

    if (delegacionId != null && delegacionId > 0) {
      request.fields['delegacion_id'] = delegacionId.toString();
    }
    if (fecha.trim().isNotEmpty) request.fields['fecha'] = fecha.trim();
    if (hora.trim().isNotEmpty) request.fields['hora'] = hora.trim();
    request.fields['tipo_ejercicio'] = tipoEjercicio.trim();
    request.fields['elementos_participantes'] = elementosParticipantes
        .toString();
    request.files.add(
      await http.MultipartFile.fromPath(
        'foto',
        foto.path,
        filename: p.basename(foto.path),
      ),
    );

    final streamed = await request.send().timeout(
      NetworkErrorHelper.interactiveRequestTimeout,
    );
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_backendError(resp));
    }

    final raw = jsonDecode(resp.body);
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map) {
        return DelegacionActividadFisica.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
    }

    throw Exception('Respuesta invalida del servidor.');
  }

  static String cleanExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Ocurrio un error inesperado.';
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  static String _backendError(http.Response resp) {
    try {
      final raw = jsonDecode(resp.body);
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

    return 'Error HTTP ${resp.statusCode}';
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }
}
