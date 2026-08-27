import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/semaforo_priority.dart';

void main() {
  test('solo confirma estados reconocidos por el gateway', () {
    final active = SemaforoPriorityRequest.fromJson({
      'id': '1',
      'estado': 'active',
    });
    final unknown = SemaforoPriorityRequest.fromJson({
      'id': '2',
      'estado': 'sin_respuesta',
    });
    expect(active.confirmed, isTrue);
    expect(unknown.status, PriorityRequestStatus.pending);
    expect(unknown.confirmed, isFalse);
  });

  test('lee un crucero persistido con ubicación y programación conocida', () {
    final node = SemaforoNode.fromJson({
      'node_id': 'FBF61B44',
      'ruta': 'QUIROGA_SALIDA',
      'nombre': 'SALIDA QUIROGA',
      'ubicacion': 'Morelia, Michoacán',
      'vialidad_principal': 'SALIDA A QUIROGA',
      'vialidad_transversal': 'CRUCE TRANSVERSAL',
      'latitud': '19.7020000',
      'longitud': -101.243,
      'plan_activo': 'LOCAL CC1',
      'horario_inicio': '18:30',
      'horario_fin': '19:30',
      'online': true,
      'ultimo_contacto_at': '2026-08-20T18:30:00-06:00',
    });

    expect(node.id, 'FBF61B44');
    expect(node.route, 'QUIROGA_SALIDA');
    expect(node.streets, 'SALIDA A QUIROGA / CRUCE TRANSVERSAL');
    expect(node.latitude, closeTo(19.702, .000001));
    expect(node.longitude, closeTo(-101.243, .000001));
    expect(node.online, isTrue);
    expect(node.lastSeen, isNotNull);
  });
}
