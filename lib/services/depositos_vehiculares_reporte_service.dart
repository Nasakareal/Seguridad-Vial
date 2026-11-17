import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class DepositosVehicularesReporteService {
  const DepositosVehicularesReporteService();

  static DateTime oneMonthBefore(DateTime value) {
    final previousYear = value.month == 1 ? value.year - 1 : value.year;
    final previousMonth = value.month == 1 ? 12 : value.month - 1;
    final lastDay = DateTime(previousYear, previousMonth + 1, 0).day;
    final day = value.day > lastDay ? lastDay : value.day;
    return DateTime(previousYear, previousMonth, day);
  }

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

  Future<DepositosVehicularesReportePage> fetch({
    Map<String, dynamic> filters = const <String, dynamic>{},
    int page = 1,
    int perPage = 25,
  }) async {
    final response = await http.get(
      _uri('/settings/depositos-vehiculares', <String, dynamic>{
        ...filters,
        'page': page,
        'per_page': perPage,
      }),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'No se pudo cargar el reporte de depósitos.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('El servidor devolvió una respuesta inválida.');
    }
    return DepositosVehicularesReportePage.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<Uint8List> downloadExcel({
    Map<String, dynamic> filters = const <String, dynamic>{},
  }) async {
    final response = await http.get(
      _uri('/settings/depositos-vehiculares/excel', filters),
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
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList();
        if (errors.isNotEmpty) return Exception(errors.first);
      }
    } catch (_) {}
    return Exception('$fallback (HTTP ${response.statusCode})');
  }
}

class DepositosVehicularesReportePage {
  final List<DepositoVehicularReporteRow> vehicles;
  final DepositosVehicularesReporteSummary summary;
  final DepositosVehicularesReporteOptions options;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const DepositosVehicularesReportePage({
    required this.vehicles,
    required this.summary,
    required this.options,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory DepositosVehicularesReportePage.fromJson(Map<String, dynamic> json) {
    final pagination = _map(json['pagination']);
    final rows = json['data'] is List ? json['data'] as List : const [];
    return DepositosVehicularesReportePage(
      vehicles: rows
          .whereType<Map>()
          .map(
            (row) => DepositoVehicularReporteRow.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(),
      summary: DepositosVehicularesReporteSummary.fromJson(
        _map(json['summary']),
      ),
      options: DepositosVehicularesReporteOptions.fromJson(
        _map(json['options']),
      ),
      currentPage: _int(pagination['current_page'], 1),
      lastPage: _int(pagination['last_page'], 1),
      perPage: _int(pagination['per_page'], 25),
      total: _int(pagination['total']),
    );
  }
}

class DepositosVehicularesReporteSummary {
  final int total;
  final int released;
  final int pendingRelease;

  const DepositosVehicularesReporteSummary({
    required this.total,
    required this.released,
    required this.pendingRelease,
  });

  factory DepositosVehicularesReporteSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return DepositosVehicularesReporteSummary(
      total: _int(json['total']),
      released: _int(json['liberados']),
      pendingRelease: _int(json['sin_liberacion']),
    );
  }
}

class DepositosVehicularesReporteOptions {
  final Map<int, String> units;
  final List<String> types;
  final List<String> brands;
  final List<String> deposits;

  const DepositosVehicularesReporteOptions({
    required this.units,
    required this.types,
    required this.brands,
    required this.deposits,
  });

  factory DepositosVehicularesReporteOptions.fromJson(
    Map<String, dynamic> json,
  ) {
    List<String> values(String key) => json[key] is List
        ? (json[key] as List)
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList()
        : const <String>[];

    final units = <int, String>{};
    if (json['unidades'] is Map) {
      (json['unidades'] as Map).forEach((key, value) {
        final id = int.tryParse(key.toString());
        final name = value?.toString().trim() ?? '';
        if (id != null && name.isNotEmpty) units[id] = name;
      });
    }

    return DepositosVehicularesReporteOptions(
      units: units,
      types: values('tipos'),
      brands: values('marcas'),
      deposits: values('corralones'),
    );
  }
}

class DepositoVehicularReporteRow {
  final int vehicleId;
  final String type;
  final String brand;
  final String line;
  final String model;
  final String color;
  final String plates;
  final String serialNumber;
  final String inventory;
  final int? releaseId;
  final String releaseFolio;
  final String admissionDate;
  final String releaseDate;
  final int? unitId;
  final String municipality;
  final String location;
  final String deposit;
  final String origin;
  final String status;

  const DepositoVehicularReporteRow({
    required this.vehicleId,
    required this.type,
    required this.brand,
    required this.line,
    required this.model,
    required this.color,
    required this.plates,
    required this.serialNumber,
    required this.inventory,
    required this.releaseId,
    required this.releaseFolio,
    required this.admissionDate,
    required this.releaseDate,
    required this.unitId,
    required this.municipality,
    required this.location,
    required this.deposit,
    required this.origin,
    required this.status,
  });

  factory DepositoVehicularReporteRow.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    return DepositoVehicularReporteRow(
      vehicleId: _int(json['vehiculo_id']),
      type: text('tipo'),
      brand: text('marca'),
      line: text('linea'),
      model: text('modelo'),
      color: text('color'),
      plates: text('placas'),
      serialNumber: text('serie'),
      inventory: text('inventario'),
      releaseId: _nullableInt(json['liberacion_id']),
      releaseFolio: text('folio_liberacion'),
      admissionDate: text('fecha_ingreso'),
      releaseDate: text('fecha_egreso'),
      unitId: _nullableInt(json['unidad_id']),
      municipality: text('municipio'),
      location: text('ubicacion'),
      deposit: text('corralon'),
      origin: text('origen'),
      status: text('estado'),
    );
  }

  bool get released => releaseDate.isNotEmpty || releaseId != null;
  String get title =>
      [brand, line].where((value) => value.isNotEmpty).join(' · ');
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

int _int(dynamic value, [int fallback = 0]) =>
    int.tryParse(value?.toString() ?? '') ?? fallback;

int? _nullableInt(dynamic value) => int.tryParse(value?.toString() ?? '');
