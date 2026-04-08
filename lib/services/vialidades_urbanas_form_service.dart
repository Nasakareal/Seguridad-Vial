import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'offline_sync_service.dart';

class VialidadesUrbanasFormPayload {
  final int catalogoId;
  final DateTime fecha;
  final TimeOfDay hora;
  final String asunto;
  final String municipio;
  final String lugar;
  final String evento;
  final String objetivo;
  final String descripcion;
  final String narrativa;
  final String accionesRealizadas;
  final String observaciones;
  final String supervision;
  final int elementos;
  final int crp;
  final int motopatrullas;
  final int fenix;
  final int unidadesMotorizadas;
  final int patrullas;
  final int gruas;
  final int otrosApoyos;
  final List<File> fotos;

  const VialidadesUrbanasFormPayload({
    required this.catalogoId,
    required this.fecha,
    required this.hora,
    required this.asunto,
    required this.municipio,
    required this.lugar,
    required this.evento,
    required this.objetivo,
    required this.descripcion,
    required this.narrativa,
    required this.accionesRealizadas,
    required this.observaciones,
    required this.supervision,
    required this.elementos,
    required this.crp,
    required this.motopatrullas,
    required this.fenix,
    required this.unidadesMotorizadas,
    required this.patrullas,
    required this.gruas,
    required this.otrosApoyos,
    required this.fotos,
  });
}

class VialidadesUrbanasFormService {
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
    required VialidadesUrbanasFormPayload payload,
  }) async {
    if (payload.catalogoId <= 0) {
      return 'Selecciona un catalogo valido.';
    }

    if (payload.asunto.trim().isEmpty) {
      return 'El asunto es obligatorio.';
    }

    for (final foto in payload.fotos) {
      final ext = foto.path.split('.').last.toLowerCase();
      if (!const <String>{'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
        return 'Las fotos deben estar en formato JPG, JPEG, PNG o WEBP.';
      }

      final size = await foto.length();
      if (size > _maxImageBytes) {
        return 'Cada foto debe pesar maximo 5 MB.';
      }
    }

    return null;
  }

  static Future<OfflineActionResult> create({
    required VialidadesUrbanasFormPayload payload,
  }) async {
    final clientUuid = OfflineSyncService.newClientUuid();

    final body = <String, dynamic>{
      'client_uuid': clientUuid,
      'vialidad_dispositivo_catalogo_id': payload.catalogoId,
      'fecha': _fmtYmd(payload.fecha),
      'hora': _fmtHm(payload.hora),
      'asunto': payload.asunto.trim(),
      'elementos': payload.elementos,
      'crp': payload.crp,
      'motopatrullas': payload.motopatrullas,
      'fenix': payload.fenix,
      'unidades_motorizadas': payload.unidadesMotorizadas,
      'patrullas': payload.patrullas,
      'gruas': payload.gruas,
      'otros_apoyos': payload.otrosApoyos,
    };

    void addText(String key, String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        body[key] = trimmed;
      }
    }

    addText('municipio', payload.municipio);
    addText('lugar', payload.lugar);
    addText('evento', payload.evento);
    addText('objetivo', payload.objetivo);
    addText('descripcion', payload.descripcion);
    addText('narrativa', payload.narrativa);
    addText('acciones_realizadas', payload.accionesRealizadas);
    addText('observaciones', payload.observaciones);
    addText('supervision', payload.supervision);

    if (payload.fotos.isEmpty) {
      return OfflineSyncService.submitJson(
        label: 'Dispositivo Vialidades Urbanas',
        method: 'POST',
        uri: Uri.parse('${AuthService.baseUrl}/vialidades-urbanas'),
        body: body,
        requestId: clientUuid,
        successCodes: const <int>{200, 201},
        errorParser: parseBackendError,
      );
    }

    final fields = body.map(
      (key, value) => MapEntry(key, value == null ? '' : '$value'),
    );

    return OfflineSyncService.submitMultipart(
      label: 'Dispositivo Vialidades Urbanas',
      method: 'POST',
      uri: Uri.parse('${AuthService.baseUrl}/vialidades-urbanas'),
      fields: fields,
      files: <OfflineUploadFile>[
        for (final foto in payload.fotos)
          OfflineUploadFile(field: 'fotos[]', path: foto.path),
      ],
      requestId: clientUuid,
      successCodes: const <int>{200, 201},
      errorParser: parseBackendError,
    );
  }
}
