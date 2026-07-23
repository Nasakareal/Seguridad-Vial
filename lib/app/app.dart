import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/globals.dart';
import '../core/platform_support.dart';
import '../widgets/alerts_listener.dart';
import '../widgets/offline_connection_banner.dart';
import '../widgets/offline_sync_listener.dart';
import '../widgets/unit_branding_watermark.dart';

import 'auth_gate.dart';
import 'nav.dart';
import 'router_map.dart';

class SeguridadVialApp extends StatelessWidget {
  const SeguridadVialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [unitBrandingNavigatorObserver],
      title: 'Seguridad Vial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xED2196F3),
          surfaceTintColor: Color(0x33FFFFFF),
          elevation: 0,
          scrolledUnderElevation: 2,
          shadowColor: Color(0x2B1D4ED8),
          shape: Border(bottom: BorderSide(color: Color(0x66FFFFFF), width: 1)),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xF2F4F8FF),
          surfaceTintColor: Colors.white,
          elevation: 1,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xF2FFFFFF),
          surfaceTintColor: const Color(0x333B82F6),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0x80B8C9E5)),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xF5FFFFFF),
          modalBackgroundColor: Color(0xF5FFFFFF),
          surfaceTintColor: Color(0x263B82F6),
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xF5FFFFFF),
          surfaceTintColor: const Color(0x263B82F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0x80B8C9E5)),
          ),
        ),
      ),
      builder: (context, child) {
        final appChild = child ?? const SizedBox.shrink();
        final brandedChild = UnitBrandingBackdrop(
          opacity: .022,
          widthFactor: .68,
          child: appChild,
        );
        final offlineAwareChild = OfflineConnectionBanner(child: brandedChild);
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
