import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PushService {
  static bool _refreshListenerInstalled = false;
  static bool _registering = false;
  static DateTime? _lastSuccessAt;

  static Future<void> ensurePermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
  }

  static void listenTokenRefresh() {
    if (_refreshListenerInstalled) return;
    _refreshListenerInstalled = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
      await registerDeviceToken(reason: 'token_refresh');
    });
  }

  static Future<void> registerDeviceToken({String reason = 'manual'}) async {
    if (_registering) return;

    final last = _lastSuccessAt;
    if (last != null) {
      final diff = DateTime.now().difference(last);
      if (diff.inSeconds < 20) return;
    }

    _registering = true;

    try {
      final logged = await AuthService.isLoggedIn();
      if (!logged) return;

      final apiToken = await AuthService.getToken();
      if (apiToken == null || apiToken.isEmpty) return;

      final fcm = await _getFcmTokenSafely(maxWait: const Duration(seconds: 6));
      if (fcm == null || fcm.isEmpty) return;

      final uri = Uri.parse('${AuthService.baseUrl}/device-tokens');

      final resp = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiToken',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': fcm,
              'platform': _platform(),
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _lastSuccessAt = DateTime.now();
      }
    } catch (_) {
    } finally {
      _registering = false;
    }
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  static Future<String?> _getFcmTokenSafely({required Duration maxWait}) async {
    final messaging = FirebaseMessaging.instance;

    final start = DateTime.now();
    int i = 0;

    while (DateTime.now().difference(start) < maxWait) {
      i++;

      try {
        if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
          try {
            final apns = await messaging.getAPNSToken();
            if (apns == null || apns.isEmpty) {
              await Future.delayed(Duration(milliseconds: 200 * i));
              continue;
            }
          } catch (_) {}
        }

        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (e) {
        final s = e.toString();
        if (s.contains('apns-token-not-set') ||
            s.contains('APNS token has not been received')) {
          await Future.delayed(Duration(milliseconds: 200 * i));
          continue;
        }
        return null;
      }

      await Future.delayed(Duration(milliseconds: 200 * i));
    }

    return null;
  }
}
