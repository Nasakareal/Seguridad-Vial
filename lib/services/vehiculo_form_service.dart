import 'offline_sync_service.dart';

class VehiculoFormService {
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
    final cleaned = (value ?? '').trim().toUpperCase();
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
      if (estadoClean.length > 15) {
        return 'Estado de placas inválido: máximo 15 caracteres.';
      }
      if (!RegExp(r'^[A-Z]{3,15}$').hasMatch(estadoClean)) {
        return 'Estado de placas inválido: escribe solo letras.';
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
}
