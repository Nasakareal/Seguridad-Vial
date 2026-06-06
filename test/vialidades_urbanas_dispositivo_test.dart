import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/vialidades_urbanas_dispositivo.dart';

void main() {
  test('parses vialidades creator ids for ownership checks', () {
    final dispositivo = VialidadesUrbanasDispositivo.fromJson(<String, dynamic>{
      'id': 12,
      'created_by': 45,
      'catalogo': <String, dynamic>{'id': 1, 'nombre': 'Operativo'},
      'detalles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 7,
          'orden': 1,
          'contenido': 'Detalle propio',
          'creador': <String, dynamic>{'id': 45, 'name': 'Agente Vial'},
        },
      ],
      'fotos': <Map<String, dynamic>>[
        <String, dynamic>{'id': 9, 'ruta': 'foto.jpg', 'user_id': 45},
      ],
    });

    expect(dispositivo.creadorId, 45);
    expect(dispositivo.belongsToUser(45), isTrue);
    expect(dispositivo.belongsToUser(77), isFalse);
    expect(dispositivo.detalles.first.belongsToUser(45), isTrue);
    expect(dispositivo.fotos.first.belongsToUser(45), isTrue);
  });

  test('uses child owners when parent creator id is not present', () {
    final dispositivo = VialidadesUrbanasDispositivo.fromJson(<String, dynamic>{
      'id': 13,
      'catalogo': <String, dynamic>{'id': 1, 'nombre': 'Operativo'},
      'detalles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 8,
          'orden': 1,
          'contenido': 'Detalle propio',
          'created_by': 46,
        },
      ],
    });

    expect(dispositivo.creadorId, isNull);
    expect(dispositivo.belongsToUser(46), isTrue);
    expect(dispositivo.belongsToUser(45), isFalse);
  });

  test('does not treat mixed child owners as own capture', () {
    final dispositivo = VialidadesUrbanasDispositivo.fromJson(<String, dynamic>{
      'id': 14,
      'created_by': 46,
      'catalogo': <String, dynamic>{'id': 1, 'nombre': 'Operativo'},
      'detalles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 8,
          'orden': 1,
          'contenido': 'Detalle propio',
          'created_by': 46,
        },
        <String, dynamic>{
          'id': 9,
          'orden': 2,
          'contenido': 'Detalle de otro agente',
          'created_by': 47,
        },
      ],
    });

    expect(dispositivo.belongsToUser(46), isFalse);
  });

  test('normalizes parent and detail hours', () {
    final dispositivo = VialidadesUrbanasDispositivo.fromJson(<String, dynamic>{
      'id': 15,
      'hora': '2026-06-05T11:25:00.000000Z',
      'catalogo': <String, dynamic>{'id': 1, 'nombre': 'Operativo'},
      'detalles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 10,
          'orden': 1,
          'contenido': 'Detalle',
          'hora': '07:05:00',
        },
      ],
    });

    expect(dispositivo.hora, '11:25');
    expect(dispositivo.detalles.first.hora, '07:05');
  });
}
