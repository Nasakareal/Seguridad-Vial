import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class SettingsStatisticsFilesService {
  static String get _base => AuthService.baseUrl;

  Future<List<SettingsStatisticsModule>> fetchModules() async {
    final res = await http.get(
      Uri.parse('$_base/settings/statistics-files'),
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw _error(res, 'No se pudieron cargar los archivos.');
    }

    final decoded = jsonDecode(res.body);
    final rawModules = decoded is Map ? decoded['modules'] : null;
    if (rawModules is! List) {
      throw Exception('Respuesta invalida del servidor.');
    }

    return rawModules
        .whereType<Map>()
        .map((item) => SettingsStatisticsModule.fromJson(item))
        .toList();
  }

  Future<Uint8List> download(SettingsStatisticsFile file) async {
    final endpoint = file.downloadEndpoint.trim();
    if (endpoint.isEmpty) {
      throw Exception('El archivo no tiene endpoint de descarga.');
    }

    final res = await http.get(
      _endpointUri(endpoint),
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw _error(res, 'No se pudo descargar el archivo.');
    }

    return res.bodyBytes;
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _endpointUri(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint);
    }

    final clean = endpoint
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'^api/'), '');
    return Uri.parse('$_base/$clean');
  }

  Exception _error(http.Response res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['message'] != null) {
        return Exception(decoded['message'].toString());
      }
    } catch (_) {}

    return Exception('$fallback HTTP ${res.statusCode}');
  }
}

class SettingsStatisticsModule {
  final String id;
  final String title;
  final String subtitle;
  final List<SettingsStatisticsReport> reports;
  final List<SettingsSiniestrosPatrol> patrullas;

  const SettingsStatisticsModule({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.reports,
    this.patrullas = const [],
  });

  factory SettingsStatisticsModule.fromJson(Map<dynamic, dynamic> json) {
    final rawReports = json['reports'];
    final rawPatrullas = json['patrullas'];

    return SettingsStatisticsModule(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      reports: rawReports is List
          ? rawReports
                .whereType<Map>()
                .map((item) => SettingsStatisticsReport.fromJson(item))
                .toList()
          : const [],
      patrullas: rawPatrullas is List
          ? rawPatrullas
                .whereType<Map>()
                .map((item) => SettingsSiniestrosPatrol.fromJson(item))
                .toList()
          : const [],
    );
  }
}

class SettingsSiniestrosPatrol {
  final int id;
  final String numeroEconomico;
  final bool activa;
  final String tipo;
  final String marca;
  final String linea;
  final String modelo;
  final String placas;
  final List<SettingsPatrolUser> usuarios;

  const SettingsSiniestrosPatrol({
    required this.id,
    required this.numeroEconomico,
    required this.activa,
    required this.tipo,
    required this.marca,
    required this.linea,
    required this.modelo,
    required this.placas,
    required this.usuarios,
  });

  factory SettingsSiniestrosPatrol.fromJson(Map<dynamic, dynamic> json) {
    final rawUsers = json['usuarios'];

    return SettingsSiniestrosPatrol(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      numeroEconomico: (json['numero_economico'] ?? '').toString().trim(),
      activa: _readBool(json['activa']),
      tipo: (json['tipo'] ?? '').toString().trim(),
      marca: (json['marca'] ?? '').toString().trim(),
      linea: (json['linea'] ?? '').toString().trim(),
      modelo: (json['modelo'] ?? '').toString().trim(),
      placas: (json['placas'] ?? '').toString().trim(),
      usuarios: rawUsers is List
          ? rawUsers
                .whereType<Map>()
                .map((item) => SettingsPatrolUser.fromJson(item))
                .toList()
          : const [],
    );
  }

  String get vehicleLabel => [
    tipo,
    [marca, linea, modelo].where((value) => value.isNotEmpty).join(' '),
    if (placas.isNotEmpty) 'Placas $placas',
  ].where((value) => value.isNotEmpty).join(' · ');

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;

    final values = <String>[
      numeroEconomico,
      tipo,
      marca,
      linea,
      modelo,
      placas,
      ...usuarios.expand((user) => [user.nombre, user.turno, user.estado]),
    ];
    return values.any((value) => value.toLowerCase().contains(needle));
  }
}

class SettingsPatrolUser {
  final int id;
  final String nombre;
  final String estado;
  final int? turnoId;
  final String turno;

  const SettingsPatrolUser({
    required this.id,
    required this.nombre,
    required this.estado,
    required this.turnoId,
    required this.turno,
  });

  factory SettingsPatrolUser.fromJson(Map<dynamic, dynamic> json) {
    return SettingsPatrolUser(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      nombre: (json['nombre'] ?? '').toString().trim(),
      estado: (json['estado'] ?? '').toString().trim(),
      turnoId: int.tryParse((json['turno_id'] ?? '').toString()),
      turno: (json['turno'] ?? '').toString().trim(),
    );
  }

  bool get activa => estado.toLowerCase() == 'activo';
  String get shiftLabel => turno.isEmpty ? 'Sin turno' : 'Turno $turno';
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'si' || text == 'sí';
}

class SettingsStatisticsReport {
  final String id;
  final String title;
  final String subtitle;
  final String extension;
  final List<SettingsStatisticsFile> files;

  const SettingsStatisticsReport({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.extension,
    required this.files,
  });

  factory SettingsStatisticsReport.fromJson(Map<dynamic, dynamic> json) {
    final rawFiles = json['files'];

    return SettingsStatisticsReport(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      extension: (json['extension'] ?? '').toString(),
      files: rawFiles is List
          ? rawFiles
                .whereType<Map>()
                .map((item) => SettingsStatisticsFile.fromJson(item))
                .toList()
          : const [],
    );
  }
}

class SettingsStatisticsFile {
  final String fileName;
  final String date;
  final String extension;
  final int? sizeBytes;
  final String updatedAt;
  final String downloadEndpoint;

  const SettingsStatisticsFile({
    required this.fileName,
    required this.date,
    required this.extension,
    required this.sizeBytes,
    required this.updatedAt,
    required this.downloadEndpoint,
  });

  factory SettingsStatisticsFile.fromJson(Map<dynamic, dynamic> json) {
    return SettingsStatisticsFile(
      fileName: (json['file_name'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      extension: (json['extension'] ?? '').toString(),
      sizeBytes: int.tryParse((json['size_bytes'] ?? '').toString()),
      updatedAt: (json['updated_at'] ?? '').toString(),
      downloadEndpoint: (json['download_endpoint'] ?? '').toString(),
    );
  }

  String get baseName {
    final ext = extension.trim();
    if (ext.isEmpty || !fileName.toLowerCase().endsWith('.$ext')) {
      return fileName;
    }

    return fileName.substring(0, fileName.length - ext.length - 1);
  }
}
