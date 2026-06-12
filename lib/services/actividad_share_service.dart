import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/actividad.dart';
import 'actividades_service.dart';
import 'auth_service.dart';

class ActividadShareService {
  static List<XFile> _pendingImages = <XFile>[];
  static bool _awaitingReturnFromWhatsappText = false;
  static bool _sendingImagesNow = false;

  static Future<void> compartirEnWhatsapp({
    required int actividadId,
    Actividad? actividad,
  }) async {
    var payload = await ActividadesService.fetchShareData(
      actividadId: actividadId,
    );
    payload = await _conHoraFallback(
      payload,
      actividadId: actividadId,
      actividad: actividad,
    );
    payload = _conUbicacionFallback(payload, actividad);
    payload = _conFotosOriginalesLocales(payload, actividad);
    await _compartirPayload(payload);
  }

  static Future<void> compartirTotalesEnWhatsapp({
    required DateTime fecha,
  }) async {
    final payload = await ActividadesService.fetchShareTotalsData(fecha: fecha);
    await _compartirPayload(payload);
  }

  static Future<void> compartirTextoConFotos({
    required String texto,
    List<String> fotos = const <String>[],
  }) async {
    final cleanText = texto.trim();
    final urls = fotos
        .map((e) => ActividadesService.toPublicUrl(e))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final archivos = await _descargarArchivosTemporales(urls);

    await _compartirTextoYDespuesImagenes(texto: cleanText, archivos: archivos);
  }

  static Future<void> compartirTextoConArchivosLocales({
    required String texto,
    List<String> archivos = const <String>[],
  }) async {
    final localFiles = archivos
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => XFile(e))
        .toList();

