import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PushService {
  static bool _refreshListenerInstalled = false;

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

    final uri = Uri.parse('${AuthService.baseUrl}/device-tokens');

    await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'token': fcm, 'platform': 'android', 'reason': reason}),
    );
  }

  static void listenTokenRefresh() {
    if (_refreshListenerInstalled) return;
    _refreshListenerInstalled = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
      await registerDeviceToken(reason: 'token_refresh');
    });
  }
}
