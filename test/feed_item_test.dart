import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/feed_item.dart';

void main() {
  test('parses direct feed delegacion id', () {
    final item = FeedItem.fromJson(<String, dynamic>{
      'type': 'ACTIVIDAD',
      'id': 1,
      'user_id': 2,
      'user_name': 'Operador',
      'resumen': 'Actividad',
      'unidad_id': 2,
      'unidad_nombre': 'Delegaciones',
      'delegacion_id': 7,
      'delegacion_nombre': 'Regional Centro',
    });

    expect(item.unidadId, 2);
    expect(item.unidadLabel, 'Delegaciones');
    expect(item.delegacionId, 7);
    expect(item.delegacionLabel, 'Regional Centro');
    expect(
      item.origenLabel,
      'Delegación: Regional Centro • Unidad: Delegaciones',
    );
  });

  test('parses nested feed delegacion id', () {
    final item = FeedItem.fromJson(<String, dynamic>{
      'type': 'HECHO',
      'id': 3,
      'user_id': 4,
      'user_name': 'Operador',
      'resumen': 'Hecho',
      'actividad': <String, dynamic>{
        'unidad': <String, dynamic>{'id': 6, 'nombre': 'Cultura Vial'},
        'delegacion': <String, dynamic>{'id': 12},
      },
    });

    expect(item.unidadId, 6);
    expect(item.unidadLabel, 'Cultura Vial');
    expect(item.delegacionId, 12);
    expect(item.delegacionLabel, 'Delegación 12');
  });

  test('uses unidad fallback when feed only sends ids', () {
    final item = FeedItem.fromJson(<String, dynamic>{
      'type': 'CARRETERAS',
      'id': 8,
      'user_id': 9,
      'user_name': 'Operador',
      'resumen': 'Operativo',
      'unidad_id': 4,
    });

    expect(item.unidadLabel, 'PROTECCION A CARRETERAS');
    expect(item.delegacionLabel, isNull);
    expect(item.origenLabel, 'Unidad: PROTECCION A CARRETERAS');
  });

  test('copyWith can add missing feed delegacion context', () {
    final item = FeedItem.fromJson(<String, dynamic>{
      'type': 'ACTIVIDAD',
      'id': 9,
      'user_id': 10,
      'user_name': 'Operador',
      'resumen': 'Actividad',
      'unidad_id': 2,
      'unidad_nombre': 'DELEGACIONES',
    }).copyWith(delegacionId: 7, delegacionNombre: 'Regional Centro');

    expect(item.delegacionId, 7);
    expect(item.delegacionLabel, 'Regional Centro');
    expect(
      item.origenLabel,
      'Delegación: Regional Centro • Unidad: DELEGACIONES',
    );
  });
}
