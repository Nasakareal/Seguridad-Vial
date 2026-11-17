import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ConduceLegalidadReporteService {
  const ConduceLegalidadReporteService();

  static String get _base => AuthService.baseUrl;

  Future<Map<String, String>> _headers({bool download = false}) async {
    final token = await AuthService.getToken();
    return <String, String>{
      'Accept': download ? '*/*' : 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, Map<String, dynamic> filters) {
    final query = <String, String>{};
    filters.forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isNotEmpty) query[key] = text;
    });
    return Uri.parse(
      '$_base$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  Future<ConduceLegalidadReportePage> fetch({
    Map<String, dynamic> filters = const <String, dynamic>{},
    int page = 1,
    int perPage = 25,
  }) async {
    final params = <String, dynamic>{
      ...filters,
      'page': page,
      'per_page': perPage,
    };
    final response = await http.get(
      _uri('/settings/conduce-legalidad/vehiculos', params),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'No se pudo cargar el reporte.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('El servidor devolvió una respuesta inválida.');
    }
    return ConduceLegalidadReportePage.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<Uint8List> downloadExcel({
    Map<String, dynamic> filters = const <String, dynamic>{},
  }) async {
    final response = await http.get(
      _uri('/settings/conduce-legalidad/vehiculos/excel', filters),
      headers: await _headers(download: true),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'No se pudo descargar el Excel.');
    }
    return response.bodyBytes;
  }

  Exception _error(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map &&
          body['message']?.toString().trim().isNotEmpty == true) {
        return Exception(body['message'].toString());
      }
      if (body is Map && body['errors'] is Map) {
        final errors = (body['errors'] as Map).values
            .expand((value) => value is List ? value : <dynamic>[value])
            .map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList();
        if (errors.isNotEmpty) return Exception(errors.first);
      }
    } catch (_) {}
    return Exception('$fallback (HTTP ${response.statusCode})');
  }
}

class ConduceLegalidadReportePage {
  final List<ConduceLegalidadReporteVehiculo> vehicles;
  final ConduceLegalidadReporteSummary summary;
  final ConduceLegalidadReporteOptions options;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const ConduceLegalidadReportePage({
    required this.vehicles,
    required this.summary,
    required this.options,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory ConduceLegalidadReportePage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : const <String, dynamic>{};
    final rows = json['data'] is List ? json['data'] as List : const [];
    return ConduceLegalidadReportePage(
      vehicles: rows
          .whereType<Map>()
          .map(
            (row) => ConduceLegalidadReporteVehiculo.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(),
      summary: ConduceLegalidadReporteSummary.fromJson(
        json['summary'] is Map
            ? Map<String, dynamic>.from(json['summary'] as Map)
            : const <String, dynamic>{},
      ),
      options: ConduceLegalidadReporteOptions.fromJson(
        json['options'] is Map
            ? Map<String, dynamic>.from(json['options'] as Map)
            : const <String, dynamic>{},
      ),
      currentPage: _int(pagination['current_page'], 1),
      lastPage: _int(pagination['last_page'], 1),
      perPage: _int(pagination['per_page'], 25),
      total: _int(pagination['total']),
    );
  }
}

class ConduceLegalidadReporteSummary {
  final int vehicles;
  final int operations;
  final int municipalities;
  final int retained;

  const ConduceLegalidadReporteSummary({
    required this.vehicles,
    required this.operations,
    required this.municipalities,
    required this.retained,
  });

  factory ConduceLegalidadReporteSummary.fromJson(Map<String, dynamic> json) {
    return ConduceLegalidadReporteSummary(
      vehicles: _int(json['vehiculos']),
      operations: _int(json['operativos']),
      municipalities: _int(json['municipios']),
      retained: _int(json['retenidos']),
    );
  }
}

class ConduceLegalidadReporteOptions {
  final List<String> municipalities;
  final List<String> brands;
  final List<String> types;
  final List<String> colors;

  const ConduceLegalidadReporteOptions({
    required this.municipalities,
    required this.brands,
    required this.types,
    required this.colors,
  });

  factory ConduceLegalidadReporteOptions.fromJson(Map<String, dynamic> json) {
    List<String> values(String key) => json[key] is List
        ? (json[key] as List)
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList()
        : const <String>[];
    return ConduceLegalidadReporteOptions(
      municipalities: values('municipios'),
      brands: values('marcas'),
      types: values('tipos'),
      colors: values('colores'),
    );
  }
}

class ConduceLegalidadReporteVehiculo {
  final int id;
  final int operationId;
  final String date;
  final String place;
  final String brand;
  final String line;
  final String model;
  final String color;
  final String plates;
  final String serialNumber;
  final String inventoryNumber;
  final bool retained;
  final String vehicleData;
  final String reason;

  const ConduceLegalidadReporteVehiculo({
    required this.id,
    required this.operationId,
    required this.date,
    required this.place,
    required this.brand,
    required this.line,
    required this.model,
    required this.color,
    required this.plates,
    required this.serialNumber,
    required this.inventoryNumber,
    required this.retained,
    required this.vehicleData,
    required this.reason,
  });

  factory ConduceLegalidadReporteVehiculo.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    return ConduceLegalidadReporteVehiculo(
      id: _int(json['id']),
      operationId: _int(json['operativo_id']),
      date: text('fecha_reporte'),
      place: text('lugar_reporte'),
      brand: text('marca'),
      line: text('linea'),
      model: text('modelo'),
      color: text('color'),
      plates: text('placas'),
      serialNumber: text('serie'),
      inventoryNumber: text('numero_inventario'),
      retained:
          json['retencion_vehiculo'] == true ||
          json['retencion_vehiculo'] == 1 ||
          json['retencion_vehiculo']?.toString() == '1',
      vehicleData: text('datos_vehiculo'),
      reason: text('motivo_reporte'),
    );
  }

  String get title =>
      [brand, line].where((value) => value.isNotEmpty).join(' · ');
}

int _int(dynamic value, [int fallback = 0]) =>
    int.tryParse(value?.toString() ?? '') ?? fallback;
