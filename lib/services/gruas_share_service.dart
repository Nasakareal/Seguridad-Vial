import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class GruasShareService {
  static Future<void> compartirTextoEnWhatsapp({required String texto}) async {
    final message = texto.trim();
    if (message.isEmpty) {
      throw Exception('No hay informacion para compartir.');
    }

    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (opened) {
      return;
    }

    await Share.share(message);
  }
}
