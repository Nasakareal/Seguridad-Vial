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

bool get isDesktopTestPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
