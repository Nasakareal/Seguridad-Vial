import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

final ValueNotifier<String?> bootFatal = ValueNotifier<String?>(null);

bool _appBootCompleted = false;

void markAppBootCompleted() {
  _appBootCompleted = true;
}

void reportBootFatal(String message) {
  bootFatal.value = message;
}

void reportRuntimeIssue(String message) {
  debugPrint(message);
}

void reportAppIssue(String message) {
  if (_appBootCompleted) {
    reportRuntimeIssue(message);
    return;
  }
  reportBootFatal(message);
}
