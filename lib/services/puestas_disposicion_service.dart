import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'auth_service.dart';
import 'photo_orientation_service.dart';

class PuestaUnidad {
  final int id;
  final String nombre;

  const PuestaUnidad({required this.id, required this.nombre});
}

class PuestaDisposicionCatalog {
  static const String motivoOtro = 'OTRO';

  static const List<String> tipos = <String>[
    'PERSONA',
    'VEHICULO',
    'OBJETO',
    'MIXTA',
  ];

  static const List<String> motivos = <String>[
    'PERSONA DETENIDA',
    'FALTA ADMINISTRATIVA',
    'ALTERAR EL ORDEN PUBLICO',
    'AGRESIONES',
    'AMENAZAS',
    'VIOLENCIA FAMILIAR',
    'POSESION DE SUSTANCIAS PROHIBIDAS',
    'POSESION DE ARMA DE FUEGO',
    'POSESION DE ARMA BLANCA',
    'ROBO',
    'ROBO A COMERCIO',
    'ROBO A CASA HABITACION',
    'ROBO DE VEHICULO',
    'VEHICULO RECUPERADO',
    'VEHICULO CON REPORTE DE ROBO',
    'VEHICULO ABANDONADO',
    'VEHICULO ALTERADO',
    'DAÑOS',
    'LESIONES',
    'OBJETO ASEGURADO',
    'MERCANCIA ASEGURADA',
    'MANDAMIENTO JUDICIAL',
    'ORDEN DE APREHENSION',
    'HECHO DE TRANSITO',
    'HECHO DE TRANSITO TURNADO',
    motivoOtro,
  ];

  static bool esMotivoCatalogado(String value) => motivos.contains(value);
}

class PuestaUploadFile {
  final String field;
  final File file;

  const PuestaUploadFile({required this.field, required this.file});
}

class PuestaPdfInspection {
  final int bytes;
  final bool hasDigitalSignature;

  const PuestaPdfInspection({
    required this.bytes,
    required this.hasDigitalSignature,
  });

  bool get serverWillTryCompression =>
      bytes >= PuestasDisposicionService.pdfCompressionMinBytes &&
      !hasDigitalSignature;
}

class PuestasDisposicionService {
  static const int maxPdfBytes = 50 * 1024 * 1024;
  static const int pdfCompressionMinBytes = 1024 * 1024;
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  static const Duration uploadTimeout = Duration(minutes: 5);

  static Future<PuestaPdfInspection> inspectPdf(
    File file, {
    String label = 'El PDF',
  }) async {
    if (!await file.exists()) {
      throw Exception('$label ya no existe en el dispositivo.');
    }

    final bytes = await file.length();
    if (bytes <= 0) {
      throw Exception('$label está vacío.');
    }
    if (bytes > maxPdfBytes) {
      throw Exception('$label es muy pesado (máximo 50 MB).');
    }

    final handle = await file.open();
    try {
      final header = await handle.read(5);
      if (header.length != 5 ||
          ascii.decode(header, allowInvalid: true) != '%PDF-') {
        throw Exception('$label no contiene un PDF válido.');
      }
    } finally {
      await handle.close();
    }

    var carry = '';
    var signed = false;
    await for (final chunk in file.openRead()) {
      final content = carry + latin1.decode(chunk, allowInvalid: true);
      if (content.contains('/ByteRange')) {
        signed = true;
        break;
      }
      carry = content.length <= 9
          ? content
          : content.substring(content.length - 9);
    }

    return PuestaPdfInspection(bytes: bytes, hasDigitalSignature: signed);
  }

  static String pdfPreparationMessage(PuestaPdfInspection inspection) {
    if (inspection.hasDigitalSignature) {
      return 'El PDF tiene firma digital: se enviará sin modificar para '
          'conservarla.';
    }
    if (inspection.serverWillTryCompression) {
      return 'El servidor intentará comprimir este PDF automáticamente al guardarlo.';
    }
    return 'El PDF ya es pequeño y no necesita compresión.';
  }

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

  Future<List<Map<String, dynamic>>> index({
    int? anio,
    String? tipoPuesta,
    String? motivo,
  }) async {
    final query = <String, dynamic>{
      if (anio != null) 'anio': anio,
      if ((tipoPuesta ?? '').trim().isNotEmpty)
        'tipo_puesta': tipoPuesta!.trim(),
      if ((motivo ?? '').trim().isNotEmpty) 'motivo': motivo!.trim(),
    };
    final response = await http.get(
      _uri('/puestas-disposicion', query.isEmpty ? null : query),
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
    List<PuestaUploadFile> archivosExtra = const <PuestaUploadFile>[],
  }) async {
    if (archivoPuesta != null) {
      await inspectPdf(archivoPuesta, label: 'El PDF de la puesta');
    }

    final preparedExtras = <PuestaUploadFile>[];
    for (final extra in archivosExtra) {
      if (extra.field.contains('[archivo_uso_fuerza]')) {
        await inspectPdf(extra.file, label: 'El PDF de uso de fuerza');
        preparedExtras.add(extra);
        continue;
      }

      if (extra.field == 'fotos[]') {
        if (!PhotoOrientationService.isAcceptedInput(extra.file)) {
          throw Exception(
            PhotoOrientationService.isRawInput(extra.file)
                ? 'Una foto está en RAW/DNG; expórtala como JPG antes de subirla.'
                : 'Una foto tiene un formato no compatible.',
          );
        }
        final normalized = await PhotoOrientationService.forceLandscape(
          extra.file,
        );
        if (await normalized.length() > maxPhotoBytes) {
          throw Exception('Cada foto debe pesar máximo 5 MB.');
        }
        preparedExtras.add(
          PuestaUploadFile(field: extra.field, file: normalized),
        );
        continue;
      }

      preparedExtras.add(extra);
    }

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

    for (final extra in preparedExtras) {
      request.files.add(
        await http.MultipartFile.fromPath(
          extra.field,
          extra.file.path,
          filename: p.basename(extra.file.path),
        ),
      );
    }

    if (kDebugMode) {
      debugPrint(
        'Puestas API POST ${request.url} fields=${request.fields.keys.join(',')} files=${request.files.length}',
      );
    }

    final http.Response response;
    try {
      final streamed = await request.send().timeout(uploadTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw Exception(
        'El servidor tardó más de 5 minutos procesando los PDF. '
        'Antes de reintentar, revisa la lista por si la puesta sí se guardó.',
      );
    } on SocketException {
      throw Exception(
        'Se perdió la conexión mientras se enviaban los archivos. '
        'Revisa la lista antes de volver a registrar la puesta.',
      );
    }

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

  Future<void> destroy(int id) async {
    final response = await http.delete(
      _uri('/puestas-disposicion/$id'),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateBasic({
    required int id,
    required String tipoPuesta,
    required String motivo,
    required String nombrePolicia,
  }) async {
    final headers = await _headers();
    headers['Content-Type'] = 'application/json';
    final response = await http.put(
      _uri('/puestas-disposicion/$id'),
      headers: headers,
      body: json.encode(<String, String>{
        'tipo_puesta': tipoPuesta,
        'motivo': motivo,
        'nombre_policia': nombrePolicia,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = json.decode(response.body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
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
