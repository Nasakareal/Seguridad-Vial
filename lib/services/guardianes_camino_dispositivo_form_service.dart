import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/guardianes_camino/guardianes_camino_dispositivos_catalogos.dart';
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
    required this.fotos,
  });
}

class GuardianesCaminoDispositivoFormService {
  static const int _maxImageBytes = 5 * 1024 * 1024;

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

  static Future<String?> validateBeforeSubmit({
    required GuardianesCaminoDispositivoFormPayload payload,
  }) async {
    if (payload.catalogo.id <= 0) {
      return 'Selecciona un dispositivo válido.';
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

    final fotos = payload.fotos.isEmpty
        ? const <File>[]
        : await PhotoOrientationService.forceLandscapeAll(payload.fotos);

    if (fotos.isEmpty) {
      return OfflineSyncService.submitJson(
        label: 'Dispositivo Guardianes del Camino',
        method: 'POST',
        uri: Uri.parse('${AuthService.baseUrl}/guardianes-camino/dispositivos'),
        body: Map<String, dynamic>.from(fields),
        requestId: clientUuid,
        successCodes: const <int>{200, 201},
        errorParser: parseBackendError,
      );
    }

    return OfflineSyncService.submitMultipart(
      label: 'Dispositivo Guardianes del Camino',
      method: 'POST',
      uri: Uri.parse('${AuthService.baseUrl}/guardianes-camino/dispositivos'),
      fields: fields,
      files: <OfflineUploadFile>[
        for (final foto in fotos)
          OfflineUploadFile(field: 'fotos[]', path: foto.path),
      ],
      requestId: clientUuid,
      successCodes: const <int>{200, 201},
      errorParser: parseBackendError,
    );
  }
}
