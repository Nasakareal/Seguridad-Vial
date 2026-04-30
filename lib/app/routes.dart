class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String homePerito = '/home-perito';
  static const String homeAgenteUpec = '/home-agente-upec';
  static const String profile = '/profile';
  static const String changePassword = '/profile/change-password';

  static const String accidentes = '/accidentes';
  static const String accidentesCreate = '/accidentes/create';
  static const String accidentesShow = '/accidentes/show';
  static const String accidentesEdit = '/accidentes/edit';
  static const String accidentesCroquis = '/accidentes/croquis';
  static const String pendingHechoCapture = '/accidentes/pending-capture';

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

  static const String puestasDisposicion = '/puestas-disposicion';
  static const String puestasDisposicionCreate = '/puestas-disposicion/create';

  static const String actividades = '/actividades';
  static const String actividadesCreate = '/actividades/create';
  static const String actividadesShow = '/actividades/show';
  static const String actividadesEdit = '/actividades/edit';

  static const String culturaVial = '/cultura-vial';
  static const String culturaVialSala = '/cultura-vial/sala';
  static const String culturaVialJoin = '/cultura-vial/join';

  static const String constanciasManejo = '/constancias-manejo';
  static const String constanciasManejoScanner = '/constancias-manejo/scanner';
  static const String constanciasManejoDetalle = '/constancias-manejo/detalle';

  static const String dispositivos = '/dispositivos';
  static const String dispositivosCreate = '/dispositivos/create';
  static const String dispositivosShow = '/dispositivos/show';
  static const String dispositivosRevision = '/dispositivos/revision';
  static const String vialidadesUrbanas = '/vialidades-urbanas';
  static const String vialidadesUrbanasCreate = '/vialidades-urbanas/create';
  static const String vialidadesUrbanasDispositivoShow =
      '/vialidades-urbanas/dispositivo/show';
  static const String vialidadesUrbanasDispositivoCreate =
      '/vialidades-urbanas/dispositivo/create';
  static const String vialidadesUrbanasDispositivoEdit =
      '/vialidades-urbanas/dispositivo/edit';

  static const String feed = '/feed';
  static const String offlineSyncErrors = '/offline-sync/errors';

  static const String pendientesCortes = '/pendientes/cortes';
  static const String pendientesCorteShow = '/pendientes/cortes/show';
}
