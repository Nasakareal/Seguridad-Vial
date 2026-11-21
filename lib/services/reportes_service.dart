import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import 'accidentes_service.dart';

class ReporteHechoService {
  static Future<void> descargarYCompartirHecho({
    required int hechoId,
    String ext = 'doc',
  }) async {
    final bytes = await AccidentesService.downloadReporteDoc(hechoId: hechoId);
    final fileNameBase = 'hecho_$hechoId';
    final mime = _mimeByExt(ext);

    await FileSaver.instance.saveFile(
      name: fileNameBase,
      bytes: bytes,
      ext: ext,
      mimeType: mime,
    );

    final tmpDir = await getTemporaryDirectory();
    final tmpPath = '${tmpDir.path}/$fileNameBase.$ext';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([
      XFile(tmpFile.path),
    ], text: 'Informe del hecho $hechoId');
  }

  static Future<void> descargarYCompartirIphPuesta({
    required int hechoId,
  }) async {
    final bytes = await AccidentesService.downloadIphPuestaDisposicion(
      hechoId: hechoId,
    );
    final fileNameBase = 'iph_puesta_disposicion_hecho_$hechoId';

    await FileSaver.instance.saveFile(
      name: fileNameBase,
      bytes: bytes,
      ext: 'docx',
      mimeType: MimeType.microsoftWord,
    );

    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File('${tmpDir.path}/$fileNameBase.docx');
    await tmpFile.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([
      XFile(
        tmpFile.path,
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
    ], text: 'IPH y puesta a disposición del hecho $hechoId');
  }

  static MimeType _mimeByExt(String ext) {
    final e = ext.toLowerCase().trim();
    if (e == 'pdf') return MimeType.pdf;
    if (e == 'docx') return MimeType.microsoftWord; // sirve en la práctica
    return MimeType.microsoftWord; // doc
  }
}
