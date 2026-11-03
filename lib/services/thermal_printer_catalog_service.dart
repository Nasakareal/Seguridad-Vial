import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ThermalPrinterCatalogEntry {
  final int id;
  final String displayName;
  final String macAddress;
  final String? hardwareName;
  final bool active;
  final String? updatedAt;

  const ThermalPrinterCatalogEntry({
    required this.id,
    required this.displayName,
    required this.macAddress,
    required this.active,
    this.hardwareName,
    this.updatedAt,
  });

  factory ThermalPrinterCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ThermalPrinterCatalogEntry(
      id: _asInt(json['id']),
      displayName: (json['display_name'] ?? '').toString().trim(),
      macAddress: ThermalPrinterCatalogService.normalizeMac(
        (json['mac_address'] ?? '').toString(),
      ),
      hardwareName: _nullableString(json['hardware_name']),
      active: _asBool(json['active']),
      updatedAt: _nullableString(json['updated_at']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return const {
      '1',
      'true',
      'yes',
      'si',
    }.contains((value ?? '').toString().trim().toLowerCase());
  }

  static String? _nullableString(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }
}

class ThermalPrinterCatalogService {
  static const Duration _cacheTtl = Duration(minutes: 5);
  static List<ThermalPrinterCatalogEntry>? _cached;
  static DateTime? _cachedAt;

  static String get _base => '${AuthService.baseUrl}/thermal-printers';

  static String normalizeMac(String value) {
    final compact = value.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (compact.length != 12) return value.trim().toUpperCase();
    return List<String>.generate(
      6,
      (index) => compact.substring(index * 2, index * 2 + 2),
    ).join(':');
  }

  static bool isValidMac(String value) {
    return RegExp(
      r'^[0-9A-F]{2}(?::[0-9A-F]{2}){5}$',
    ).hasMatch(normalizeMac(value));
  }

  static Future<List<ThermalPrinterCatalogEntry>> index({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheTtl) {
      return _cached!;
    }

    final response = await http
        .get(Uri.parse(_base), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    final data = body['data'];
    final entries = data is List
        ? data
              .whereType<Map>()
              .map(
                (item) => ThermalPrinterCatalogEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : <ThermalPrinterCatalogEntry>[];
    _cached = entries;
    _cachedAt = now;
    return entries;
  }

  static Future<Map<String, ThermalPrinterCatalogEntry>> aliasesByMac() async {
    final entries = await index();
    return <String, ThermalPrinterCatalogEntry>{
      for (final entry in entries)
        if (entry.active) normalizeMac(entry.macAddress): entry,
    };
  }

  static Future<ThermalPrinterCatalogEntry> save({
    int? id,
    required String displayName,
    required String macAddress,
    String? hardwareName,
    required bool active,
  }) async {
    final uri = Uri.parse(id == null ? _base : '$_base/$id');
    final payload = jsonEncode(<String, dynamic>{
      'display_name': displayName.trim(),
      'mac_address': normalizeMac(macAddress),
      'hardware_name': _emptyToNull(hardwareName),
      'active': active,
    });
    final response = id == null
        ? await http
              .post(uri, headers: await _headers(json: true), body: payload)
              .timeout(const Duration(seconds: 15))
        : await http
              .put(uri, headers: await _headers(json: true), body: payload)
              .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    final data = body['data'];
    if (data is! Map) throw Exception('Respuesta inválida del servidor.');
    clearCache();
    return ThermalPrinterCatalogEntry.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> delete(int id) async {
    final response = await http
        .delete(Uri.parse('$_base/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _decode(response);
    clearCache();
  }

  static void clearCache() {
    _cached = null;
    _cachedAt = null;
  }

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  static Map<String, dynamic> _decode(http.Response response) {
    dynamic raw;
    try {
      raw = jsonDecode(response.body);
    } catch (_) {
      raw = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (raw is Map) {
        final errors = raw['errors'];
        if (errors is Map) {
          final messages = errors.values
              .whereType<List>()
              .where((values) => values.isNotEmpty)
              .map((values) => values.first.toString())
              .toList();
          if (messages.isNotEmpty) throw Exception(messages.join('\n'));
        }
        final message = (raw['message'] ?? '').toString().trim();
        if (message.isNotEmpty) throw Exception(message);
      }
      throw Exception('Error HTTP ${response.statusCode}.');
    }
    if (raw is! Map) throw Exception('Respuesta inválida del servidor.');
    return Map<String, dynamic>.from(raw);
  }

  static String? _emptyToNull(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  static String cleanError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }
}
