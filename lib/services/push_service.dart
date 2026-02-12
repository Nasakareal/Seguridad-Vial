import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PushService {
  static bool _refreshListenerInstalled = false;
  static String? _lastSentFcm;

  static String get _platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  static Future<void> ensurePermissions() async {
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
  }

  static Future<void> registerDeviceToken({String reason = 'manual'}) async {
    final logged = await AuthService.isLoggedIn();
    if (!logged) return;

    final apiToken = await AuthService.getToken();
    if (apiToken == null || apiToken.isEmpty) return;

    final fcm = await FirebaseMessaging.instance.getToken();
    if (fcm == null || fcm.isEmpty) return;

    if (_lastSentFcm == fcm && reason != 'token_refresh') return;

    final uri = Uri.parse('${AuthService.baseUrl}/device-tokens');

    try {
      final res = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiToken',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': fcm,
              'platform': _platform,
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200 || res.statusCode == 201) {
        _lastSentFcm = fcm;
        return;
      }

      throw Exception('Error ${res.statusCode}: ${res.body}');
    } on TimeoutException {
      return;
    } catch (_) {
      return;
    }
  }

  static void listenTokenRefresh() {
    if (_refreshListenerInstalled) return;
    _refreshListenerInstalled = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _lastSentFcm = null;
      await registerDeviceToken(reason: 'token_refresh');
    });
  }
}
