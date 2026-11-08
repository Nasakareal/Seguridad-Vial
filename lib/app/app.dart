import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/globals.dart';
import '../core/platform_support.dart';
import '../widgets/alerts_listener.dart';
import '../widgets/offline_connection_banner.dart';
import '../widgets/offline_sync_listener.dart';
import '../widgets/screen_size_text_scale.dart';
import '../widgets/unit_branding_watermark.dart';
import '../services/auth_service.dart';
import '../services/auth_session_events.dart';
import 'routes.dart';

import 'auth_gate.dart';
import 'nav.dart';
import 'router_map.dart';

class SeguridadVialApp extends StatefulWidget {
  const SeguridadVialApp({super.key});

  @override
  State<SeguridadVialApp> createState() => _SeguridadVialAppState();
}

class _SeguridadVialAppState extends State<SeguridadVialApp> {
  Timer? _sessionRefreshTimer;
  int _lastSessionEventSequence = 0;

  @override
  void initState() {
    super.initState();
    AuthSessionEvents.notifier.addListener(_handleSessionEvent);
    _sessionRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(AuthService.refreshSessionContext());
    });
  }

  @override
  void dispose() {
    _sessionRefreshTimer?.cancel();
    AuthSessionEvents.notifier.removeListener(_handleSessionEvent);
    super.dispose();
  }

  void _handleSessionEvent() {
    final event = AuthSessionEvents.notifier.value;
    if (event == null || event.sequence <= _lastSessionEventSequence) return;
    _lastSessionEventSequence = event.sequence;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      if (event.type == AuthSessionEventType.signedOut) {
        navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        return;
      }

      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => _buildAuthRoot()),
        (_) => false,
      );
    });
  }

  static Widget _buildAuthRoot() {
    return const PushNavBinder(
      child: AlertsListener(child: OfflineSyncListener(child: AuthGate())),
    );
  }

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
        final sizeScaledChild = ScreenSizeTextScale(child: appChild);
        final brandedChild = UnitBrandingBackdrop(
          opacity: .022,
          widthFactor: .68,
          child: sizeScaledChild,
        );
        final offlineAwareChild = OfflineConnectionBanner(child: brandedChild);
        if (!supportsForegroundTaskShell) {
          return offlineAwareChild;
        }
        return WithForegroundTask(child: offlineAwareChild);
      },
      home: _buildAuthRoot(),
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
