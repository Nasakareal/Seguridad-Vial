import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/depositos_vehiculares_reporte_service.dart';

void main() {
  test('calculates a rolling one-month range with safe month-end dates', () {
    expect(
      DepositosVehicularesReporteService.oneMonthBefore(DateTime(2026, 11, 16)),
      DateTime(2026, 10, 16),
    );
    expect(
      DepositosVehicularesReporteService.oneMonthBefore(DateTime(2026, 3, 31)),
      DateTime(2026, 2, 28),
    );
    expect(
      DepositosVehicularesReporteService.oneMonthBefore(DateTime(2026, 1, 17)),
      DateTime(2025, 12, 17),
    );
  });

  test('parses deposit summary, filters, pagination and vehicle rows', () {
    final page = DepositosVehicularesReportePage.fromJson({
      'data': [
        {
          'vehiculo_id': 45,
          'tipo': 'MOTOCICLETA',
          'marca': 'ITALIKA',
          'linea': 'FT150',
          'modelo': '2025',
          'color': 'ROJO',
          'placas': 'ABC123',
          'serie': 'SERIE123',
          'inventario': 'INV-90',
          'liberacion_id': 8,
          'folio_liberacion': 'LIB-8',
          'fecha_ingreso': '2026-11-10',
          'fecha_egreso': '2026-11-15',
          'unidad_id': 2,
          'municipio': 'MORELIA',
          'ubicacion': 'CENTRO, MORELIA',
          'corralon': 'DEPÓSITO CENTRAL',
          'origen': 'SINIESTROS',
          'estado': 'LIBERADO',
        },
      ],
      'summary': {'total': 20, 'liberados': 7, 'sin_liberacion': 13},
      'options': {
        'unidades': {'1': 'SINIESTROS', '2': 'DELEGACIONES'},
        'tipos': ['MOTOCICLETA'],
        'marcas': ['ITALIKA'],
        'corralones': ['DEPÓSITO CENTRAL'],
      },
      'pagination': {
        'current_page': 2,
        'last_page': 4,
        'per_page': 25,
        'total': 88,
      },
    });

    expect(page.summary.total, 20);
    expect(page.summary.released, 7);
    expect(page.summary.pendingRelease, 13);
    expect(page.options.units[2], 'DELEGACIONES');
    expect(page.currentPage, 2);
    expect(page.total, 88);
    expect(page.vehicles.single.title, 'ITALIKA · FT150');
    expect(page.vehicles.single.released, isTrue);
    expect(page.vehicles.single.releaseFolio, 'LIB-8');
  });

  test('uses safe defaults for an empty response', () {
    final page = DepositosVehicularesReportePage.fromJson(const {});

    expect(page.vehicles, isEmpty);
    expect(page.summary.total, 0);
    expect(page.options.units, isEmpty);
    expect(page.currentPage, 1);
    expect(page.lastPage, 1);
  });
}
