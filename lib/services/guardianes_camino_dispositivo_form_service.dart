import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/guardianes_camino/guardianes_camino_dispositivos_catalogos.dart';
import '../models/dispositivo_relacionados.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';
import 'photo_orientation_service.dart';

class GuardianesCaminoDispositivoFormPayload {
  final GuardianesCaminoCatalogoLocal catalogo;
  final DateTime fecha;
  final TimeOfDay hora;
  final TimeOfDay? horaInicio;
  final TimeOfDay? horaFin;
  final String tipoReporte;
  final String asunto;
  final String lugar;
  final String descripcion;
  final String carretera;
  final String tramo;
  final String kilometro;
  final String narrativa;
  final String accionesRealizadas;
  final String fraseInstitucional;
  final String nombreConductor;
  final String ocupacionConductor;
  final String acompanantesCantidad;
  final String vehiculoDescripcion;
  final String placasApoyado;
  final String procedencia;
  final String destino;
  final String motivoApoyo;
  final String cargoResponsable;
  final String nombreResponsable;
  final String observaciones;
  final bool requiereEvidencia;
  final double? lat;
  final double? lng;
  final Map<String, String> dynamicFields;
  final List<DispositivoVehiculoRelacionado> vehiculosRelacionados;
  final List<DispositivoPersonaRelacionada> personasRelacionadas;
  final List<File> fotos;

  const GuardianesCaminoDispositivoFormPayload({
    required this.catalogo,
    required this.fecha,
    required this.hora,
    required this.horaInicio,
    required this.horaFin,
    required this.tipoReporte,
    required this.asunto,
    required this.lugar,
    required this.descripcion,
    required this.carretera,
    required this.tramo,
    required this.kilometro,
    required this.narrativa,
    required this.accionesRealizadas,
    required this.fraseInstitucional,
    required this.nombreConductor,
    required this.ocupacionConductor,
    required this.acompanantesCantidad,
    required this.vehiculoDescripcion,
    required this.placasApoyado,
    required this.procedencia,
    required this.destino,
    required this.motivoApoyo,
    required this.cargoResponsable,
    required this.nombreResponsable,
    required this.observaciones,
    required this.requiereEvidencia,
    required this.lat,
    required this.lng,
    required this.dynamicFields,
    required this.vehiculosRelacionados,
    required this.personasRelacionadas,
    required this.fotos,
  });
}

class GuardianesCaminoDispositivoFormService {
  static const int _maxImageBytes = 5 * 1024 * 1024;

  static void _trace(String message) {
    debugPrint('[CARRETERAS_FORM] $message');
  }

  static String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _fmtHm(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String? _fmtYmdNullable(DateTime? d) {
    if (d == null) return null;
    return _fmtYmd(d);
  }

  static List<Map<String, dynamic>> _vehiculosRelacionadosJson(
    GuardianesCaminoDispositivoFormPayload payload, {
    bool includeClientUuid = false,
  }) {
    final out = <Map<String, dynamic>>[];

    for (var i = 0; i < payload.vehiculosRelacionados.length; i++) {
      final item = payload.vehiculosRelacionados[i];
      final vehiculo = item.vehiculo;

      final row = <String, dynamic>{
        'rol': item.rol,
        'observaciones': item.observaciones,
        'marca': vehiculo.marca,
        'modelo': vehiculo.modelo,
        'tipo_general': vehiculo.tipoGeneral,
        'tipo': vehiculo.tipo,
        'linea': vehiculo.linea,
        'color': vehiculo.color,
        'placas': vehiculo.placas,
        'estado_placas': vehiculo.estadoPlacas,
        'serie': vehiculo.serie,
        'capacidad_personas': vehiculo.capacidadPersonas,
        'tipo_servicio': vehiculo.tipoServicio,
        'tarjeta_circulacion_nombre': vehiculo.tarjetaCirculacionNombre,
        'grua': vehiculo.grua,
        'corralon': vehiculo.corralon,
        'aseguradora': vehiculo.aseguradora,
        'antecedente_vehiculo': vehiculo.antecedenteVehiculo ? 1 : 0,
        if (includeClientUuid)
          'client_uuid': OfflineSyncService.newClientUuid(),
      };

      row.removeWhere((_, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) return true;
        return false;
      });

      out.add(row);
    }

    return out;
  }

