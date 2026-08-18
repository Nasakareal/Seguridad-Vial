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
}