    await _compartirTextoYDespuesImagenes(
      texto: texto.trim(),
      archivos: localFiles,
    );
  }

  static Future<void> _compartirTextoYDespuesImagenes({
    required String texto,
    required List<XFile> archivos,
  }) async {
    if (texto.isNotEmpty) {
      _pendingImages = archivos;
      _awaitingReturnFromWhatsappText = archivos.isNotEmpty;

      await _abrirTextoEnWhatsapp(texto);
      return;
    }

    if (archivos.isNotEmpty) {
      await _compartirSoloImagenes(archivos);
      return;
    }

    throw Exception('No hay informacion disponible para compartir.');
  }

  static Future<void> onAppResumed() async {
    if (!_awaitingReturnFromWhatsappText || _sendingImagesNow) {
      return;
    }

    final archivos = List<XFile>.from(_pendingImages);

    _awaitingReturnFromWhatsappText = false;
    _pendingImages = <XFile>[];

    if (archivos.isEmpty) {
      return;
    }

    _sendingImagesNow = true;
    try {
      await _compartirSoloImagenes(archivos);
    } finally {
      _sendingImagesNow = false;
    }
  }

  static Future<void> _compartirPayload(
    ActividadNativeShareData payload,
  ) async {
    final texto = payload.message.trim();
    final fotos = payload.media
        .map((e) => ActividadesService.toPublicUrl(e))
        .where((e) => e.isNotEmpty)
        .toList();

    final archivos = await _descargarArchivosTemporales(fotos);

    if (texto.isNotEmpty) {
      _pendingImages = archivos;
      _awaitingReturnFromWhatsappText = archivos.isNotEmpty;

      await _abrirTextoEnWhatsapp(texto);
      return;
    }

    if (archivos.isNotEmpty) {
      await _compartirSoloImagenes(archivos);
      return;
    }

    throw Exception('No hay informacion disponible para compartir.');
  }

  static Future<ActividadNativeShareData> _conHoraFallback(
    ActividadNativeShareData payload, {
    required int actividadId,
    Actividad? actividad,
  }) async {
    final withLocalHora = payload.withHoraFallback(actividad?.hora);
    if (withLocalHora.hasClockTimeInMessage) {
      return withLocalHora;
    }

    try {
      final full = await ActividadesService.fetchShow(actividadId);
      return withLocalHora.withHoraFallback(full.hora);
    } catch (_) {
      return withLocalHora;
    }
  }

  static ActividadNativeShareData _conFotosOriginalesLocales(
    ActividadNativeShareData payload,
    Actividad? actividad,
  ) {
    final originales = actividad?.allPhotoPaths ?? const <String>[];
    if (originales.isEmpty) return payload;
    return payload.withMedia(originales);
  }

  static ActividadNativeShareData _conUbicacionFallback(
    ActividadNativeShareData payload,
    Actividad? actividad,
  ) {
    if (actividad == null || _mensajeTieneUbicacion(payload.message)) {
      return payload;
    }

    final bloque = _bloqueUbicacion(actividad);
    if (bloque.isEmpty) return payload;

    return ActividadNativeShareData(
      message: _insertarBloqueUbicacion(payload.message, bloque),
      media: payload.media,
    );
  }

  static bool _mensajeTieneUbicacion(String message) {
    final upper = message.toUpperCase();
    return upper.contains('COORDENADAS:') || upper.contains('GOOGLE MAPS:');
  }

  static String _bloqueUbicacion(Actividad actividad) {
    final lat = actividad.lat;
    final lng = actividad.lng;

    if (lat != null && lng != null) {
      final latText = lat.toStringAsFixed(7);
      final lngText = lng.toStringAsFixed(7);
      return 'COORDENADAS: $latText, $lngText\n'
          'GOOGLE MAPS: https://www.google.com/maps?q=$latText,$lngText';
    }

    final coordenadas = (actividad.coordenadasTexto ?? '').trim();
    if (coordenadas.isEmpty) return '';

    return 'COORDENADAS: $coordenadas';
  }

  static String _insertarBloqueUbicacion(String message, String bloque) {
    final text = message.trim();
    if (text.isEmpty) return bloque;

    final lines = text.split(RegExp(r'\r?\n'));
    var insertAt = lines.indexWhere(
      (line) => line.trim().toUpperCase().startsWith('HORA '),
    );

    if (insertAt < 0) {
      insertAt = lines.indexWhere(
        (line) => line.trim().toUpperCase().startsWith('FECHA '),
      );
    }

    final blockLines = bloque.split('\n');
    if (insertAt >= 0) {
      lines.insertAll(insertAt + 1, blockLines);
      return lines.join('\n').trim();
    }

    return '$text\n\n$bloque';
  }

  static Future<void> _abrirTextoEnWhatsapp(String texto) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened) {
      throw Exception('No se pudo abrir WhatsApp para enviar el texto.');
    }
  }

  static Future<void> _compartirSoloImagenes(List<XFile> archivos) async {
    if (archivos.isEmpty) return;
    await Share.shareXFiles(archivos);
  }

  static Future<List<XFile>> _descargarArchivosTemporales(
    List<String> urls,
  ) async {
    final token = await AuthService.getToken();

    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final dir = await getTemporaryDirectory();
    final archivos = <XFile>[];
    final usados = <String>{};

    for (var i = 0; i < urls.length; i++) {
      final url = urls[i].trim();
      if (url.isEmpty) continue;

      try {
        final uri = Uri.parse(url);
        final resp = await http.get(uri, headers: headers);

        if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
          continue;
        }

        final ext = _resolverExtension(
          contentType: resp.headers['content-type'],
          url: url,
        );

        final path =
            '${dir.path}/actividad_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

        if (usados.add(path)) {
          final file = File(path);
          await file.writeAsBytes(resp.bodyBytes, flush: true);
          archivos.add(XFile(file.path));
        }
      } catch (_) {}
    }

    return archivos;
  }

  static String _resolverExtension({String? contentType, required String url}) {
    final ct = (contentType ?? '').toLowerCase();

    if (ct.contains('png')) return 'png';
    if (ct.contains('webp')) return 'webp';
    if (ct.contains('gif')) return 'gif';
    if (ct.contains('heic')) return 'heic';
    if (ct.contains('jpg') || ct.contains('jpeg')) return 'jpg';

    final cleanUrl = url.split('?').first.toLowerCase();
    if (cleanUrl.endsWith('.png')) return 'png';
    if (cleanUrl.endsWith('.webp')) return 'webp';
    if (cleanUrl.endsWith('.gif')) return 'gif';
    if (cleanUrl.endsWith('.heic')) return 'heic';
    if (cleanUrl.endsWith('.jpeg')) return 'jpg';
    if (cleanUrl.endsWith('.jpg')) return 'jpg';

    return 'jpg';
  }
}
