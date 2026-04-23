import 'package:flutter/material.dart';

import 'package:seguridad_vial_app/app/routes.dart';

import '../screens/login_screen.dart';
import '../screens/home_agente_upec_screen.dart';
import '../screens/home_screen.dart';
import '../screens/home_perito_screen.dart';

import '../screens/accidentes/accidentes_screen.dart';
import '../screens/accidentes/create_screen.dart';
import '../screens/accidentes/croquis/croquis_screen.dart';
import '../screens/accidentes/edit_screen.dart';
import '../screens/accidentes/hecho_show_screen.dart';
import '../screens/accidentes/pending_capture_screen.dart';

import '../screens/vehiculos/vehiculos_screen.dart';
import '../screens/vehiculos/vehiculo_create_screen.dart';
import '../screens/vehiculos/vehiculo_edit_screen.dart';
import '../screens/vehiculos/vehiculo_conductor_create_screen.dart';
import '../screens/vehiculos/vehiculo_show_screen.dart';

import '../screens/sustento_legal/sustento_legal_home_screen.dart';
import '../screens/sustento_legal/sustento_legal_categoria_screen.dart';
import '../screens/sustento_legal/sustento_legal_detalle_screen.dart';
import '../screens/sustento_legal/sustento_legal_busqueda_screen.dart';

import '../screens/mapa/mapa_patrullas_screen.dart';
import '../screens/mapa/mapa_incidencias_screen.dart';

import '../screens/control_ubicacion/control_ubicacion_screen.dart';
import '../screens/gruas/gruas_screen.dart';

import '../screens/lesionados/lesionados_screen.dart';
import '../screens/lesionados/lesionado_create_screen.dart';
import '../screens/lesionados/lesionado_edit_screen.dart';
import '../screens/lesionados/lesionado_show_screen.dart';

import '../screens/busqueda/hechos_busqueda_screen.dart';

import '../screens/estadisticas/estadisticas_globales_home_screen.dart';
import '../screens/estadisticas/estadisticas_globales_hechos_screen.dart';

import '../screens/dictamenes/dictamenes_screen.dart';
import '../screens/dictamenes/dictamen_create_screen.dart';
import '../screens/dictamenes/dictamen_show_screen.dart';
import '../screens/dictamenes/dictamen_busqueda_screen.dart';
import '../screens/puestas_disposicion/puesta_disposicion_create_screen.dart';
import '../screens/puestas_disposicion/puestas_disposicion_screen.dart';
import '../screens/offline/offline_failed_operations_screen.dart';

import '../screens/actividades/actividades_screen.dart';
import '../screens/actividades/actividad_create_screen.dart';
import '../screens/actividades/actividad_edit_screen.dart';
import '../screens/actividades/actividad_show_screen.dart';
import '../screens/dispositivos/dispositivo_create_screen.dart';
import '../screens/dispositivos/dispositivo_show_screen.dart';
import '../screens/dispositivos/dispositivos_revision_screen.dart';
import '../screens/dispositivos/dispositivos_screen.dart';
import '../screens/vialidades_urbanas/vialidades_urbanas_create_screen.dart';
import '../screens/vialidades_urbanas/vialidades_urbanas_dispositivo_form_screen.dart';
import '../screens/vialidades_urbanas/vialidades_urbanas_dispositivo_show_screen.dart';
import '../screens/vialidades_urbanas/vialidades_urbanas_screen.dart';

import '../screens/pendientes/pendientes_cortes_screen.dart';
import '../screens/pendientes/pendiente_corte_show_screen.dart';

