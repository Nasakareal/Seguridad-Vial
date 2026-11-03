import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/thermal_printer_catalog_service.dart';

void main() {
  test('normaliza direcciones MAC con separadores distintos', () {
    expect(
      ThermalPrinterCatalogService.normalizeMac('86-67-7a-62-d8-c3'),
      '86:67:7A:62:D8:C3',
    );
    expect(
      ThermalPrinterCatalogService.normalizeMac('86677a62d8c3'),
      '86:67:7A:62:D8:C3',
    );
  });

  test('valida una MAC normalizada', () {
    expect(
      ThermalPrinterCatalogService.isValidMac('86:67:7A:62:D8:C3'),
      isTrue,
    );
    expect(ThermalPrinterCatalogService.isValidMac('BT-802'), isFalse);
  });

  test('interpreta la entrada del catálogo', () {
    final entry = ThermalPrinterCatalogEntry.fromJson({
      'id': 1,
      'display_name': 'UAS-001',
      'mac_address': '86-67-7a-62-d8-c3',
      'hardware_name': 'BT-802',
      'active': 1,
    });

    expect(entry.displayName, 'UAS-001');
    expect(entry.macAddress, '86:67:7A:62:D8:C3');
    expect(entry.hardwareName, 'BT-802');
    expect(entry.active, isTrue);
  });
}
