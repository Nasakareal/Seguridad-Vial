import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/hechos/hechos_catalogos.dart';
import '../models/dictamen_item.dart';
import '../models/hecho_form_data.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';

class HechosFormService {
  static const int _maxImageBytes = 5 * 1024 * 1024;

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

  static Future<String?> validateBeforeSubmit({
    required HechoFormData data,
    required DictamenItem? dictamenSelected,
    File? fotoLugar,
    File? fotoSituacion,
  }) async {
    if (data.hora == null || data.fecha == null) {
      return 'Completa la hora y la fecha.';
    }

    if ((data.sector ?? '').trim().isEmpty ||
        (data.tipoHecho ?? '').trim().isEmpty ||
        (data.superficieVia ?? '').trim().isEmpty ||
        (data.tiempo ?? '').trim().isEmpty ||
        (data.clima ?? '').trim().isEmpty ||
        (data.condiciones ?? '').trim().isEmpty ||
        (data.controlTransito ?? '').trim().isEmpty ||
        (data.causa ?? '').trim().isEmpty ||
        (data.colisionCamino ?? '').trim().isEmpty ||
        (data.situacion ?? '').trim().isEmpty) {
      return 'Completa todos los campos obligatorios.';
    }

    if (_trimmedLength(data.folioC5i) > 20) {
      return 'El Folio C5i no puede exceder 20 caracteres.';
    }
    if (_trimmedLength(data.perito) > 255) {
      return 'El nombre del perito no puede exceder 255 caracteres.';
    }
    if (_trimmedLength(data.autorizacionPractico) > 255) {
      return 'La autorización práctico no puede exceder 255 caracteres.';
    }
    if (_trimmedLength(data.unidad) > 50) {
      return 'La unidad no puede exceder 50 caracteres.';
    }
    if (_trimmedLength(data.calle) > 255) {
      return 'La calle no puede exceder 255 caracteres.';
    }
    if (_trimmedLength(data.colonia) > 255) {
      return 'La colonia no puede exceder 255 caracteres.';
    }
    if (_trimmedLength(data.entreCalles) > 255) {
      return 'Entre calles no puede exceder 255 caracteres.';
    }
    if (_trimmedLength(data.municipio) > 100) {
      return 'El municipio no puede exceder 100 caracteres.';
    }
    if (_trimmedLength(data.propiedadesAfectadas) > 2000) {
      return 'Propiedades afectadas no puede exceder 2000 caracteres.';
    }

    final situacion = (data.situacion ?? '').trim().toUpperCase();

    if (situacion == 'TURNADO' &&
        (data.dictamenId == null || dictamenSelected == null)) {
      return 'Selecciona el dictamen.';
    }

    if (situacion == 'RESUELTO' &&
        fotoSituacion == null &&
        !data.hasFotoSituacionActual) {
      return 'Para marcar el hecho como RESUELTO debes subir la foto de situación.';
    }

    final vehiculosMp = data.vehiculosMp.trim();
    if (situacion == 'TURNADO' && vehiculosMp.isEmpty) {
      return 'Indica cuántos vehículos se turnaron.';
    }
    if (vehiculosMp.isNotEmpty) {
      final parsed = int.tryParse(vehiculosMp);
      if (parsed == null) return 'En Vehículos MP solo se permiten números.';
      if (parsed < 0) return 'Vehículos MP no puede ser negativo.';
    }

    final personasMp = data.personasMp.trim();
    if (situacion == 'TURNADO' && personasMp.isEmpty) {
      return 'Indica cuántas personas se turnaron.';
    }
    if (personasMp.isNotEmpty) {
      final parsed = int.tryParse(personasMp);
      if (parsed == null) return 'En Personas MP solo se permiten números.';
      if (parsed < 0) return 'Personas MP no puede ser negativo.';
    }

    if (data.danosPatrimoniales) {
      final props = data.propiedadesAfectadas.trim();
      final monto = data.montoDanos.trim();

      if (props.isEmpty && monto.isEmpty) {
        return 'Si hay daños patrimoniales, captura el monto o describe las propiedades afectadas.';
      }

      if (monto.isNotEmpty) {
        final parsed = double.tryParse(monto.replaceAll(',', ''));
        if (parsed == null) {
          return 'En Monto daños patrimoniales solo se permiten números.';
        }
        if (parsed < 0) {
          return 'El monto no puede ser negativo.';
        }
      }
    }

    final hasLat = data.lat != null;
    final hasLng = data.lng != null;
    if (hasLat != hasLng) {
      return 'Si envías ubicación, debes enviar lat y lng.';
    }
    if (hasLat && (data.lat! < -90 || data.lat! > 90)) {
      return 'Latitud inválida.';
    }
    if (hasLng && (data.lng! < -180 || data.lng! > 180)) {
      return 'Longitud inválida.';
    }

    final fotoLugarError = await _validateImageFile(
      file: fotoLugar,
      label: 'La foto del lugar',
    );
    if (fotoLugarError != null) return fotoLugarError;

    final fotoSituacionError = await _validateImageFile(
      file: fotoSituacion,
      label: 'La foto de situación',
    );
    if (fotoSituacionError != null) return fotoSituacionError;

    return null;
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

  static int _trimmedLength(String value) => value.trim().length;

  static Future<String?> _validateImageFile({
    required File? file,
    required String label,
  }) async {
    if (file == null) return null;

    final ext = file.path.split('.').last.toLowerCase();
    const allowed = <String>{'jpg', 'jpeg', 'png', 'webp'};
    if (!allowed.contains(ext)) {
      return '$label debe estar en formato JPG, JPEG, PNG o WEBP.';
    }

    final size = await file.length();
    if (size > _maxImageBytes) {
      return '$label es muy pesada (máximo 5 MB).';
    }

    return null;
  }
}
