import 'package:flutter/material.dart';

import 'package:seguridad_vial_app/app/routes.dart';

import '../models/comunicacion_usuario.dart';

import '../screens/comunicaciones/comunicaciones_screen.dart';
import '../screens/comunicaciones/conversacion_screen.dart';
import '../screens/comunicaciones/comunicacion_detalle_screen.dart';
import '../screens/comunicaciones/comunicacion_create_screen.dart';
import '../services/auth_service.dart';
import '../services/comunicacion_service.dart';

import '../models/conduce_legalidad.dart';
import '../screens/login_screen.dart';
import '../screens/home_agente_vial_screen.dart';
import '../screens/home_agente_upec_screen.dart';
import '../screens/home_delegaciones_screen.dart';
import '../screens/home_fenix_screen.dart';
import '../screens/home_motociclista_screen.dart';
import '../screens/home_screen.dart';
import '../screens/home_perito_screen.dart';
import '../screens/account/change_password_screen.dart';
import '../screens/account/profile_screen.dart';
import '../screens/mis_capturas/mis_capturas_screen.dart';
import '../screens/notes/user_notes_screen.dart';
import '../screens/settings/personal_incidencia_form_screen.dart';
import '../screens/settings/personal_show_screen.dart';
import '../screens/settings/settings_home_screen.dart';
import '../screens/settings/settings_personal_screen.dart';
import '../screens/settings/settings_statistics_files_screen.dart';
import '../screens/settings/user_form_screen.dart';
import '../screens/settings/user_show_screen.dart';
import '../screens/settings/users_screen.dart';
import '../screens/tutoriales/tutoriales_screen.dart';
import '../screens/red_apoyo/directorio_red_apoyo_screen.dart';
import '../screens/red_apoyo/directorio_red_apoyo_show_screen.dart';

import '../screens/accidentes/accidentes_screen.dart';
import '../screens/accidentes/create_screen.dart';
import '../screens/accidentes/croquis/croquis_screen.dart';
import '../screens/accidentes/edit_screen.dart';
import '../screens/accidentes/hecho_show_screen.dart';
import '../screens/accidentes/pending_capture_screen.dart';
import '../screens/accidentes/seguimiento_hechos_screen.dart';

import '../screens/vehiculos/vehiculos_screen.dart';
import '../screens/vehiculos/vehiculo_create_screen.dart';
import '../screens/vehiculos/vehiculo_edit_screen.dart';
import '../screens/vehiculos/vehiculo_conductor_create_screen.dart';
import '../screens/vehiculos/vehiculo_show_screen.dart';

import '../screens/sustento_legal/sustento_legal_home_screen.dart';
import '../screens/sustento_legal/sustento_legal_categoria_screen.dart';
import '../screens/sustento_legal/sustento_legal_detalle_screen.dart';
import '../screens/sustento_legal/sustento_legal_busqueda_screen.dart';
import '../screens/herramientas/velocidad_huella_frenado_screen.dart';
import '../screens/herramientas/velocidad_deformacion_laminas_screen.dart';
import '../screens/herramientas/rnd_faltas_administrativas_screen.dart';
import '../screens/herramientas/reconstructor_transito_2d_screen.dart';

import '../screens/mapa/mapa_patrullas_screen.dart';
import '../screens/mapa/mapa_incidencias_screen.dart';

import '../screens/control_ubicacion/control_ubicacion_screen.dart';
import '../screens/control_semaforico/control_semaforico_screen.dart';
import '../screens/semaforos_talleres/semaforos_talleres_screen.dart';
import '../screens/gruas/gruas_screen.dart';

import '../screens/lesionados/lesionados_screen.dart';
import '../screens/lesionados/lesionado_create_screen.dart';
import '../screens/lesionados/lesionado_edit_screen.dart';
import '../screens/lesionados/lesionado_show_screen.dart';

import '../screens/busqueda/hechos_busqueda_screen.dart';

import '../screens/estadisticas/estadisticas_globales_home_screen.dart';
import '../screens/estadisticas/estadisticas_globales_hechos_screen.dart';
import '../screens/estadisticas/estadisticas_actividades_home_screen.dart';

import '../screens/dictamenes/dictamenes_screen.dart';
import '../screens/dictamenes/dictamen_create_screen.dart';
import '../screens/dictamenes/dictamen_show_screen.dart';
import '../screens/dictamenes/dictamen_busqueda_screen.dart';
import '../screens/puestas_disposicion/puesta_disposicion_create_screen.dart';
import '../screens/puestas_disposicion/puesta_disposicion_show_screen.dart';
import '../screens/puestas_disposicion/puestas_disposicion_screen.dart';
import '../screens/offline/offline_failed_operations_screen.dart';

