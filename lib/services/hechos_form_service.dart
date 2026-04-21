import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/hechos/hechos_catalogos.dart';
import '../models/dictamen_item.dart';
import '../models/hecho_form_data.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';
import 'photo_orientation_service.dart';

class HechosFormService {
  static const int _maxImageBytes = 5 * 1024 * 1024;

  static String parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final errors = raw['errors'];
        if (errors is Map) {
          final sb = StringBuffer();
          errors.forEach((_, v) {
            if (v is List && v.isNotEmpty) sb.writeln('• ${v.first}');
          });
          final out = sb.toString().trim();
          if (out.isNotEmpty) return out;
        }

        final msg = (raw['message'] is String)
            ? (raw['message'] as String).trim()
            : '';
        final friendlyMsg = _friendlyKnownBackendMessage(msg);
        if (friendlyMsg.isNotEmpty) return friendlyMsg;
      }
    } catch (_) {}

    final rawFriendly = _friendlyKnownBackendMessage(body);
    if (rawFriendly.isNotEmpty) return rawFriendly;

    return 'Error HTTP $statusCode';
  }

  static int? hechoIdFromCreateResult(OfflineActionResult result) {
    final body = result.responseBody?.trim() ?? '';
    if (body.isEmpty) return null;

    try {
      final raw = jsonDecode(body);
      if (raw is! Map<String, dynamic>) return null;

      int? readId(dynamic value) {
        if (value == null) return null;
        if (value is int && value > 0) return value;
        if (value is num && value > 0) return value.toInt();
        final parsed = int.tryParse(value.toString());
        return parsed != null && parsed > 0 ? parsed : null;
      }

      int? fromMap(Map map) {
        for (final key in const ['id', 'hecho_id']) {
          final id = readId(map[key]);
          if (id != null) return id;
        }
        return null;
      }

      final direct = fromMap(raw);
      if (direct != null) return direct;

      for (final key in const ['hecho', 'data']) {
        final nested = raw[key];
        if (nested is Map) {
          final id = fromMap(nested);
          if (id != null) return id;
        }
      }
    } catch (_) {}

    return null;
  }

  static String cleanExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Ocurrió un error inesperado.';
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String horaStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay currentTime() {
    final now = DateTime.now();
    return TimeOfDay(hour: now.hour, minute: now.minute);
  }

  static String normalizeMunicipio(String value) {
    final cleaned = _collapseSpaces(value);
    if (cleaned.isEmpty) return '';

    final key = _normalizeKey(cleaned);
    if (key.isEmpty) return cleaned;

    const aliasesMorelia = <String>{
      'MORELIA',
      'MODELIA',
      'MOELIA',
      'MOLELIA',
      'MOLERIA',
      'MORELAI',
      'MOREILA',
      'MORELILA',
    };

    final looksLikeMorelia =
        aliasesMorelia.contains(key) ||
        (key.length >= 6 &&
            key.length <= 8 &&
            _levenshtein(key, 'MORELIA') <= 2);

    if (looksLikeMorelia) {
      return 'Morelia';
    }

    return _toTitleCase(cleaned);
  }

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
    final usesRelaxedHechosRules =
        await AuthService.isHechosCaptureRelaxedUser();

    if (data.hora == null || data.fecha == null) {
      return 'Completa la hora y la fecha.';
    }

    if ((!usesRelaxedHechosRules && (data.sector ?? '').trim().isEmpty) ||
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

    if (!usesRelaxedHechosRules && data.folioC5i.trim().isEmpty) {
      return 'Captura el Folio C5i.';
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
      return 'El lugar no puede exceder 255 caracteres.';
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
    if (data.responsable.trim().isEmpty) {
      return 'Captura quién es responsable.';
    }
    if (_trimmedLength(data.responsable) > 255) {
      return 'El responsable no puede exceder 255 caracteres.';
    }

    if (await AuthService.isDelegacionesUser()) {
      final totalsError = _validateExpectedCaptureTotals(data);
      if (totalsError != null) return totalsError;
    }

    final situacion = (data.situacion ?? '').trim().toUpperCase();

    if (situacion == 'TURNADO' &&
        (data.dictamenId == null || dictamenSelected == null)) {
      return 'Selecciona el dictamen.';
    }

    if (!usesRelaxedHechosRules &&
        {'RESUELTO', 'TURNADO'}.contains(situacion) &&
        fotoSituacion == null &&
        !data.hasFotoSituacionActual) {
      return 'Para marcar el hecho como RESUELTO o TURNADO debes subir la foto de situación.';
    }

    final vehiculosMp = data.vehiculosMp.trim();
    if (situacion == 'TURNADO' && vehiculosMp.isEmpty) {
      return 'Indica cuántos vehículos se turnaron.';
    }
    if (vehiculosMp.isNotEmpty) {
      final parsed = int.tryParse(vehiculosMp);
      if (parsed == null) return 'En Vehículos MP solo se permiten números.';
      if (parsed < 0) return 'Vehículos MP no puede ser negativo.';
      if (situacion == 'TURNADO' && parsed < 1) {
        return 'Cuando el hecho está TURNADO, Vehículos MP debe ser mayor que cero.';
      }
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
    final usesRelaxedHechosRules =
        await AuthService.isHechosCaptureRelaxedUser();
    final fields = _buildFields(
      data,
      dictamenSelected,
      usesRelaxedHechosRules: usesRelaxedHechosRules,
    );
    fields['client_uuid'] = clientUuid;
    final landscapeFotoLugar = fotoLugar == null
        ? null
        : await PhotoOrientationService.forceLandscape(fotoLugar);

    return OfflineSyncService.submitMultipart(
      label: 'Hecho',
      method: 'POST',
      uri: Uri.parse('${AuthService.baseUrl}/hechos'),
      fields: fields,
      files: <OfflineUploadFile>[
        if (landscapeFotoLugar != null)
          OfflineUploadFile(field: 'foto_lugar', path: landscapeFotoLugar.path),
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
    final usesRelaxedHechosRules =
        await AuthService.isHechosCaptureRelaxedUser();
    final fields = _buildFields(
      data,
      dictamenSelected,
      usesRelaxedHechosRules: usesRelaxedHechosRules,
    );
    fields['_method'] = 'PUT';
    final landscapeFotoLugar = fotoLugar == null
        ? null
        : await PhotoOrientationService.forceLandscape(fotoLugar);

    return OfflineSyncService.submitMultipart(
      label: 'Hecho',
      method: 'POST',
      uri: Uri.parse('${AuthService.baseUrl}/hechos/$hechoId'),
      fields: fields,
      files: <OfflineUploadFile>[
        if (landscapeFotoLugar != null)
          OfflineUploadFile(field: 'foto_lugar', path: landscapeFotoLugar.path),
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

  static Map<String, String> _buildFields(
    HechoFormData d,
    DictamenItem? dict, {
    required bool usesRelaxedHechosRules,
  }) {
    final fields = <String, String>{
      'folio_c5i': d.folioC5i.trim(),
      'perito': d.perito.trim(),
      'autorizacion_practico': d.autorizacionPractico.trim(),
      'unidad': d.unidad.trim(),
      'hora': horaStr(d.hora!),
      'fecha': ymd(d.fecha!),
      'sector': usesRelaxedHechosRules
          ? ''
          : HechosCatalogos.normalizeSector(d.sector!),
      'calle': d.calle.trim(),
      'colonia': d.colonia.trim(),
      'entre_calles': d.entreCalles.trim(),
      'municipio': normalizeMunicipio(d.municipio),
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
      'responsable': d.responsable.trim(),
      'colision_camino': HechosCatalogos.normalizeColisionCamino(
        d.colisionCamino!,
      ),
      'situacion': d.situacion ?? '',
      'vehiculos_mp': d.vehiculosMp.trim(),
      'personas_mp': d.personasMp.trim(),
      'vehiculos_esperados': _intField(d.vehiculosEsperados),
      'conductores_esperados': _intField(d.conductoresEsperados),
      'lesionados_esperados': _intField(d.lesionadosEsperados),
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
      if ((d.ubicacionFormateada ?? '').trim().isNotEmpty) {
        fields['ubicacion_formateada'] = d.ubicacionFormateada!.trim();
      }
      if ((d.placeId ?? '').trim().isNotEmpty) {
        fields['place_id'] = d.placeId!.trim();
      }
    }

    return fields;
  }

  static String? _validateExpectedCaptureTotals(HechoFormData data) {
    final vehiculos = _parseNonNegativeInt(data.vehiculosEsperados);
    if (vehiculos == null) {
      return 'Indica cuántos vehículos participaron.';
    }

    final conductores = _parseNonNegativeInt(data.conductoresEsperados);
    if (conductores == null) {
      return 'Indica cuántos conductores participaron.';
    }

    final lesionados = _parseNonNegativeInt(data.lesionadosEsperados);
    if (lesionados == null) {
      return 'Indica cuántos lesionados hubo.';
    }

    if (conductores > vehiculos) {
      return 'Los conductores no pueden ser mayores que los vehículos.';
    }

    if (vehiculos == 0 && conductores > 0) {
      return 'No puede haber conductores si no hay vehículos.';
    }

    return null;
  }

  static int? _parseNonNegativeInt(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  static String _intField(String value) {
    final parsed = _parseNonNegativeInt(value);
    return (parsed ?? 0).toString();
  }

  static int _trimmedLength(String value) => value.trim().length;

  static String _collapseSpaces(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _normalizeKey(String value) {
    return value
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^A-Z]'), '');
  }

  static String _toTitleCase(String value) {
    return _collapseSpaces(value)
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          final lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i += 1) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;

      for (var j = 0; j < b.length; j += 1) {
        final cost = a[i] == b[j] ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }

      previous = current;
    }

    return previous[b.length];
  }

  static String _friendlyKnownBackendMessage(String rawMessage) {
    final msg = rawMessage.trim();
    if (msg.isEmpty) return '';

    final lower = msg.toLowerCase();

    if (lower.contains('hechos_folio_c5i_unique') ||
        (lower.contains('duplicate entry') && lower.contains('folio_c5i')) ||
        (lower.contains('duplicate entry') &&
            lower.contains('mor') &&
            lower.contains('insert into `hechos`'))) {
      return 'Ese folio C5i ya está registrado. Usa uno diferente.';
    }

    if (lower.contains('device_tokens_token_unique') ||
        lower.contains('duplicate entry')) {
      return 'Ese registro ya existe en el servidor.';
    }

    return msg;
  }

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
