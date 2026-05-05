import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';

class _VersionPolicy {
  final String minVersion;
  final String latestVersion;
  final bool force;
  final String storeUrl;
  final String marketUrl;
  final String message;
  final String storeName;

  const _VersionPolicy({
    required this.minVersion,
    required this.latestVersion,
    required this.force,
    required this.storeUrl,
    required this.marketUrl,
    required this.message,
    required this.storeName,
  });
}

class AppVersionService {
  static Future<void> enforceUpdateIfNeeded(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final data = await _fetchPolicy();
      final policy = _policyForCurrentPlatform(data);

      if (policy.minVersion.isEmpty && policy.latestVersion.isEmpty) return;

      final belowMin =
          policy.minVersion.isNotEmpty &&
          _compareSemver(current, policy.minVersion) < 0;
      final belowLatest =
          policy.latestVersion.isNotEmpty &&
          _compareSemver(current, policy.latestVersion) < 0;
      final needsUpdate = belowMin || belowLatest;
      if (!context.mounted) return;

      if (policy.force && needsUpdate) {
        await _showForcedDialog(
          context: context,
          message: policy.message.isEmpty
              ? 'Debes actualizar la app para continuar.'
              : policy.message,
          marketUrl: policy.marketUrl,
          storeUrl: policy.storeUrl,
        );
        return;
      }

      if (!policy.force && needsUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hay una actualización disponible en ${policy.storeName}',
            ),
            action: SnackBarAction(
              label: 'Actualizar',
              onPressed: () {
                _openStore(
                  marketUrl: policy.marketUrl,
                  storeUrl: policy.storeUrl,
                );
              },
            ),
          ),
        );
      }
    } catch (_) {}
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
    if (decoded is! Map<String, dynamic>) return {};

    final data = decoded['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return decoded;
  }

  static _VersionPolicy _policyForCurrentPlatform(Map<String, dynamic> raw) {
    final platform = Platform.isIOS
        ? 'ios'
        : (Platform.isAndroid ? 'android' : '');
    final upper = platform.toUpperCase();
    final nested = platform.isEmpty ? null : raw[platform];
    final sources = <Map<String, dynamic>>[
      if (nested is Map) Map<String, dynamic>.from(nested),
      raw,
    ];

    final minVersion = _firstString(sources, [
      if (platform.isNotEmpty) '${platform}_min_version',
      if (platform.isNotEmpty) '${upper}_MIN_VERSION',
      'min_version',
      'minimum_version',
    ]);
    final latestVersion = _firstString(sources, [
      if (platform.isNotEmpty) '${platform}_latest_version',
      if (platform.isNotEmpty) '${upper}_LATEST_VERSION',
      'latest_version',
    ]);
    final force = _firstBool(sources, [
      if (platform.isNotEmpty) '${platform}_force_update',
      if (platform.isNotEmpty) '${platform}_force',
      if (platform.isNotEmpty) '${upper}_FORCE_UPDATE',
      if (platform.isNotEmpty) '${upper}_FORCE',
      'force_update',
      'force',
    ]);
    final storeUrl = _firstString(sources, [
      if (platform.isNotEmpty) '${platform}_store_url',
      if (platform.isNotEmpty) '${upper}_STORE_URL',
      'store_url',
    ]);
    final marketUrl = _firstString(sources, [
      if (platform.isNotEmpty) '${platform}_market_url',
      if (platform.isNotEmpty) '${upper}_MARKET_URL',
      'market_url',
    ]);
    final message = _firstString(sources, [
      if (platform.isNotEmpty) '${platform}_message',
      if (platform.isNotEmpty) '${upper}_MESSAGE',
      'message',
    ]);

    return _VersionPolicy(
      minVersion: minVersion,
      latestVersion: latestVersion,
      force: force,
      storeUrl: storeUrl,
      marketUrl: marketUrl,
      message: message,
      storeName: Platform.isIOS ? 'App Store' : 'Play Store',
    );
  }

  static String _firstString(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        if (!source.containsKey(key)) continue;
        final value = source[key];
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  static bool _firstBool(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        if (!source.containsKey(key)) continue;
        return _asBool(source[key]);
      }
    }
    return false;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'si' ||
        text == 'sí';
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
      if (await _launchExternal(marketUrl)) return;
    }

    if (Platform.isIOS && _isIosStoreUrl(marketUrl)) {
      if (await _launchExternal(marketUrl)) return;
    }

    if (storeUrl.isNotEmpty) {
      await _launchExternal(storeUrl);
    }
  }

  static bool _isIosStoreUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    return uri.scheme == 'itms-apps' ||
        uri.scheme == 'itms' ||
        uri.host == 'apps.apple.com';
  }

  static Future<bool> _launchExternal(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (!await canLaunchUrl(uri)) return false;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return true;
  }

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
