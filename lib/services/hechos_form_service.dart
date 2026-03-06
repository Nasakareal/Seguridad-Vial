import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/hechos/hechos_catalogos.dart';
import '../models/dictamen_item.dart';
import '../models/hecho_form_data.dart';
import 'auth_service.dart';

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
    if (num.isNotEmpty && anio != null)
      parts.add('$num/$anio');
    else if (num.isNotEmpty)
      parts.add(num);
    if (mp.isNotEmpty) parts.add(mp);
    return parts.join(' ').trim();
  }

  static Future<void> create({
    required HechoFormData data,
    required DictamenItem? dictamenSelected,
    File? fotoLugar,
    File? fotoSituacion,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${AuthService.baseUrl}/hechos');
    final req = http.MultipartRequest('POST', uri);

    req.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    _fillFields(req, data, dictamenSelected);

    if (fotoLugar != null) {
      req.files.add(
        await http.MultipartFile.fromPath('foto_lugar', fotoLugar.path),
      );
    }
    if (fotoSituacion != null) {
      req.files.add(
        await http.MultipartFile.fromPath('foto_situacion', fotoSituacion.path),
      );
    }

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 201 || streamed.statusCode == 200) return;
    if (streamed.statusCode == 422) {
      throw Exception(parseBackendError(body, streamed.statusCode));
    }
    throw Exception('HTTP ${streamed.statusCode}: $body');
  }

  static Future<void> update({
    required int hechoId,
    required HechoFormData data,
    required DictamenItem? dictamenSelected,
    File? fotoLugar,
    File? fotoSituacion,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('${AuthService.baseUrl}/hechos/$hechoId');
    final req = http.MultipartRequest('POST', uri);

    req.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    req.fields['_method'] = 'PUT';

    _fillFields(req, data, dictamenSelected);

    if (fotoLugar != null) {
      req.files.add(
        await http.MultipartFile.fromPath('foto_lugar', fotoLugar.path),
      );
    }
    if (fotoSituacion != null) {
      req.files.add(
        await http.MultipartFile.fromPath('foto_situacion', fotoSituacion.path),
      );
    }

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) return;
    if (streamed.statusCode == 422) {
      throw Exception(parseBackendError(body, streamed.statusCode));
    }
    throw Exception('HTTP ${streamed.statusCode}: $body');
  }

  static void _fillFields(
    http.MultipartRequest req,
    HechoFormData d,
    DictamenItem? dict,
  ) {
    req.fields['folio_c5i'] = d.folioC5i.trim();
    req.fields['perito'] = d.perito.trim();
    req.fields['autorizacion_practico'] = d.autorizacionPractico.trim();
    req.fields['unidad'] = d.unidad.trim();

    final unidadOrg = d.unidadOrgId.trim();
    if (unidadOrg.isNotEmpty) req.fields['unidad_org_id'] = unidadOrg;

    req.fields['hora'] = horaStr(d.hora!);
    req.fields['fecha'] = ymd(d.fecha!);

    req.fields['sector'] = HechosCatalogos.normalizeSector(d.sector!);

    req.fields['calle'] = d.calle.trim();
    req.fields['colonia'] = d.colonia.trim();
    req.fields['entre_calles'] = d.entreCalles.trim();
    req.fields['municipio'] = d.municipio.trim();

    req.fields['tipo_hecho'] = d.tipoHecho ?? '';
    req.fields['superficie_via'] = HechosCatalogos.normalizeSuperficieVia(
      d.superficieVia!,
    );

    req.fields['tiempo'] = HechosCatalogos.normalizeTiempo(d.tiempo!);
    req.fields['clima'] = HechosCatalogos.normalizeClima(d.clima!);
    req.fields['condiciones'] = HechosCatalogos.normalizeCondiciones(
      d.condiciones!,
    );

    req.fields['control_transito'] = HechosCatalogos.normalizeControlTransito(
      d.controlTransito!,
    );
    req.fields['checaron_antecedentes'] = d.checaronAntecedentes ? '1' : '0';

    req.fields['causas'] = HechosCatalogos.normalizeCausa(d.causa!);
    req.fields['colision_camino'] = HechosCatalogos.normalizeColisionCamino(
      d.colisionCamino!,
    );

    req.fields['situacion'] = d.situacion ?? '';

    if (d.situacion == 'TURNADO' && dict != null) {
      req.fields['dictamen_id'] = dict.id.toString();
      req.fields['oficio_mp'] = buildOficio(dict);

      if ((dict.numeroDictamen ?? '').trim().isNotEmpty) {
        req.fields['dictamen_numero'] = dict.numeroDictamen!.trim();
      }
      if (dict.anio != null) req.fields['dictamen_anio'] = dict.anio.toString();

      if ((dict.nombrePolicia ?? '').trim().isNotEmpty) {
        req.fields['dictamen_nombre_policia'] = dict.nombrePolicia!.trim();
      }
      if ((dict.nombreMp ?? '').trim().isNotEmpty) {
        req.fields['dictamen_nombre_mp'] = dict.nombreMp!.trim();
      }
      if ((dict.area ?? '').trim().isNotEmpty) {
        req.fields['dictamen_area'] = dict.area!.trim();
      }
      if ((dict.archivoDictamen ?? '').trim().isNotEmpty) {
        req.fields['dictamen_archivo'] = dict.archivoDictamen!.trim();
      }
      if (dict.createdBy != null) {
        req.fields['dictamen_created_by'] = dict.createdBy.toString();
      }
      if (dict.updatedBy != null) {
        req.fields['dictamen_updated_by'] = dict.updatedBy.toString();
      }
    } else {
      req.fields['oficio_mp'] = '';
    }

    req.fields['vehiculos_mp'] = d.vehiculosMp.trim();
    req.fields['personas_mp'] = d.personasMp.trim();

    req.fields['danos_patrimoniales'] = d.danosPatrimoniales ? '1' : '0';
    if (d.danosPatrimoniales) {
      final props = d.propiedadesAfectadas.trim();
      final monto = d.montoDanos.trim();

      if (props.isNotEmpty) req.fields['propiedades_afectadas'] = props;
      if (monto.isNotEmpty) {
        req.fields['monto_danos_patrimoniales'] = monto.replaceAll(',', '');
      }
    }

    if (d.hasCoords) {
      req.fields['lat'] = d.lat!.toStringAsFixed(7);
      req.fields['lng'] = d.lng!.toStringAsFixed(7);

      if ((d.calidadGeo ?? '').trim().isNotEmpty) {
        req.fields['calidad_geo'] = d.calidadGeo!.trim();
      }
      if ((d.notaGeo ?? '').trim().isNotEmpty) {
        req.fields['nota_geo'] = d.notaGeo!.trim();
      }
      if ((d.fuenteUbicacion ?? '').trim().isNotEmpty) {
        req.fields['fuente_ubicacion'] = d.fuenteUbicacion!.trim();
      }
    }
  }
}
