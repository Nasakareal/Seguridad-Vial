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

  const SettingsStatisticsModule({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.reports,
  });

  factory SettingsStatisticsModule.fromJson(Map<dynamic, dynamic> json) {
    final rawReports = json['reports'];

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
    );
  }
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