import '../screens/actividades/actividades_screen.dart';
import '../screens/actividades/actividad_create_screen.dart';
import '../screens/actividades/actividad_edit_screen.dart';
import '../screens/actividades/actividad_show_screen.dart';
import '../screens/motociclista/motociclista_report_form_screen.dart';
import '../screens/motociclista/motociclista_reports_screen.dart';
import '../screens/cultura_vial/cultura_vial_home_screen.dart';
import '../screens/cultura_vial/cultura_vial_join_screen.dart';
import '../screens/constancias_manejo/constancias_manejo_screen.dart';
import '../screens/constancias_manejo/constancia_manejo_scan_screen.dart';
import '../screens/licencias_puntos/licencias_puntos_screen.dart';
import '../screens/licencias_puntos/licencias_puntos_public_screen.dart';
import '../screens/conduce_legalidad/conduce_legalidad_captura_screen.dart';
import '../screens/conduce_legalidad/conduce_legalidad_boleta_screen.dart';
import '../screens/conduce_legalidad/conduce_legalidad_module.dart';
import '../screens/conduce_legalidad/conduce_legalidad_operativo_form_screen.dart';
import '../screens/conduce_legalidad/conduce_legalidad_screen.dart';
import '../screens/conduce_legalidad/conduce_legalidad_show_screen.dart';
import '../screens/modulo_examenes_diarios/modulo_examenes_diarios_screen.dart';
import '../screens/operativos/operativos_screen.dart';
import '../screens/dispositivos/dispositivo_create_screen.dart';
import '../screens/dispositivos/dispositivo_show_screen.dart';
import '../screens/dispositivos/dispositivos_revision_screen.dart';
import '../screens/dispositivos/dispositivos_screen.dart';
import '../screens/delegaciones/delegaciones_actividades_fisicas_screen.dart';
import '../screens/delegaciones/delegaciones_excel_revision_screen.dart';
import '../screens/vialidades_urbanas/vialidades_urbanas_create_screen.dart';
import '../screens/vialidades_urbanas/vialidades_urbanas_dispositivo_form_screen.dart';
import '../screens/vialidades_urbanas/vialidades_urbanas_dispositivo_show_screen.dart';
import '../screens/vialidades_urbanas/vialidades_urbanas_screen.dart';

import '../screens/pendientes/pendientes_cortes_screen.dart';
import '../screens/pendientes/pendiente_corte_show_screen.dart';
import '../widgets/constancias_manejo_schedule_guard.dart';

