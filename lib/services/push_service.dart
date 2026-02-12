import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PushService {
  static bool _refreshListenerInstalled = false;

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
    try {
      final logged = await AuthService.isLoggedIn();
      if (!logged) return;

      final apiToken = await AuthService.getToken();
      if (apiToken == null || apiToken.isEmpty) return;

      final fcm = await _getFcmTokenSafely();
      if (fcm == null || fcm.isEmpty) return;

      final uri = Uri.parse('${AuthService.baseUrl}/device-tokens');

      await http.post(
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
      );
    } catch (_) {}
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  static Future<String?> _getFcmTokenSafely() async {
    final messaging = FirebaseMessaging.instance;

    for (var i = 0; i < 8; i++) {
      try {
        if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
          try {
            final apns = await messaging.getAPNSToken();
            if (apns == null || apns.isEmpty) {
              await Future.delayed(Duration(milliseconds: 350 * (i + 1)));
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
          await Future.delayed(Duration(milliseconds: 350 * (i + 1)));
          continue;
        }
        return null;
      }
    }

    return null;
  }
}
