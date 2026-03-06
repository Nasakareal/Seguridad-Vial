import 'package:flutter/material.dart';

import '../core/globals.dart';
import '../widgets/alerts_listener.dart';

import 'auth_gate.dart';
import 'routes.dart';
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
      home: const PushNavBinder(child: AlertsListener(child: AuthGate())),
      routes: appRoutesMap,
      onGenerateRoute: onGenerateRoute,
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => UnknownRouteScreen(routeName: settings.name ?? ''),
      ),
    );
  }
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
