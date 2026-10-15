import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'auth_service.dart';

class GruaCorralonResult {
  final List<Map<String, dynamic>> items;
  final String? gruaNombre;
  final Map<String, dynamic> summary;
  final int currentPage;
  final int lastPage;
  final int total;

  const GruaCorralonResult({
    required this.items,
    required this.summary,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.gruaNombre,
  });
}

class GruaCorralonService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  static Future<GruaCorralonResult> fetch({
    required String estado,
    String search = '',
    String origin = 'TODOS',
    int days = 0,
    int page = 1,
  }) async {
    final uri = Uri.parse('${AuthService.baseUrl}/grua/corralon').replace(
      queryParameters: {
        'estado': estado,
        if (search.trim().isNotEmpty) 'q': search.trim(),
        'origen': origin,
        'dias': '$days',
        'page': '$page',
        'per_page': '50',
      },
    );
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final raw = jsonDecode(response.body);
    if (raw is! Map) throw Exception('Respuesta inválida del servidor.');

    final rawItems = raw['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final grua = raw['grua'];
    final meta = raw['meta'] is Map
        ? Map<String, dynamic>.from(raw['meta'] as Map)
        : const <String, dynamic>{};

    return GruaCorralonResult(
      items: items,
      gruaNombre: grua is Map ? grua['nombre']?.toString() : null,
      summary: raw['summary'] is Map
          ? Map<String, dynamic>.from(raw['summary'] as Map)
          : const {},
      currentPage: int.tryParse('${meta['current_page'] ?? 1}') ?? 1,
      lastPage: int.tryParse('${meta['last_page'] ?? 1}') ?? 1,
      total: int.tryParse('${meta['total'] ?? items.length}') ?? items.length,
    );
  }

  static String imageUrl(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return endpoint;
    }
    return '${AuthService.baseUrl}${endpoint.startsWith('/') ? endpoint : '/$endpoint'}';
  }

  static Future<Map<String, String>> authenticatedHeaders() => _headers();

  static Future<void> exportAndShare({
    required String format,
    required String estado,
    String search = '',
    String origin = 'TODOS',
    int days = 0,
  }) async {
    final normalized = format.toLowerCase();
    if (normalized != 'csv' && normalized != 'pdf') {
      throw Exception('Formato de exportación no válido.');
    }

    final uri =
        Uri.parse(
          '${AuthService.baseUrl}/grua/corralon/exportar/$normalized',
        ).replace(
          queryParameters: {
            'estado': estado,
            if (search.trim().isNotEmpty) 'q': search.trim(),
            'origen': origin,
            'dias': '$days',
          },
        );
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(
      '${directory.path}${Platform.pathSeparator}servicios_corralon_$timestamp.$normalized',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    await Share.shareXFiles([
      XFile(
        file.path,
        mimeType: normalized == 'pdf' ? 'application/pdf' : 'text/csv',
      ),
    ], text: 'Reporte de servicios de corralón');
  }

  static Future<Map<String, dynamic>> updateService({
    required int vehiculoId,
    required bool realizoManiobras,
    required String maniobrasDescripcion,
    required String observaciones,
  }) async {
    final uri = Uri.parse(
      '${AuthService.baseUrl}/grua/corralon/$vehiculoId/servicio',
    );
    final response = await http
        .patch(
          uri,
          headers: {...await _headers(), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'realizo_maniobras': realizoManiobras,
            'maniobras_descripcion': maniobrasDescripcion.trim(),
            'observaciones_grua': observaciones.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }

    final raw = jsonDecode(response.body);
    if (raw is! Map || raw['item'] is! Map) {
      throw Exception('Respuesta inválida del servidor.');
    }
    return Map<String, dynamic>.from(raw['item'] as Map);
  }

  static Future<Map<String, dynamic>> createService({
    required Map<String, String> fields,
    XFile? memoriaDescriptiva,
  }) => _sendRecord(
    path: '/grua/corralon/servicios',
    fields: fields,
    memoriaDescriptiva: memoriaDescriptiva,
  );

  static Future<Map<String, dynamic>> updateRecord({
    required int vehiculoId,
    required Map<String, String> fields,
    XFile? memoriaDescriptiva,
  }) => _sendRecord(
    path: '/grua/corralon/$vehiculoId/expediente',
    fields: fields,
    memoriaDescriptiva: memoriaDescriptiva,
  );

  static Future<Map<String, dynamic>> _sendRecord({
    required String path,
    required Map<String, String> fields,
    XFile? memoriaDescriptiva,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AuthService.baseUrl}$path'),
    );
    request.headers.addAll(await _headers());
    request.fields.addAll(fields);
    if (memoriaDescriptiva != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'memoria_descriptiva',
          await memoriaDescriptiva.readAsBytes(),
          filename: memoriaDescriptiva.name,
        ),
      );
    }
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
    final raw = jsonDecode(response.body);
    if (raw is! Map || raw['item'] is! Map) {
      throw Exception('Respuesta inválida del servidor.');
    }
    return Map<String, dynamic>.from(raw['item'] as Map);
  }

  static Future<void> shareServiceMemory({required int vehiculoId}) async {
    final uri = Uri.parse(
      '${AuthService.baseUrl}/grua/corralon/$vehiculoId/memoria-descriptiva',
    );
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}memoria_servicio_$vehiculoId.pdf',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/pdf'),
    ], text: 'Memoria descriptiva del servicio de grúa');
  }

  static Future<void> shareUploadedMemory({required int vehiculoId}) async {
    final uri = Uri.parse(
      '${AuthService.baseUrl}/grua/corralon/$vehiculoId/memoria-descriptiva/archivo',
    );
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) throw Exception(_errorMessage(response));
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}memoria_sierse_$vehiculoId.pdf',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Memoria descriptiva SIERSE');
  }

  static Future<void> entregar({
    required int vehiculoId,
    required String personaRecibe,
    required String identificacionRecibe,
    required String sierseFolio,
    required String condicionEntrega,
    required String observaciones,
    required XFile fotoEntrega,
    XFile? fotoIdentificacion,
    XFile? documentoLiberacion,
    XFile? comprobantePago,
    XFile? firmaRecibe,
    String telefono = '',
  }) async {
    final uri = Uri.parse(
      '${AuthService.baseUrl}/grua/corralon/$vehiculoId/entregar',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers());
    request.fields.addAll({
      'persona_recibe': personaRecibe.trim(),
      'identificacion_recibe': identificacionRecibe.trim(),
      'telefono_recibe': telefono.trim(),
      'sierse_folio': sierseFolio.trim(),
      'condicion_entrega': condicionEntrega,
      'observaciones': observaciones.trim(),
      'conformidad_memoria': '1',
      'confirmar_entrega': '1',
    });
    request.files.add(
      http.MultipartFile.fromBytes(
        'foto_entrega',
        await fotoEntrega.readAsBytes(),
        filename: fotoEntrega.name,
      ),
    );
    for (final entry in <String, XFile?>{
      'foto_identificacion': fotoIdentificacion,
      'documento_liberacion': documentoLiberacion,
      'comprobante_pago': comprobantePago,
      'firma_recibe': firmaRecibe,
    }.entries) {
      if (entry.value == null) continue;
      request.files.add(
        http.MultipartFile.fromBytes(
          entry.key,
          await entry.value!.readAsBytes(),
          filename: entry.value!.name,
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 40));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
  }

  static String _errorMessage(http.Response response) {
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map) {
        final errors = raw['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
          }
        }
        final message = raw['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return 'No se pudo completar la operación (${response.statusCode}).';
  }
}
