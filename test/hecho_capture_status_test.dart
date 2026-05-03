import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/core/hechos/hecho_capture_status.dart';

void main() {
  test('reports missing expected capture items from nested relations', () {
    final detalles = HechoCaptureStatus.detallesFaltantes({
      'vehiculos_esperados': 2,
      'conductores_esperados': 2,
      'lesionados_esperados': 1,
      'vehiculos': [
        {
          'id': 10,
          'conductores': [
            {'id': 20, 'nombre': 'Persona conductora'},
          ],
        },
      ],
      'lesionados': [],
    });

    expect(detalles, ['1 vehículo', '1 conductor', '1 lesionado']);
  });

  test('uses direct captured counts when relations are not loaded', () {
    final detalles = HechoCaptureStatus.detallesFaltantes({
      'vehiculos_esperados': '3',
      'conductores_esperados': '2',
      'lesionados_esperados': '2',
      'vehiculos_capturados': 1,
      'conductores_count': 2,
      'total_lesionados': 0,
    });

    expect(detalles, ['2 vehículos', '2 lesionados']);
  });

  test('keeps backend-provided missing details when available', () {
    final detalles = HechoCaptureStatus.detallesFaltantes({
      'captura_faltantes': {'vehiculos': 2, 'conductores': 1},
      'vehiculos_esperados': 0,
      'conductores_esperados': 0,
    });

    expect(detalles, ['2 vehículos', '1 conductor']);
  });

  test('returns no details when expected or captured totals are unknown', () {
    final detalles = HechoCaptureStatus.detallesFaltantes({
      'captura_completa': false,
    });

    expect(detalles, isEmpty);
  });
}