  static List<Map<String, dynamic>> _personasRelacionadasJson(
    GuardianesCaminoDispositivoFormPayload payload,
  ) {
    final out = <Map<String, dynamic>>[];

    for (var i = 0; i < payload.personasRelacionadas.length; i++) {
      final persona = payload.personasRelacionadas[i];

      final row = <String, dynamic>{
        'nombre': persona.nombre,
        'tipo_participacion': persona.tipoParticipacion,
        'curp': persona.curp,
        'telefono': persona.telefono,
        'domicilio': persona.domicilio,
        'sexo': persona.sexo,
        'ocupacion': persona.ocupacion,
        'edad': persona.edad,
        'tipo_licencia': persona.tipoLicencia,
        'estado_licencia': persona.estadoLicencia,
        'vigencia_licencia': _fmtYmdNullable(persona.vigenciaLicencia),
        'numero_licencia': persona.numeroLicencia,
        'permanente': persona.permanente ? 1 : 0,
        'cinturon': persona.cinturon ? 1 : 0,
        'antecedentes': persona.antecedentes ? 1 : 0,
        'certificado_lesiones': persona.certificadoLesiones ? 1 : 0,
        'certificado_alcoholemia': persona.certificadoAlcoholemia ? 1 : 0,
        'aliento_etilico': persona.alientoEtilico ? 1 : 0,
        'observaciones': persona.observaciones,
      };

      row.removeWhere((_, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) return true;
        return false;
      });

      out.add(row);
    }

