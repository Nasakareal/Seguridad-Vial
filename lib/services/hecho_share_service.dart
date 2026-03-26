import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'accidentes_service.dart';

class HechoShareService {
  static Future<void> compartirEnWhatsapp({required int hechoId}) async {
    try {
      final payload = await AccidentesService.fetchNativeShareData(
        hechoId: hechoId,
      );

      if (payload.message.trim().isNotEmpty) {
        await Share.share(payload.message, subject: payload.title);
        return;
      }

      await _abrirWhatsappDesdeBackend(hechoId);
      return;
    } catch (_) {
      await _abrirWhatsappDesdeBackend(hechoId);
    }
  }

  static Future<void> _abrirWhatsappDesdeBackend(int hechoId) async {
    final uri = await AccidentesService.fetchWhatsappUri(hechoId: hechoId);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened) {
      throw Exception('No se pudo abrir WhatsApp en este dispositivo.');
    }
  }
}
