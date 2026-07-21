import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/settings_statistics_files_service.dart';

void main() {
  test('parses every patrol user and keeps multiple users in one shift', () {
    final module = SettingsStatisticsModule.fromJson({
      'id': 'siniestros',
      'title': 'Estadisticas Siniestros',
      'subtitle': 'Archivos y patrullas',
      'reports': const [],
      'patrullas': [
        {
          'id': 8,
          'numero_economico': '3144',
          'activa': 1,
          'tipo': 'SEDAN',
          'marca': 'DODGE',
          'linea': 'CHARGER',
          'modelo': 2016,
          'placas': 'MC214A7',
          'usuarios': [
            {
              'id': 10,
              'nombre': 'AGENTE UNO',
              'estado': 'Activo',
              'turno_id': 1,
              'turno': 'A',
            },
            {
              'id': 11,
              'nombre': 'AGENTE DOS',
              'estado': 'Activo',
              'turno_id': 1,
              'turno': 'A',
            },
            {
              'id': 12,
              'nombre': 'AGENTE TRES',
              'estado': 'Activo',
              'turno_id': 2,
              'turno': 'B',
            },
          ],
        },
      ],
    });

    expect(module.patrullas, hasLength(1));
    final patrol = module.patrullas.single;
    expect(patrol.numeroEconomico, '3144');
    expect(patrol.activa, isTrue);
    expect(patrol.usuarios, hasLength(3));
    expect(
      patrol.usuarios.where((user) => user.shiftLabel == 'Turno A'),
      hasLength(2),
    );
    expect(patrol.vehicleLabel, contains('MC214A7'));
  });

  test('patrol search includes assigned user and shift', () {
    final patrol = SettingsSiniestrosPatrol.fromJson({
      'id': 1,
      'numero_economico': 'C1030',
      'activa': true,
      'usuarios': [
        {
          'id': 20,
          'nombre': 'RAFAEL LORENZO CRUZ',
          'estado': 'Activo',
          'turno': 'B',
        },
      ],
    });

    expect(patrol.matches('c1030'), isTrue);
    expect(patrol.matches('rafael'), isTrue);
    expect(patrol.matches('B'), isTrue);
    expect(patrol.matches('sin coincidencia'), isFalse);
  });
}
