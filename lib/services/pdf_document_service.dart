import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'auth_service.dart';

class PdfDocumentService {
  static Future<void> openFromUrl({
    required String url,
    required String fileName,
  }) async {
    final file = await _downloadToTemporaryFile(url: url, fileName: fileName);
    final result = await OpenFilex.open(file.path);

    if (result.type != ResultType.done) {
      throw Exception(
        result.message.isEmpty ? 'No se pudo abrir el PDF.' : result.message,
      );
    }
  }

  static Future<void> saveAndShareFromUrl({
    required String url,
    required String fileName,
    String? shareText,
  }) async {
    final bytes = await _downloadBytes(url);
    final cleanName = _safePdfFileName(fileName);
    final baseName = p.basenameWithoutExtension(cleanName);

    await FileSaver.instance.saveFile(
      name: baseName,
      bytes: bytes,
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );

    final file = await _writeTemporaryFile(bytes: bytes, fileName: cleanName);
    await Share.shareXFiles([XFile(file.path)], text: shareText);
  }

  static Future<File> _downloadToTemporaryFile({
    required String url,
    required String fileName,
  }) async {
    final bytes = await _downloadBytes(url);
    return _writeTemporaryFile(bytes: bytes, fileName: fileName);
  }

  static Future<Uint8List> _downloadBytes(String url) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final response = await http.get(
      Uri.parse(url),
      headers: <String, String>{
        'Accept': 'application/pdf,application/octet-stream,*/*',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}');
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception('El PDF descargado está vacío.');
    }

    return response.bodyBytes;
  }

  static Future<File> _writeTemporaryFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeName = _safePdfFileName(fileName);
    final uniqueName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(safeName)}';
    final file = File(p.join(dir.path, uniqueName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String _safePdfFileName(String fileName) {
    var clean = fileName.trim();
    if (clean.isEmpty) clean = 'documento.pdf';
    clean = clean.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!clean.toLowerCase().endsWith('.pdf')) clean = '$clean.pdf';
    return clean;
  }
}
