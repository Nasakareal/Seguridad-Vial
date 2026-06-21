import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

bool get supportsPushMessaging {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

bool get supportsLocalNotifications {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

bool get supportsForegroundTaskShell {
  if (kIsWeb) return false;
  return Platform.isAndroid;
}

bool get supportsBackgroundLocationTracking {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

bool get isMobilePlatform {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

bool get isDesktopTestPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

String get currentPlatformLabel {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}
