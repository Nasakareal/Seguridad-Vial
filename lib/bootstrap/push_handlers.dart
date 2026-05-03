import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/globals.dart';
import '../core/safe_payload.dart';
import '../firebase_options.dart';
import '../app/routes.dart';

Map<String, dynamic>? _pendingPushTapData;

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
      reportAppIssue('No se pudo abrir Google Maps: $uri');
    }
  } catch (e, st) {
    reportAppIssue('openMaps ERROR: $e\n\n$st');
  }
}

void handlePushTap(Map<String, dynamic> data) {
  try {
    final type = (data['type'] ?? '').toString();

    if (type == 'WAZE_ACCIDENT' || type == 'WAZE_ROAD_CLOSED') {
      unawaited(openMapsFromData(data));
      return;
    }

    if (type == 'GUARDIANES_REVISION') {
      navigatorKey.currentState?.pushNamed(AppRoutes.dispositivosRevision);
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
    reportAppIssue('handlePushTap ERROR: $e\n\n$st');
  }
}

void queuePushTap(Map<String, dynamic> data) {
  if (data.isEmpty) return;
  _pendingPushTapData = Map<String, dynamic>.from(data);
}

void flushPendingPushTap() {
  final pending = _pendingPushTapData;
  if (pending == null || pending.isEmpty) return;
  _pendingPushTapData = null;
  handlePushTap(pending);
}

String payloadFromData(Map<String, dynamic> data) {
  try {
    return jsonEncode(data);
  } catch (_) {
    return '{}';
  }
}
