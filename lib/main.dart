import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

import 'services/auth_service.dart';
import 'services/push_service.dart';
import 'widgets/alerts_listener.dart';

import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

import 'screens/accidentes/accidentes_screen.dart';
import 'screens/accidentes/create_screen.dart';
import 'screens/accidentes/hecho_show_screen.dart';

import 'screens/vehiculos/vehiculos_screen.dart';
import 'screens/vehiculos/vehiculo_create_screen.dart';
import 'screens/vehiculos/vehiculo_edit_screen.dart';
import 'screens/vehiculos/vehiculo_conductor_create_screen.dart';
import 'screens/vehiculos/vehiculo_show_screen.dart';

import 'screens/sustento_legal/sustento_legal_home_screen.dart';
import 'screens/sustento_legal/sustento_legal_categoria_screen.dart';
import 'screens/sustento_legal/sustento_legal_detalle_screen.dart';
import 'screens/sustento_legal/sustento_legal_busqueda_screen.dart';

import 'screens/mapa/mapa_patrullas_screen.dart';
import 'screens/mapa/mapa_incidencias_screen.dart';

import 'screens/control_ubicacion/control_ubicacion_screen.dart';
import 'screens/gruas/gruas_screen.dart';
import 'screens/lesionados/lesionados_screen.dart';
import 'screens/lesionados/lesionado_create_screen.dart';
import 'screens/lesionados/lesionado_edit_screen.dart';
import 'screens/lesionados/lesionado_show_screen.dart';

import 'screens/busqueda/hechos_busqueda_screen.dart';

import 'screens/estadisticas/estadisticas_globales_home_screen.dart';
import 'screens/estadisticas/estadisticas_globales_hechos_screen.dart';

import 'screens/dictamenes/dictamenes_screen.dart';
import 'screens/dictamenes/dictamen_create_screen.dart';
import 'screens/dictamenes/dictamen_show_screen.dart';
import 'screens/dictamenes/dictamen_busqueda_screen.dart';

import 'screens/actividades/actividades_screen.dart';
import 'screens/actividades/actividad_create_screen.dart';
import 'screens/actividades/actividad_edit_screen.dart';
import 'screens/actividades/actividad_show_screen.dart';

import 'screens/pendientes/pendientes_cortes_screen.dart';
import 'screens/pendientes/pendiente_corte_show_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel svAlertasChannel = AndroidNotificationChannel(
  'SV_ALERTAS',
  'Alertas de Hechos',
  description: 'Notificaciones de 48h / 72h y recordatorios',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

final ValueNotifier<String?> bootFatal = ValueNotifier<String?>(null);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  static bool _running = false;

  static void ensureInstalled() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        PushService.registerDeviceToken(reason: 'app_resumed');
      } catch (_) {}
    }
  }
}

Future<void> _initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await localNotifications.initialize(initSettings);

  final androidPlugin = localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(svAlertasChannel);
  }
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        final msg = details.exceptionAsString();

        if (msg.contains('A RenderFlex overflowed by')) {
          FlutterError.presentError(details);
          return;
        }

        final st = details.stack ?? StackTrace.current;
        bootFatal.value = 'FLUTTER ERROR: $msg\n\n$st';
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        bootFatal.value = 'UNCAUGHT: $error\n\n$stack';
        return true;
      };

      runApp(const _BootApp());
    },
    (error, stack) {
      bootFatal.value = 'ZONED: $error\n\n$stack';
    },
  );
}

class _BootApp extends StatefulWidget {
  const _BootApp();

  @override
  State<_BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<_BootApp> {
  String step = 'Iniciando...';
  String? error;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      setState(() => step = 'Inicializando Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw Exception('TIMEOUT: Firebase.initializeApp tardó demasiado.'),
      );

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      setState(() => step = 'Permisos de notificaciones...');
      await PushService.ensurePermissions().timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw Exception('TIMEOUT: ensurePermissions tardó demasiado.'),
      );

      try {
        PushService.listenTokenRefresh();
      } catch (_) {}

