import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/globals.dart';
import '../core/platform_support.dart';
import '../widgets/alerts_listener.dart';
import '../widgets/offline_connection_banner.dart';
import '../widgets/offline_sync_listener.dart';

import 'auth_gate.dart';
import 'nav.dart';
import 'router_map.dart';

class SeguridadVialApp extends StatelessWidget {
  const SeguridadVialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Seguridad Vial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      builder: (context, child) {
        final appChild = child ?? const SizedBox.shrink();
        final offlineAwareChild = OfflineConnectionBanner(child: appChild);
        if (!supportsForegroundTaskShell) {
          return offlineAwareChild;
        }
        return WithForegroundTask(child: offlineAwareChild);
      },
      home: const PushNavBinder(
        child: AlertsListener(child: OfflineSyncListener(child: AuthGate())),
      ),
      routes: appRoutesMap,
      onGenerateRoute: _generateRoute,
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => UnknownRouteScreen(routeName: settings.name ?? ''),
      ),
    );
  }
}

Route<dynamic>? _generateRoute(RouteSettings settings) {
  final staticBuilder = appRoutesMap[settings.name];
  if (staticBuilder != null) {
    return MaterialPageRoute(builder: staticBuilder, settings: settings);
  }

  return onGenerateRoute(settings);
}

class UnknownRouteScreen extends StatelessWidget {
  final String routeName;
  const UnknownRouteScreen({super.key, required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta no encontrada')),
      body: Center(child: Text('No existe la ruta: $routeName')),
    );
  }
}
