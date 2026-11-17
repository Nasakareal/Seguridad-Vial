import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/conduce_legalidad_reporte_service.dart';

void main() {
  test('parses summary, options, pagination and vehicle rows', () {
    final page = ConduceLegalidadReportePage.fromJson({
      'data': [
        {
          'id': 8,
          'operativo_id': 3,
          'fecha_reporte': '2026-11-14',
          'lugar_reporte': 'Morelia · Centro',
          'marca': 'ITALIKA',
          'linea': 'FT150',
          'modelo': '2026',
          'color': 'ROJO',
          'placas': '39PNK6',
          'serie': 'ABC123',
          'numero_inventario': '0863',
          'retencion_vehiculo': 1,
          'datos_vehiculo': 'Marca: ITALIKA; Línea: FT150',
          'motivo_reporte': 'Art. 328 - Sin placas',
        },
      ],
      'summary': {
        'vehiculos': 20,
        'operativos': 4,
        'municipios': 2,
        'retenidos': 11,
      },
      'options': {
        'municipios': ['Morelia', 'Uruapan'],
        'marcas': ['ITALIKA'],
        'tipos': ['MOTOCICLETA'],
        'colores': ['ROJO'],
      },
      'pagination': {
        'current_page': 2,
        'last_page': 3,
        'per_page': 10,
        'total': 20,
      },
    });

    expect(page.summary.vehicles, 20);
    expect(page.summary.operations, 4);
    expect(page.options.municipalities, ['Morelia', 'Uruapan']);
    expect(page.currentPage, 2);
    expect(page.lastPage, 3);
    expect(page.vehicles.single.title, 'ITALIKA · FT150');
    expect(page.vehicles.single.retained, isTrue);
    expect(page.vehicles.single.inventoryNumber, '0863');
  });

  test('uses safe defaults for an empty response', () {
    final page = ConduceLegalidadReportePage.fromJson(const {});

    expect(page.vehicles, isEmpty);
    expect(page.summary.vehicles, 0);
    expect(page.currentPage, 1);
    expect(page.lastPage, 1);
    expect(page.perPage, 25);
  });
}
