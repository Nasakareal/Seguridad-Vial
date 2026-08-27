import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/comunicacion_notification_service.dart';

void main() {
  group('ComunicacionNotificationService', () {
    test('reconoce los mensajes de comunicaciones enviados por Firebase', () {
      final message = RemoteMessage(
        messageId: 'push-123',
        data: const {
          'modulo': 'comunicaciones',
          'tipo': 'mensaje',
          'comunicacion_id': '42',
          'remitente_user_id': '7',
        },
      );

      expect(
        ComunicacionNotificationService.esComunicacion(message),
        isTrue,
      );
    });

    test(
      'el payload local conserva los datos necesarios para abrir el chat',
      () {
        const original = ComunicacionPushEvento(
          accion: ComunicacionPushAccion.recibida,
          messageId: 'push-123',
          comunicacionId: 42,
          remitenteUserId: 7,
          tipo: 'mensaje',
          remitente: 'Agente de prueba',
          contenido: 'Hola',
        );

        final restored = ComunicacionPushEvento.fromPayload(
          original.toPayload(),
          accion: ComunicacionPushAccion.abierta,
        );

        expect(restored.accion, ComunicacionPushAccion.abierta);
        expect(restored.comunicacionId, 42);
        expect(restored.remitenteUserId, 7);
        expect(restored.puedeAbrirConversacion, isTrue);
      },
    );
  });
}
