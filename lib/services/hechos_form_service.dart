import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/hechos/hechos_catalogos.dart';
import '../models/dictamen_item.dart';
import '../models/hecho_form_data.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';

class HechosFormService {
  static String parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final msg = (raw['message'] is String)
            ? (raw['message'] as String).trim()
            : '';
        if (msg.isNotEmpty) return msg;

        final errors = raw['errors'];
        if (errors is Map) {
          final sb = StringBuffer();
          errors.forEach((_, v) {
            if (v is List && v.isNotEmpty) sb.writeln('• ${v.first}');
          });
          final out = sb.toString().trim();
          if (out.isNotEmpty) return out;
        }
      }
    } catch (_) {}
    return 'Error HTTP $statusCode';
  }

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String horaStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String buildOficio(DictamenItem d) {
    final num = (d.numeroDictamen ?? '').trim();
    final anio = d.anio;
    final mp = (d.nombreMp ?? '').trim();

    final parts = <String>[];
    if (num.isNotEmpty && anio != null) {
      parts.add('$num/$anio');
    } else if (num.isNotEmpty) {
      parts.add(num);
    }
    if (mp.isNotEmpty) parts.add(mp);
    return parts.join(' ').trim();
  }

  static Future<OfflineActionResult> create({
    required HechoFormData data,
    required DictamenItem? dictamenSelected,
    File? fotoLugar,
    File? fotoSituacion,
  }) async {
    final clientUuid = _ensureClientUuid(data);
    final fields = _buildFields(data, dictamenSelected);
    fields['client_uuid'] = clientUuid;

    return OfflineSyncService.submitMultipart(
      label: 'Hecho',
      method: 'POST',
      uri: Uri.parse('${AuthService.baseUrl}/hechos'),
      fields: fields,
      files: <OfflineUploadFile>[
        if (fotoLugar != null)
          OfflineUploadFile(field: 'foto_lugar', path: fotoLugar.path),
        if (fotoSituacion != null)
          OfflineUploadFile(field: 'foto_situacion', path: fotoSituacion.path),
      ],
      requestId: clientUuid,
      successCodes: const <int>{200, 201},
      errorParser: parseBackendError,
    );
  }

  static Future<OfflineActionResult> update({
    required int hechoId,
    required HechoFormData data,
    required DictamenItem? dictamenSelected,
    File? fotoLugar,
    File? fotoSituacion,
  }) async {
    final fields = _buildFields(data, dictamenSelected);
    fields['_method'] = 'PUT';

    return OfflineSyncService.submitMultipart(
      label: 'Hecho',
      method: 'POST',
      uri: Uri.parse('${AuthService.baseUrl}/hechos/$hechoId'),
      fields: fields,
      files: <OfflineUploadFile>[
        if (fotoLugar != null)
          OfflineUploadFile(field: 'foto_lugar', path: fotoLugar.path),
        if (fotoSituacion != null)
          OfflineUploadFile(field: 'foto_situacion', path: fotoSituacion.path),
      ],
      successCodes: const <int>{200},
      errorParser: parseBackendError,
    );
  }

  static String _ensureClientUuid(HechoFormData data) {
    final current = data.clientUuid?.trim() ?? '';
    if (current.isNotEmpty) return current;

    final generated = OfflineSyncService.newClientUuid();
    data.clientUuid = generated;
    return generated;
  }

  static Map<String, String> _buildFields(HechoFormData d, DictamenItem? dict) {
    final fields = <String, String>{
      'folio_c5i': d.folioC5i.trim(),
      'perito': d.perito.trim(),
      'autorizacion_practico': d.autorizacionPractico.trim(),
      'unidad': d.unidad.trim(),
      'hora': horaStr(d.hora!),
      'fecha': ymd(d.fecha!),
      'sector': HechosCatalogos.normalizeSector(d.sector!),
      'calle': d.calle.trim(),
      'colonia': d.colonia.trim(),
      'entre_calles': d.entreCalles.trim(),
      'municipio': d.municipio.trim(),
      'tipo_hecho': d.tipoHecho ?? '',
      'superficie_via': HechosCatalogos.normalizeSuperficieVia(
        d.superficieVia!,
      ),
      'tiempo': HechosCatalogos.normalizeTiempo(d.tiempo!),
      'clima': HechosCatalogos.normalizeClima(d.clima!),
      'condiciones': HechosCatalogos.normalizeCondiciones(d.condiciones!),
      'control_transito': HechosCatalogos.normalizeControlTransito(
        d.controlTransito!,
      ),
      'checaron_antecedentes': d.checaronAntecedentes ? '1' : '0',
      'causas': HechosCatalogos.normalizeCausa(d.causa!),
      'colision_camino': HechosCatalogos.normalizeColisionCamino(
        d.colisionCamino!,
      ),
      'situacion': d.situacion ?? '',
      'vehiculos_mp': d.vehiculosMp.trim(),
      'personas_mp': d.personasMp.trim(),
      'danos_patrimoniales': d.danosPatrimoniales ? '1' : '0',
      'oficio_mp': '',
    };

    final unidadOrg = d.unidadOrgId.trim();
    if (unidadOrg.isNotEmpty) fields['unidad_org_id'] = unidadOrg;

    if (d.situacion == 'TURNADO' && dict != null) {
      fields['dictamen_id'] = dict.id.toString();
      fields['oficio_mp'] = buildOficio(dict);

      if ((dict.numeroDictamen ?? '').trim().isNotEmpty) {
        fields['dictamen_numero'] = dict.numeroDictamen!.trim();
      }
      if (dict.anio != null) fields['dictamen_anio'] = dict.anio.toString();

      if ((dict.nombrePolicia ?? '').trim().isNotEmpty) {
        fields['dictamen_nombre_policia'] = dict.nombrePolicia!.trim();
      }
      if ((dict.nombreMp ?? '').trim().isNotEmpty) {
        fields['dictamen_nombre_mp'] = dict.nombreMp!.trim();
      }
      if ((dict.area ?? '').trim().isNotEmpty) {
        fields['dictamen_area'] = dict.area!.trim();
      }
      if ((dict.archivoDictamen ?? '').trim().isNotEmpty) {
        fields['dictamen_archivo'] = dict.archivoDictamen!.trim();
      }
      if (dict.createdBy != null) {
        fields['dictamen_created_by'] = dict.createdBy.toString();
      }
      if (dict.updatedBy != null) {
        fields['dictamen_updated_by'] = dict.updatedBy.toString();
      }
    }

    if (d.danosPatrimoniales) {
      final props = d.propiedadesAfectadas.trim();
      final monto = d.montoDanos.trim();

      if (props.isNotEmpty) fields['propiedades_afectadas'] = props;
      if (monto.isNotEmpty) {
        fields['monto_danos_patrimoniales'] = monto.replaceAll(',', '');
      }
    }

    if (d.hasCoords) {
      fields['lat'] = d.lat!.toStringAsFixed(7);
      fields['lng'] = d.lng!.toStringAsFixed(7);

      if ((d.calidadGeo ?? '').trim().isNotEmpty) {
        fields['calidad_geo'] = d.calidadGeo!.trim();
      }
      if ((d.notaGeo ?? '').trim().isNotEmpty) {
        fields['nota_geo'] = d.notaGeo!.trim();
      }
      if ((d.fuenteUbicacion ?? '').trim().isNotEmpty) {
        fields['fuente_ubicacion'] = d.fuenteUbicacion!.trim();
      }
    }

    return fields;
  }
}
