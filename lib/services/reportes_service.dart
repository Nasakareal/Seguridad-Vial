import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../services/auth_service.dart';

class ReporteHechoService {
  static Future<void> descargarYCompartirHecho({
    required int hechoId,
    String ext = 'doc', // 'doc' o 'docx' o 'pdf'
  }) async {
    final token = await AuthService.getToken();

    // ✅ Ajusta a tu endpoint real (ej: /hechos/{id}/reporte)
    final uri = Uri.parse(
      'https://seguridadvial-mich.com/api/hechos/$hechoId/reporte',
    );

    final headers = <String, String>{
      'Accept': 'application/octet-stream',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode != 200) {
      // si viene JSON con error, lo intentamos leer bonito
      String msg = 'HTTP ${resp.statusCode}';
      try {
        final raw = jsonDecode(resp.body);
        if (raw is Map && raw['message'] is String) msg = raw['message'];
      } catch (_) {}
      throw Exception(msg);
    }

    final Uint8List bytes = resp.bodyBytes;

    final fileNameBase = 'hecho_$hechoId';
    final mime = _mimeByExt(ext);

    // ==========================
    // A) GUARDAR “COMO DESCARGA”
    // ==========================
    // Esto abre el diálogo del sistema. Si el usuario elige “Descargas”, queda ahí.
    await FileSaver.instance.saveFile(
      name: fileNameBase,
      bytes: bytes,
      ext: ext,
      mimeType: mime,
    );

    // ==========================
    // B) COMPARTIR POR WHATSAPP
    // ==========================
    // Para compartir, necesitamos un archivo físico accesible -> lo guardamos temporal.
    final tmpDir = await getTemporaryDirectory();
    final tmpPath = '${tmpDir.path}/$fileNameBase.$ext';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([
      XFile(tmpFile.path),
    ], text: 'Informe del hecho $hechoId');
  }

  static MimeType _mimeByExt(String ext) {
    final e = ext.toLowerCase().trim();
    if (e == 'pdf') return MimeType.pdf;
    if (e == 'docx') return MimeType.microsoftWord; // sirve en la práctica
    return MimeType.microsoftWord; // doc
  }
}
