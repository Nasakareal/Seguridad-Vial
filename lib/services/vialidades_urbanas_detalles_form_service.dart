import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'offline_sync_service.dart';
import 'photo_orientation_service.dart';

class VialidadesUrbanasDetalleInput {
  final String tipo;
  final String titulo;
  final String contenido;
  final String ubicacion;
  final TimeOfDay? hora;

  const VialidadesUrbanasDetalleInput({
    required this.tipo,
    required this.titulo,
    required this.contenido,
    required this.ubicacion,
    required this.hora,
  });
}

class VialidadesUrbanasDetallesFormPayload {
  final int dispositivoId;
  final List<VialidadesUrbanasDetalleInput> detalles;
  final List<File> fotosNuevas;
  final List<int> eliminarFotoIds;
  final int? fotoPortadaId;

  const VialidadesUrbanasDetallesFormPayload({
    required this.dispositivoId,
    required this.detalles,
    required this.fotosNuevas,
    this.eliminarFotoIds = const <int>[],
    this.fotoPortadaId,
  });
}

class VialidadesUrbanasDetallesFormService {
  static const int _referenceId = 1;
  static const int _maxImageBytes = 5 * 1024 * 1024;

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

  static String _fmtHm(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _base(int dispositivoId) =>
      '${AuthService.baseUrl}/vialidades-urbanas/$_referenceId/dispositivos/$dispositivoId';

  static List<VialidadesUrbanasDetalleInput> _normalizedDetalles(
    List<VialidadesUrbanasDetalleInput> detalles,
  ) {
    return detalles.where((detalle) {
      return detalle.contenido.trim().isNotEmpty;
    }).toList();
  }

  static Future<String?> validateBeforeSubmit({
    required VialidadesUrbanasDetallesFormPayload payload,
  }) async {
    if (payload.dispositivoId <= 0) {
      return 'No se identifico el dispositivo padre.';
    }

    final detalles = _normalizedDetalles(payload.detalles);
    if (detalles.isEmpty) {
      return 'Agrega al menos un detalle con contenido.';
    }

    for (final foto in payload.fotosNuevas) {
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

  static Map<String, String> _buildFields(
    VialidadesUrbanasDetallesFormPayload payload, {
    bool isUpdate = false,
  }) {
    final fields = <String, String>{};
    final detalles = _normalizedDetalles(payload.detalles);

    if (isUpdate) {
      fields['_method'] = 'PUT';
    }

    for (var i = 0; i < detalles.length; i += 1) {
      final detalle = detalles[i];
      fields['detalles[$i][tipo]'] = detalle.tipo.trim().isEmpty
          ? 'texto'
          : detalle.tipo.trim();
      if (detalle.titulo.trim().isNotEmpty) {
        fields['detalles[$i][titulo]'] = detalle.titulo.trim();
      }
      fields['detalles[$i][contenido]'] = detalle.contenido.trim();
      if (detalle.ubicacion.trim().isNotEmpty) {
        fields['detalles[$i][ubicacion]'] = detalle.ubicacion.trim();
      }
      if (detalle.hora != null) {
        fields['detalles[$i][hora]'] = _fmtHm(detalle.hora!);
      }
    }

    if (isUpdate) {
      for (var i = 0; i < payload.eliminarFotoIds.length; i += 1) {
        fields['eliminar_fotos[$i]'] = '${payload.eliminarFotoIds[i]}';
      }

      if ((payload.fotoPortadaId ?? 0) > 0) {
        fields['foto_portada_id'] = '${payload.fotoPortadaId}';
      }
    }

    return fields;
  }

  static Future<OfflineActionResult> create({
    required VialidadesUrbanasDetallesFormPayload payload,
  }) async {
    final requestId = OfflineSyncService.newClientUuid();
    final fotosNuevas = await PhotoOrientationService.forceLandscapeAll(
      payload.fotosNuevas,
    );

    return OfflineSyncService.submitMultipart(
      label: 'Detalle Vialidades Urbanas',
      method: 'POST',
      uri: Uri.parse(_base(payload.dispositivoId)),
      fields: _buildFields(payload),
      files: <OfflineUploadFile>[
        for (final foto in fotosNuevas)
          OfflineUploadFile(field: 'fotos[]', path: foto.path),
      ],
      requestId: requestId,
      successCodes: const <int>{200, 201},
      errorParser: parseBackendError,
    );
  }

  static Future<OfflineActionResult> update({
    required VialidadesUrbanasDetallesFormPayload payload,
  }) async {
    final fotosNuevas = await PhotoOrientationService.forceLandscapeAll(
      payload.fotosNuevas,
    );

    return OfflineSyncService.submitMultipart(
      label: 'Detalle Vialidades Urbanas',
      method: 'POST',
      uri: Uri.parse(_base(payload.dispositivoId)),
      fields: _buildFields(payload, isUpdate: true),
      files: <OfflineUploadFile>[
        for (final foto in fotosNuevas)
          OfflineUploadFile(field: 'fotos[]', path: foto.path),
      ],
      successCodes: const <int>{200},
      errorParser: parseBackendError,
    );
  }
}
