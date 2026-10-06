import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/constancia_manejo.dart';

void main() {
  ConstanciaManejo makeConstancia(Map<String, dynamic> overrides) {
    return ConstanciaManejo.fromJson(<String, dynamic>{
      'id': 1,
      'folio': 'D-0001',
      'qr_token': 'token',
      'estatus': 'IMPRESA_INACTIVA',
      ...overrides,
    });
  }

  test('folio impreso de lote puede activarse sin flujo de examen', () {
    final constancia = makeConstancia(<String, dynamic>{});

    expect(constancia.tieneFlujoExamen, isFalse);
    expect(constancia.puedeActivarDirectamente, isTrue);
  });

  test('constancia con examen conserva flujo de examen', () {
    final constancia = makeConstancia(<String, dynamic>{
      'tipo_examen': 'LINEA',
      'resultado': 'APROBADO',
      'examen': <String, dynamic>{
        'modalidad': 'LINEA',
        'resultado': 'APROBADO',
      },
    });

    expect(constancia.tieneFlujoExamen, isTrue);
    expect(constancia.puedeActivarDirectamente, isFalse);
  });

  test('lee edad y resultado del envio de WhatsApp', () {
    final constancia = makeConstancia(<String, dynamic>{
      'edad': 29,
      '_response_message': 'Constancia activada y enviada por WhatsApp.',
      '_whatsapp_sent': true,
      '_whatsapp_status': 'enviado',
    });

    expect(constancia.edad, 29);
    expect(constancia.whatsappSent, isTrue);
    expect(constancia.whatsappStatus, 'enviado');
    expect(
      constancia.activationMessage,
      'Constancia activada y enviada por WhatsApp.',
    );
  });

  test('lee solucionario autenticado del examen', () {
    final examen = ConstanciaExamenSolicitud.fromJson(<String, dynamic>{
      'id': 7,
      'folio_examen': 'EX-000007',
      'token': 'token-examen',
      'nombre_solicitante': 'PERSONA PRUEBA',
      'sexo': 'HOMBRE',
      'tipo_licencia': 'AUTOMOVILISTA',
      'modalidad': 'IMPRESO',
      'estatus': 'PENDIENTE',
      'solucionario': <Map<String, dynamic>>[
        <String, dynamic>{
          'numero': 1,
          'pregunta': 'Que indica la luz roja?',
          'respuesta_correcta': 'Alto total',
        },
      ],
    });

    expect(examen.solucionario, hasLength(1));
    expect(examen.solucionario.single.numero, 1);
    expect(examen.solucionario.single.respuestaCorrecta, 'Alto total');
  });

  test('lee examen imprimible y su respuesta correcta', () {
    final examen = ConstanciaExamenImprimible.fromJson(<String, dynamic>{
      'tipo_licencia': 'MOTOCICLISTA',
      'label': 'Motociclista',
      'total_preguntas': 20,
      'disponible': true,
      'url_imprimir': 'https://example.test/examen.pdf',
      'solucionario': <Map<String, dynamic>>[
        <String, dynamic>{
          'numero': 1,
          'pregunta': 'Pregunta',
          'respuesta_correcta': 'Respuesta',
        },
      ],
    });

    expect(examen.disponible, isTrue);
    expect(examen.totalPreguntas, 20);
    expect(examen.solucionario.single.respuestaCorrecta, 'Respuesta');
  });
}
