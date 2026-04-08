import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vialidades_urbanas_dispositivo.dart';
import 'auth_service.dart';

class VialidadesUrbanasService {
  static String get _base => '${AuthService.baseUrl}/vialidades-urbanas';

  static Future<Map<String, String>> _headersJson() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesion invalida. Vuelve a iniciar sesion.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);

      if (raw is Map<String, dynamic>) {
        final errors = raw['errors'];
        if (errors is Map) {
          final buffer = StringBuffer();
          errors.forEach((_, value) {
            if (value is List && value.isNotEmpty) {
              buffer.writeln('• ${value.first}');
            }
          });
          final text = buffer.toString().trim();
          if (text.isNotEmpty) return text;
        }

        final message = (raw['message'] ?? '').toString().trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static String toPublicUrl(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.isEmpty) return '';

    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return value;
    }

    final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    if (value.startsWith('/storage/')) return '$root$value';
    if (value.startsWith('storage/')) return '$root/$value';

    return '$root/storage/$value';
  }

  static Future<VialidadesUrbanasIndexResult> fetchIndex({
    required DateTime fecha,
    int page = 1,
  }) async {
    final headers = await _headersJson();
    final uri = Uri.parse(_base).replace(
      queryParameters: <String, String>{
        'fecha': _fmtYmd(fecha),
        'page': page.toString(),
      },
    );

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    final catalogosRaw = raw['catalogos'] is List
        ? raw['catalogos'] as List
        : const [];

    final catalogos =
        catalogosRaw
            .whereType<Map>()
            .map(
              (item) => VialidadesUrbanasCatalogo.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
          ..sort((a, b) {
            final byOrder = a.orden.compareTo(b.orden);
            if (byOrder != 0) return byOrder;
            return a.nombre.compareTo(b.nombre);
          });

    final paginator = raw['dispositivos'] is Map
        ? Map<String, dynamic>.from(raw['dispositivos'] as Map)
        : const <String, dynamic>{};

    final itemsRaw = paginator['data'] is List ? paginator['data'] as List : [];

    int asInt(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;

    final items = itemsRaw
        .whereType<Map>()
        .map(
          (item) => VialidadesUrbanasDispositivo.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();

    return VialidadesUrbanasIndexResult(
      fecha: (raw['fecha'] ?? '').toString().trim(),
      catalogos: catalogos,
      items: items,
      currentPage: asInt(paginator['current_page']),
      lastPage: asInt(paginator['last_page']),
      total: asInt(paginator['total']),
    );
  }

  static Future<List<VialidadesUrbanasCatalogo>> fetchCatalogos({
    DateTime? fecha,
  }) async {
    final result = await fetchIndex(fecha: fecha ?? DateTime.now());
    return result.catalogos;
  }

  static Future<VialidadesUrbanasTotales> fetchResumen({
    required DateTime fecha,
  }) async {
    final headers = await _headersJson();
    final uri = Uri.parse(
      '$_base/1/resumen',
    ).replace(queryParameters: <String, String>{'fecha': _fmtYmd(fecha)});

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    final totales = raw['totales'] is Map
        ? Map<String, dynamic>.from(raw['totales'] as Map)
        : const <String, dynamic>{};

    return VialidadesUrbanasTotales.fromJson(totales);
  }

  static Future<String> fetchWhatsappText({
    required DateTime fecha,
    int referenceId = 1,
  }) async {
    final headers = await _headersJson();
    final uri = Uri.parse(
      '$_base/$referenceId/whatsapp',
    ).replace(queryParameters: <String, String>{'fecha': _fmtYmd(fecha)});

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    final texto = (raw['texto'] ?? '').toString().trim();
    if (texto.isEmpty) {
      throw Exception('No hay informacion disponible para compartir.');
    }

    return texto;
  }
}
