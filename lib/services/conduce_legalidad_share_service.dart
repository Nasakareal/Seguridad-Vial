import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';
import 'conduce_legalidad_service.dart';

class ConduceLegalidadShareService {
  static List<XFile> _pendingImages = <XFile>[];
  static bool _awaitingReturnFromWhatsappText = false;
  static bool _sendingImagesNow = false;

  static Future<void> compartirTotalesOperativo({
    required int operativoId,
  }) async {
    final payload = await ConduceLegalidadService.fetchOperativoNativeShareData(
      operativoId: operativoId,
    );
    await _compartirPayload(payload);
  }

  static Future<void> compartirCaptura({
    required int operativoId,
    required int capturaId,
  }) async {
    final payload = await ConduceLegalidadService.fetchCapturaNativeShareData(
      operativoId: operativoId,
      capturaId: capturaId,
    );
    await _compartirPayload(payload);
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
    ConduceLegalidadNativeShareData payload,
  ) async {
    final texto = payload.message.trim();
    final fotos = payload.media
        .map(_toAbsoluteUrl)
        .where((item) => item.isNotEmpty)
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

  static String _toAbsoluteUrl(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.isEmpty) return '';

    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return value;
    }

    final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    if (value.startsWith('/storage/')) return '$root$value';
    if (value.startsWith('storage/')) return '$root/$value';
    return '$root/storage/$value';
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
            '${dir.path}/conduce_legalidad_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

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
