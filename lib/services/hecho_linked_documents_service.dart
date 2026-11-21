import 'auth_service.dart';

enum HechoLinkedDocumentType { dictamen, puestaDisposicion }

class HechoLinkedDocument {
  final String key;
  final HechoLinkedDocumentType type;
  final String label;
  final String url;
  final String fileName;
  final String shareText;

  const HechoLinkedDocument({
    required this.key,
    required this.type,
    required this.label,
    required this.url,
    required this.fileName,
    required this.shareText,
  });
}

class HechoLinkedDocumentsService {
  const HechoLinkedDocumentsService._();

  static List<HechoLinkedDocument> fromHecho(
    Map<String, dynamic> hecho, {
    required int hechoId,
  }) {
    final documents = <HechoLinkedDocument>[];
    final seen = <String>{};

    void add(HechoLinkedDocument document) {
      if (document.url.trim().isEmpty || !seen.add(document.key)) return;
      documents.add(document);
    }

    final dictamen = hecho['dictamen'] is Map
        ? Map<String, dynamic>.from(hecho['dictamen'] as Map)
        : const <String, dynamic>{};
    final dictamenId = _toInt(hecho['dictamen_id'] ?? dictamen['id']);
    final dictamenArchivo = _text(
      hecho['dictamen_archivo_url'] ??
          hecho['dictamen_archivo'] ??
          dictamen['archivo_dictamen_url'] ??
          dictamen['archivo_url'] ??
          dictamen['archivo_dictamen'],
    );
    if (dictamenId > 0 || dictamenArchivo.isNotEmpty) {
      add(
        HechoLinkedDocument(
          key: 'dictamen:${dictamenId > 0 ? dictamenId : hechoId}',
          type: HechoLinkedDocumentType.dictamen,
          label: 'Descargar dictamen',
          url: dictamenId > 0
              ? '${AuthService.baseUrl}/dictamenes/$dictamenId/archivo'
              : _absoluteUrl(dictamenArchivo),
          fileName: 'dictamen_hecho_$hechoId.pdf',
          shareText: 'Dictamen del hecho #$hechoId',
        ),
      );
    }

    final puestas = _puestasFromHecho(hecho);
    for (var index = 0; index < puestas.length; index++) {
      final puesta = puestas[index];
      final id = _toInt(puesta['id'] ?? puesta['puesta_disposicion_id']);
      final direct = _text(
        puesta['archivo_puesta_url'] ??
            puesta['archivo_url'] ??
            puesta['pdf_url'] ??
            puesta['url'],
      );
      final archivo = _text(puesta['archivo_puesta'] ?? puesta['archivo']);
      if (id <= 0 && direct.isEmpty && archivo.isEmpty) continue;

      final numero = _text(puesta['numero_puesta']);
      final anio = _text(puesta['anio']);
      final folio = [
        if (numero.isNotEmpty) numero,
        if (anio.isNotEmpty) anio,
      ].join('/');
      final suffix = folio.isNotEmpty
          ? ' $folio'
          : (puestas.length > 1 ? ' ${index + 1}' : '');

      add(
        HechoLinkedDocument(
          key: 'puesta:${id > 0 ? id : index}',
          type: HechoLinkedDocumentType.puestaDisposicion,
          label: 'Descargar puesta$suffix',
          url: id > 0
              ? '${AuthService.baseUrl}/puestas-disposicion/$id/archivo'
              : _absoluteUrl(direct.isNotEmpty ? direct : archivo),
          fileName: id > 0
              ? 'puesta_disposicion_$id.pdf'
              : 'puesta_disposicion_hecho_$hechoId.pdf',
          shareText: folio.isNotEmpty
              ? 'Puesta a disposición $folio del hecho #$hechoId'
              : 'Puesta a disposición del hecho #$hechoId',
        ),
      );
    }

    return documents;
  }

  static List<Map<String, dynamic>> _puestasFromHecho(
    Map<String, dynamic> hecho,
  ) {
    final items = <Map<String, dynamic>>[];

    void addMap(dynamic value) {
      if (value is Map) items.add(Map<String, dynamic>.from(value));
    }

    void addList(dynamic value) {
      if (value is! List) return;
      for (final item in value) {
        addMap(item);
      }
    }

    addList(hecho['puestas_disposicion']);
    addList(hecho['puestas']);
    addMap(hecho['puesta_disposicion']);
    addMap(hecho['puestaDisposicion']);

    if (items.isEmpty) {
      final id = _toInt(hecho['puesta_disposicion_id']);
      final archivo = _text(
        hecho['archivo_puesta_url'] ?? hecho['archivo_puesta'],
      );
      if (id > 0 || archivo.isNotEmpty) {
        items.add(<String, dynamic>{'id': id, 'archivo_puesta': archivo});
      }
    }

    final seenIds = <int>{};
    return items.where((item) {
      final id = _toInt(item['id'] ?? item['puesta_disposicion_id']);
      return id <= 0 || seenIds.add(id);
    }).toList();
  }

  static String _absoluteUrl(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    if (clean.startsWith('/api/')) return '$root$clean';
    if (clean.startsWith('api/')) return '$root/$clean';
    if (clean.startsWith('/storage/')) return '$root$clean';
    if (clean.startsWith('storage/')) return '$root/$clean';
    return '$root/storage/$clean';
  }

  static String _text(dynamic value) => (value ?? '').toString().trim();

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
