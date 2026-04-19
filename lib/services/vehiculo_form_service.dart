import 'dart:convert';

import '../core/vehiculos/estados_republica.dart';
import '../core/vehiculos/vehiculo_taxonomia.dart';
import 'offline_sync_service.dart';

class VehiculoQrData {
  final String rawText;
  final String? marca;
  final String? linea;
  final String? modelo;
  final String? color;
  final String? placas;
  final String? estadoPlacas;
  final String? serie;
  final String? tipoServicio;
  final String? tarjetaCirculacionNombre;
  final String? tipoGeneral;
  final String? tipoCarroceria;

  const VehiculoQrData({
    required this.rawText,
    this.marca,
    this.linea,
    this.modelo,
    this.color,
    this.placas,
    this.estadoPlacas,
    this.serie,
    this.tipoServicio,
    this.tarjetaCirculacionNombre,
    this.tipoGeneral,
    this.tipoCarroceria,
  });

  bool get hasAnyValue {
    return <String?>[
      marca,
      linea,
      modelo,
      color,
      placas,
      estadoPlacas,
      serie,
      tipoServicio,
      tarjetaCirculacionNombre,
      tipoGeneral,
      tipoCarroceria,
    ].any((value) => (value ?? '').trim().isNotEmpty);
  }
}

class VehiculoFormService {
  static VehiculoQrData parseTarjetaCirculacionQr(String raw) {
    final rawText = raw.trim();
    if (rawText.isEmpty) return const VehiculoQrData(rawText: '');

    final pairs = _extractQrPairs(rawText);

    final marca = _upper(
      _pickValue(pairs, const [
        'marca',
        'marca vehiculo',
        'marca del vehiculo',
        'brand',
      ]),
    );

    final modeloCandidate = _pickValue(pairs, const [
      'modelo',
      'modelo vehiculo',
      'mod',
    ]);
    final anioCandidate = _pickValue(pairs, const [
      'anio',
      'año',
      'ano',
      'ano modelo',
      'año modelo',
      'year',
    ]);

    final modelo = _modelYear(anioCandidate) ?? _modelYear(modeloCandidate);
    final lineaFromModelo = _lineaFromModeloField(modeloCandidate);

    final linea =
        _upper(
          _pickValue(pairs, const [
            'linea',
            'línea',
            'submarca',
            'version',
            'versión',
            'descripcion',
          ]),
        ) ??
        _upper(lineaFromModelo);

    final color = _upper(
      _pickValue(pairs, const [
        'color',
        'color vehiculo',
        'color del vehiculo',
      ]),
    );

    final placas = normalizePlacas(
      _pickValue(pairs, const [
            'placa',
            'placas',
            'placa vehiculo',
            'placas vehiculo',
            'matricula',
            'matrícula',
            'lamina',
            'lámina',
            'numero placa',
            'número placa',
          ]) ??
          _looseMatch(
            rawText,
            RegExp(
              r'(?:placas?|matr[ií]cula|l[aá]mina)\s*[:#\-]?\s*([A-Z0-9\-\s]{5,15})',
              caseSensitive: false,
            ),
          ) ??
          '',
    );

    final serie = normalizeSerie(
      _pickValue(pairs, const [
            'serie',
            'no serie',
            'número de serie',
            'numero de serie',
            'niv',
            'vin',
            'nvi',
            'num serie',
            'numero identificacion vehicular',
            'número identificación vehicular',
          ]) ??
          _looseMatch(
            rawText,
            RegExp(
              r'(?:niv|vin|serie)\s*[:#\-]?\s*([A-HJ-NPR-Z0-9]{6,17})',
              caseSensitive: false,
            ),
          ) ??
          '',
    );

    final estadoPlacas = EstadosRepublica.valueFromAny(
      _pickValue(pairs, const [
        'estado placas',
        'entidad placas',
        'entidad',
        'estado',
        'entidad federativa',
        'expedido en',
      ]),
    );

    final tipoServicio = _normalizeTipoServicio(
      _pickValue(pairs, const [
        'servicio',
        'tipo servicio',
        'tipo de servicio',
        'uso',
        'clase servicio',
      ]),
    );

    final propietario = _title(
      _pickValue(pairs, const [
        'propietario',
        'nombre propietario',
        'nombre del propietario',
        'nombre',
        'razon social',
        'razón social',
        'titular',
      ]),
    );

    final rawTipo = _pickValue(pairs, const [
      'tipo',
      'clase',
      'tipo vehiculo',
      'tipo de vehiculo',
      'clase vehiculo',
      'carroceria',
      'carrocería',
    ]);
    final tipoGeneral = _inferTipoGeneral(rawTipo, linea);
    final tipoCarroceria = _inferTipoCarroceria(rawTipo);
    final effectiveTipoGeneral =
        tipoGeneral ?? _inferTipoGeneral(tipoCarroceria, linea);

    return VehiculoQrData(
      rawText: rawText,
      marca: marca,
      linea: linea,
      modelo: modelo,
      color: color,
      placas: placas.isEmpty ? null : placas,
      estadoPlacas: estadoPlacas,
      serie: serie,
      tipoServicio: tipoServicio,
      tarjetaCirculacionNombre: propietario,
      tipoGeneral: effectiveTipoGeneral,
      tipoCarroceria: tipoCarroceria,
    );
  }