final Map<String, WidgetBuilder> appRoutesMap = {
  AppRoutes.login: (context) => const LoginScreen(),
  AppRoutes.home: (context) => const HomeScreen(),
  AppRoutes.homePerito: (context) => const HomePeritoScreen(),
  AppRoutes.homeAgenteUpec: (context) => const HomeAgenteUpecScreen(),
  AppRoutes.homeAgenteVial: (context) => const HomeAgenteVialScreen(),
  AppRoutes.homeMotociclista: (context) => const HomeMotociclistaScreen(),
  AppRoutes.homeFenix: (context) => const HomeFenixScreen(),
  AppRoutes.motociclistaReporte: (context) =>
      const MotociclistaReportFormScreen(),
  AppRoutes.motociclistaReportes: (context) =>
      const MotociclistaReportsScreen(),
  AppRoutes.homeDelegaciones: (context) => const HomeDelegacionesScreen(),
  AppRoutes.profile: (context) => const ProfileScreen(),
  AppRoutes.changePassword: (context) => const ChangePasswordScreen(),
  AppRoutes.misCapturas: (context) => const MisCapturasScreen(),
  AppRoutes.notes: (context) => const UserNotesScreen(),
  AppRoutes.comunicaciones: (context) => _ComunicacionesServiceLoader(
    builder: (service) => ComunicacionesScreen(service: service),
  ),
  AppRoutes.comunicacionesCreate: (context) => _ComunicacionesServiceLoader(
    builder: (service) => ComunicacionCreateScreen(service: service),
  ),
  AppRoutes.settings: (context) => const SettingsHomeScreen(),
  AppRoutes.users: (context) => const SettingsUsersScreen(),
  AppRoutes.usersCreate: (context) => const UserCreateScreen(),
  AppRoutes.usersShow: (context) => const UserShowScreen(),
  AppRoutes.usersEdit: (context) => const UserEditScreen(),
  AppRoutes.settingsPersonal: (context) => const SettingsPersonalScreen(),
  AppRoutes.settingsPersonalShow: (context) => const PersonalShowScreen(),
  AppRoutes.settingsPersonalIncidenciaCreate: (context) =>
      const PersonalIncidenciaCreateScreen(),
  AppRoutes.settingsStatisticsFiles: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return SettingsStatisticsFilesScreen(
      initialModuleId: args is String ? args : null,
    );
  },
  AppRoutes.tutoriales: (context) => const TutorialesScreen(),
  AppRoutes.directorioRedApoyo: (context) => const DirectorioRedApoyoScreen(),
  AppRoutes.directorioRedApoyoShow: (context) =>
      const DirectorioRedApoyoShowScreen(),

  AppRoutes.accidentes: (context) => const AccidentesScreen(),
  AppRoutes.accidentesCreate: (context) => const CreateHechoScreen(),
  AppRoutes.accidentesShow: (context) => const HechoShowScreen(),
  AppRoutes.accidentesCroquis: (context) => const CroquisScreen(),
  AppRoutes.hechosSeguimiento: (context) => const SeguimientoHechosScreen(),
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
  AppRoutes.herramientasVelocidadFrenado: (context) =>
      const VelocidadHuellaFrenadoScreen(),
  AppRoutes.herramientasVelocidadDeformacion: (context) =>
      const VelocidadDeformacionLaminasScreen(),
  AppRoutes.herramientasRndFaltas: (context) =>
      const RndFaltasAdministrativasScreen(),
  AppRoutes.herramientasReconstructorTransito2d: (context) =>
      const ReconstructorTransito2dScreen(),

  AppRoutes.controlUbicacion: (context) => const ControlUbicacionScreen(),
  AppRoutes.controlSemaforico: (context) => const ControlSemaforicoScreen(),
  AppRoutes.semaforosTalleres: (context) => const SemaforosTalleresScreen(),
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
  AppRoutes.estadisticasActividades: (context) =>
      const EstadisticasActividadesHomeScreen(),

  AppRoutes.dictamenes: (context) => const DictamenesScreen(),
  AppRoutes.dictamenesCreate: (context) => const DictamenCreateScreen(),
  AppRoutes.dictamenesShow: (context) => const DictamenShowScreen(),
  AppRoutes.dictamenesBuscar: (context) => const DictamenesBusquedaScreen(),
  AppRoutes.puestasDisposicion: (context) => const PuestasDisposicionScreen(),
  AppRoutes.puestasDisposicionCreate: (context) =>
      const PuestaDisposicionCreateScreen(),
  AppRoutes.puestasDisposicionShow: (context) =>
      const PuestaDisposicionShowScreen(),
  AppRoutes.offlineSyncErrors: (context) =>
      const OfflineFailedOperationsScreen(),

  AppRoutes.actividades: (context) => const ActividadesScreen(),
  AppRoutes.actividadesCreate: (context) => const ActividadCreateScreen(),
  AppRoutes.actividadesShow: (context) => const ActividadShowScreen(),
  AppRoutes.actividadesEdit: (context) => const ActividadEditScreen(),
  AppRoutes.culturaVial: (context) => const CulturaVialHomeScreen(),
  AppRoutes.culturaVialSala: (context) => const CulturaVialSalaScreen(),
  AppRoutes.culturaVialJoin: (context) => const CulturaVialJoinScreen(),
  AppRoutes.constanciasManejo: (context) =>
      const ConstanciasManejoScheduleGuard(child: ConstanciasManejoScreen()),
  AppRoutes.constanciasManejoScanner: (context) =>
      const ConstanciasManejoScheduleGuard(child: ConstanciaManejoScanScreen()),
  AppRoutes.constanciasManejoDetalle: (context) =>
      const ConstanciasManejoScheduleGuard(
        child: ConstanciaManejoDetailScreen(),
      ),
  AppRoutes.licenciasPuntos: (context) => const LicenciasPuntosScreen(),
  AppRoutes.licenciasPuntosPublica: (context) =>
      const LicenciasPuntosPublicScreen(),
  AppRoutes.operativos: (context) => const OperativosScreen(),
  AppRoutes.conduceLegalidad: (context) => const ConduceLegalidadScreen(),
  AppRoutes.conduceLegalidadCreate: (context) =>
      const ConduceLegalidadOperativoFormScreen(),
  AppRoutes.alcoholimetria: (context) => const ConduceLegalidadScreen(
    module: ConduceLegalidadModule.alcoholimetria,
  ),
  AppRoutes.alcoholimetriaCreate: (context) =>
      const ConduceLegalidadOperativoFormScreen(
        module: ConduceLegalidadModule.alcoholimetria,
      ),
  AppRoutes.moduloExamenesDiarios: (context) =>
      const ModuloExamenesDiariosScreen(),
  AppRoutes.dispositivos: (context) => const DispositivosScreen(),
  AppRoutes.dispositivosCreate: (context) => const DispositivoCreateScreen(),
  AppRoutes.dispositivosRevision: (context) =>
      const DispositivosRevisionScreen(),
  AppRoutes.vialidadesUrbanas: (context) => const VialidadesUrbanasScreen(),
  AppRoutes.vialidadesUrbanasCreate: (context) =>
      const VialidadesUrbanasCreateScreen(),

  AppRoutes.pendientesCortes: (context) => const PendientesCortesScreen(),
  AppRoutes.pendientesCorteShow: (context) => const PendienteCorteShowScreen(),
  AppRoutes.delegacionesExcelRevision: (context) =>
      const DelegacionesExcelRevisionScreen(),
  AppRoutes.delegacionesActividadesFisicas: (context) =>
      const DelegacionesActividadesFisicasScreen(),
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

