import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/hecho_linked_documents_service.dart';

void main() {
  test('detects linked dictamen and puestas from a hecho list item', () {
    final documents = HechoLinkedDocumentsService.fromHecho(<String, dynamic>{
      'dictamen_id': 18,
      'puestas_disposicion': <Map<String, dynamic>>[
        <String, dynamic>{'id': 31, 'numero_puesta': 'PD-10', 'anio': 2026},
        <String, dynamic>{'id': 32},
      ],
    }, hechoId: 77);

    expect(documents, hasLength(3));
    expect(documents.first.type, HechoLinkedDocumentType.dictamen);
    expect(documents.first.label, 'Descargar dictamen');
    expect(documents[1].type, HechoLinkedDocumentType.puestaDisposicion);
    expect(documents[1].label, 'Descargar puesta PD-10/2026');
    expect(documents[2].label, 'Descargar puesta 2');
  });

  test('does not invent document actions when a hecho has no links', () {
    final documents = HechoLinkedDocumentsService.fromHecho(
      const <String, dynamic>{},
      hechoId: 77,
    );

    expect(documents, isEmpty);
  });
}
