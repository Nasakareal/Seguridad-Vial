// lib/services/app_version_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';

class AppVersionService {
  static Future<void> enforceUpdateIfNeeded(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // ej: 1.2.0

      final data = await _fetchPolicy();

      final minV = (data['min_version'] ?? '') as String;
      final latestV = (data['latest_version'] ?? '') as String;
      final force = (data['force'] ?? false) == true;

      final storeUrl = (data['store_url'] ?? '') as String;
      final marketUrl = (data['market_url'] ?? '') as String;

      if (minV.isEmpty) return;

      final belowMin = _compareSemver(current, minV) < 0;
      final belowLatest =
          latestV.isNotEmpty && _compareSemver(current, latestV) < 0;

      // 🔒 UPDATE FORZADO
      if (force && belowMin) {
        final msg =
            (data['message'] ?? 'Debes actualizar para continuar.') as String;

        await _showForcedDialog(
          context: context,
          message: msg,
          marketUrl: marketUrl,
          storeUrl: storeUrl,
        );
        return;
      }

      // ℹ️ UPDATE OPCIONAL (no bloquea)
      if (!force && belowLatest && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Hay una actualización disponible en Play Store',
            ),
            action: SnackBarAction(
              label: 'Actualizar',
              onPressed: () {
                _openStore(marketUrl: marketUrl, storeUrl: storeUrl);
              },
            ),
          ),
        );
      }
    } catch (_) {
      // Si falla el check, no rompas la app
    }
  }

  static Future<Map<String, dynamic>> _fetchPolicy() async {
    final res = await http
        .get(
          Uri.parse('${AuthService.baseUrl}/app/version'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode < 200 || res.statusCode >= 300) return {};

    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Future<void> _showForcedDialog({
    required BuildContext context,
    required String message,
    required String marketUrl,
    required String storeUrl,
  }) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Actualización requerida'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  _openStore(marketUrl: marketUrl, storeUrl: storeUrl);
                },
                child: const Text('Actualizar'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _openStore({
    required String marketUrl,
    required String storeUrl,
  }) async {
    if (Platform.isAndroid && marketUrl.isNotEmpty) {
      final u = Uri.parse(marketUrl);
      if (await canLaunchUrl(u)) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (storeUrl.isNotEmpty) {
      final u = Uri.parse(storeUrl);
      if (await canLaunchUrl(u)) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// -1 si a < b | 0 si igual | 1 si a > b
  static int _compareSemver(String a, String b) {
    final pa = _parseSemver(a);
    final pb = _parseSemver(b);

    for (var i = 0; i < 3; i++) {
      if (pa[i] < pb[i]) return -1;
      if (pa[i] > pb[i]) return 1;
    }
    return 0;
  }

  static List<int> _parseSemver(String v) {
    final core = v.split('+').first.trim();
    final parts = core.split('.');
    int p(int i) => (i < parts.length) ? int.tryParse(parts[i]) ?? 0 : 0;
    return [p(0), p(1), p(2)];
  }
}