int? _readOperativoIdFromArgs(Object? args) {
  if (args == null) return null;
  if (args is int) return args;
  if (args is String) return int.tryParse(args);
  if (args is Map) {
    final raw = args['operativoId'] ?? args['id'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
  }
  return null;
}

ConduceLegalidadCaptura? _readConduceLegalidadCapturaFromArgs(Object? args) {
  if (args is Map && args['captura'] is ConduceLegalidadCaptura) {
    return args['captura'] as ConduceLegalidadCaptura;
  }
  return null;
}

ConduceLegalidadOperativo? _readConduceLegalidadOperativoFromArgs(
  Object? args,
) {
  if (args is Map && args['operativo'] is ConduceLegalidadOperativo) {
    return args['operativo'] as ConduceLegalidadOperativo;
  }
  return null;
}

int? _readCapturaIdFromArgs(Object? args) {
  if (args == null) return null;
  if (args is int) return args;
  if (args is String) return int.tryParse(args);
  if (args is Map) {
    final raw = args['capturaId'] ?? args['captura_id'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
  }
  return null;
}

ComunicacionUsuario? _readComunicacionUsuarioFromArgs(Object? args) {
  if (args is ComunicacionUsuario) {
    return args;
  }

  if (args is int) {
    return ComunicacionUsuario(id: args, nombre: 'Usuario');
  }

  if (args is String) {
    final id = int.tryParse(args);

    if (id != null) {
      return ComunicacionUsuario(id: id, nombre: 'Usuario');
    }
  }

  if (args is Map) {
    final rawId = args['userId'] ?? args['user_id'] ?? args['id'];

    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    if (id == null) {
      return null;
    }

    final nombre = args['nombre']?.toString().trim();

    return ComunicacionUsuario(
      id: id,
      nombre: nombre != null && nombre.isNotEmpty ? nombre : 'Usuario',
    );
  }

  return null;
}

int? _readComunicacionIdFromArgs(Object? args) {
  if (args is int) {
    return args;
  }

  if (args is String) {
    return int.tryParse(args);
  }

  if (args is Map) {
    final raw = args['comunicacionId'] ?? args['comunicacion_id'] ?? args['id'];

    if (raw is int) {
      return raw;
    }

    return int.tryParse(raw?.toString() ?? '');
  }

  return null;
}

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? '';
  final uri = Uri.tryParse(name);
  final routePath = uri?.path ?? name;

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

  if (name == AppRoutes.conduceLegalidadShow ||
      name == AppRoutes.alcoholimetriaShow) {
    final id = _readOperativoIdFromArgs(settings.arguments);
    if (id == null) {
      return MaterialPageRoute(
        builder: (_) => const _UnknownArgsScreen(
          routeName: '/operativo/show',
          message: 'sin operativoId',
        ),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      builder: (_) => ConduceLegalidadShowScreen(
        operativoId: id,
        highlightedCapturaId: _readCapturaIdFromArgs(settings.arguments),
        module: name == AppRoutes.alcoholimetriaShow
            ? ConduceLegalidadModule.alcoholimetria
            : ConduceLegalidadModule.conduceLegalidad,
      ),
      settings: settings,
    );
  }

  if (name == AppRoutes.conduceLegalidadCaptura ||
      name == AppRoutes.alcoholimetriaCaptura) {
    final id = _readOperativoIdFromArgs(settings.arguments);
    final captura = _readConduceLegalidadCapturaFromArgs(settings.arguments);
    if (id == null) {
      return MaterialPageRoute(
        builder: (_) => const _UnknownArgsScreen(
          routeName: '/operativo/captura',
          message: 'sin operativoId',
        ),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      builder: (_) => ConduceLegalidadCapturaScreen(
        operativoId: id,
        initialCaptura: captura,
        module: name == AppRoutes.alcoholimetriaCaptura
            ? ConduceLegalidadModule.alcoholimetria
            : ConduceLegalidadModule.conduceLegalidad,
      ),
      settings: settings,
    );
  }

  if (routePath == AppRoutes.conduceLegalidadBoleta ||
      routePath == AppRoutes.alcoholimetriaBoleta) {
    final args = settings.arguments;
    final operativo = _readConduceLegalidadOperativoFromArgs(args);
    final captura = _readConduceLegalidadCapturaFromArgs(args);
    final operativoId =
        _readOperativoIdFromArgs(args) ??
        int.tryParse(uri?.queryParameters['operativo'] ?? '') ??
        int.tryParse(uri?.queryParameters['operativoId'] ?? '');
    final capturaId =
        _readCapturaIdFromArgs(args) ??
        int.tryParse(uri?.queryParameters['captura'] ?? '') ??
        int.tryParse(uri?.queryParameters['capturaId'] ?? '');
    final preview = const {
      '1',
      'true',
      'si',
    }.contains((uri?.queryParameters['preview'] ?? '').trim().toLowerCase());

    return MaterialPageRoute(
      builder: (_) => ConduceLegalidadBoletaScreen(
        initialOperativo: operativo,
        initialCaptura: captura,
        operativoId: operativoId,
        capturaId: capturaId,
        preview: preview,
        module: routePath == AppRoutes.alcoholimetriaBoleta
            ? ConduceLegalidadModule.alcoholimetria
            : ConduceLegalidadModule.conduceLegalidad,
      ),
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

  if (routePath == AppRoutes.comunicacionesConversacion) {
    final usuario = _readComunicacionUsuarioFromArgs(settings.arguments);

    final userId =
        usuario?.id ??
        int.tryParse(
          uri?.queryParameters['userId'] ??
              uri?.queryParameters['user_id'] ??
              '',
        );

    if (userId == null) {
      return MaterialPageRoute(
        builder: (_) => const _UnknownArgsScreen(
          routeName: '/comunicaciones/conversacion',
          message: 'sin userId',
        ),
        settings: settings,
      );
    }

    final usuarioFinal =
        usuario ?? ComunicacionUsuario(id: userId, nombre: 'Usuario');

    return MaterialPageRoute(
      builder: (_) => _ComunicacionesServiceLoader(
        builder: (service) =>
            ConversacionScreen(service: service, usuario: usuarioFinal),
      ),
      settings: settings,
    );
  }

  if (routePath == AppRoutes.comunicacionesDetalle) {
    final comunicacionId =
        _readComunicacionIdFromArgs(settings.arguments) ??
        int.tryParse(
          uri?.queryParameters['comunicacionId'] ??
              uri?.queryParameters['comunicacion_id'] ??
              uri?.queryParameters['id'] ??
              '',
        );

    if (comunicacionId == null) {
      return MaterialPageRoute(
        builder: (_) => const _UnknownArgsScreen(
          routeName: '/comunicaciones/detalle',
          message: 'sin comunicacionId',
        ),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      builder: (_) => _ComunicacionesServiceLoader(
        builder: (service) => ComunicacionDetalleScreen(
          service: service,
          comunicacionId: comunicacionId,
        ),
      ),
      settings: settings,
    );
  }

  return null;
}

class _ComunicacionesServiceLoader extends StatefulWidget {
  final Widget Function(ComunicacionService service) builder;

  const _ComunicacionesServiceLoader({required this.builder});

  @override
  State<_ComunicacionesServiceLoader> createState() =>
      _ComunicacionesServiceLoaderState();
}

class _ComunicacionesServiceLoaderState
    extends State<_ComunicacionesServiceLoader> {
  late final Future<ComunicacionService> _serviceFuture;

  ComunicacionService? _service;

  @override
  void initState() {
    super.initState();

    _serviceFuture = _crearService();
  }

  Future<ComunicacionService> _crearService() async {
    final token = await AuthService.getToken();

    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final service = ComunicacionService(
      baseUrl: AuthService.baseUrl,
      token: token,
    );

    _service = service;

    return service;
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ComunicacionService>(
      future: _serviceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Comunicaciones')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error?.toString() ??
                      'No fue posible iniciar el módulo de comunicaciones.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return widget.builder(snapshot.data!);
      },
    );
  }
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