      setState(() => step = 'Inicializando notificaciones locales...');
      await _initLocalNotifications().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception(
          'TIMEOUT: _initLocalNotifications tardó demasiado.',
        ),
      );

      _AppLifecycleObserver.ensureInstalled();

      setState(() => step = 'Validando sesión...');
      final logged = await AuthService.isLoggedIn().timeout(
        const Duration(seconds: 12),
        onTimeout: () =>
            throw Exception('TIMEOUT: AuthService.isLoggedIn tardó demasiado.'),
      );

      if (logged) {
        try {
          PushService.registerDeviceToken(reason: 'app_start');
        } catch (_) {}
      }

      setState(() => step = 'Inicializando servicio de ubicación...');
      if (Platform.isAndroid) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'seguridad_vial_tracking',
            channelName: 'Seguimiento de patrullas',
            channelDescription:
                'Envía la ubicación de la patrulla mientras el servicio esté activo',
            channelImportance: NotificationChannelImportance.LOW,
            priority: NotificationPriority.LOW,
          ),
          iosNotificationOptions: const IOSNotificationOptions(
            showNotification: true,
            playSound: false,
          ),
          foregroundTaskOptions: const ForegroundTaskOptions(
            interval: 10000,
            isOnceEvent: false,
            autoRunOnBoot: false,
            allowWakeLock: true,
            allowWifiLock: true,
          ),
        );
      }

      if (!mounted) return;
      setState(() => ready = true);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => error = '$e\n\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: bootFatal,
      builder: (context, fatal, _) {
        final showError = fatal ?? error;

        if (showError == null && ready) {
          return const SeguridadVialApp();
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Seguridad Vial',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          showError == null ? step : 'FALLÓ EN:\n$step',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (showError == null)
                          const CircularProgressIndicator()
                        else
                          Text(
                            showError,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';

  static const String accidentes = '/accidentes';
  static const String accidentesCreate = '/accidentes/create';
  static const String accidentesShow = '/accidentes/show';

  static const String vehiculos = '/accidentes/vehiculos';
  static const String vehiculosCreate = '/accidentes/vehiculos/create';
  static const String vehiculosEdit = '/accidentes/vehiculos/edit';
  static const String vehiculosShow = '/accidentes/vehiculos/show';
  static const String vehiculoConductorCreate =
      '/accidentes/vehiculos/conductor/create';

  static const String mapa = '/mapa';
  static const String mapaIncidencias = '/mapa-incidencias';

  static const String sustentoLegal = '/sustento-legal';
  static const String sustentoLegalCategoria = '/sustento-legal/categoria';
  static const String sustentoLegalDetalle = '/sustento-legal/detalle';
  static const String sustentoLegalBuscar = '/sustento-legal/buscar';

  static const String controlUbicacion = '/control-ubicacion';
  static const String gruas = '/gruas';

  static const String lesionados = '/lesionados';
  static const String lesionadoCreate = '/lesionados/create';
  static const String lesionadoEdit = '/lesionados/edit';
  static const String lesionadoShow = '/lesionados/show';

  static const String hechosBuscar = '/hechos/buscar';

  static const String estadisticasGlobales = '/estadisticas-globales';
  static const String estadisticasGlobalesHechos =
      '/estadisticas-globales/hechos';

  static const String dictamenes = '/dictamenes';
  static const String dictamenesCreate = '/dictamenes/create';
  static const String dictamenesShow = '/dictamenes/show';
  static const String dictamenesBuscar = '/dictamenes/buscar';

  static const String actividades = '/actividades';
  static const String actividadesCreate = '/actividades/create';
  static const String actividadesShow = '/actividades/show';
  static const String actividadesEdit = '/actividades/edit';

  static const String feed = '/feed';

  static const String pendientesCortes = '/pendientes/cortes';
  static const String pendientesCorteShow = '/pendientes/cortes/show';
}

class SeguridadVialApp extends StatefulWidget {
  const SeguridadVialApp({super.key});

  @override
  State<SeguridadVialApp> createState() => _SeguridadVialAppState();
}

class _SeguridadVialAppState extends State<SeguridadVialApp> {
  StreamSubscription<RemoteMessage>? _subOnMessage;
  StreamSubscription<RemoteMessage>? _subOnOpen;

  @override
  void initState() {
    super.initState();

    _subOnMessage = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) async {
      try {
        final n = message.notification;
        if (n == null) return;

        await localNotifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          n.title ?? 'Aviso',
          n.body ?? '',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'SV_ALERTAS',
              'Alertas de Hechos',
              channelDescription: 'Notificaciones de 48h / 72h y recordatorios',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      } catch (e, st) {
        bootFatal.value = 'onMessage ERROR: $e\n\n$st';
      }
    });

    _subOnOpen = FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage message,
    ) {
      try {
        final data = message.data;
        final type = (data['type'] ?? '').toString();
        final hechoId = (data['hecho_id'] ?? '').toString();

        if (hechoId.isEmpty) return;

        if (type == 'HECHO_48H' || type == 'HECHO_72H') {
          navigatorKey.currentState?.pushNamed(
            AppRoutes.accidentesShow,
            arguments: {'id': hechoId},
          );
        }
      } catch (e, st) {
        bootFatal.value = 'onMessageOpenedApp ERROR: $e\n\n$st';
      }
    });
  }

  @override
  void dispose() {
    _subOnMessage?.cancel();
    _subOnOpen?.cancel();
    super.dispose();
  }

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
      home: const AlertsListener(child: AuthGate()),
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.home: (context) => const HomeScreen(),

        AppRoutes.accidentes: (context) => const AccidentesScreen(),
        AppRoutes.accidentesCreate: (context) => const CreateHechoScreen(),
        AppRoutes.accidentesShow: (context) => const HechoShowScreen(),

        AppRoutes.vehiculos: (context) => const VehiculosScreen(),
        AppRoutes.vehiculosCreate: (context) => const VehiculoCreateScreen(),
        AppRoutes.vehiculosEdit: (context) => const VehiculoEditScreen(),
        AppRoutes.vehiculosShow: (context) => const VehiculoShowScreen(),
        AppRoutes.vehiculoConductorCreate: (context) =>
            const VehiculoConductorCreateScreen(),

        AppRoutes.mapa: (context) => const MapaPatrullasScreen(),
        AppRoutes.mapaIncidencias: (context) => const MapaIncidenciasScreen(),

        AppRoutes.sustentoLegal: (context) => const SustentoLegalHomeScreen(),
        AppRoutes.sustentoLegalCategoria: (context) =>
            const SustentoLegalCategoriaScreen(),
        AppRoutes.sustentoLegalDetalle: (context) =>
            const SustentoLegalDetalleScreen(),
        AppRoutes.sustentoLegalBuscar: (context) =>
            const SustentoLegalBusquedaScreen(),

        AppRoutes.controlUbicacion: (context) => const ControlUbicacionScreen(),
        AppRoutes.gruas: (context) => const GruasScreen(),

        AppRoutes.lesionados: (context) => const LesionadosScreen(),
        AppRoutes.lesionadoCreate: (context) => const LesionadoCreateScreen(),
        AppRoutes.lesionadoEdit: (context) => const LesionadoEditScreen(),
        AppRoutes.lesionadoShow: (context) => const LesionadoShowScreen(),

        AppRoutes.hechosBuscar: (context) => const HechosBusquedaScreen(),

        AppRoutes.estadisticasGlobales: (context) =>
            const EstadisticasGlobalesHomeScreen(),
        AppRoutes.estadisticasGlobalesHechos: (context) =>
            const EstadisticasGlobalesHechosScreen(),

        AppRoutes.dictamenes: (context) => const DictamenesScreen(),
        AppRoutes.dictamenesCreate: (context) => const DictamenCreateScreen(),
        AppRoutes.dictamenesShow: (context) => const DictamenShowScreen(),
        AppRoutes.dictamenesBuscar: (context) =>
            const DictamenesBusquedaScreen(),

        AppRoutes.actividades: (context) => const ActividadesScreen(),
        AppRoutes.actividadesCreate: (context) => const ActividadCreateScreen(),
        AppRoutes.actividadesShow: (context) => const ActividadShowScreen(),
        AppRoutes.actividadesEdit: (context) => const ActividadEditScreen(),

        AppRoutes.pendientesCortes: (context) => const PendientesCortesScreen(),
        AppRoutes.pendientesCorteShow: (context) =>
            const PendienteCorteShowScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => UnknownRouteScreen(routeName: settings.name ?? ''),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const HomeScreen() : const WelcomeScreen();
      },
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
