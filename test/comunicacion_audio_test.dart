import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/comunicacion.dart';
import 'package:seguridad_vial_app/models/comunicacion_adjunto.dart';

void main() {
  test('recognizes PTT audio attachments in communications', () {
    const audio = ComunicacionAdjunto(
      id: 9,
      tipo: 'audio',
      nombreOriginal: 'ptt.m4a',
      mimeType: 'audio/mp4',
      tamanoBytes: 2048,
      ancho: null,
      alto: null,
      url: 'https://example.test/api/comunicaciones/adjuntos/9',
    );

    const message = Comunicacion(
      id: 20,
      tipo: 'mensaje',
      asunto: null,
      contenido: null,
      alcance: 'usuario',
      remitenteUserId: 1,
      destinatarioUserId: 2,
      requiereEnterado: false,
      esMio: false,
      enviadoAt: null,
      remitente: null,
      destinatario: null,
      unidad: null,
      turno: null,
      rol: null,
      adjuntos: [audio],
    );

    expect(audio.esAudio, isTrue);
    expect(audio.esImagen, isFalse);
    expect(audio.nombre, 'ptt.m4a');
    expect(message.tieneAudio, isTrue);
    expect(message.tieneImagenes, isFalse);
  });
}
