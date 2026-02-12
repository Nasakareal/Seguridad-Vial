import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

import 'screens/sustento_legal/sustento_legal_home_screen.dart';
import 'screens/sustento_legal/sustento_legal_categoria_screen.dart';
import 'screens/sustento_legal/sustento_legal_detalle_screen.dart';
import 'screens/sustento_legal/sustento_legal_busqueda_screen.dart';

import 'screens/mapa/mapa_patrullas_screen.dart';

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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Importante: initializeApp puede fallar si el plist está mal/ausente.
  await Firebase.initializeApp();
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
      PushService.registerDeviceToken(reason: 'app_resumed');
    }
  }
}

Future<void> _initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

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
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Para que NO se quede blanco en release si truena algo:
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'ERROR:\n${details.exception}\n\n${details.stack}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
    return true; // evita crash silencioso
  };

  // 2) Firebase init protegido (si falla, mostramos el motivo en pantalla)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Text(
                    'Firebase.initializeApp() falló:\n\n$e',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

  await _initLocalNotifications();

  _AppLifecycleObserver.ensureInstalled();

  try {
    final logged = await AuthService.isLoggedIn();
    if (logged) {
      await PushService.registerDeviceToken(reason: 'app_start');
      PushService.listenTokenRefresh();
    }
  } catch (_) {}

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

  runApp(const SeguridadVialApp());
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
  static const String vehiculoConductorCreate =
      '/accidentes/vehiculos/conductor/create';

  static const String mapa = '/mapa';

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
}

class SeguridadVialApp extends StatefulWidget {
  const SeguridadVialApp({super.key});

  @override
  State<SeguridadVialApp> createState() => _SeguridadVialAppState();
}

class _SeguridadVialAppState extends State<SeguridadVialApp> {
  @override
  void initState() {
    super.initState();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final n = message.notification;
      if (n == null) return;

      await localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        n.title ?? 'Aviso',
        n.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            svAlertasChannel.id,
            svAlertasChannel.name,
            channelDescription: svAlertasChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      final type = (data['type'] ?? '').toString();
      final hechoId = (data['hecho_id'] ?? '').toString();

      if (type == 'HECHO_48H' || type == 'HECHO_72H') {
        navigatorKey.currentState?.pushNamed(
          AppRoutes.accidentesShow,
          arguments: {'id': hechoId},
        );
      }
    });
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
        AppRoutes.vehiculoConductorCreate: (context) =>
            const VehiculoConductorCreateScreen(),
        AppRoutes.mapa: (context) => const MapaPatrullasScreen(),
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
