import 'package:audioplayers/audioplayers.dart';

class ComunicacionSoundService {
  static final AudioPlayer _sentPlayer = AudioPlayer();
  static final AudioPlayer _receivedPlayer = AudioPlayer();

  static Future<void> enviado() async {
    try {
      await _sentPlayer.stop();
      await _sentPlayer.play(AssetSource('sounds/message_sent.mp3'));
    } catch (_) {
      // El sonido es una confirmación secundaria: si el dispositivo está
      // silenciado o el reproductor falla, el mensaje ya enviado sigue siendo
      // un envío exitoso.
    }
  }

  static Future<void> recibido() async {
    try {
      await _receivedPlayer.stop();
      await _receivedPlayer.play(AssetSource('sounds/recibido.mp3'));
    } catch (_) {
      // La notificación visual y la actualización del chat deben continuar
      // aunque el dispositivo no permita reproducir audio.
    }
  }
}
