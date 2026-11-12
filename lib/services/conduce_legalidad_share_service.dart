import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/conduce_legalidad.dart';
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

  static Future<void> compartirTotalesPorUsuario({
    required int operativoId,
  }) async {
    if (!await AuthService.isSuperadmin()) {
      throw Exception('Esta exportación es exclusiva para Superadmin.');
    }

    final operativo = await ConduceLegalidadService.fetchOperativo(operativoId);
    if (operativo.isAlcoholimetria) {
      throw Exception(
        'El concentrado de folios CL sólo aplica a Conduce con Legalidad.',
      );
    }

    final texto = construirTotalesPorUsuario(operativo);
    await Share.share(
      texto,
      subject: 'Totales por usuario · Operativo CL-${operativo.id}',
    );
  }

  static String construirTotalesPorUsuario(
    ConduceLegalidadOperativo operativo,
  ) {
    final grupos = <String, _TotalesUsuario>{};
    final capturas = List<ConduceLegalidadCaptura>.from(operativo.capturas)
      ..sort((a, b) {
        final aNumero = a.folioNumero ?? a.id;
        final bNumero = b.folioNumero ?? b.id;
        return aNumero.compareTo(bNumero);
      });

    for (final captura in capturas) {
      final creador = captura.creador;
      final userId = creador?.id ?? captura.createdBy;
      final nombre = (creador?.nombre ?? captura.agenteNombre ?? '').trim();
      final nombreVisible = nombre.isNotEmpty
          ? nombre
          : userId != null
          ? 'Usuario #$userId'
          : 'Usuario sin identificar';
      final key = userId != null
          ? 'id:$userId'
          : 'nombre:${nombreVisible.toLowerCase()}';
      final folio = captura.folioPara(operativoId: operativo.id, prefijo: 'CL');

      grupos
          .putIfAbsent(
            key,
            () => _TotalesUsuario(nombre: nombreVisible, folios: <String>[]),
          )
          .folios
          .add(folio);
    }

    final usuarios = grupos.values.toList()
      ..sort((a, b) {
        final total = b.folios.length.compareTo(a.folios.length);
        return total != 0
            ? total
            : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
    final punto = operativo.lugarConNumero.trim().isNotEmpty
        ? operativo.lugarConNumero.trim()
        : operativo.nombre.trim();
    final lines = <String>[
      'CONDUCE CON LEGALIDAD',
      'TOTALES DE BOLETAS POR USUARIO',
      '',
      'Operativo: CL-${operativo.id}',
      if (punto.isNotEmpty) 'Punto: $punto',
      if ((operativo.fecha ?? '').trim().isNotEmpty)
        'Fecha: ${operativo.fecha!.trim()}',
      'Total general: ${capturas.length} ${capturas.length == 1 ? 'boleta' : 'boletas'}',
      '',
    ];

    if (usuarios.isEmpty) {
      lines.add('Sin boletas registradas.');
    } else {
      for (var index = 0; index < usuarios.length; index++) {
        final usuario = usuarios[index];
        lines.add(
          '${index + 1}. ${usuario.nombre} — ${usuario.folios.length} ${usuario.folios.length == 1 ? 'boleta' : 'boletas'}',
        );
        lines.add(usuario.folios.join(', '));
        if (index < usuarios.length - 1) lines.add('');
      }
    }

    return lines.join('\n').trim();
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

    final tieneDocumentos = archivos.any(
      (archivo) => archivo.path.toLowerCase().endsWith('.docx'),
    );
    if (tieneDocumentos) {
      await Share.shareXFiles(
        archivos,
        text: texto.isEmpty ? null : texto,
        subject: payload.title,
      );
      return;
    }

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
          archivos.add(
            XFile(file.path, mimeType: resp.headers['content-type']),
          );
        }
      } catch (_) {}
    }

    return archivos;
  }

  static String _resolverExtension({String? contentType, required String url}) {
    final ct = (contentType ?? '').toLowerCase();
    if (ct.contains(
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    )) {
      return 'docx';
    }
    if (ct.contains('png')) return 'png';
    if (ct.contains('webp')) return 'webp';
    if (ct.contains('gif')) return 'gif';
    if (ct.contains('heic')) return 'heic';
    if (ct.contains('jpg') || ct.contains('jpeg')) return 'jpg';

    final cleanUrl = url.split('?').first.toLowerCase();
    if (cleanUrl.endsWith('.docx')) return 'docx';
    if (cleanUrl.endsWith('.png')) return 'png';
    if (cleanUrl.endsWith('.webp')) return 'webp';
    if (cleanUrl.endsWith('.gif')) return 'gif';
    if (cleanUrl.endsWith('.heic')) return 'heic';
    if (cleanUrl.endsWith('.jpeg')) return 'jpg';
    if (cleanUrl.endsWith('.jpg')) return 'jpg';
    return 'jpg';
  }
}

class _TotalesUsuario {
  final String nombre;
  final List<String> folios;

  const _TotalesUsuario({required this.nombre, required this.folios});
}