  static String normalizePlacas(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[\s\-\._,]'), '');
  }

  static String? normalizeSerie(String value) {
    final cleaned = value.trim().toUpperCase().replaceAll(
      RegExp(r'[\s\-\._,]'),
      '',
    );
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? normalizeEstadoPlacas(String? value) {
    final canonical = EstadosRepublica.valueFromAny(value);
    final source = canonical ?? value ?? '';
    final cleaned = source
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? validateRequiredText(
    String? value, {
    required int max,
    required String label,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Requerido';
    if (text.length > max) return '$label: máximo $max caracteres';
    return null;
  }

  static String? validateOptionalText(
    String? value, {
    required int max,
    required String label,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (text.length > max) return '$label: máximo $max caracteres';
    return null;
  }

  static String? validatePlacas(String? value) {
    final cleaned = normalizePlacas(value ?? '');
    if (cleaned.isEmpty) return null;
    if (cleaned.length > 15) return 'Placas inválidas: máximo 15 caracteres.';
    if (!RegExp(r'^[A-Z0-9]{5,15}$').hasMatch(cleaned)) {
      return 'Placas inválidas: solo letras y números, sin espacios ni guiones.';
    }
    return null;
  }

  static String? validateSerie(String? value) {
    final cleaned = normalizeSerie(value ?? '');
    if (cleaned == null) return null;
    if (cleaned.length > 17) {
      return 'El NIV/serie no debe superar 17 caracteres.';
    }
    if (!RegExp(r'^[A-Z0-9]{6,17}$').hasMatch(cleaned)) {
      return 'NIV/serie inválido: solo letras y números, sin espacios ni guiones.';
    }
    return null;
  }

  static String? validateCapacidad(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Requerido';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Debe ser número entero';
    if (parsed < 0) return 'No puede ser negativo';
    return null;
  }

  static String? validateMonto(String? value, {bool required = false}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return required ? 'Requerido' : null;
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Debe ser número';
    if (parsed < 0) return 'No puede ser negativo';
    return null;
  }

  static String? validateTelefono(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (!RegExp(r'^\d{10}$').hasMatch(text)) {
      return 'El teléfono debe tener 10 dígitos.';
    }
    return null;
  }

  static String? validateEdad(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null) return 'La edad debe ser número entero.';
    if (parsed < 0 || parsed > 100) return 'La edad debe estar entre 0 y 100.';
    return null;
  }

  static String? validateVehiculoBeforeSubmit({
    required String marca,
    required String linea,
    required String color,
    required String tipoServicio,
    required String partesDanadas,
    required String? tipoGeneral,
    required String? tipoCarroceria,
    required String placas,
    required String? estadoPlacas,
    required String serie,
    required String capacidad,
    required String montoDanos,
    required String modelo,
    required String tarjetaCirculacionNombre,
    required String aseguradora,
  }) {
    if ((tipoGeneral ?? '').trim().isEmpty) {
      return 'Selecciona el tipo de vehículo.';
    }
    if ((tipoCarroceria ?? '').trim().isEmpty) {
      return 'Selecciona la carrocería.';
    }

    final marcaError = validateRequiredText(marca, max: 50, label: 'Marca');
    if (marcaError != null) return marcaError;

    final lineaError = validateRequiredText(linea, max: 50, label: 'Línea');
    if (lineaError != null) return lineaError;

    final colorError = validateRequiredText(color, max: 30, label: 'Color');
    if (colorError != null) return colorError;

    final modeloError = validateOptionalText(modelo, max: 10, label: 'Modelo');
    if (modeloError != null) return modeloError;

    final placasError = validatePlacas(placas);
    if (placasError != null) return placasError;

    final placasClean = normalizePlacas(placas);
    final estadoClean = normalizeEstadoPlacas(estadoPlacas);
    if (placasClean.isNotEmpty) {
      if (estadoClean == null) {
        return 'Si capturas placas, también debes capturar el estado de placas.';
      }
      if (EstadosRepublica.valueFromAny(estadoClean) == null) {
        return 'Estado de placas inválido: selecciona una opción válida.';
      }
    }

    final serieError = validateSerie(serie);
    if (serieError != null) return serieError;

    final capacidadError = validateCapacidad(capacidad);
    if (capacidadError != null) return capacidadError;

    final tipoServicioError = validateRequiredText(
      tipoServicio,
      max: 50,
      label: 'Tipo de servicio',
    );
    if (tipoServicioError != null) return tipoServicioError;

    final tarjetaError = validateOptionalText(
      tarjetaCirculacionNombre,
      max: 60,
      label: 'Nombre en tarjeta de circulación',
    );
    if (tarjetaError != null) return tarjetaError;

    final aseguradoraError = validateOptionalText(
      aseguradora,
      max: 100,
      label: 'Aseguradora',
    );
    if (aseguradoraError != null) return aseguradoraError;

    final montoError = validateMonto(montoDanos, required: true);
    if (montoError != null) return montoError;

    if (partesDanadas.trim().isEmpty) {
      return 'Captura las partes dañadas.';
    }

    return null;
  }

  static String? validateConductorBeforeSubmit({
    required String nombre,
    required String telefono,
    required String domicilio,
    required String? sexo,
    required String ocupacion,
    required String edad,
    required String tipoLicencia,
    required String estadoLicencia,
    required String numeroLicencia,
  }) {
    final nombreError = validateRequiredText(
      nombre,
      max: 255,
      label: 'Nombre del conductor',
    );
    if (nombreError != null) return nombreError;

    final telefonoError = validateTelefono(telefono);
    if (telefonoError != null) return telefonoError;

    final domicilioError = validateOptionalText(
      domicilio,
      max: 255,
      label: 'Domicilio',
    );
    if (domicilioError != null) return domicilioError;

    final sexoClean = (sexo ?? '').trim().toUpperCase();
    if (sexoClean.isNotEmpty &&
        !const {'MASCULINO', 'FEMENINO', 'OTRO'}.contains(sexoClean)) {
      return 'Sexo inválido.';
    }

    final ocupacionError = validateOptionalText(
      ocupacion,
      max: 255,
      label: 'Ocupación',
    );
    if (ocupacionError != null) return ocupacionError;

    final edadError = validateEdad(edad);
    if (edadError != null) return edadError;

    final tipoLicenciaError = validateOptionalText(
      tipoLicencia,
      max: 50,
      label: 'Tipo de licencia',
    );
    if (tipoLicenciaError != null) return tipoLicenciaError;

    final estadoLicenciaError = validateOptionalText(
      estadoLicencia,
      max: 100,
      label: 'Estado de licencia',
    );
    if (estadoLicenciaError != null) return estadoLicenciaError;

    final numeroLicenciaError = validateOptionalText(
      numeroLicencia,
      max: 50,
      label: 'Número de licencia',
    );
    if (numeroLicenciaError != null) return numeroLicenciaError;

    return null;
  }

  static Future<String?> validateVehiculoDuplicatesWithinHecho({
    required int hechoId,
    required String? hechoClientUuid,
    required List<Map<String, dynamic>> existingVehiculos,
    int? currentVehiculoId,
    required String placas,
    required String serie,
  }) async {
    final placasNorm = normalizePlacas(placas);
    final serieNorm = normalizeSerie(serie) ?? '';

    for (final item in existingVehiculos) {
      final itemId = _asInt(item['id']);
      if (currentVehiculoId != null && itemId == currentVehiculoId) {
        continue;
      }

      final itemPlacas = normalizePlacas((item['placas'] ?? '').toString());
      if (placasNorm.isNotEmpty && itemPlacas == placasNorm) {
        return 'Ya existe un vehículo con estas placas en este hecho.';
      }

      final itemSerie = normalizeSerie((item['serie'] ?? '').toString()) ?? '';
      if (serieNorm.isNotEmpty && itemSerie == serieNorm) {
        return 'Ya existe un vehículo con este NIV/serie en este hecho.';
      }
    }

    final queue = await OfflineSyncService.loadQueueSnapshot();
    for (final op in queue) {
      if ((op['label'] ?? '').toString() != 'Vehículo') continue;
      if ((op['state'] ?? 'pending').toString() == 'failed') continue;

      final body = _jsonMap(op['body']);
      if (!_isSameHechoOperation(
        op: op,
        body: body,
        hechoId: hechoId,
        hechoClientUuid: hechoClientUuid,
      )) {
        continue;
      }

      final queuedVehiculoId = _vehiculoIdFromOperation(op, body: body);
      if (currentVehiculoId != null && queuedVehiculoId == currentVehiculoId) {
        continue;
      }

      final queuedPlacas = normalizePlacas((body['placas'] ?? '').toString());
      if (placasNorm.isNotEmpty && queuedPlacas == placasNorm) {
        return 'Ya hay un vehículo pendiente con estas placas dentro de este hecho.';
      }

      final queuedSerie =
          normalizeSerie((body['serie'] ?? '').toString()) ?? '';
      if (serieNorm.isNotEmpty && queuedSerie == serieNorm) {
        return 'Ya hay un vehículo pendiente con este NIV/serie dentro de este hecho.';
      }
    }

    return null;
  }

  static Future<String?> validateConductorDuplicatesWithinHecho({
    required int hechoId,
    required String? hechoClientUuid,
    required List<Map<String, dynamic>> existingVehiculos,
    required int currentVehiculoId,
    required String conductorNombre,
  }) async {
    final nombreNorm = _normalizeName(conductorNombre);
    if (nombreNorm.isEmpty) return null;

    for (final item in existingVehiculos) {
      final itemId = _asInt(item['id']);
      if (itemId == currentVehiculoId) continue;

      final existingName = _extractConductorName(item);
      if (existingName.isNotEmpty && existingName == nombreNorm) {
        return 'Este conductor ya está registrado en este hecho.';
      }
    }

    final queue = await OfflineSyncService.loadQueueSnapshot();
    for (final op in queue) {
      if ((op['label'] ?? '').toString() != 'Vehículo') continue;
      if ((op['state'] ?? 'pending').toString() == 'failed') continue;

      final body = _jsonMap(op['body']);
      if (!_isSameHechoOperation(
        op: op,
        body: body,
        hechoId: hechoId,
        hechoClientUuid: hechoClientUuid,
      )) {
        continue;
      }

      final queuedVehiculoId = _vehiculoIdFromOperation(op, body: body);
      if (queuedVehiculoId == currentVehiculoId) continue;

      final queuedName = _normalizeName(
        (body['conductor_nombre'] ?? '').toString(),
      );
      if (queuedName.isNotEmpty && queuedName == nombreNorm) {
        return 'Ya hay un conductor pendiente con ese nombre dentro de este hecho.';
      }
    }

    return null;
  }

  static bool _isSameHechoOperation({
    required Map<String, dynamic> op,
    required Map<String, dynamic> body,
    required int hechoId,
    required String? hechoClientUuid,
  }) {
    final clientUuid = (hechoClientUuid ?? '').trim();
    final bodyHechoId = _asInt(body['hecho_id']);
    if (hechoId > 0 && bodyHechoId == hechoId) return true;

    final bodyHechoClientUuid = (body['hecho_client_uuid'] ?? '')
        .toString()
        .trim();
    if (clientUuid.isNotEmpty && bodyHechoClientUuid == clientUuid) return true;

    final dependsOn = (op['depends_on_operation_id'] ?? '').toString().trim();
    if (clientUuid.isNotEmpty && dependsOn == clientUuid) return true;

    final url = (op['url'] ?? '').toString();
    if (hechoId > 0 && url.contains('/hechos/$hechoId/vehiculos')) return true;

    return false;
  }

  static int? _vehiculoIdFromOperation(
    Map<String, dynamic> op, {
    required Map<String, dynamic> body,
  }) {
    final bodyId = _asInt(body['vehiculo_id']);
    if (bodyId > 0) return bodyId;

    final url = (op['url'] ?? '').toString();
    final match = RegExp(r'/vehiculos/(\d+)(?:/|$)').firstMatch(url);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static Map<String, dynamic> _jsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static String _extractConductorName(Map<String, dynamic> vehiculo) {
    final conductores = vehiculo['conductores'];
    if (conductores is List &&
        conductores.isNotEmpty &&
        conductores.first is Map) {
      final first = Map<String, dynamic>.from(conductores.first as Map);
      return _normalizeName((first['nombre'] ?? '').toString());
    }

    return _normalizeName((vehiculo['conductor_nombre'] ?? '').toString());
  }

  static String _normalizeName(String value) {
    final cleaned = value
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }

  static Map<String, String> _extractQrPairs(String raw) {
    final pairs = <String, String>{};
    final jsonPairs = _tryExtractJsonPairs(raw);
    pairs.addAll(jsonPairs);

    final text = raw.replaceAll('\r', '\n');
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      _putLooseLinePair(pairs, line);

      final label = _labelOnlyKey(line);
      if (label == null) continue;

      final nextValue = _nextLineValue(lines, index);
      if (nextValue == null) continue;
      _putPair(pairs, label, nextValue);
    }

    final segments = text.split(RegExp(r'[\n|;]+'));
    for (final segment in segments) {
      final item = segment.trim();
      if (item.isEmpty) continue;

      final match = RegExp(
        r'^([^:=#]{2,50})\s*[:=#]\s*(.+)$',
        dotAll: true,
      ).firstMatch(item);
      if (match == null) continue;

      _putPair(pairs, match.group(1), match.group(2));
    }

    final inlineMatches = RegExp(
      r'([A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 _\-/\.]{2,50})\s*[:=#]\s*([^|;\n\r]+)',
      multiLine: true,
    ).allMatches(text);
    for (final match in inlineMatches) {
      _putPair(pairs, match.group(1), match.group(2));
    }

    return pairs;
  }

  static void _putLooseLinePair(Map<String, String> pairs, String line) {
    if (RegExp(r'[:=#]').hasMatch(line)) return;

    final parts = line
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.length < 2) return;

    final maxKeyParts = parts.length - 1 < 4 ? parts.length - 1 : 4;
    for (var count = maxKeyParts; count >= 1; count -= 1) {
      final keyCandidate = parts.take(count).join(' ');
      final key = _normalizeQrKey(keyCandidate);
      if (!_knownQrKeys.contains(key)) continue;

      final value = parts.skip(count).join(' ');
      _putPair(pairs, keyCandidate, value);
      return;
    }
  }

  static String? _labelOnlyKey(String line) {
    final cleaned = line.trim().replaceFirst(RegExp(r'[:=#]\s*$'), '').trim();
    if (cleaned.isEmpty || RegExp(r'[:=#]').hasMatch(cleaned)) return null;
    final key = _normalizeQrKey(cleaned);
    return _knownQrKeys.contains(key) ? cleaned : null;
  }

  static String? _nextLineValue(List<String> lines, int currentIndex) {
    final nextIndex = currentIndex + 1;
    if (nextIndex >= lines.length) return null;

    final next = lines[nextIndex].trim();
    if (next.isEmpty) return null;
    if (_labelOnlyKey(next) != null) return null;
    if (RegExp(r'^[^:=#]{2,50}\s*[:=#]').hasMatch(next)) return null;
    return next;
  }

  static Map<String, String> _tryExtractJsonPairs(String raw) {
    try {
      final decoded = _jsonDecode(raw);
      final pairs = <String, String>{};
      void walk(dynamic value, [String prefix = '']) {
        if (value is Map) {
          for (final entry in value.entries) {
            final key = prefix.isEmpty
                ? entry.key.toString()
                : '$prefix ${entry.key}';
            walk(entry.value, key);
          }
          return;
        }
        if (value is List) {
          for (var i = 0; i < value.length; i += 1) {
            walk(value[i], prefix);
          }
          return;
        }
        _putPair(pairs, prefix, value?.toString());
      }

      walk(decoded);
      return pairs;
    } catch (_) {
      return const <String, String>{};
    }
  }

  static dynamic _jsonDecode(String raw) {
    return jsonDecode(raw);
  }

  static void _putPair(Map<String, String> pairs, String? key, String? value) {
    final cleanKey = _normalizeQrKey(key ?? '');
    final cleanValue = _cleanQrValue(value ?? '');
    if (cleanKey.isEmpty || cleanValue.isEmpty) return;
    pairs.putIfAbsent(cleanKey, () => cleanValue);
  }

  static String? _pickValue(Map<String, String> pairs, List<String> aliases) {
    final normalizedAliases = aliases.map(_normalizeQrKey).toList();
    for (final alias in normalizedAliases) {
      final exact = pairs[alias];
      if ((exact ?? '').trim().isNotEmpty) return exact;
    }

    for (final entry in pairs.entries) {
      for (final alias in normalizedAliases) {
        if (entry.key == alias ||
            entry.key.endsWith(alias) ||
            entry.key.contains(alias)) {
          return entry.value;
        }
      }
    }

    return null;
  }

  static String _normalizeQrKey(String value) {
    return _removeAccents(
      value,
    ).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  }

  static String _cleanQrValue(String value) {
    var cleaned = value
        .trim()
        .replaceAll(RegExp(r'^\s*["“”]+|["“”]+\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'^[\-:=>#\s]+'), '').trim();
    return cleaned;
  }

  static String? _looseMatch(String raw, RegExp regex) {
    final match = regex.firstMatch(raw);
    return _cleanQrValue(match?.group(1) ?? '');
  }

  static String? _upper(String? value) {
    final cleaned = _cleanQrValue(value ?? '');
    if (cleaned.isEmpty) return null;
    return _removeAccents(cleaned).toUpperCase();
  }

  static String? _title(String? value) {
    final cleaned = _cleanQrValue(value ?? '');
    if (cleaned.isEmpty) return null;
    final parts = cleaned
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty);
    return parts
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          final lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  static String? _modelYear(String? value) {
    final cleaned = _cleanQrValue(value ?? '');
    if (cleaned.isEmpty) return null;
    final match = RegExp(r'(19|20)\d{2}').firstMatch(cleaned);
    return match?.group(0);
  }

  static String? _lineaFromModeloField(String? value) {
    var cleaned = _cleanQrValue(value ?? '');
    if (cleaned.isEmpty) return null;

    final year = _modelYear(cleaned);
    if (year != null) {
      cleaned = cleaned
          .replaceFirst(year, '')
          .replaceAll(RegExp(r'[\-_/|,;]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    if (cleaned.isEmpty) return null;
    if (RegExp(r'^(19|20)\d{2}$').hasMatch(cleaned)) return null;
    return cleaned;
  }

  static String? _normalizeTipoServicio(String? value) {
    final normalized = _upper(value);
    if (normalized == null) return null;
    if (normalized.contains('PUBLIC')) return 'PÚBLICO';
    if (normalized.contains('PARTICULAR') || normalized.contains('PRIVAD')) {
      return 'PARTICULAR';
    }
    if (normalized.contains('OFICIAL') || normalized.contains('GOBIERNO')) {
      return 'OFICIAL';
    }
    return normalized;
  }

  static String? _inferTipoGeneral(String? rawTipo, String? linea) {
    final source = _removeAccents(
      '${rawTipo ?? ''} ${linea ?? ''}',
    ).toUpperCase();
    if (source.trim().isEmpty) return null;

    if (source.contains('MOTO')) return 'motocicleta';
    if (source.contains('BICI')) return 'bicicleta';
    if (source.contains('REMOLQUE') || source.contains('DOLLY')) {
      return 'remolque';
    }
    if (source.contains('TRACTO') ||
        source.contains('TORTON') ||
        source.contains('RABON') ||
        source.contains('CAMION')) {
      return 'camion';
    }
    if (source.contains('PICK') ||
        source.contains('CAMIONETA') ||
        source.contains('VAGONETA') ||
        source.contains('SUV') ||
        source.contains('VAN')) {
      return 'camioneta';
    }
    if (source.contains('SEDAN') ||
        source.contains('HATCH') ||
        source.contains('COUPE') ||
        source.contains('AUTOMOVIL') ||
        source.contains('AUTO')) {
      return 'automovil';
    }
    if (source.contains('TRACTOR') ||
        source.contains('EXCAV') ||
        source.contains('CARGADOR') ||
        source.contains('MAQUIN')) {
      return 'maquinaria';
    }
    return null;
  }

  static String? _inferTipoCarroceria(String? rawTipo) {
    final cleaned = _cleanQrValue(rawTipo ?? '');
    if (cleaned.isEmpty) return null;

    final normalized = _removeAccents(cleaned).toUpperCase();
    for (final options in VehiculoTaxonomia.carrocerias.values) {
      for (final option in options) {
        final optionNormalized = _removeAccents(option).toUpperCase();
        if (normalized == optionNormalized ||
            normalized.contains(optionNormalized) ||
            optionNormalized.contains(normalized)) {
          return option;
        }
      }
    }

    final guessed = VehiculoTaxonomia.normalizeCarroceria(cleaned);
    for (final options in VehiculoTaxonomia.carrocerias.values) {
      if (options.contains(guessed)) return guessed;
    }

    return null;
  }

  static String _removeAccents(String value) {
    return value
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
  }

  static final Set<String> _knownQrKeys = _knownQrAliases
      .map(_normalizeQrKey)
      .toSet();

  static const List<String> _knownQrAliases = [
    'marca',
    'marca vehiculo',
    'marca del vehiculo',
    'brand',
    'modelo',
    'modelo vehiculo',
    'mod',
    'anio',
    'año',
    'ano',
    'ano modelo',
    'año modelo',
    'year',
    'linea',
    'línea',
    'submarca',
    'version',
    'versión',
    'descripcion',
    'color',
    'color vehiculo',
    'color del vehiculo',
    'placa',
    'placas',
    'placa vehiculo',
    'placas vehiculo',
    'matricula',
    'matrícula',
    'lamina',
    'lámina',
    'numero placa',
    'número placa',
    'serie',
    'no serie',
    'número de serie',
    'numero de serie',
    'niv',
    'vin',
    'nvi',
    'num serie',
    'numero identificacion vehicular',
    'número identificación vehicular',
    'motor',
    'estado placas',
    'entidad placas',
    'entidad',
    'estado',
    'entidad federativa',
    'expedido en',
    'servicio',
    'tipo servicio',
    'tipo de servicio',
    'uso',
    'clase servicio',
    'propietario',
    'nombre propietario',
    'nombre del propietario',
    'nombre',
    'razon social',
    'razón social',
    'titular',
    'curp',
    'tipo',
    'clase',
    'tipo vehiculo',
    'tipo de vehiculo',
    'clase vehiculo',
    'carroceria',
    'carrocería',
  ];
}
