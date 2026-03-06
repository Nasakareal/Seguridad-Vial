import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/globals.dart';
import '../core/safe_payload.dart';
import '../firebase_options.dart';
import '../app/routes.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> openMapsFromData(Map<String, dynamic> data) async {
  try {
    final mapsUrl = (data['maps_url'] ?? '').toString().trim();

    Uri? uri;
    if (mapsUrl.isNotEmpty) {
      uri = Uri.tryParse(mapsUrl);
    } else {
      final lat = parseDouble(data['lat']);
      final lng = parseDouble(data['lng']);
      if (lat != null && lng != null) {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        );
      }
    }

    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      bootFatal.value = 'No se pudo abrir Google Maps: $uri';
    }
  } catch (e, st) {
    bootFatal.value = 'openMaps ERROR: $e\n\n$st';
  }
}

void handlePushTap(Map<String, dynamic> data) {
  try {
    final type = (data['type'] ?? '').toString();

    if (type == 'WAZE_ACCIDENT') {
      unawaited(openMapsFromData(data));
      return;
    }

    final hechoId = (data['hecho_id'] ?? '').toString();
    if (hechoId.isEmpty) return;

    if (type == 'HECHO_48H' || type == 'HECHO_72H') {
      navigatorKey.currentState?.pushNamed(
        AppRoutes.accidentesShow,
        arguments: {'id': hechoId},
      );
    }
  } catch (e, st) {
    bootFatal.value = 'handlePushTap ERROR: $e\n\n$st';
  }
}

String payloadFromData(Map<String, dynamic> data) {
  try {
    return jsonEncode(data);
  } catch (_) {
    return '{}';
  }
}
