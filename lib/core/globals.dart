import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

final ValueNotifier<String?> bootFatal = ValueNotifier<String?>(null);
