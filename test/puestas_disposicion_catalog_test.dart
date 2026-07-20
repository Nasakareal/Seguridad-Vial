import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/puestas_disposicion_service.dart';

void main() {
  test('catálogo de motivos coincide con las reglas del backend', () {
    expect(PuestaDisposicionCatalog.motivos, contains('PERSONA DETENIDA'));
    expect(
      PuestaDisposicionCatalog.motivos,
      contains('HECHO DE TRANSITO TURNADO'),
    );
    expect(
      PuestaDisposicionCatalog.motivos.last,
      PuestaDisposicionCatalog.motivoOtro,
    );
    expect(PuestaDisposicionCatalog.motivos.toSet().length, 26);
  });

  test('tipos de puesta incluyen las cuatro opciones del backend', () {
    expect(PuestaDisposicionCatalog.tipos, <String>[
      'PERSONA',
      'VEHICULO',
      'OBJETO',
      'MIXTA',
    ]);
  });

  test('detecta PDF sin firma que el backend intentará comprimir', () async {
    final dir = await Directory.systemTemp.createTemp('puesta_pdf_test_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}puesta.pdf');
    await file.writeAsBytes(<int>[
      ...'%PDF-1.7\n'.codeUnits,
      ...List<int>.filled(PuestasDisposicionService.pdfCompressionMinBytes, 32),
    ]);

    final inspection = await PuestasDisposicionService.inspectPdf(file);

    expect(inspection.hasDigitalSignature, isFalse);
    expect(inspection.serverWillTryCompression, isTrue);
    expect(
      PuestasDisposicionService.pdfPreparationMessage(inspection),
      contains('intentará comprimir'),
    );
  });

  test('detecta PDF firmado para conservarlo sin cambios', () async {
    final dir = await Directory.systemTemp.createTemp('puesta_signed_test_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}firmado.pdf');
    await file.writeAsString('%PDF-1.7\n/ByteRange [0 10 20 30]\n%%EOF');

    final inspection = await PuestasDisposicionService.inspectPdf(file);

    expect(inspection.hasDigitalSignature, isTrue);
    expect(inspection.serverWillTryCompression, isFalse);
    expect(
      PuestasDisposicionService.pdfPreparationMessage(inspection),
      contains('firma digital'),
    );
  });

  test('rechaza archivo renombrado como PDF sin cabecera PDF', () async {
    final dir = await Directory.systemTemp.createTemp('puesta_bad_pdf_test_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}invalido.pdf');
    await file.writeAsString('esto no es un PDF');

    expect(
      () => PuestasDisposicionService.inspectPdf(file),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('PDF válido'),
        ),
      ),
    );
  });
}