final Map<String, WidgetBuilder> appRoutesMap = {
  AppRoutes.login: (context) => const LoginScreen(),
  AppRoutes.home: (context) => const HomeScreen(),
  AppRoutes.homePerito: (context) => const HomePeritoScreen(),
  AppRoutes.homeAgenteUpec: (context) => const HomeAgenteUpecScreen(),

  AppRoutes.accidentes: (context) => const AccidentesScreen(),
  AppRoutes.accidentesCreate: (context) => const CreateHechoScreen(),
  AppRoutes.accidentesShow: (context) => const HechoShowScreen(),
  AppRoutes.accidentesCroquis: (context) => const CroquisScreen(),
  AppRoutes.pendingHechoCapture: (context) => const PendingHechoCaptureScreen(),

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
  AppRoutes.dictamenesBuscar: (context) => const DictamenesBusquedaScreen(),
  AppRoutes.puestasDisposicion: (context) => const PuestasDisposicionScreen(),
  AppRoutes.puestasDisposicionCreate: (context) =>
      const PuestaDisposicionCreateScreen(),
  AppRoutes.offlineSyncErrors: (context) =>
      const OfflineFailedOperationsScreen(),

  AppRoutes.actividades: (context) => const ActividadesScreen(),
  AppRoutes.actividadesCreate: (context) => const ActividadCreateScreen(),
  AppRoutes.actividadesShow: (context) => const ActividadShowScreen(),
  AppRoutes.actividadesEdit: (context) => const ActividadEditScreen(),
  AppRoutes.dispositivos: (context) => const DispositivosScreen(),
  AppRoutes.dispositivosCreate: (context) => const DispositivoCreateScreen(),
  AppRoutes.dispositivosRevision: (context) =>
      const DispositivosRevisionScreen(),
  AppRoutes.vialidadesUrbanas: (context) => const VialidadesUrbanasScreen(),
  AppRoutes.vialidadesUrbanasCreate: (context) =>
      const VialidadesUrbanasCreateScreen(),

  AppRoutes.pendientesCortes: (context) => const PendientesCortesScreen(),
  AppRoutes.pendientesCorteShow: (context) => const PendienteCorteShowScreen(),
};

int? _readHechoIdFromArgs(Object? args) {
  if (args == null) return null;
  if (args is int) return args;
  if (args is String) return int.tryParse(args);
  if (args is Map) {
    final raw = args['id'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
  }
  return null;
}

int? _readDispositivoIdFromArgs(Object? args) {
  if (args == null) return null;
  if (args is int) return args;
  if (args is String) return int.tryParse(args);
  if (args is Map) {
    final raw = args['dispositivoId'] ?? args['id'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
  }
  return null;
}

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? '';

  if (name == AppRoutes.accidentesEdit) {
    final id = _readHechoIdFromArgs(settings.arguments);
    if (id == null) {
      return MaterialPageRoute(
        builder: (_) => const _UnknownArgsScreen(
          routeName: '/accidentes/edit',
          message: 'sin id',
        ),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      builder: (_) => EditHechoScreen(hechoId: id),
      settings: settings,
    );
  }

  if (name == AppRoutes.vialidadesUrbanasDispositivoShow) {
    final id = _readDispositivoIdFromArgs(settings.arguments);
    if (id == null) {
      return MaterialPageRoute(
        builder: (_) => const _UnknownArgsScreen(
          routeName: '/vialidades-urbanas/dispositivo/show',
          message: 'sin dispositivoId',
        ),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      builder: (_) => VialidadesUrbanasDispositivoShowScreen(dispositivoId: id),
      settings: settings,
    );
  }

  if (name == AppRoutes.dispositivosShow) {
    final id = _readDispositivoIdFromArgs(settings.arguments);
    if (id == null) {
      return MaterialPageRoute(
        builder: (_) => const _UnknownArgsScreen(
          routeName: '/dispositivos/show',
          message: 'sin dispositivoId',
        ),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      builder: (_) => DispositivoShowScreen(dispositivoId: id),
      settings: settings,
    );
  }

  if (name == AppRoutes.vialidadesUrbanasDispositivoCreate) {
    final id = _readDispositivoIdFromArgs(settings.arguments);
    if (id == null) {
      return MaterialPageRoute(
        builder: (_) => const _UnknownArgsScreen(
          routeName: '/vialidades-urbanas/dispositivo/create',
          message: 'sin dispositivoId',
        ),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      builder: (_) => VialidadesUrbanasDispositivoFormScreen(
        dispositivoId: id,
        isEditing: false,
      ),
      settings: settings,
    );
  }

  if (name == AppRoutes.vialidadesUrbanasDispositivoEdit) {
    final id = _readDispositivoIdFromArgs(settings.arguments);
    if (id == null) {
      return MaterialPageRoute(
        builder: (_) => const _UnknownArgsScreen(
          routeName: '/vialidades-urbanas/dispositivo/edit',
          message: 'sin dispositivoId',
        ),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      builder: (_) => VialidadesUrbanasDispositivoFormScreen(
        dispositivoId: id,
        isEditing: true,
      ),
      settings: settings,
    );
  }

  return null;
}

class _UnknownArgsScreen extends StatelessWidget {
  final String routeName;
  final String message;

  const _UnknownArgsScreen({required this.routeName, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta inválida')),
      body: Center(child: Text('Ruta: $routeName ($message)')),
    );
  }
}