    return out;
  }

  static Map<String, dynamic> _relacionadosBody(
    GuardianesCaminoDispositivoFormPayload payload,
    String clientUuid,
  ) {
    final body = <String, dynamic>{'client_uuid': clientUuid};
    final vehiculos = _vehiculosRelacionadosJson(
      payload,
      includeClientUuid: true,
    );
    if (vehiculos.isNotEmpty) {
      body['vehiculos_json'] = jsonEncode(vehiculos);
    }

    final personas = _personasRelacionadasJson(payload);
    if (personas.isNotEmpty) {
      body['personas_json'] = jsonEncode(personas);
    }

    return body;
  }

  static bool _hasRelacionados(Map<String, dynamic> body) {
    return (body['vehiculos_json'] ?? '').toString().trim().isNotEmpty ||
        (body['personas_json'] ?? '').toString().trim().isNotEmpty;
  }

  static Future<OfflineActionResult> _submitRelacionados({
    required GuardianesCaminoDispositivoFormPayload payload,
    required String clientUuid,
    required OfflineActionResult createResult,
  }) async {
    final body = _relacionadosBody(payload, clientUuid);
    if (!_hasRelacionados(body)) {
      return createResult;
    }

    final dispositivoId = _extractDispositivoId(createResult.responseBody);
    final uri = dispositivoId == null
        ? Uri.parse(
            '${AuthService.baseUrl}/guardianes-camino/dispositivos/relacionados',
          )
        : Uri.parse(
            '${AuthService.baseUrl}/guardianes-camino/dispositivos/$dispositivoId/relacionados',
          );

    if (createResult.queued) {
      try {
        _trace('relacionados queued dependency=$clientUuid');
        await OfflineSyncService.submitJson(
          label: 'Relacionados dispositivo Guardianes del Camino',
          method: 'POST',
          uri: Uri.parse(
            '${AuthService.baseUrl}/guardianes-camino/dispositivos/relacionados',
          ),
          body: body,
          requestId: '${clientUuid}_relacionados',
          dependsOnOperationId: clientUuid,
          successCodes: const <int>{200, 201},
          errorParser: parseBackendError,
          announceOnQueue: false,
        );
        return const OfflineActionResult.queued(
          message:
              'Guardado sin conexión. Los vehículos se sincronizarán después del dispositivo.',
        );
      } catch (e) {
        return OfflineActionResult.queued(
          message:
              'Guardado sin conexión. No se pudieron dejar listos los vehículos: ${_cleanException(e)}',
        );
      }
    }

    try {
      _trace(
        'relacionados send uri=$uri vehiculos=${payload.vehiculosRelacionados.length} personas=${payload.personasRelacionadas.length}',
      );
      final relacionadosResult = await OfflineSyncService.submitJson(
        label: 'Relacionados dispositivo Guardianes del Camino',
        method: 'POST',
        uri: uri,
        body: body,
        requestId: '${clientUuid}_relacionados',
        successCodes: const <int>{200, 201},
        errorParser: parseBackendError,
      );

      if (relacionadosResult.queued) {
        _trace('relacionados queued after create');
        return OfflineActionResult.synced(
          message:
              'Dispositivo capturado. Vehículos pendientes de sincronizar.',
          responseBody: createResult.responseBody,
        );
      }

      _trace('relacionados ok');
      return createResult;
    } catch (e) {
      _trace('relacionados error=${_cleanException(e)}');
      return OfflineActionResult.synced(
        message:
            'Dispositivo capturado. No se pudieron anexar los vehículos: ${_cleanException(e)}',
        responseBody: createResult.responseBody,
      );
    }
  }

  static String parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final msg = (raw['message'] ?? '').toString().trim();
        if (msg.isNotEmpty) return msg;

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
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static int? _extractDispositivoId(String? responseBody) {
    if (responseBody == null || responseBody.trim().isEmpty) return null;

    try {
      final raw = jsonDecode(responseBody);
      if (raw is! Map<String, dynamic>) return null;

      int? asInt(dynamic value) => int.tryParse('${value ?? ''}');
      final meta = raw['meta'];
      final data = raw['data'];

      if (meta is Map && asInt(meta['id']) != null) return asInt(meta['id']);
      if (data is Map && asInt(data['id']) != null) return asInt(data['id']);
    } catch (_) {}

    return null;
  }

  static String _cleanException(Object error) {
    final text = '$error'.trim();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length).trim();
    }
    return text;
  }

  static Future<String?> validateBeforeSubmit({
    required GuardianesCaminoDispositivoFormPayload payload,
  }) async {
    if (payload.catalogo.id <= 0) {
      return 'Selecciona un dispositivo válido.';
    }

    final placas = <String>{};
    final series = <String>{};
    for (final item in payload.vehiculosRelacionados) {
      final placa = (item.vehiculo.placas ?? '').trim().toUpperCase();
      if (placa.isNotEmpty && !placas.add(placa)) {
        return 'No repitas placas en los vehículos relacionados.';
      }

      final serie = (item.vehiculo.serie ?? '').trim().toUpperCase();
      if (serie.isNotEmpty && !series.add(serie)) {
        return 'No repitas números de serie en los vehículos relacionados.';
      }
    }

    for (final foto in payload.fotos) {
      final ext = foto.path.split('.').last.toLowerCase();
      if (!const <String>{'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
        return 'Las fotos deben estar en formato JPG, JPEG, PNG o WEBP.';
      }

      final size = await foto.length();
      if (size > _maxImageBytes) {
        return 'Cada foto debe pesar máximo 5 MB.';
      }
    }

    return null;
  }

  static Future<OfflineActionResult> create({
    required GuardianesCaminoDispositivoFormPayload payload,
  }) async {
    final clientUuid = OfflineSyncService.newClientUuid();
    _trace(
      'create start client=$clientUuid catalogo=${payload.catalogo.id} vehiculos=${payload.vehiculosRelacionados.length} personas=${payload.personasRelacionadas.length} fotos=${payload.fotos.length}',
    );

    int? asInt(dynamic value) => int.tryParse('${value ?? ''}');

    final fields = <String, String>{
      'client_uuid': clientUuid,
      'operativo_dispositivo_catalogo_id': payload.catalogo.id.toString(),
      'fecha': _fmtYmd(payload.fecha),
      'hora': _fmtHm(payload.hora),
      'requiere_evidencia': payload.requiereEvidencia ? '1' : '0',
      if (payload.horaInicio != null)
        'hora_inicio': _fmtHm(payload.horaInicio!),
      if (payload.horaFin != null) 'hora_fin': _fmtHm(payload.horaFin!),
      if (payload.tipoReporte.trim().isNotEmpty)
        'tipo_reporte': payload.tipoReporte.trim(),
      if (payload.asunto.trim().isNotEmpty) 'asunto': payload.asunto.trim(),
      if (payload.lugar.trim().isNotEmpty) 'lugar': payload.lugar.trim(),
      if (payload.descripcion.trim().isNotEmpty)
        'descripcion': payload.descripcion.trim(),
      if (payload.carretera.trim().isNotEmpty)
        'carretera': payload.carretera.trim(),
      if (payload.tramo.trim().isNotEmpty) 'tramo': payload.tramo.trim(),
      if (payload.kilometro.trim().isNotEmpty)
        'kilometro': payload.kilometro.trim(),
      if (payload.narrativa.trim().isNotEmpty)
        'narrativa': payload.narrativa.trim(),
      if (payload.accionesRealizadas.trim().isNotEmpty)
        'acciones_realizadas': payload.accionesRealizadas.trim(),
      if (payload.fraseInstitucional.trim().isNotEmpty)
        'frase_institucional': payload.fraseInstitucional.trim(),
      if (payload.nombreConductor.trim().isNotEmpty)
        'nombre_conductor': payload.nombreConductor.trim(),
      if (payload.ocupacionConductor.trim().isNotEmpty)
        'ocupacion_conductor': payload.ocupacionConductor.trim(),
      if (payload.vehiculoDescripcion.trim().isNotEmpty)
        'vehiculo_descripcion': payload.vehiculoDescripcion.trim(),
      if (payload.placasApoyado.trim().isNotEmpty)
        'placas_apoyado': payload.placasApoyado.trim(),
      if (payload.procedencia.trim().isNotEmpty)
        'procedencia': payload.procedencia.trim(),
      if (payload.destino.trim().isNotEmpty) 'destino': payload.destino.trim(),
      if (payload.motivoApoyo.trim().isNotEmpty)
        'motivo_apoyo': payload.motivoApoyo.trim(),
      if (payload.cargoResponsable.trim().isNotEmpty)
        'cargo_responsable': payload.cargoResponsable.trim(),
      if (payload.nombreResponsable.trim().isNotEmpty)
        'nombre_responsable': payload.nombreResponsable.trim(),
      if (payload.observaciones.trim().isNotEmpty)
        'observaciones': payload.observaciones.trim(),
      if (payload.lat != null) 'lat': payload.lat!.toString(),
      if (payload.lng != null) 'lng': payload.lng!.toString(),
      if (payload.lat != null && payload.lng != null)
        'coordenadas_texto':
            '${payload.lat!.toStringAsFixed(6)},${payload.lng!.toStringAsFixed(6)}',
    };

    final acompanantes = payload.acompanantesCantidad.trim();
    if (acompanantes.isNotEmpty) {
      fields['acompanantes_cantidad'] = acompanantes;
    }

    final hasFullOperationalAccess =
        await AuthService.hasFullOperationalAccess();
    var unidadId = hasFullOperationalAccess
        ? AuthService.unidadProteccionCarreterasId
        : await AuthService.getUnidadId();
    var delegacionId = await AuthService.getDelegacionId();
    var destacamentoId = await AuthService.getDestacamentoId();

    if (!hasFullOperationalAccess &&
        ((unidadId ?? 0) <= 0 ||
            ((delegacionId ?? 0) <= 0 && (destacamentoId ?? 0) <= 0))) {
      final me = await AuthService.getCurrentUserPayload(refresh: true);
      unidadId ??= await AuthService.getUnidadId();
      delegacionId ??= await AuthService.getDelegacionId();
      destacamentoId ??= await AuthService.getDestacamentoId();
      unidadId ??= asInt(
        me?['unidad_id'] ?? me?['unidad_org_id'] ?? me?['unidad'],
      );
      delegacionId ??= asInt(me?['delegacion_id'] ?? me?['delegacion']);
      destacamentoId ??= asInt(me?['destacamento_id'] ?? me?['destacamento']);
    }

    if ((unidadId ?? 0) <= 0) {
      throw Exception(
        'Tu sesión no tiene una unidad asignada. Conéctate una vez para actualizar tus datos.',
      );
    }

    if (!hasFullOperationalAccess &&
        (delegacionId ?? 0) <= 0 &&
        (destacamentoId ?? 0) <= 0) {
      throw Exception(
        'Tu sesión no tiene delegación ni destacamento guardados. Conéctate una vez para actualizar tus datos.',
      );
    }

    if ((unidadId ?? 0) > 0) fields['unidad_org_id'] = '$unidadId';
    if ((delegacionId ?? 0) > 0) fields['delegacion_id'] = '$delegacionId';
    if ((destacamentoId ?? 0) > 0) {
      fields['destacamento_id'] = '$destacamentoId';
    }

    for (final entry in payload.dynamicFields.entries) {
      final value = entry.value.trim();
      if (value.isNotEmpty) fields[entry.key] = value;
    }

    _trace('create dispositivo send fields=${fields.keys.join(',')}');
    final createResult = await OfflineSyncService.submitJson(
      label: 'Dispositivo Guardianes del Camino',
      method: 'POST',
      uri: Uri.parse('${AuthService.baseUrl}/guardianes-camino/dispositivos'),
      body: Map<String, dynamic>.from(fields),
      requestId: clientUuid,
      successCodes: const <int>{200, 201},
      errorParser: parseBackendError,
    );
    _trace(
      'create dispositivo result synced=${createResult.synced} queued=${createResult.queued} message=${createResult.message}',
    );

    final relatedResult = await _submitRelacionados(
      payload: payload,
      clientUuid: clientUuid,
      createResult: createResult,
    );

    if (payload.fotos.isEmpty) {
      _trace(
        'create done no fotos synced=${relatedResult.synced} queued=${relatedResult.queued}',
      );
      return relatedResult;
    }

    final fotos = await PhotoOrientationService.forceLandscapeAll(
      payload.fotos,
    );
    final photoFiles = <OfflineUploadFile>[
      for (final foto in fotos)
        OfflineUploadFile(field: 'fotos[]', path: foto.path),
    ];
    final photoFields = <String, String>{'client_uuid': clientUuid};
    final dispositivoId = _extractDispositivoId(relatedResult.responseBody);
    final photoUri = dispositivoId == null
        ? Uri.parse(
            '${AuthService.baseUrl}/guardianes-camino/dispositivos/fotos',
          )
        : Uri.parse(
            '${AuthService.baseUrl}/guardianes-camino/dispositivos/$dispositivoId/fotos',
          );

    if (relatedResult.queued) {
      try {
        _trace(
          'fotos queued dependency=$clientUuid count=${photoFiles.length}',
        );
        await OfflineSyncService.submitMultipart(
          label: 'Fotos dispositivo Guardianes del Camino',
          method: 'POST',
          uri: Uri.parse(
            '${AuthService.baseUrl}/guardianes-camino/dispositivos/fotos',
          ),
          fields: photoFields,
          files: photoFiles,
          requestId: '${clientUuid}_fotos',
          dependsOnOperationId: clientUuid,
          successCodes: const <int>{200, 201},
          errorParser: parseBackendError,
          announceOnQueue: false,
        );
        return const OfflineActionResult.queued(
          message:
              'Guardado sin conexión. Las fotos se sincronizarán después del dispositivo.',
        );
      } catch (e) {
        return OfflineActionResult.queued(
          message:
              'Guardado sin conexión. No se pudieron dejar listas las fotos: ${_cleanException(e)}',
        );
      }
    }

    try {
      _trace('fotos send uri=$photoUri count=${photoFiles.length}');
      final photosResult = await OfflineSyncService.submitMultipart(
        label: 'Fotos dispositivo Guardianes del Camino',
        method: 'POST',
        uri: photoUri,
        fields: photoFields,
        files: photoFiles,
        requestId: '${clientUuid}_fotos',
        successCodes: const <int>{200, 201},
        errorParser: parseBackendError,
      );

      if (photosResult.queued) {
        _trace('fotos queued after create');
        return OfflineActionResult.synced(
          message: 'Dispositivo capturado. Fotos pendientes de sincronizar.',
          responseBody: relatedResult.responseBody,
        );
      }

      _trace('fotos ok');
      return OfflineActionResult.synced(
        message: relatedResult.message,
        responseBody: relatedResult.responseBody,
      );
    } catch (e) {
      _trace('fotos error=${_cleanException(e)}');
      return OfflineActionResult.synced(
        message:
            'Dispositivo capturado. No se pudieron subir las fotos: ${_cleanException(e)}',
        responseBody: relatedResult.responseBody,
      );
    }
  }
}
