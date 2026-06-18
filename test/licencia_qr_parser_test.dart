import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:seguridad_vial_app/core/licencias/licencia_barcode_payload.dart';
import 'package:seguridad_vial_app/core/licencias/licencia_qr_parser.dart';
import 'package:seguridad_vial_app/services/vehiculo_form_service.dart';

void main() {
  test('parsea licencia con separadores dobles y fecha con mes textual', () {
    const raw =
        '5604618//8//JULIO ERNESTO BAUTISTA JIMENEZ//21 | DIC | 1977//0101P3279509II&S=texto no legible';

    final data = LicenciaQrParser.parse(raw);

    expect(data.numeroLicencia, '0101P3279509II');
    expect(data.nombre, 'JULIO ERNESTO BAUTISTA JIMENEZ');
    expect(
      data.fechaNacimiento?.toIso8601String().substring(0, 10),
      '1977-12-21',
    );
    expect(data.tipoLicencia, isNull);
  });

  test('el parser de conductor tambien llena numero de licencia', () {
    const raw =
        '5604618//8//JULIO ERNESTO BAUTISTA JIMENEZ//21 | DIC | 1977//0101P3279509II&S=texto no legible';

    final data = VehiculoFormService.parseLicenciaConducirQr(raw);

    expect(data.numeroLicencia, '0101P3279509II');
    expect(data.nombre, 'JULIO ERNESTO BAUTISTA JIMENEZ');
    expect(data.tipoLicencia, isNull);
  });

  test('rescata la lectura desde bytes crudos cuando rawValue viene vacio', () {
    const visible =
        '5604618//8//JULIO ERNESTO BAUTISTA JIMENEZ//21 | DIC | 1977//0101P3279509II&S=';
    final bytes = Uint8List.fromList(<int>[
      ...visible.codeUnits,
      0,
      1,
      19,
      87,
      255,
      216,
      147,
      8,
      0,
      28,
    ]);
    final barcode = Barcode(
      format: BarcodeFormat.qrCode,
      rawDecodedBytes: DecodedBarcodeBytes(bytes: bytes),
    );

    final payload = LicenciaBarcodePayload.fromBarcode(barcode);
    final data = LicenciaQrParser.parse(payload ?? '');

    expect(payload, contains('5604618//8//JULIO ERNESTO BAUTISTA JIMENEZ'));
    expect(data.numeroLicencia, '0101P3279509II');
    expect(data.nombre, 'JULIO ERNESTO BAUTISTA JIMENEZ');
    expect(
      data.fechaNacimiento?.toIso8601String().substring(0, 10),
      '1977-12-21',
    );
  });
}
