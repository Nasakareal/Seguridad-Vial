<?php

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Response;
use App\Http\Controllers\ApoyoController;
use App\Http\Controllers\BusquedaController;
use App\Http\Controllers\CampanaController;
use App\Http\Controllers\CiudadanoLicenciaPuntosController;
use App\Http\Controllers\DocumentoHechoController;
use App\Http\Controllers\EstadisticasController;
use App\Http\Controllers\EstadisticasGlobalesController;
use App\Http\Controllers\EstadisticasActividadesController;
use App\Http\Controllers\EstadisticasAseguramientosController;

use App\Http\Controllers\FormatoController;
use App\Http\Controllers\GruaController;
use App\Http\Controllers\HechoFotoArchivoController;
use App\Http\Controllers\HechosController;
use App\Http\Controllers\HomeController;
use App\Http\Controllers\LiberacionController;
use App\Http\Controllers\LicenciaController;
use App\Http\Controllers\LicenciaPuntoCursoController;
use App\Http\Controllers\LicenciaPuntoInfraccionCatalogoController;
use App\Http\Controllers\LicenciaPuntosController;
use App\Http\Controllers\ListaController;
use App\Http\Controllers\MapaPatrullasController;
use App\Http\Controllers\MapaIncidenciasController;
use App\Http\Controllers\OficioController;
use App\Http\Controllers\PatrullaController;
use App\Http\Controllers\RoleController;
use App\Http\Controllers\ServiceScheduleController;
use App\Http\Controllers\ServicioController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\VehiculosController;
use App\Http\Controllers\LesionadoController;
use App\Http\Controllers\ActividadController;
use App\Http\Controllers\ActividadFotoArchivoController;
use App\Http\Controllers\DictamenController;
use App\Http\Controllers\PendientesCortesController;
use App\Http\Controllers\OperativoController;
use App\Http\Controllers\TramoController;
use App\Http\Controllers\GruaGuardiaController;
use App\Http\Controllers\GruaGuardiaSctController;
use App\Http\Controllers\GruaTramoController;
use App\Http\Controllers\TramoLookupController;
use App\Http\Controllers\DestacamentoController;
use App\Http\Controllers\DestacamentoRedApoyoController;
use App\Http\Controllers\WazeAlertWebController;
use App\Http\Controllers\RiesgoDashboardController;
use App\Http\Controllers\PuestaDisposicionController;
use App\Http\Controllers\PersonalController;
use App\Http\Controllers\PersonalContactoController;
use App\Http\Controllers\PersonalDomicilioController;
use App\Http\Controllers\PersonalEmergenciaController;
use App\Http\Controllers\PersonalAsignacionController;
use App\Http\Controllers\PersonalIncidenciaController;
use App\Http\Controllers\PersonalDocumentoController;
use App\Http\Controllers\PersonalFotoController;
use App\Http\Controllers\PersonalLicenciaController;
use App\Http\Controllers\DelegacionController;
use App\Http\Controllers\ExportController;
use App\Http\Controllers\BackupsSqlController;
use App\Http\Controllers\ModuloConstanciaExamenController;
use App\Http\Controllers\ArmamentoController;
use App\Http\Controllers\PatrullaKilometrajeController;
use App\Http\Controllers\RadarRiesgoController;
use App\Http\Controllers\ModuloExamenDiarioController;
use App\Http\Controllers\EstadisticasCarreterasController;
use App\Http\Controllers\GuardianesCaminoController;
use App\Http\Controllers\GuardianesCaminoDispositivoController;
use App\Http\Controllers\GuardianesCaminoDispositivoFotoController;
use App\Http\Controllers\ResumenEjecutivoController;
use App\Http\Controllers\EstadisticasSeguridadVialController;
use App\Http\Controllers\ZonaMapaController;
use App\Http\Controllers\MapaDelegacionesController;

use App\Http\Controllers\EstadisticasCarreterasSettingsController;
use App\Http\Controllers\EstadisticasSiniestrosSettingsController;
use App\Http\Controllers\EstadisticasDelegacionesSettingsController;
use App\Http\Controllers\EstadisticasFomentoSettingsController;
use App\Http\Controllers\EstadisticasVialidadSettingsController;

use App\Http\Controllers\VialidadesUrbanasController;
use App\Http\Controllers\VialidadesUrbanasDispositivoController;
use App\Http\Controllers\VialidadesUrbanasDispositivoFotoController;

use App\Http\Controllers\ConstanciaManejoController;
use App\Http\Controllers\ConstanciaExamenSolicitudController;
use App\Http\Controllers\ConstanciaExamenPublicoController;
use App\Http\Controllers\ConstanciaValidacionController;
use App\Http\Controllers\ConstanciaPreguntaController;

use App\Http\Controllers\GruaUsuarioController;
use App\Http\Controllers\LiberacionCorralonController;

use App\Http\Controllers\ActividadCategoriaController;
use App\Http\Controllers\ActividadSubcategoriaController;
use App\Http\Controllers\FomentoCulturaVialProgramaController;
use App\Http\Controllers\TutorialController;
use App\Http\Controllers\BoquillaDotacionController;

use App\Http\Controllers\ComunicacionController;

use App\Http\Controllers\CaleaDirectivaController;
use App\Http\Controllers\CaleaDirectivaVersionController;
use App\Http\Controllers\CaleaDirectivaSeccionController;
use App\Http\Controllers\CaleaDirectivaBloqueController;

Route::get('/', function () { return view('welcome'); })->name('welcome');

// Ruta para las constancias de manejo
Route::prefix('constancias-manejo')->group(function () {
    Route::get('/examen/{token}', [ConstanciaExamenPublicoController::class, 'iniciar'])->name('constancias_manejo.examen.iniciar');
    Route::post('/examen/{token}', [ConstanciaExamenPublicoController::class, 'guardar'])->name('constancias_manejo.examen.guardar');
    Route::get('/examen-escrito/{token}', [ConstanciaExamenPublicoController::class, 'escrito'])->name('constancias_manejo.examen.escrito');
    Route::get('/validar/{token}', [ConstanciaValidacionController::class, 'validar'])->name('constancias_manejo.validar');
    Route::get('/imprimir-lote-firmado', [ConstanciaManejoController::class, 'imprimirLoteFirmado'])->middleware('signed')->name('constancias_manejo.imprimir_lote_firmado');
});

Route::prefix('calea')->middleware(['auth', 'can:ver calea'])->group(function () {
    Route::get('/', [CaleaDirectivaController::class, 'index'])->name('calea.index');
    Route::get('/buscar', [CaleaDirectivaController::class, 'buscar'])->name('calea.buscar');
    Route::get('/estudio', [CaleaDirectivaController::class, 'estudio'])->name('calea.estudio');
    Route::get('/versiones/{version}/pdf', [CaleaDirectivaVersionController::class, 'pdf'])->name('calea.versiones.pdf');
    Route::get('/{directiva}', [CaleaDirectivaController::class, 'show'])->name('calea.show');
});

// Ruta para usuarios de las grúas, no convfundir para rutas para creacion de grúas y servicios
Route::prefix('grua-usuarios')->middleware(['auth','can:ver gruas'])->group(function () {
    Route::get('/', [GruaUsuarioController::class, 'index'])->name('grua_usuarios.index');
    Route::get('/create', [GruaUsuarioController::class, 'create'])->middleware('can:crear gruas')->name('grua_usuarios.create');
    Route::post('/', [GruaUsuarioController::class, 'store'])->middleware('can:crear gruas')->name('grua_usuarios.store');
    Route::get('/{gruaUsuario}/edit', [GruaUsuarioController::class, 'edit'])->middleware('can:editar gruas')->name('grua_usuarios.edit');
    Route::put('/{gruaUsuario}', [GruaUsuarioController::class, 'update'])->middleware('can:editar gruas')->name('grua_usuarios.update');
    Route::delete('/{gruaUsuario}', [GruaUsuarioController::class, 'destroy'])->middleware('can:eliminar gruas')->name('grua_usuarios.destroy');
});

// Rutas para las liberaciones de los vehículos del corralón
Route::prefix('liberaciones-corralon')->middleware(['auth','can:ver gruas'])->group(function () {
    Route::get('/', [LiberacionCorralonController::class, 'index'])->name('liberaciones_corralon.index');
    Route::get('/vehiculo/{vehiculo}', [LiberacionCorralonController::class, 'show'])->name('liberaciones_corralon.show');
    Route::get('/vehiculo/{vehiculo}/create', [LiberacionCorralonController::class, 'create'])->name('liberaciones_corralon.create');
    Route::post('/vehiculo/{vehiculo}', [LiberacionCorralonController::class, 'store'])->name('liberaciones_corralon.store');
    Route::get('/{liberacionCorralon}/edit', [LiberacionCorralonController::class, 'edit'])->name('liberaciones_corralon.edit');
    Route::put('/{liberacionCorralon}', [LiberacionCorralonController::class, 'update'])->name('liberaciones_corralon.update');
});

Route::prefix('grua/corralon')->middleware('auth:grua')->group(function () {
    Route::get('/', [LiberacionCorralonController::class, 'index'])->name('grua.corralon.index');
    Route::get('/vehiculo/{vehiculo}', [LiberacionCorralonController::class, 'show'])->name('grua.corralon.show');
    Route::post('/vehiculo/{vehiculo}', [LiberacionCorralonController::class, 'store'])->name('grua.corralon.store');
});

Route::prefix('constancias-manejo/preguntas')->middleware(['auth', 'can:ver configuraciones'])->group(function () {
    Route::get('/', [ConstanciaPreguntaController::class, 'index'])->name('constancias_manejo.preguntas.index');
    Route::get('/create', [ConstanciaPreguntaController::class, 'create'])->middleware('can:crear modulo examenes')->name('constancias_manejo.preguntas.create');
    Route::post('/', [ConstanciaPreguntaController::class, 'store'])->middleware('can:crear modulo examenes')->name('constancias_manejo.preguntas.store');
    Route::get('/imprimir', [ConstanciaPreguntaController::class, 'imprimir'])->name('constancias_manejo.preguntas.imprimir');
    Route::get('/{pregunta}/edit', [ConstanciaPreguntaController::class, 'edit'])->middleware('can:editar modulo examenes')->name('constancias_manejo.preguntas.edit');
    Route::put('/{pregunta}', [ConstanciaPreguntaController::class, 'update'])->middleware('can:editar modulo examenes')->name('constancias_manejo.preguntas.update');
    Route::delete('/{pregunta}', [ConstanciaPreguntaController::class, 'destroy'])->middleware('can:eliminar modulo examenes')->name('constancias_manejo.preguntas.destroy');
});

Route::prefix('constancias-manejo')->middleware(['auth','can:ver modulo examenes'])->group(function () {
    Route::get('/', [ConstanciaManejoController::class, 'index'])->name('constancias_manejo.index');
    Route::get('/create', [ConstanciaManejoController::class, 'create'])->middleware('can:crear modulo examenes')->name('constancias_manejo.create');
    Route::post('/', [ConstanciaManejoController::class, 'store'])->middleware('can:crear modulo examenes')->name('constancias_manejo.store');

    Route::get('/pendientes-activar', [ConstanciaManejoController::class, 'pendientesActivar'])->name('constancias_manejo.pendientes_activar');
    Route::get('/inactivas-vencidas', [ConstanciaManejoController::class, 'inactivasVencidas'])->name('constancias_manejo.inactivas_vencidas');
    Route::get('/imprimir-lote', [ConstanciaManejoController::class, 'imprimirLote'])->middleware('can:crear modulo examenes')->name('constancias_manejo.imprimir_lote');
    Route::get('/lotes/{lote}/descargar', [ConstanciaManejoController::class, 'descargarLote'])
        ->where('lote', '[0-9a-fA-F-]{36}')
        ->middleware('can:crear modulo examenes')
        ->name('constancias_manejo.lotes.descargar');
    Route::get('/activar-manual', [ConstanciaManejoController::class, 'activarManualForm'])->middleware('can:editar modulo examenes')->name('constancias_manejo.activar_manual');
    Route::post('/activar-manual', [ConstanciaManejoController::class, 'activarManual'])->middleware('can:editar modulo examenes')->name('constancias_manejo.activar_manual.store');

    Route::get('/examenes', [ConstanciaExamenSolicitudController::class, 'index'])->name('constancias_manejo.examenes.index');
    Route::get('/examenes/create', [ConstanciaExamenSolicitudController::class, 'create'])->middleware('can:crear modulo examenes')->name('constancias_manejo.examenes.create');
    Route::post('/examenes', [ConstanciaExamenSolicitudController::class, 'store'])->middleware('can:crear modulo examenes')->name('constancias_manejo.examenes.store');
    Route::get('/examenes/{solicitud}/descargar-pdf', [ConstanciaExamenSolicitudController::class, 'descargarPdf'])->name('constancias_manejo.examenes.descargar_pdf');
    Route::get('/examenes/{solicitud}', [ConstanciaExamenSolicitudController::class, 'show'])->name('constancias_manejo.examenes.show');
    Route::post('/examenes/{solicitud}/capturar-impreso', [ConstanciaExamenSolicitudController::class, 'capturarImpreso'])->middleware('can:editar modulo examenes')->name('constancias_manejo.examenes.capturar_impreso');
    Route::post('/examenes/{solicitud}/activar', [ConstanciaExamenSolicitudController::class, 'activar'])->middleware('can:editar modulo examenes')->name('constancias_manejo.examenes.activar');

    Route::get('/descargar-examenes', [ConstanciaPreguntaController::class, 'descargas'])->name('constancias_manejo.preguntas.descargas');
    Route::get('/descargar-examenes/{tipoLicencia}', [ConstanciaPreguntaController::class, 'descargar'])
        ->where('tipoLicencia', 'MOTOCICLISTA|AUTOMOVILISTA|CHOFER|SERVICIO_PUBLICO|PERMISO')
        ->name('constancias_manejo.preguntas.descargar');

    Route::get('/{constancia}', [ConstanciaManejoController::class, 'show'])->name('constancias_manejo.show');
    Route::get('/{constancia}/edit', [ConstanciaManejoController::class, 'edit'])->middleware('can:editar modulo examenes')->name('constancias_manejo.edit');
    Route::put('/{constancia}', [ConstanciaManejoController::class, 'update'])->middleware('can:editar modulo examenes')->name('constancias_manejo.update');
    Route::delete('/{constancia}', [ConstanciaManejoController::class, 'destroy'])->middleware('can:eliminar modulo examenes')->name('constancias_manejo.destroy');

    Route::get('/{constancia}/imprimir', [ConstanciaManejoController::class, 'imprimir'])->name('constancias_manejo.imprimir');
    Route::get('/{constancia}/reimprimir', [ConstanciaManejoController::class, 'reimprimir'])->middleware('can:crear modulo examenes')->name('constancias_manejo.reimprimir');

    Route::post('/{constancia}/generar-acceso', [ConstanciaManejoController::class, 'generarAcceso'])->middleware('can:editar modulo examenes')->name('constancias_manejo.generar_acceso');
    Route::post('/{constancia}/capturar-examen-impreso', [ConstanciaManejoController::class, 'capturarExamenImpreso'])->middleware('can:editar modulo examenes')->name('constancias_manejo.capturar_examen_impreso');
    Route::post('/{constancia}/activar', [ConstanciaManejoController::class, 'activar'])->middleware('can:editar modulo examenes')->name('constancias_manejo.activar');
    Route::post('/{constancia}/cancelar', [ConstanciaManejoController::class, 'cancelar'])->middleware('can:editar modulo examenes')->name('constancias_manejo.cancelar');
});

Route::prefix('resumen-ejecutivo')->middleware(['auth', 'can:ver estadisticas'])->group(function () {
    Route::get('/', [ResumenEjecutivoController::class, 'index'])->name('resumen_ejecutivo.index');
    Route::get('/{fecha}', [ResumenEjecutivoController::class, 'show'])->name('resumen_ejecutivo.show');
    Route::get('/{fecha}', [ResumenEjecutivoController::class, 'show'])->name('resumen_ejecutivo.show');
    Route::get('/data/{fecha}', [ResumenEjecutivoController::class, 'data'])->name('resumen_ejecutivo.data');
});

Route::middleware(['auth','can:ver mapa'])->group(function () {
    Route::get('/mapa',[MapaPatrullasController::class,'index'])->name('mapa.index');
    Route::get('/mapa-patrullas/data',[MapaPatrullasController::class,'data'])->name('mapa.patrullas.data');
    Route::get('/mapa/mi-personal',[MapaPatrullasController::class,'miPersonal'])->name('mapa.mi_personal');
    Route::post('/mapa/mi-personal/{user}/ubicacion',[MapaPatrullasController::class,'toggleUbicacionUsuario'])->name('mapa.mi_personal.toggle');
    Route::post('/mapa/mi-personal/ubicacion/todos',[MapaPatrullasController::class,'toggleUbicacionTodos'])->name('mapa.mi_personal.toggle_all');
});

Route::prefix('operativos')->middleware(['auth','can:ver operativos'])->group(function () {
    Route::get('/whatsapp', [OperativoController::class, 'whatsapp'])->name('operativos.whatsapp');
    Route::get('/', [OperativoController::class, 'index'])->name('operativos.index');
    Route::get('/create', [OperativoController::class, 'create'])->middleware('can:crear operativos')->name('operativos.create');
    Route::post('/', [OperativoController::class, 'store'])->middleware('can:crear operativos')->name('operativos.store');
    Route::get('/{capturaUuid}', [OperativoController::class, 'show'])->name('operativos.show');
    Route::get('/{capturaUuid}/edit', [OperativoController::class, 'edit'])->middleware('can:editar operativos')->name('operativos.edit');
    Route::put('/{capturaUuid}', [OperativoController::class, 'update'])->middleware('can:editar operativos')->name('operativos.update');
    Route::delete('/{capturaUuid}', [OperativoController::class, 'destroy'])->middleware('can:eliminar operativos')->name('operativos.destroy');
});

Route::middleware(['auth'])->group(function () {
    Route::get('/waze/alerts', [WazeAlertWebController::class, 'index'])->name('waze.alerts.index');
    Route::post('/waze/alerts/{alert}/read', [WazeAlertWebController::class, 'markRead'])->name('waze.alerts.read');
    Route::post('/waze/alerts/read-all', [WazeAlertWebController::class, 'markAllRead'])->name('waze.alerts.read_all');
    Route::get('/waze/alerts/unread-count', [WazeAlertWebController::class, 'unreadCount'])->name('waze.alerts.unread_count');
});

Route::middleware(['auth'])->group(function () {
    Route::get('/waze/riesgo', [RiesgoDashboardController::class, 'index'])->name('waze.riesgo.index');
    Route::get('/waze/riesgo/data', [RiesgoDashboardController::class, 'data'])->name('waze.riesgo.data');
});

Route::middleware(['auth','can:ver mapa'])->group(function () {
    Route::get('/mapa-incidencias', [MapaIncidenciasController::class,'index'])->name('mapa.incidencias.index');
    Route::get('/mapa-incidencias/data', [MapaIncidenciasController::class,'data'])->name('mapa.incidencias.data');
    Route::get('/mapa-incidencias/hechos', [MapaIncidenciasController::class,'hechos'])->name('mapa.incidencias.hechos');
    Route::view('/mapa-colonias', 'mapa.colonias')->name('mapa.colonias.index');
});


Route::get('/liberacion/{vehiculo}',[LiberacionController::class,'publica'])->name('liberacion.publica');
Route::get('liberacion/qr/{token}',[LiberacionController::class,'desdeToken'])->name('liberacion.publica.token');

Route::middleware('auth')->group(function () {
    Route::get('/profile',[UserController::class,'profile'])->name('profile');
    Route::get('/change-password',[UserController::class,'showChangePasswordForm'])->name('password.change');
    Route::post('/change-password',[UserController::class,'updatePassword'])->name('user.password.update');
});

Route::middleware(['auth','can:subir liberacion grua'])->group(function () {
    Route::get('/liberacion/{vehiculo}/grua',[LiberacionController::class,'verParaGruas'])->name('liberacion.grua.ver');
    Route::post('/liberacion/{vehiculo}/grua',[LiberacionController::class,'storePdfGruas'])->name('liberacion.grua.subir');
});

Route::middleware(['auth'])->group(function () {
    Route::get('/liberacion/{vehiculo}/crear',[LiberacionController::class,'create'])->name('liberacion.create');
    Route::post('/liberacion/{vehiculo}',[LiberacionController::class,'store'])->name('liberacion.store');
    Route::get('/liberacion/{vehiculo}/editar',[LiberacionController::class,'edit'])->name('liberacion.edit');
    Route::put('/liberacion/{vehiculo}',[LiberacionController::class,'update'])->name('liberacion.update');
    Route::get('/liberacion/{vehiculo}/detalles',[LiberacionController::class,'detalles'])->name('liberacion.detalles');
    Route::get('/liberacion/{vehiculo}/acuse',[LiberacionController::class,'generarAcuse'])->name('liberacion.descargar');
});

Route::get('/busqueda',[BusquedaController::class,'index'])->middleware(['auth', 'can:ver hechos'])->name('busqueda.index');
Route::get('/campanas',[CampanaController::class,'index'])->name('campanas.index');
Route::get('/apoyo',[ApoyoController::class,'index'])->name('apoyo.index');

Route::prefix('licencias')->group(function () {
    Route::get('/requisitos',[LicenciaController::class,'requisitos'])->name('licencias.requisitos');
    Route::get('/costos',[LicenciaController::class,'costos'])->name('licencias.costos');
    Route::get('/ubicaciones',[LicenciaController::class,'ubicaciones'])->name('licencias.ubicaciones');
});

Route::match(['get', 'post'], '/consulta-puntos-licencia', [LicenciaPuntosController::class, 'consulta'])->name('licencias_puntos.consulta');

Route::prefix('mis-puntos-licencia')->middleware(['auth', 'can:ver portal ciudadano puntos licencias'])->group(function () {
        Route::get('/', [CiudadanoLicenciaPuntosController::class, 'index'])->name('ciudadano.licencias_puntos.index');
        Route::post('/licencias', [CiudadanoLicenciaPuntosController::class, 'storeLicencia'])->middleware('throttle:6,1')->name('ciudadano.licencias_puntos.licencias.store');
        Route::get('/cursos', [CiudadanoLicenciaPuntosController::class, 'cursos'])->name('ciudadano.licencias_puntos.cursos');
        Route::get('/cursos/participantes/{participante}/aula', [CiudadanoLicenciaPuntosController::class, 'aula'])->whereNumber('participante')->name('ciudadano.licencias_puntos.cursos.aula');
        Route::get('/licencias/{cuenta}', [CiudadanoLicenciaPuntosController::class, 'show'])->whereNumber('cuenta')->name('ciudadano.licencias_puntos.show');
        Route::delete('/licencias/{cuenta}', [CiudadanoLicenciaPuntosController::class, 'destroyLicencia'])->whereNumber('cuenta')->name('ciudadano.licencias_puntos.licencias.destroy');
});

Route::get('/licencias-puntos/cursos/{curso}/participantes/{participante}/aula', [LicenciaPuntoCursoController::class, 'entrarClaseEnVivo'])->middleware('signed')->name('licencias_puntos.cursos.aula.participante');

Route::prefix('licencias-puntos')->middleware(['auth', 'can:ver puntos licencias'])->group(function () {
    Route::get('/', [LicenciaPuntosController::class, 'index'])->name('licencias_puntos.index');
    Route::post('/', [LicenciaPuntosController::class, 'store'])->middleware('can:registrar infracciones puntos licencias')->name('licencias_puntos.store');
    Route::get('/cursos', [LicenciaPuntoCursoController::class, 'index'])->middleware('can:ver cursos puntos licencias')->name('licencias_puntos.cursos.index');
    Route::get('/cursos/create', [LicenciaPuntoCursoController::class, 'create'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.create');
    Route::post('/cursos', [LicenciaPuntoCursoController::class, 'store'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.store');
    Route::get('/cursos/{curso}', [LicenciaPuntoCursoController::class, 'show'])->middleware('can:ver cursos puntos licencias')->name('licencias_puntos.cursos.show');
    Route::get('/cursos/{curso}/edit', [LicenciaPuntoCursoController::class, 'edit'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.edit');
    Route::put('/cursos/{curso}', [LicenciaPuntoCursoController::class, 'update'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.update');
    Route::post('/cursos/{curso}/aula/iniciar', [LicenciaPuntoCursoController::class, 'iniciarClaseEnVivo'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.aula.iniciar');
    Route::post('/cursos/{curso}/materiales', [LicenciaPuntoCursoController::class, 'storeMaterial'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.materiales.store');
    Route::delete('/cursos/{curso}/materiales/{material}', [LicenciaPuntoCursoController::class, 'destroyMaterial'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.materiales.destroy');
    Route::post('/cursos/{curso}/participantes', [LicenciaPuntoCursoController::class, 'storeParticipante'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.participantes.store');
    Route::put('/cursos/{curso}/participantes/{participante}', [LicenciaPuntoCursoController::class, 'updateParticipante'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.participantes.update');
    Route::put('/cursos/{curso}/participantes/{participante}/calificacion', [LicenciaPuntoCursoController::class, 'calificarParticipante'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.participantes.calificacion');
    Route::delete('/cursos/{curso}/participantes/{participante}', [LicenciaPuntoCursoController::class, 'destroyParticipante'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.participantes.destroy');
    Route::post('/cursos/{curso}/participantes/{participante}/acreditar', [LicenciaPuntoCursoController::class, 'acreditarParticipante'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.participantes.acreditar');
    Route::post('/cursos/{curso}/cerrar', [LicenciaPuntoCursoController::class, 'cerrar'])->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.cursos.cerrar');
    Route::get('/{cuenta}', [LicenciaPuntosController::class, 'show'])->whereNumber('cuenta')->name('licencias_puntos.show');
    Route::post('/{cuenta}/infracciones', [LicenciaPuntosController::class, 'registrarInfraccion'])->whereNumber('cuenta')->middleware('can:registrar infracciones puntos licencias')->name('licencias_puntos.infracciones.store');
    Route::post('/{cuenta}/capacitacion', [LicenciaPuntosController::class, 'acreditarCapacitacion'])->whereNumber('cuenta')->middleware('can:acreditar capacitacion puntos licencias')->name('licencias_puntos.capacitacion.store');
});

Route::prefix('admin/settings/licencias-puntos/infracciones')->middleware(['auth', 'can:ver configuraciones', 'can:ver catalogo infracciones puntos licencias'])->group(function () {
        Route::get('/', [LicenciaPuntoInfraccionCatalogoController::class, 'index'])->name('settings.licencias_puntos.infracciones.index');
        Route::post('/', [LicenciaPuntoInfraccionCatalogoController::class, 'store'])->middleware('can:crear catalogo infracciones puntos licencias')->name('settings.licencias_puntos.infracciones.store');
        Route::put('/{infraccion}', [LicenciaPuntoInfraccionCatalogoController::class, 'update'])->middleware('can:editar catalogo infracciones puntos licencias')->name('settings.licencias_puntos.infracciones.update');
});

Auth::routes();

Route::prefix('comunicaciones')->middleware(['auth'])->group(function () {
    Route::get('/', [ComunicacionController::class, 'index'])->name('comunicaciones.index');
    Route::get('/create', [ComunicacionController::class, 'create'])->name('comunicaciones.create');
    Route::post('/', [ComunicacionController::class, 'store'])->name('comunicaciones.store');
    Route::get('/destinatarios', [ComunicacionController::class, 'destinatarios'])->name('comunicaciones.destinatarios');
    Route::get('/no-leidas/count', [ComunicacionController::class, 'countNoLeidas'])->name('comunicaciones.no_leidas.count');
    Route::get('/adjuntos/{adjunto}', [ComunicacionController::class, 'verAdjunto'])->whereNumber('adjunto')->name('comunicaciones.adjuntos.show');
    Route::get('/{comunicacion}', [ComunicacionController::class, 'show'])->whereNumber('comunicacion')->name('comunicaciones.show');
    Route::post('/{comunicacion}/leer', [ComunicacionController::class, 'marcarLeido'])->whereNumber('comunicacion')->name('comunicaciones.leer');
    Route::post('/{comunicacion}/enterado', [ComunicacionController::class, 'marcarEnterado'])->whereNumber('comunicacion')->name('comunicaciones.enterado');
});

Route::get('/personal-fotos/{foto}/archivo-temporal', [PersonalFotoController::class, 'showSigned'])->middleware('signed')->name('personal.fotos.signed');
Route::get('/personal/{personal}/foto-principal-temporal', [PersonalFotoController::class, 'showPrincipalSigned'])->middleware('signed')->name('personal.fotos.principal.signed');

Route::get('/personal-documentos/{documento}/{archivo}/archivo-temporal', [PersonalDocumentoController::class, 'showSigned'])->middleware('signed')->where('archivo', 'general|comision|asignacion')->name('personal.documentos.signed');

Route::get('/hechos-fotos/archivo-temporal/{path}', [HechoFotoArchivoController::class, 'showSigned'])->middleware('signed')->where('path', '.*')->name('hechos.fotos.signed');

Route::get('/actividad-fotos/{foto}/{tipo?}', [ActividadFotoArchivoController::class, 'show'])->whereNumber('foto')->where('tipo', 'original|thumbnail')->name('actividades.fotos.archivo');

Route::get('/actividad-fotos-principal/{actividad}/{tipo?}', [ActividadFotoArchivoController::class, 'principal'])->whereNumber('actividad')->where('tipo', 'original|thumbnail')->name('actividades.fotos.principal_archivo');

Route::get('/home',[HomeController::class,'index'])->name('home');
Route::get('/home/feed',[HomeController::class,'feed'])->name('home.feed');

Route::prefix('actividades')->middleware(['auth','can:ver actividades'])->group(function () {
    Route::get('/subcategorias/{categoria}', [ActividadController::class, 'subcategorias'])->name('actividades.subcategorias');
    Route::get('/',[ActividadController::class,'index'])->name('actividades.index');
    Route::get('/create',[ActividadController::class,'create'])->middleware('can:crear actividades')->name('actividades.create');
    Route::post('/',[ActividadController::class,'store'])->middleware('can:crear actividades')->name('actividades.store');
    Route::get('/informe/diario',[ActividadController::class,'informeDiario'])->name('actividades.informe.diario');
    Route::get('/informe/fecha/{fecha}',[ActividadController::class,'informeFecha'])->name('actividades.informe.fecha');
    Route::get('/{actividad}',[ActividadController::class,'show'])->name('actividades.show');
    Route::get('/{actividad}/edit',[ActividadController::class,'edit'])->middleware('can:editar actividades')->name('actividades.edit');
    Route::put('/{actividad}',[ActividadController::class,'update'])->middleware('can:editar actividades')->name('actividades.update');
    Route::delete('/{actividad}',[ActividadController::class,'destroy'])->middleware('can:eliminar actividades')->name('actividades.destroy');
    Route::post('/{actividad}/vehiculos',[ActividadController::class,'storeVehiculo'])->middleware('can:editar actividades')->name('actividades.vehiculos.store');
    Route::delete('/{actividad}/vehiculos/{vehiculo}',[ActividadController::class,'destroyVehiculo'])->middleware('can:editar actividades')->name('actividades.vehiculos.destroy');

    Route::get('/{actividad}/compartir', [ActividadController::class, 'compartir'])->name('actividades.compartir');
    Route::get('actividades/compartir-totales-whatsapp', [ActividadController::class, 'compartirTotalesWhatsapp'])->name('actividades.compartir_totales_whatsapp');
});

Route::prefix('estadisticas-globales')->middleware(['auth','can:ver estadisticas globales'])->group(function () {
    Route::get('/',[EstadisticasGlobalesController::class,'index'])->name('estadisticas_globales.index');
    Route::get('/kpis',[EstadisticasGlobalesController::class,'kpis'])->name('estadisticas_globales.kpis');
    Route::get('/series/hechos',[EstadisticasGlobalesController::class,'seriesHechos'])->name('estadisticas_globales.series.hechos');
    Route::get('/series/lesionados',[EstadisticasGlobalesController::class,'seriesLesionados'])->name('estadisticas_globales.series.lesionados');
    Route::get('/series/personas-puestas-edades',[EstadisticasGlobalesController::class,'seriesPersonasPuestasEdad'])->name('estadisticas_globales.series.personas_puestas_edades');
    Route::get('/series/tipo-hecho',[EstadisticasGlobalesController::class,'seriesTipoHecho'])->name('estadisticas_globales.series.tipo_hecho');
    Route::get('/series/sector',[EstadisticasGlobalesController::class,'seriesSector'])->name('estadisticas_globales.series.sector');
    Route::get('/series/municipio',[EstadisticasGlobalesController::class,'seriesMunicipio'])->name('estadisticas_globales.series.municipio');
    Route::get('/series/delegacion',[EstadisticasGlobalesController::class,'seriesDelegacion'])->name('estadisticas_globales.series.delegacion');
    Route::get('/series/tiempo',[EstadisticasGlobalesController::class,'seriesTiempo'])->name('estadisticas_globales.series.tiempo');
    Route::get('/series/clima',[EstadisticasGlobalesController::class,'seriesClima'])->name('estadisticas_globales.series.clima');
    Route::get('/series/condiciones',[EstadisticasGlobalesController::class,'seriesCondiciones'])->name('estadisticas_globales.series.condiciones');
    Route::get('/series/control-transito',[EstadisticasGlobalesController::class,'seriesControlTransito'])->name('estadisticas_globales.series.control_transito');
    Route::get('/series/vehiculos/tipo',[EstadisticasGlobalesController::class,'seriesVehiculosTipo'])->name('estadisticas_globales.series.vehiculos_tipo');
    Route::get('/series/vehiculos/marca',[EstadisticasGlobalesController::class,'seriesVehiculosMarca'])->name('estadisticas_globales.series.vehiculos_marca');
    Route::get('/series/vehiculos/modelo',[EstadisticasGlobalesController::class,'seriesVehiculosModelo'])->name('estadisticas_globales.series.vehiculos_modelo');
    Route::get('/hechos',[EstadisticasGlobalesController::class,'hechos'])->name('estadisticas_globales.hechos');
    Route::get('/export/hechos',[EstadisticasGlobalesController::class,'exportHechos'])->name('estadisticas_globales.export.hechos');
    Route::get('/export/mensual',[EstadisticasGlobalesController::class,'exportMensual'])->name('estadisticas_globales.export.mensual');
});

Route::prefix('estadisticas-actividades')->middleware(['auth','can:ver estadisticas actividades'])->group(function () {
    Route::get('/',[EstadisticasActividadesController::class,'index'])->name('estadisticas_actividades.index');
    Route::post('/preferencias/graficas',[EstadisticasActividadesController::class,'updateChartLayout'])->name('estadisticas_actividades.preferencias_graficas');

    Route::get('/kpis',[EstadisticasActividadesController::class,'kpis'])->name('estadisticas_actividades.kpis');

    Route::get('/series/actividades',[EstadisticasActividadesController::class,'seriesActividades'])->name('estadisticas_actividades.series.actividades');
    Route::get('/series/categoria',[EstadisticasActividadesController::class,'seriesCategoria'])->name('estadisticas_actividades.series.categoria');
    Route::get('/resumen/categorias',[EstadisticasActividadesController::class,'resumenCategorias'])->name('estadisticas_actividades.resumen.categorias');
    Route::get('/series/subcategoria',[EstadisticasActividadesController::class,'seriesSubcategoria'])->name('estadisticas_actividades.series.subcategoria');
    Route::get('/series/unidad',[EstadisticasActividadesController::class,'seriesUnidad'])->name('estadisticas_actividades.series.unidad');
    Route::get('/series/delegacion',[EstadisticasActividadesController::class,'seriesDelegacion'])->name('estadisticas_actividades.series.delegacion');
    Route::get('/series/destacamento',[EstadisticasActividadesController::class,'seriesDestacamento'])->name('estadisticas_actividades.series.destacamento');
    Route::get('/series/municipio',[EstadisticasActividadesController::class,'seriesMunicipio'])->name('estadisticas_actividades.series.municipio');
    Route::get('/series/carretera',[EstadisticasActividadesController::class,'seriesCarretera'])->name('estadisticas_actividades.series.carretera');
    Route::get('/series/tiempo',[EstadisticasActividadesController::class,'seriesTiempo'])->name('estadisticas_actividades.series.tiempo');
    Route::get('/series/revision',[EstadisticasActividadesController::class,'seriesRevision'])->name('estadisticas_actividades.series.revision');

    Route::get('/series/personas-alcanzadas',[EstadisticasActividadesController::class,'seriesPersonasAlcanzadas'])->name('estadisticas_actividades.series.personas_alcanzadas');
    Route::get('/series/personas-participantes',[EstadisticasActividadesController::class,'seriesPersonasParticipantes'])->name('estadisticas_actividades.series.personas_participantes');
    Route::get('/series/personas-detenidas',[EstadisticasActividadesController::class,'seriesPersonasDetenidas'])->name('estadisticas_actividades.series.personas_detenidas');
    Route::get('/series/km-recorridos',[EstadisticasActividadesController::class,'seriesKmRecorridos'])->name('estadisticas_actividades.series.km_recorridos');
    Route::get('/series/puestas-personas-edades',[EstadisticasActividadesController::class,'seriesPuestasPersonasEdad'])->name('estadisticas_actividades.series.puestas_personas_edades');
    Route::get('/series/personas-actividad-edades',[EstadisticasActividadesController::class,'seriesActividadPersonasEdad'])->name('estadisticas_actividades.series.personas_actividad_edades');
    Route::get('/series/articulos',[EstadisticasActividadesController::class,'seriesArticulos'])->name('estadisticas_actividades.series.articulos');

    Route::get('/puestas-disposicion',[EstadisticasActividadesController::class,'puestasDisposicion'])->name('estadisticas_actividades.puestas_disposicion');
    Route::get('/actividades',[EstadisticasActividadesController::class,'actividades'])->name('estadisticas_actividades.actividades');

    Route::get('/catalogos/categorias',[EstadisticasActividadesController::class,'catalogoCategorias'])->name('estadisticas_actividades.catalogos.categorias');
    Route::get('/catalogos/subcategorias',[EstadisticasActividadesController::class,'catalogoSubcategorias'])->name('estadisticas_actividades.catalogos.subcategorias');
    Route::get('/catalogos/unidades',[EstadisticasActividadesController::class,'catalogoUnidades'])->name('estadisticas_actividades.catalogos.unidades');
    Route::get('/catalogos/delegaciones',[EstadisticasActividadesController::class,'catalogoDelegaciones'])->name('estadisticas_actividades.catalogos.delegaciones');
    Route::get('/catalogos/destacamentos',[EstadisticasActividadesController::class,'catalogoDestacamentos'])->name('estadisticas_actividades.catalogos.destacamentos');
    Route::get('/catalogos/articulos',[EstadisticasActividadesController::class,'catalogoArticulos'])->name('estadisticas_actividades.catalogos.articulos');

    Route::get('/export/actividades',[EstadisticasActividadesController::class,'exportActividades'])->name('estadisticas_actividades.export.actividades');
    Route::get('/export/vista-excel',[EstadisticasActividadesController::class,'exportVistaExcel'])->name('estadisticas_actividades.export.vista_excel');
    Route::get('/export/mensual',[EstadisticasActividadesController::class,'exportMensual'])->name('estadisticas_actividades.export.mensual');
    Route::get('/export/fomento-cultura-vial',[EstadisticasActividadesController::class,'exportFomentoCulturaVial'])->name('estadisticas_actividades.export.fomento_cultura_vial');
    Route::get('/export/puestas-disposicion',[EstadisticasActividadesController::class,'exportPuestasDisposicion'])->name('estadisticas_actividades.export.puestas_disposicion');
});

Route::prefix('estadisticas-aseguramientos')->middleware(['auth'])->group(function () {
    Route::get('/', [EstadisticasAseguramientosController::class, 'index'])->name('estadisticas_aseguramientos.index');
    Route::get('/resumen', [EstadisticasAseguramientosController::class, 'resumen'])->name('estadisticas_aseguramientos.resumen');
    Route::get('/catalogos', [EstadisticasAseguramientosController::class, 'catalogos'])->name('estadisticas_aseguramientos.catalogos');
});

Route::prefix('estadisticas-carreteras')->middleware(['auth', 'can:ver estadisticas carreteras', 'unidad:carreteras'])->group(function () {
        Route::get('/', [EstadisticasCarreterasController::class, 'index'])->name('estadisticas_carreteras.index');
        Route::get('/kpis', [EstadisticasCarreterasController::class, 'kpis'])->name('estadisticas_carreteras.kpis');

        Route::get('/series/actividades', [EstadisticasCarreterasController::class, 'seriesActividades'])->name('estadisticas_carreteras.series.actividades');
        Route::get('/series/operativos', [EstadisticasCarreterasController::class, 'seriesOperativos'])->name('estadisticas_carreteras.series.operativos');
        Route::get('/series/puestas-disposicion', [EstadisticasCarreterasController::class, 'seriesPuestasDisposicion'])->name('estadisticas_carreteras.series.puestas_disposicion');

        Route::get('/actividades', [EstadisticasCarreterasController::class, 'actividades'])->name('estadisticas_carreteras.actividades');
        Route::get('/operativos', [EstadisticasCarreterasController::class, 'operativos'])->name('estadisticas_carreteras.operativos');
        Route::get('/puestas-disposicion', [EstadisticasCarreterasController::class, 'puestasDisposicion'])->name('estadisticas_carreteras.puestas_disposicion');

        Route::get('/export/actividades', [EstadisticasCarreterasController::class, 'exportActividades'])->name('estadisticas_carreteras.export.actividades');
        Route::get('/export/operativos', [EstadisticasCarreterasController::class, 'exportOperativos'])->name('estadisticas_carreteras.export.operativos');
        Route::get('/export/puestas-disposicion', [EstadisticasCarreterasController::class, 'exportPuestasDisposicion'])->name('estadisticas_carreteras.export.puestas_disposicion');
});

Route::prefix('guardianes-camino')->middleware(['auth', 'can:ver operativos carreteras', 'unidad:carreteras'])->group(function () {
    Route::get('/', [GuardianesCaminoController::class, 'index'])->name('guardianes_camino.index');
    Route::get('/edit', [GuardianesCaminoController::class, 'edit'])->middleware('can:editar operativos carreteras')->name('guardianes_camino.edit');
    Route::put('/', [GuardianesCaminoController::class, 'update'])->middleware('can:editar operativos carreteras')->name('guardianes_camino.update');
    Route::get('/resumen', [GuardianesCaminoController::class, 'resumen'])->name('guardianes_camino.resumen');
    Route::get('/whatsapp', [GuardianesCaminoController::class, 'whatsapp'])->name('guardianes_camino.whatsapp');

    Route::prefix('dispositivos')->group(function () {
        Route::get('/', [GuardianesCaminoDispositivoController::class, 'index'])->name('guardianes_camino.dispositivos.index');
        Route::get('/pendientes-revision', [GuardianesCaminoDispositivoController::class, 'pendientesRevision'])->name('guardianes_camino.dispositivos.pendientes_revision');
        Route::get('/count-pendientes-revision', [GuardianesCaminoDispositivoController::class, 'countPendientesRevision'])->name('guardianes_camino.dispositivos.count_pendientes_revision');

        Route::get('/create', [GuardianesCaminoDispositivoController::class, 'create'])->middleware('can:crear operativos carreteras')->name('guardianes_camino.dispositivos.create');
        Route::post('/', [GuardianesCaminoDispositivoController::class, 'store'])->middleware('can:crear operativos carreteras')->name('guardianes_camino.dispositivos.store');

        Route::get('/{dispositivo}', [GuardianesCaminoDispositivoController::class, 'show'])->name('guardianes_camino.dispositivos.show');
        Route::get('/{dispositivo}/edit', [GuardianesCaminoDispositivoController::class, 'edit'])->middleware('can:editar operativos carreteras')->name('guardianes_camino.dispositivos.edit');
        Route::put('/{dispositivo}', [GuardianesCaminoDispositivoController::class, 'update'])->middleware('can:editar operativos carreteras')->name('guardianes_camino.dispositivos.update');
        Route::delete('/{dispositivo}', [GuardianesCaminoDispositivoController::class, 'destroy'])->middleware('can:eliminar operativos carreteras')->name('guardianes_camino.dispositivos.destroy');
        Route::get('/{dispositivo}/whatsapp', [GuardianesCaminoDispositivoController::class, 'whatsapp'])->name('guardianes_camino.dispositivos.whatsapp');

        Route::post('/{dispositivo}/aprobar-revision', [GuardianesCaminoDispositivoController::class, 'aprobarRevision'])->middleware('can:editar operativos carreteras')->name('guardianes_camino.dispositivos.aprobar_revision');
        Route::post('/{dispositivo}/rechazar-revision', [GuardianesCaminoDispositivoController::class, 'rechazarRevision'])->middleware('can:editar operativos carreteras')->name('guardianes_camino.dispositivos.rechazar_revision');

        Route::prefix('{dispositivo}/fotos')->group(function () {
            Route::post('/', [GuardianesCaminoDispositivoFotoController::class, 'store'])->middleware('can:editar operativos carreteras')->name('guardianes_camino.dispositivos.fotos.store');
            Route::delete('/{foto}', [GuardianesCaminoDispositivoFotoController::class, 'destroy'])->middleware('can:editar operativos carreteras')->name('guardianes_camino.dispositivos.fotos.destroy');
        });
    });
    Route::get('/guardianes-camino/count-pendientes', [GuardianesCaminoController::class, 'countPendientesRevision'])->name('guardianes_camino.countPendientesRevision');
});

Route::prefix('vialidades-urbanas')->middleware(['auth', 'can:ver operativos vialidades'])->group(function () {
    Route::get('/', [VialidadesUrbanasController::class, 'index'])->name('vialidades_urbanas.index');
    Route::get('/create', [VialidadesUrbanasController::class, 'create'])->middleware('can:crear operativos vialidades')->name('vialidades_urbanas.create');
    Route::post('/', [VialidadesUrbanasController::class, 'store'])->middleware('can:crear operativos vialidades')->name('vialidades_urbanas.store');
    Route::get('/{vialidadUrbana}/edit', [VialidadesUrbanasController::class, 'edit'])->middleware('can:editar operativos vialidades')->name('vialidades_urbanas.edit');
    Route::put('/{vialidadUrbana}', [VialidadesUrbanasController::class, 'update'])->middleware('can:editar operativos vialidades')->name('vialidades_urbanas.update');
    Route::get('/{vialidadUrbana}/resumen', [VialidadesUrbanasController::class, 'resumen'])->name('vialidades_urbanas.resumen');
    Route::get('/{vialidadUrbana}/whatsapp', [VialidadesUrbanasController::class, 'whatsapp'])->name('vialidades_urbanas.whatsapp');

    Route::prefix('{vialidadUrbana}/dispositivos')->group(function () {
        Route::get('/{dispositivo}', [VialidadesUrbanasDispositivoController::class, 'index'])->name('vialidades_urbanas.dispositivos.index');
        Route::get('/{dispositivo}/create', [VialidadesUrbanasDispositivoController::class, 'create'])->middleware('can:crear operativos vialidades')->name('vialidades_urbanas.dispositivos.create');
        Route::post('/{dispositivo}', [VialidadesUrbanasDispositivoController::class, 'store'])->middleware('can:crear operativos vialidades')->name('vialidades_urbanas.dispositivos.store');
        Route::get('/{dispositivo}/show', [VialidadesUrbanasDispositivoController::class, 'show'])->name('vialidades_urbanas.dispositivos.show');
        Route::get('/{dispositivo}/edit', [VialidadesUrbanasDispositivoController::class, 'edit'])->middleware('can:editar operativos vialidades')->name('vialidades_urbanas.dispositivos.edit');
        Route::put('/{dispositivo}', [VialidadesUrbanasDispositivoController::class, 'update'])->middleware('can:editar operativos vialidades')->name('vialidades_urbanas.dispositivos.update');
        Route::delete('/{dispositivo}/{detalle}', [VialidadesUrbanasDispositivoController::class, 'destroy'])->middleware('can:eliminar operativos vialidades')->name('vialidades_urbanas.dispositivos.destroy');
        Route::get('/{dispositivo}/whatsapp', [VialidadesUrbanasDispositivoController::class, 'whatsapp'])->name('vialidades_urbanas.dispositivos.whatsapp');
    });
});

Route::prefix('admin/settings/oficios')->middleware(['auth', 'can:ver oficios'])->group(function () {
    Route::get('/',[OficioController::class,'index'])->name('oficios.index');
    Route::get('/create',[OficioController::class,'create'])->middleware('can:crear oficios')->name('oficios.create');
    Route::get('/preview-numero',[OficioController::class,'previewNumero'])->middleware('can:crear oficios')->name('oficios.preview-numero');
    Route::get('/buscar-contestables',[OficioController::class,'buscarContestables'])->name('oficios.buscar-contestables');
    Route::post('/',[OficioController::class,'store'])->middleware('can:crear oficios')->name('oficios.store');
    Route::get('/{oficio}/archivo/pdf',[OficioController::class,'archivoPdf'])->middleware('can:ver oficios')->name('oficios.archivo.pdf');
    Route::get('/{oficio}/archivo/fotos/{indice}',[OficioController::class,'archivoFoto'])->middleware('can:ver oficios')->whereNumber('indice')->name('oficios.archivo.foto');
    Route::get('/{oficio}',[OficioController::class,'show'])->middleware('can:ver oficios')->name('oficios.show');
    Route::get('/{oficio}/edit',[OficioController::class,'edit'])->middleware('can:editar oficios')->name('oficios.edit');
    Route::put('/{oficio}',[OficioController::class,'update'])->middleware('can:editar oficios')->name('oficios.update');
    Route::delete('/{oficio}',[OficioController::class,'destroy'])->middleware('can:eliminar oficios')->name('oficios.destroy');
});

Route::prefix('listas')->middleware('can:ver listas')->group(function () {
    Route::get('/',[ListaController::class,'index'])->name('listas.index');
    Route::get('/create',[ListaController::class,'create'])->middleware('can:crear listas')->name('listas.create');
    Route::post('/',[ListaController::class,'store'])->middleware('can:crear listas')->name('listas.store');
    Route::get('/{lista}',[ListaController::class,'show'])->middleware('can:ver listas')->name('listas.show');
    Route::get('/{lista}/edit',[ListaController::class,'edit'])->middleware('can:editar listas')->name('listas.edit');
    Route::put('/{lista}',[ListaController::class,'update'])->middleware('can:editar listas')->name('listas.update');
    Route::delete('/{lista}',[ListaController::class,'destroy'])->middleware('can:eliminar listas')->name('listas.destroy');
});

Route::prefix('formatos')->middleware('can:ver formatos')->group(function () {
    Route::get('/',[FormatoController::class,'index'])->name('formatos.index');
    Route::get('/create',[FormatoController::class,'create'])->middleware('can:crear formatos')->name('formatos.create');
    Route::post('/',[FormatoController::class,'store'])->middleware('can:crear formatos')->name('formatos.store');
    Route::get('/{formato}',[FormatoController::class,'show'])->middleware('can:ver formatos')->name('formatos.show');
    Route::get('/{formato}/edit',[FormatoController::class,'edit'])->middleware('can:editar formatos')->name('formatos.edit');
    Route::put('/{formato}',[FormatoController::class,'update'])->middleware('can:editar formatos')->name('formatos.update');
    Route::delete('/{formato}',[FormatoController::class,'destroy'])->middleware('can:eliminar formatos')->name('formatos.destroy');
});

Route::prefix('dictamenes')->middleware(['auth', 'can:ver dictamenes', 'unidad:siniestros'])->group(function () {
    Route::get('/', [DictamenController::class, 'index'])->name('dictamenes.index');
    Route::get('/create', [DictamenController::class, 'create'])->middleware('can:crear dictamenes')->name('dictamenes.create');
    Route::post('/', [DictamenController::class, 'store'])->middleware('can:crear dictamenes')->name('dictamenes.store');
    Route::get('/{dictamen}/archivo', [DictamenController::class, 'archivo'])->middleware('can:ver dictamenes')->name('dictamenes.archivo');
    Route::get('/{dictamen}', [DictamenController::class, 'show'])->middleware('can:ver dictamenes')->name('dictamenes.show');
    Route::get('/{dictamen}/edit', [DictamenController::class, 'edit'])->middleware('can:editar dictamenes')->name('dictamenes.edit');
    Route::put('/{dictamen}', [DictamenController::class, 'update'])->middleware('can:editar dictamenes')->name('dictamenes.update');
    Route::delete('/{dictamen}', [DictamenController::class, 'destroy'])->middleware('can:eliminar dictamenes')->name('dictamenes.destroy');
});

Route::prefix('puestas-disposicion')->middleware(['auth'])->group(function () {
    Route::get('/', [PuestaDisposicionController::class, 'index'])->middleware('can:ver puestas a disposicion')->name('puestas_disposicion.index');
    Route::get('/create', [PuestaDisposicionController::class, 'create'])->middleware('can:crear puestas a disposicion')->name('puestas_disposicion.create');
    Route::post('/', [PuestaDisposicionController::class, 'store'])->middleware('can:crear puestas a disposicion')->name('puestas_disposicion.store');
    Route::get('/{puestaDisposicion}/archivo', [PuestaDisposicionController::class, 'archivo'])->middleware('can:ver puestas a disposicion')->name('puestas_disposicion.archivo');
    Route::get('/{puestaDisposicion}/uso-fuerza', [PuestaDisposicionController::class, 'archivoUsoFuerzaGeneral'])->middleware('can:ver puestas a disposicion')->name('puestas_disposicion.uso_fuerza');
    Route::get('/{puestaDisposicion}/personas/{persona}/uso-fuerza', [PuestaDisposicionController::class, 'archivoUsoFuerza'])->middleware('can:ver puestas a disposicion')->name('puestas_disposicion.personas.uso_fuerza');
    Route::get('/{puestaDisposicion}', [PuestaDisposicionController::class, 'show'])->middleware('can:ver puestas a disposicion')->name('puestas_disposicion.show');
    Route::get('/{puestaDisposicion}/edit', [PuestaDisposicionController::class, 'edit'])->middleware('can:editar puestas a disposicion')->name('puestas_disposicion.edit');
    Route::put('/{puestaDisposicion}', [PuestaDisposicionController::class, 'update'])->middleware('can:editar puestas a disposicion')->name('puestas_disposicion.update');
    Route::delete('/{puestaDisposicion}', [PuestaDisposicionController::class, 'destroy'])->middleware('can:eliminar puestas a disposicion')->name('puestas_disposicion.destroy');
});

    /** =========================
     *  GRÚAS
     *  ========================= */

Route::middleware(['auth','can:ver gruas'])->group(function () {
    Route::resource('tramos', TramoController::class);
    Route::resource('grua-guardias', GruaGuardiaController::class);
    Route::resource('grua-guardias-sct', GruaGuardiaSctController::class);
    Route::get('tramos-lookup', [TramoLookupController::class,'index'])->name('tramos.lookup.index');
    Route::post('tramos-lookup', [TramoLookupController::class,'resolve'])->name('tramos.lookup.resolve');
});

Route::prefix('gruas')->middleware(['auth','can:ver gruas'])->group(function () {
    Route::get('/',[GruaController::class,'index'])->name('gruas.index');
    Route::get('/create',[GruaController::class,'create'])->middleware('can:crear gruas')->name('gruas.create');
    Route::post('/',[GruaController::class,'store'])->middleware('can:crear gruas')->name('gruas.store');
    Route::get('/{grua}',[GruaController::class,'show'])->middleware('can:ver gruas')->name('gruas.show');
    Route::get('/{grua}/edit',[GruaController::class,'edit'])->middleware('can:editar gruas')->name('gruas.edit');
    Route::put('/{grua}',[GruaController::class,'update'])->middleware('can:editar gruas')->name('gruas.update');
    Route::delete('/{grua}',[GruaController::class,'destroy'])->middleware('can:eliminar gruas')->name('gruas.destroy');

    Route::prefix('{grua}/servicios')->group(function () {
        Route::get('/',[ServicioController::class,'index'])->name('servicios.index');
        Route::get('/{servicio}',[ServicioController::class,'show'])->where('servicio', '[0-9]+')->name('servicios.show');
    });

    Route::get('/{grua}/tramos', [GruaTramoController::class,'index'])->name('gruas.tramos.index');
    Route::post('/{grua}/tramos', [GruaTramoController::class,'store'])->name('gruas.tramos.store');
    Route::delete('/{grua}/tramos/{tramo}', [GruaTramoController::class,'destroy'])->name('gruas.tramos.destroy');
});

Route::prefix('hechos')->middleware('can:ver hechos')->group(function () {
    Route::get('/',[HechosController::class,'index'])->name('hechos.index');
    Route::get('/seguimiento', [HechosController::class, 'seguimiento'])->name('hechos.seguimiento');
    Route::get('/create',[HechosController::class,'create'])->middleware('can:crear hechos')->name('hechos.create');
    Route::post('/',[HechosController::class,'store'])->middleware('can:crear hechos')->name('hechos.store');
    Route::get('/{hecho}',[HechosController::class,'show'])->middleware('can:ver hechos')->name('hechos.show');
    Route::get('/{hecho}/edit',[HechosController::class,'edit'])->middleware('can:editar hechos')->name('hechos.edit');
    Route::put('/{hecho}',[HechosController::class,'update'])->middleware('can:editar hechos')->name('hechos.update');
    Route::delete('/{hecho}',[HechosController::class,'destroy'])->middleware('can:eliminar hechos')->name('hechos.destroy');
    Route::get('/{hecho}/descargar',[DocumentoHechoController::class,'descargarDocx'])->name('hechos.descargar');
    Route::get('/{hecho}/iph-puesta-disposicion',[HechosController::class,'descargarIphPuestaDisposicion'])->name('hechos.iph_puesta_disposicion.descargar');

    Route::prefix('/{hecho}/croquis')->group(function () {
        Route::get('/', [\App\Http\Controllers\CroquisController::class, 'show'])->name('croquis.show');
        Route::get('/preview', [\App\Http\Controllers\CroquisController::class, 'preview'])->name('croquis.preview');
        Route::post('/', [\App\Http\Controllers\CroquisController::class, 'store'])->name('croquis.store');
        Route::put('/', [\App\Http\Controllers\CroquisController::class, 'update'])->name('croquis.update');
        Route::delete('/', [\App\Http\Controllers\CroquisController::class, 'destroy'])->name('croquis.destroy');
    });

    Route::post('/{hecho}/marcar-relevante', [HechosController::class, 'marcarRelevante'])->middleware('can:editar hechos')->name('hechos.marcarRelevante');

    Route::post('/{hecho}/desmarcar-relevante', [HechosController::class, 'desmarcarRelevante'])->middleware('can:editar hechos')->name('hechos.desmarcarRelevante');

    Route::prefix('/{hecho}/vehiculos')->middleware('can:ver vehiculos')->group(function () {
        Route::get('/',[VehiculosController::class,'index'])->name('vehiculos.index');
        Route::get('/create',[VehiculosController::class,'create'])->middleware('can:crear vehiculos')->name('vehiculos.create');
        Route::post('/',[VehiculosController::class,'store'])->middleware('can:crear vehiculos')->name('vehiculos.store');
        Route::get('/{vehiculo}/edit',[VehiculosController::class,'edit'])->middleware('can:editar vehiculos')->name('vehiculos.edit');
        Route::put('/{vehiculo}',[VehiculosController::class,'update'])->middleware('can:editar vehiculos')->name('vehiculos.update');
        Route::delete('/{vehiculo}',[VehiculosController::class,'destroy'])->middleware('can:eliminar vehiculos')->name('vehiculos.destroy');
        Route::get('/{vehiculo}/foto',[VehiculosController::class,'foto'])->middleware('can:editar vehiculos')->name('vehiculos.foto');
        Route::post('/{vehiculo}/foto',[VehiculosController::class,'fotoUpdate'])->middleware('can:editar vehiculos')->name('vehiculos.foto.update');
        Route::delete('/{vehiculo}/foto',[VehiculosController::class,'fotoDestroy'])->middleware('can:editar vehiculos')->name('vehiculos.foto.destroy');
    });

    Route::prefix('/{hecho}/lesionados')->middleware('can:ver lesionados')->group(function () {
        Route::get('/',[LesionadoController::class,'index'])->name('lesionados.index');
        Route::get('/create',[LesionadoController::class,'create'])->middleware('can:crear lesionados')->name('lesionados.create');
        Route::post('/',[LesionadoController::class,'store'])->middleware('can:crear lesionados')->name('lesionados.store');
        Route::get('/{lesionado}/edit',[LesionadoController::class,'edit'])->middleware('can:editar lesionados')->name('lesionados.edit');
        Route::put('/{lesionado}',[LesionadoController::class,'update'])->middleware('can:editar lesionados')->name('lesionados.update');
        Route::delete('/{lesionado}',[LesionadoController::class,'destroy'])->middleware('can:eliminar lesionados')->name('lesionados.destroy');
    });

    Route::prefix('pendientes')->group(function () {
        Route::get('/cortes', [PendientesCortesController::class, 'index'])
            ->middleware('can:menu-pendientes-cortes-siniestros')
            ->name('hechos.pendientes.cortes.index');
        Route::get('/cortes/{corte}', [PendientesCortesController::class, 'show'])
            ->whereNumber('corte')
            ->middleware('can:menu-pendientes-cortes-siniestros')
            ->name('hechos.pendientes.cortes.show');
        Route::get('/delegaciones/cortes', [PendientesCortesController::class, 'indexDelegaciones'])
            ->middleware('can:menu-pendientes-cortes-delegaciones')
            ->name('hechos.pendientes.delegaciones.cortes.index');
        Route::get('/delegaciones/cortes/{corte}', [PendientesCortesController::class, 'showDelegaciones'])
            ->whereNumber('corte')
            ->middleware('can:menu-pendientes-cortes-delegaciones')
            ->name('hechos.pendientes.delegaciones.cortes.show');
    });
    Route::get('/{hecho}/compartir', [HechosController::class, 'compartirNativo'])->name('hechos.compartir');
    Route::post('/{hecho}/whatsapp', [HechosController::class, 'sendWhatsapp'])->name('hechos.whatsapp.send');

    Route::get('/revision/pendientes', [HechosController::class, 'pendientesRevision'])->name('hechos.pendientes_revision');
    Route::get('/revision/pendientes/count', [HechosController::class, 'countPendientesRevision'])->name('hechos.pendientes_revision.count');
    Route::post('/revision/{hecho}/aprobar', [HechosController::class, 'aprobarRevision'])->name('hechos.revision.aprobar');
    Route::post('/revision/{hecho}/rechazar', [HechosController::class, 'rechazarRevision'])->name('hechos.revision.rechazar');
});

Route::prefix('modulo-examenes-diarios')->middleware('can:ver modulo examenes')->group(function () {
    Route::get('/', [ModuloExamenDiarioController::class, 'index'])->name('modulo_examenes_diarios.index');
    Route::get('/create', [ModuloExamenDiarioController::class, 'create'])->middleware('can:crear modulo examenes')->name('modulo_examenes_diarios.create');
    Route::post('/', [ModuloExamenDiarioController::class, 'store'])->middleware('can:crear modulo examenes')->name('modulo_examenes_diarios.store');
    Route::get('/{registro}', [ModuloExamenDiarioController::class, 'show'])->name('modulo_examenes_diarios.show');
    Route::get('/{registro}/edit', [ModuloExamenDiarioController::class, 'edit'])->middleware('can:editar modulo examenes')->name('modulo_examenes_diarios.edit');
    Route::put('/{registro}', [ModuloExamenDiarioController::class, 'update'])->middleware('can:editar modulo examenes')->name('modulo_examenes_diarios.update');
    Route::delete('/{registro}', [ModuloExamenDiarioController::class, 'destroy'])->middleware('can:eliminar modulo examenes')->name('modulo_examenes_diarios.destroy');
});

Route::prefix('modulo-constancias-examenes')->middleware(['auth','can:ver modulo examenes'])->group(function () {
    Route::get('/', [ModuloConstanciaExamenController::class, 'index'])->name('modulo_constancias_examenes.index');
    Route::get('/create', [ModuloConstanciaExamenController::class, 'create'])->middleware('can:crear modulo examenes')->name('modulo_constancias_examenes.create');
    Route::post('/', [ModuloConstanciaExamenController::class, 'store'])->middleware('can:crear modulo examenes')->name('modulo_constancias_examenes.store');
    Route::get('/{constancia}', [ModuloConstanciaExamenController::class, 'show'])->name('modulo_constancias_examenes.show');
    Route::get('/{constancia}/descargar-pdf', [ModuloConstanciaExamenController::class, 'descargarPdf'])->name('modulo_constancias_examenes.descargar_pdf');
    Route::get('/{constancia}/reimprimir', [ModuloConstanciaExamenController::class, 'reimprimir'])->middleware('can:crear modulo examenes')->name('modulo_constancias_examenes.reimprimir');
    Route::post('/{constancia}/cancelar', [ModuloConstanciaExamenController::class, 'cancelar'])->middleware('can:editar modulo examenes')->name('modulo_constancias_examenes.cancelar');
});

Route::get('/servicios/grafico',[ServicioController::class,'grafico'])->name('servicios.grafico');

Route::get('/admin/settings/constancias/preguntas/{path?}', function ($path = null) {
    $destino = '/constancias-manejo/preguntas';

    if ($path) {
        $destino .= '/' . ltrim($path, '/');
    }

    return redirect($destino);
})->where('path', '.*')->middleware(['auth', 'can:ver configuraciones']);

Route::prefix('admin/settings')->middleware('can:ver configuraciones')->group(function () {
    Route::get('/',[SettingsController::class,'index'])->name('settings.index');
    Route::get('/reconstructor-transito', [SettingsController::class, 'reconstructorTransito'])
        ->name('settings.reconstructor_transito.index');

    Route::prefix('boquillas')->middleware('auth')->group(function () {
        Route::get('/', [BoquillaDotacionController::class, 'index'])->name('settings.boquillas.index');
        Route::post('/', [BoquillaDotacionController::class, 'store'])->name('settings.boquillas.store');
        Route::post('/perdidas', [BoquillaDotacionController::class, 'storePerdida'])->name('settings.boquillas.perdidas.store');
        Route::put('/perdidas/{perdida}', [BoquillaDotacionController::class, 'updatePerdida'])->name('settings.boquillas.perdidas.update');
        Route::delete('/perdidas/{perdida}', [BoquillaDotacionController::class, 'destroyPerdida'])->name('settings.boquillas.perdidas.destroy');
        Route::put('/{dotacion}', [BoquillaDotacionController::class, 'update'])->name('settings.boquillas.update');
        Route::delete('/{dotacion}', [BoquillaDotacionController::class, 'destroy'])->name('settings.boquillas.destroy');
    });

    Route::get('/tutoriales', [TutorialController::class, 'index'])->name('settings.tutoriales.index');
    Route::get('/tutoriales/create', [TutorialController::class, 'create'])->name('settings.tutoriales.create');
    Route::post('/tutoriales', [TutorialController::class, 'store'])->name('settings.tutoriales.store');
    Route::get('/tutoriales/{tutorial}/edit', [TutorialController::class, 'edit'])->name('settings.tutoriales.edit');
    Route::put('/tutoriales/{tutorial}', [TutorialController::class, 'update'])->name('settings.tutoriales.update');
    Route::delete('/tutoriales/{tutorial}', [TutorialController::class, 'destroy'])->name('settings.tutoriales.destroy');

    Route::prefix('patrullas')->middleware('can:ver patrullas')->group(function () {
        Route::get('/',[PatrullaController::class,'index'])->name('patrullas.index');
        Route::get('/create',[PatrullaController::class,'create'])->middleware('can:crear patrullas')->name('patrullas.create');
        Route::post('/',[PatrullaController::class,'store'])->middleware('can:crear patrullas')->name('patrullas.store');
        Route::get('/{patrulla}',[PatrullaController::class,'show'])->middleware('can:ver patrullas')->name('patrullas.show');
        Route::get('/{patrulla}/edit',[PatrullaController::class,'edit'])->middleware('can:editar patrullas')->name('patrullas.edit');
        Route::put('/{patrulla}',[PatrullaController::class,'update'])->middleware('can:editar patrullas')->name('patrullas.update');
        Route::delete('/{patrulla}',[PatrullaController::class,'destroy'])->middleware('can:eliminar patrullas')->name('patrullas.destroy');
        Route::delete('/{patrulla}/fotos/{foto}', [PatrullaController::class, 'destroyFoto'])->middleware('can:editar patrullas')->name('patrullas.fotos.destroy');

        Route::prefix('{patrulla}/kilometrajes')->middleware('can:ver kilometrajes patrullas')->group(function () {
            Route::get('/', [PatrullaKilometrajeController::class, 'index'])->name('patrullas.kilometrajes.index');
            Route::get('/create', [PatrullaKilometrajeController::class, 'create'])->middleware('can:crear kilometrajes patrullas')->name('patrullas.kilometrajes.create');
            Route::post('/', [\App\Http\Controllers\PatrullaKilometrajeController::class, 'store'])->middleware('can:crear kilometrajes patrullas')->name('patrullas.kilometrajes.store');
            Route::get('/{kilometraje}/edit', [PatrullaKilometrajeController::class, 'edit'])->middleware('can:editar kilometrajes patrullas')->name('patrullas.kilometrajes.edit');
            Route::put('/{kilometraje}', [PatrullaKilometrajeController::class, 'update'])->middleware('can:editar kilometrajes patrullas')->name('patrullas.kilometrajes.update');
            Route::delete('/{kilometraje}', [PatrullaKilometrajeController::class, 'destroy'])->middleware('can:eliminar kilometrajes patrullas')->name('patrullas.kilometrajes.destroy');
        });
    });

    Route::prefix('delegaciones')->middleware('can:ver delegaciones')->group(function () {
        Route::get('/', [DelegacionController::class, 'index'])->name('delegaciones.index');
        Route::get('/create', [DelegacionController::class, 'create'])->middleware('can:crear delegaciones')->name('delegaciones.create');
        Route::post('/', [DelegacionController::class, 'store'])->middleware('can:crear delegaciones')->name('delegaciones.store');
        Route::get('/mapa-delegaciones', [MapaDelegacionesController::class, 'index'])->name('mapa.delegaciones.index');
        Route::get('/mapa-delegaciones/data', [MapaDelegacionesController::class, 'data'])->name('mapa.delegaciones.data');
        Route::get('/{delegacion}', [DelegacionController::class, 'show'])->name('delegaciones.show');
        Route::get('/{delegacion}/edit', [DelegacionController::class, 'edit'])->middleware('can:editar delegaciones')->name('delegaciones.edit');
        Route::put('/{delegacion}', [DelegacionController::class, 'update'])->middleware('can:editar delegaciones')->name('delegaciones.update');
        Route::delete('/{delegacion}', [DelegacionController::class, 'destroy'])->middleware('can:eliminar delegaciones')->name('delegaciones.destroy');
        Route::get('/{delegacion}/hijas', [DelegacionController::class, 'hijas'])->name('delegaciones.hijas');

    });

    Route::prefix('users')->middleware('can:ver usuarios')->group(function () {
        Route::get('/',[UserController::class,'index'])->name('users.index');
        Route::get('/create',[UserController::class,'create'])->middleware('can:crear usuarios')->name('users.create');
        Route::post('/',[UserController::class,'store'])->middleware('can:crear usuarios')->name('users.store');
        Route::get('/{user}',[UserController::class,'show'])->middleware('can:ver usuarios')->name('users.show');
        Route::get('/{user}/edit',[UserController::class,'edit'])->middleware('can:editar usuarios')->name('users.edit');
        Route::put('/{user}',[UserController::class,'update'])->middleware('can:editar usuarios')->name('users.update');
        Route::delete('/{user}',[UserController::class,'destroy'])->middleware('can:eliminar usuarios')->name('users.destroy');
    });

    Route::prefix('roles')->middleware(['can:ver roles', 'role:Superadmin'])->group(function () {
        Route::get('/',[RoleController::class,'index'])->name('roles.index');
        Route::get('/create',[RoleController::class,'create'])->middleware('can:crear roles')->name('roles.create');
        Route::post('/',[RoleController::class,'store'])->middleware('can:crear roles')->name('roles.store');
        Route::get('/{role}',[RoleController::class,'show'])->name('roles.show');
        Route::get('/{role}/edit',[RoleController::class,'edit'])->middleware('can:editar roles')->name('roles.edit');
        Route::put('/{role}',[RoleController::class,'update'])->middleware('can:editar roles')->name('roles.update');
        Route::delete('/{role}',[RoleController::class,'destroy'])->middleware('can:eliminar roles')->name('roles.destroy');
        Route::get('/{role}/permissions',[RoleController::class,'permissions'])->middleware('can:editar roles')->name('roles.permissions');
        Route::post('/{role}/permissions',[RoleController::class,'assignPermissions'])->middleware('can:editar roles')->name('roles.assignPermissions');
    });

    Route::prefix('calea')->middleware(['auth', 'can:ver calea'])->group(function () {
        Route::get('/', [CaleaDirectivaController::class, 'index'])->name('settings.calea.index');
        Route::get('/create', [CaleaDirectivaController::class, 'create'])->middleware('can:crear calea')->name('settings.calea.create');
        Route::post('/', [CaleaDirectivaController::class, 'store'])->middleware('can:crear calea')->name('settings.calea.store');
        Route::prefix('versiones')->group(function () {
            Route::get('/{version}/pdf', [CaleaDirectivaVersionController::class, 'pdf'])->name('settings.calea.versiones.pdf');
            Route::get('/{version}/edit', [CaleaDirectivaVersionController::class, 'edit'])->middleware('can:editar calea')->name('settings.calea.versiones.edit');
            Route::put('/{version}', [CaleaDirectivaVersionController::class, 'update'])->middleware('can:editar calea')->name('settings.calea.versiones.update');
            Route::delete('/{version}', [CaleaDirectivaVersionController::class, 'destroy'])->middleware('can:eliminar calea')->name('settings.calea.versiones.destroy');
            Route::post('/{version}/vigente', [CaleaDirectivaVersionController::class, 'marcarVigente'])->middleware('can:editar calea')->name('settings.calea.versiones.vigente');
            Route::post('/{version}/secciones', [CaleaDirectivaSeccionController::class, 'store'])->middleware('can:editar calea')->name('settings.calea.secciones.store');
        });
        Route::prefix('secciones')->group(function () {
            Route::get('/{seccion}/edit', [CaleaDirectivaSeccionController::class, 'edit'])->middleware('can:editar calea')->name('settings.calea.secciones.edit');
            Route::put('/{seccion}', [CaleaDirectivaSeccionController::class, 'update'])->middleware('can:editar calea')->name('settings.calea.secciones.update');
            Route::delete('/{seccion}', [CaleaDirectivaSeccionController::class, 'destroy'])->middleware('can:eliminar calea')->name('settings.calea.secciones.destroy');
            Route::post('/{seccion}/bloques', [CaleaDirectivaBloqueController::class, 'store'])->middleware('can:editar calea')->name('settings.calea.bloques.store');
        });
        Route::prefix('bloques')->group(function () {
            Route::get('/{bloque}/edit', [CaleaDirectivaBloqueController::class, 'edit'])->middleware('can:editar calea')->name('settings.calea.bloques.edit');
            Route::put('/{bloque}', [CaleaDirectivaBloqueController::class, 'update'])->middleware('can:editar calea')->name('settings.calea.bloques.update');
            Route::delete('/{bloque}', [CaleaDirectivaBloqueController::class, 'destroy'])->middleware('can:eliminar calea')->name('settings.calea.bloques.destroy');
        });
        Route::get('/{directiva}/versiones/create', [CaleaDirectivaVersionController::class, 'create'])->middleware('can:crear calea')->name('settings.calea.versiones.create');
        Route::post('/{directiva}/versiones', [CaleaDirectivaVersionController::class, 'store'])->middleware('can:crear calea')->name('settings.calea.versiones.store');
        Route::get('/{directiva}/edit', [CaleaDirectivaController::class, 'edit'])->middleware('can:editar calea')->name('settings.calea.edit');
        Route::put('/{directiva}', [CaleaDirectivaController::class, 'update'])->middleware('can:editar calea')->name('settings.calea.update');
        Route::delete('/{directiva}', [CaleaDirectivaController::class, 'destroy'])->middleware('can:eliminar calea')->name('settings.calea.destroy');
    });

    Route::prefix('personal')->middleware('can:ver personal')->group(function () {
        Route::get('/', [PersonalController::class, 'index'])->name('personal.index');
        Route::get('/create', [PersonalController::class, 'create'])->middleware('can:crear personal')->name('personal.create');
        Route::post('/importar', [PersonalController::class, 'importar'])->middleware('can:crear personal')->name('personal.importar');
        Route::post('/', [PersonalController::class, 'store'])->middleware('can:crear personal')->name('personal.store');
        Route::get('/{personal}', [PersonalController::class, 'show'])->name('personal.show');
        Route::get('/{personal}/edit', [PersonalController::class, 'edit'])->middleware('can:editar personal')->name('personal.edit');
        Route::put('/{personal}', [PersonalController::class, 'update'])->middleware('can:editar personal')->name('personal.update');
        Route::delete('/{personal}', [PersonalController::class, 'destroy'])->middleware('can:borrar personal')->name('personal.destroy');

        Route::post('/{personal}/contactos', [PersonalContactoController::class, 'store'])->middleware('can:editar personal')->name('personal.contactos.store');
        Route::put('/{personal}/contactos/{contacto}', [PersonalContactoController::class, 'update'])->middleware('can:editar personal')->name('personal.contactos.update');
        Route::delete('/{personal}/contactos/{contacto}', [PersonalContactoController::class, 'destroy'])->middleware('can:editar personal')->name('personal.contactos.destroy');

        Route::post('/{personal}/domicilios', [PersonalDomicilioController::class, 'store'])->middleware('can:editar personal')->name('personal.domicilios.store');
        Route::put('/{personal}/domicilios/{domicilio}', [PersonalDomicilioController::class, 'update'])->middleware('can:editar personal')->name('personal.domicilios.update');
        Route::delete('/{personal}/domicilios/{domicilio}', [PersonalDomicilioController::class, 'destroy'])->middleware('can:editar personal')->name('personal.domicilios.destroy');

        Route::post('/{personal}/emergencias', [PersonalEmergenciaController::class, 'store'])->middleware('can:editar personal')->name('personal.emergencias.store');
        Route::put('/{personal}/emergencias/{emergencia}', [PersonalEmergenciaController::class, 'update'])->middleware('can:editar personal')->name('personal.emergencias.update');
        Route::delete('/{personal}/emergencias/{emergencia}', [PersonalEmergenciaController::class, 'destroy'])->middleware('can:editar personal')->name('personal.emergencias.destroy');

        Route::post('/{personal}/documentos', [PersonalDocumentoController::class, 'store'])->middleware('can:editar personal')->name('personal.documentos.store');
        Route::put('/{personal}/documentos/{documento}', [PersonalDocumentoController::class, 'update'])->middleware('can:editar personal')->name('personal.documentos.update');
        Route::delete('/{personal}/documentos/{documento}', [PersonalDocumentoController::class, 'destroy'])->middleware('can:editar personal')->name('personal.documentos.destroy');

        Route::post('/{personal}/licencias', [PersonalLicenciaController::class, 'store'])->middleware('can:editar personal')->name('personal.licencias.store');
        Route::put('/{personal}/licencias/{licencia}', [PersonalLicenciaController::class, 'update'])->middleware('can:editar personal')->name('personal.licencias.update');
        Route::delete('/{personal}/licencias/{licencia}', [PersonalLicenciaController::class, 'destroy'])->middleware('can:editar personal')->name('personal.licencias.destroy');

        Route::post('/{personal}/fotos', [PersonalFotoController::class, 'store'])->middleware('can:editar personal')->name('personal.fotos.store');
        Route::get('/{personal}/fotos/principal', [PersonalFotoController::class, 'showPrincipal'])->middleware('auth')->name('personal.fotos.principal');
        Route::get('/{personal}/fotos/{foto}/archivo', [PersonalFotoController::class, 'show'])->middleware('auth')->name('personal.fotos.show');
        Route::delete('/{personal}/fotos/{foto}', [PersonalFotoController::class, 'destroy'])->middleware('can:editar personal')->name('personal.fotos.destroy');

        Route::get('/{personal}/incidencias/create', [PersonalIncidenciaController::class, 'create'])->middleware('can:editar personal')->name('personal.incidencias.create');
        Route::post('/{personal}/incidencias', [PersonalIncidenciaController::class, 'store'])->middleware('can:editar personal')->name('personal.incidencias.store');
        Route::get('/{personal}/incidencias/{incidencia}/edit', [PersonalIncidenciaController::class, 'edit'])->middleware('can:editar personal')->name('personal.incidencias.edit');
        Route::put('/{personal}/incidencias/{incidencia}', [PersonalIncidenciaController::class, 'update'])->middleware('can:editar personal')->name('personal.incidencias.update');
        Route::delete('/{personal}/incidencias/{incidencia}', [PersonalIncidenciaController::class, 'destroy'])->middleware('can:editar personal')->name('personal.incidencias.destroy');

        Route::get('/{personal}/asignaciones/create', [PersonalAsignacionController::class, 'create'])->middleware('can:editar personal')->name('personal.asignaciones.create');
        Route::post('/{personal}/asignaciones', [PersonalAsignacionController::class, 'store'])->middleware('can:editar personal')->name('personal.asignaciones.store');
        Route::get('/{personal}/asignaciones/{asignacion}/edit', [PersonalAsignacionController::class, 'edit'])->middleware('can:editar personal')->name('personal.asignaciones.edit');
        Route::put('/{personal}/asignaciones/{asignacion}', [PersonalAsignacionController::class, 'update'])->middleware('can:editar personal')->name('personal.asignaciones.update');
        Route::post('/{personal}/asignaciones/{asignacion}/cerrar', [PersonalAsignacionController::class, 'cerrar'])->middleware('can:editar personal')->name('personal.asignaciones.cerrar');
        Route::delete('/{personal}/asignaciones/{asignacion}', [PersonalAsignacionController::class, 'destroy'])->middleware('can:editar personal')->name('personal.asignaciones.destroy');

        Route::post('/{personal}/armamento/asignar', [PersonalAsignacionController::class, 'asignarArmamento'])->middleware('can:editar personal')->name('personal.armamento.asignar');
        Route::post('/{personal}/armamento/{asignacion}/quitar', [PersonalAsignacionController::class, 'quitarArmamento'])->middleware('can:editar personal')->name('personal.armamento.quitar');
    });

    Route::prefix('armamentos')->middleware('can:ver armamentos')->group(function () {
        Route::get('/', [ArmamentoController::class, 'index'])->name('armamentos.index');
        Route::get('/create', [ArmamentoController::class, 'create'])->middleware('can:crear armamentos')->name('armamentos.create');
        Route::post('/', [ArmamentoController::class, 'store'])->middleware('can:crear armamentos')->name('armamentos.store');
        Route::get('/{armamento}', [ArmamentoController::class, 'show'])->name('armamentos.show');
        Route::get('/{armamento}/edit', [ArmamentoController::class, 'edit'])->middleware('can:editar armamentos')->name('armamentos.edit');
        Route::put('/{armamento}', [ArmamentoController::class, 'update'])->middleware('can:editar armamentos')->name('armamentos.update');
        Route::delete('/{armamento}', [ArmamentoController::class, 'destroy'])->middleware('can:eliminar armamentos')->name('armamentos.destroy');
    });

    Route::prefix('estadisticas')->middleware(['can:ver estadisticas', 'role:Superadmin'])->group(function () {
        Route::get('/',[EstadisticasController::class,'index'])->name('estadisticas.index');
        Route::get('/mapa-regiones',[EstadisticasController::class,'mapaRegiones'])->name('estadisticas.mapaRegiones');
        Route::get('/comparativa-anual',[EstadisticasController::class,'comparativaAnual'])->name('estadisticas.comparativaAnual');
        Route::get('/semaforo-riesgo',[EstadisticasController::class,'semaforoRiesgo'])->name('estadisticas.semaforoRiesgo');
        Route::get('/data/coepra-puntos-licencias',[EstadisticasController::class,'dataCoepraPuntosLicencias'])->name('estadisticas.coepraPuntosLicencias.data');
        Route::get('/powerpoint/coepra-puntos-licencias',[EstadisticasController::class,'descargarPowerPointCoepraPuntos'])->name('estadisticas.coepraPuntosLicencias.powerpoint');
        Route::get('/parte-novedades',[EstadisticasController::class,'parteNovedades'])->name('estadisticas.parteNovedades');
        Route::get('/parte-novedades/descargar',[EstadisticasController::class,'descargarParte'])->name('estadisticas.parteNovedades.descargar');
        Route::get('/mini-parte',[EstadisticasController::class,'miniParte'])->name('estadisticas.miniParte');
        Route::get('/mini-parte/descargar',[EstadisticasController::class,'descargarMiniParte'])->name('estadisticas.miniParte.descargar');
        Route::get('/dictamen',[EstadisticasController::class,'dictamen'])->name('estadisticas.dictamen');
        Route::get('/dictamen/{id}',[EstadisticasController::class,'dictamenShow'])->name('estadisticas.dictamen.show');
        Route::get('/dictamen/{id}/docx',[EstadisticasController::class,'dictamenDocx'])->name('estadisticas.dictamen.docx');
        Route::get('/bitacora',[EstadisticasController::class,'bitacora'])->name('estadisticas.bitacora');
        Route::get('/bitacora/descargar',[EstadisticasController::class,'descargarBitacora'])->name('estadisticas.bitacora.descargar');
    });

    Route::middleware(['auth','can:ver mapa'])->prefix('hechos/zonas')->group(function () {
        Route::get('/', [ZonaMapaController::class, 'index'])->name('hechos.zonas.index');
        Route::post('/consulta', [ZonaMapaController::class, 'hechosEnGeometria'])->name('hechos.zonas.consulta');
    });

    Route::get('/radar-riesgo', [RadarRiesgoController::class, 'index'])->name('radar.riesgo');

    Route::prefix('backups-sql')->middleware(['auth'])->group(function () {
        Route::get('/', [BackupsSqlController::class, 'index'])->name('backups_sql.index');
        Route::post('/subir', [BackupsSqlController::class, 'upload'])->name('backups_sql.upload');
        Route::get('/delegaciones/al-momento', [BackupsSqlController::class, 'downloadDelegaciones'])
            ->name('backups_sql.delegaciones');
        Route::get('/delegaciones/reporte-excel', [BackupsSqlController::class, 'downloadDelegacionesExcel'])
            ->name('backups_sql.delegaciones.excel');

        Route::get('/{file}', [BackupsSqlController::class, 'download'])
            ->name('backups_sql.download');
    });

    Route::prefix('destacamentos')->middleware(['auth','can:ver destacamentos'])->group(function () {
        Route::get('/', [DestacamentoController::class, 'index'])->name('destacamentos.index');
        Route::get('/mapa', [DestacamentoController::class, 'mapa'])->name('destacamentos.mapa');

        Route::get('/create', [DestacamentoController::class, 'create'])->middleware('can:crear destacamentos')->name('destacamentos.create');
        Route::post('/', [DestacamentoController::class, 'store'])->middleware('can:crear destacamentos')->name('destacamentos.store');
        Route::get('/{destacamento}', [DestacamentoController::class, 'show'])->name('destacamentos.show');
        Route::get('/{destacamento}/edit', [DestacamentoController::class, 'edit'])->middleware('can:editar destacamentos')->name('destacamentos.edit');
        Route::put('/{destacamento}', [DestacamentoController::class, 'update'])->middleware('can:editar destacamentos')->name('destacamentos.update');
        Route::delete('/{destacamento}', [DestacamentoController::class, 'destroy'])->middleware('can:eliminar destacamentos')->name('destacamentos.destroy');
    });

    Route::prefix('directorio-red-apoyo')->middleware(['auth','can:ver directorio red apoyo'])->group(function () {
        Route::get('/', [DestacamentoRedApoyoController::class, 'index'])->name('directorio_red_apoyo.index');
        Route::get('/create', [DestacamentoRedApoyoController::class, 'create'])->middleware('can:crear directorio red apoyo')->name('directorio_red_apoyo.create');
        Route::post('/', [DestacamentoRedApoyoController::class, 'store'])->middleware('can:crear directorio red apoyo')->name('directorio_red_apoyo.store');
        Route::get('/{redApoyo}', [DestacamentoRedApoyoController::class, 'show'])->name('directorio_red_apoyo.show');
        Route::get('/{redApoyo}/edit', [DestacamentoRedApoyoController::class, 'edit'])->middleware('can:editar directorio red apoyo')->name('directorio_red_apoyo.edit');
        Route::put('/{redApoyo}', [DestacamentoRedApoyoController::class, 'update'])->middleware('can:editar directorio red apoyo')->name('directorio_red_apoyo.update');
        Route::delete('/{redApoyo}', [DestacamentoRedApoyoController::class, 'destroy'])->middleware('can:eliminar directorio red apoyo')->name('directorio_red_apoyo.destroy');
    });

    Route::prefix('catalogos-actividades')->middleware('can:ver catalogos actividades')->group(function () {
        Route::get('/', [ActividadCategoriaController::class, 'index'])->name('catalogos_actividades.index');
        Route::get('/categorias/create', [ActividadCategoriaController::class, 'create'])->middleware('can:crear catalogos actividades')->name('catalogos_actividades.categorias.create');
        Route::post('/categorias', [ActividadCategoriaController::class, 'store'])->middleware('can:crear catalogos actividades')->name('catalogos_actividades.categorias.store');
        Route::get('/categorias/{actividadCategoria}/edit', [ActividadCategoriaController::class, 'edit'])->middleware('can:editar catalogos actividades')->name('catalogos_actividades.categorias.edit');
        Route::put('/categorias/{actividadCategoria}', [ActividadCategoriaController::class, 'update'])->middleware('can:editar catalogos actividades')->name('catalogos_actividades.categorias.update');
        Route::delete('/categorias/{actividadCategoria}', [ActividadCategoriaController::class, 'destroy'])->middleware('can:eliminar catalogos actividades')->name('catalogos_actividades.categorias.destroy');
        Route::get('/categorias/{actividadCategoria}/subcategorias/create', [ActividadSubcategoriaController::class, 'create'])->middleware('can:crear catalogos actividades')->name('catalogos_actividades.subcategorias.create');
        Route::post('/categorias/{actividadCategoria}/subcategorias', [ActividadSubcategoriaController::class, 'store'])->middleware('can:crear catalogos actividades')->name('catalogos_actividades.subcategorias.store');
        Route::get('/subcategorias/{actividadSubcategoria}/edit', [ActividadSubcategoriaController::class, 'edit'])->middleware('can:editar catalogos actividades')->name('catalogos_actividades.subcategorias.edit');
        Route::put('/subcategorias/{actividadSubcategoria}', [ActividadSubcategoriaController::class, 'update'])->middleware('can:editar catalogos actividades')->name('catalogos_actividades.subcategorias.update');
        Route::delete('/subcategorias/{actividadSubcategoria}', [ActividadSubcategoriaController::class, 'destroy'])->middleware('can:eliminar catalogos actividades')->name('catalogos_actividades.subcategorias.destroy');
        Route::get('/subcategorias/{actividadSubcategoria}/fomento-programas/create', [FomentoCulturaVialProgramaController::class, 'create'])->middleware('can:crear catalogos actividades')->name('catalogos_actividades.fomento_programas.create');
        Route::post('/subcategorias/{actividadSubcategoria}/fomento-programas', [FomentoCulturaVialProgramaController::class, 'store'])->middleware('can:crear catalogos actividades')->name('catalogos_actividades.fomento_programas.store');
        Route::get('/fomento-programas/{fomentoPrograma}/edit', [FomentoCulturaVialProgramaController::class, 'edit'])->middleware('can:editar catalogos actividades')->name('catalogos_actividades.fomento_programas.edit');
        Route::put('/fomento-programas/{fomentoPrograma}', [FomentoCulturaVialProgramaController::class, 'update'])->middleware('can:editar catalogos actividades')->name('catalogos_actividades.fomento_programas.update');
        Route::delete('/fomento-programas/{fomentoPrograma}', [FomentoCulturaVialProgramaController::class, 'destroy'])->middleware('can:eliminar catalogos actividades')->name('catalogos_actividades.fomento_programas.destroy');
    });

    Route::prefix('estadisticas-siniestros')->group(function () {
        Route::get('/', [EstadisticasSiniestrosSettingsController::class, 'index'])->name('settings.estadisticas_siniestros.index');
        Route::get('/parte-novedades', [EstadisticasSiniestrosSettingsController::class, 'parteNovedades'])->name('settings.estadisticas_siniestros.parte_novedades');
        Route::get('/parte-novedades/descargar/{fecha}', [EstadisticasSiniestrosSettingsController::class, 'descargarParteNovedades'])->name('settings.estadisticas_siniestros.parte_novedades.descargar');
        Route::get('/bitacora', [EstadisticasSiniestrosSettingsController::class, 'bitacora'])->name('settings.estadisticas_siniestros.bitacora');
        Route::get('/bitacora/descargar/{fecha}', [EstadisticasSiniestrosSettingsController::class, 'descargarBitacora'])->name('settings.estadisticas_siniestros.bitacora.descargar');
        Route::get('/mini-parte', [EstadisticasSiniestrosSettingsController::class, 'miniParte'])->name('settings.estadisticas_siniestros.mini_parte');
        Route::get('/mini-parte/descargar/{fecha}', [EstadisticasSiniestrosSettingsController::class, 'descargarMiniParte'])->name('settings.estadisticas_siniestros.mini_parte.descargar');
        Route::get('/excel-novedades', [EstadisticasSiniestrosSettingsController::class, 'excelNovedades'])->name('settings.estadisticas_siniestros.excel_novedades');
        Route::get('/excel-novedades/descargar/{fecha}', [EstadisticasSiniestrosSettingsController::class, 'descargarExcelNovedades'])->name('settings.estadisticas_siniestros.excel_novedades.descargar');

        Route::get('/excel-diario', [EstadisticasSiniestrosSettingsController::class, 'excelDiario'])
            ->name('settings.estadisticas_siniestros.excel_diario');

        Route::get('/excel-diario/descargar/{fecha}', [EstadisticasSiniestrosSettingsController::class, 'descargarExcelDiario'])
            ->name('settings.estadisticas_siniestros.excel_diario.descargar');

        Route::get('/actividades', [EstadisticasSiniestrosSettingsController::class, 'actividades'])->name('settings.estadisticas_siniestros.actividades');
        Route::get('/actividades/descargar/{fecha}', [EstadisticasSiniestrosSettingsController::class, 'descargarActividades'])->name('settings.estadisticas_siniestros.actividades.descargar');
        Route::get('/sectorizaciones', [EstadisticasSiniestrosSettingsController::class, 'sectorizaciones'])->name('settings.estadisticas_siniestros.sectorizaciones');
        Route::get('/sectorizaciones/gestionar/{fecha}', [EstadisticasSiniestrosSettingsController::class, 'gestionarSectorizacion'])->name('settings.estadisticas_siniestros.sectorizaciones.gestionar');
        Route::get('/sectorizaciones/data/{fecha}', [EstadisticasSiniestrosSettingsController::class, 'dataSectorizacion'])->name('settings.estadisticas_siniestros.sectorizaciones.data');
        Route::post('/sectorizaciones/guardar', [EstadisticasSiniestrosSettingsController::class, 'guardarSectorizacion'])->name('settings.estadisticas_siniestros.sectorizaciones.guardar');
        Route::get('/sectorizaciones/descargar/{fecha}', [EstadisticasSiniestrosSettingsController::class, 'descargarSectorizacion'])->name('settings.estadisticas_siniestros.sectorizaciones.descargar');
        Route::get('/relacion-armamento', [EstadisticasSiniestrosSettingsController::class, 'relacionArmamento'])->name('settings.estadisticas_siniestros.relacion_armamento');
        Route::get('/relacion-armamento/data', [EstadisticasSiniestrosSettingsController::class, 'dataRelacionArmamento'])->name('settings.estadisticas_siniestros.relacion_armamento.data');
        Route::get('/relacion-armamento/descargar', [EstadisticasSiniestrosSettingsController::class, 'descargarRelacionArmamento'])->name('settings.estadisticas_siniestros.relacion_armamento.descargar');
    });

    Route::prefix('estadisticas-delegaciones')->group(function () {
        Route::get('/', [EstadisticasDelegacionesSettingsController::class, 'index'])->name('settings.estadisticas_delegaciones.index');
        Route::get('/control-hechos', [EstadisticasDelegacionesSettingsController::class, 'controlHechos'])->name('settings.estadisticas_delegaciones.control_hechos');
        Route::post('/control-hechos/{hecho}/mover-corte', [EstadisticasDelegacionesSettingsController::class, 'moverHechoCorte'])->name('settings.estadisticas_delegaciones.control_hechos.mover_corte');
        Route::get('/gruas', [EstadisticasDelegacionesSettingsController::class, 'gruasDelegaciones'])->name('settings.estadisticas_delegaciones.gruas');
        Route::get('/gruas/exportar/{formato}', [EstadisticasDelegacionesSettingsController::class, 'exportarGruasDelegaciones'])->where('formato', 'excel|pdf')->name('settings.estadisticas_delegaciones.gruas.exportar');
        Route::get('/actividades-fisicas', [EstadisticasDelegacionesSettingsController::class, 'actividadesFisicas'])->name('settings.estadisticas_delegaciones.actividades_fisicas');
        Route::post('/actividades-fisicas', [EstadisticasDelegacionesSettingsController::class, 'guardarActividadFisica'])->name('settings.estadisticas_delegaciones.actividades_fisicas.store');
        Route::get('/excel-diario', [EstadisticasDelegacionesSettingsController::class, 'excelDiario'])->name('settings.estadisticas_delegaciones.excel_diario');
        Route::get('/excel-diario/descargar/{fecha}', [EstadisticasDelegacionesSettingsController::class, 'descargarExcelDiario'])->name('settings.estadisticas_delegaciones.excel_diario.descargar');

        Route::get('/excel-mensual', [EstadisticasDelegacionesSettingsController::class,'excelMensual'])->name('settings.estadisticas_delegaciones.excel_mensual');
        Route::get('/excel-mensual/descargar/{fecha}', [EstadisticasDelegacionesSettingsController::class,'descargarExcelMensual'])->name('settings.estadisticas_delegaciones.excel_mensual.descargar');
    });

    Route::prefix('estadisticas-carreteras')->group(function () {
        Route::get('/', [EstadisticasCarreterasSettingsController::class, 'index'])->name('settings.estadisticas_carreteras.index');
        Route::get('/excel-novedades', [EstadisticasCarreterasSettingsController::class, 'excelNovedades'])->name('settings.estadisticas_carreteras.excel_novedades');
    });

    Route::get('/exports/estado-fuerza', [ExportController::class, 'estadoFuerza'])->name('settings.exports.estado_fuerza');
    Route::get('/admin/settings/exports/parte-novedades', [ExportController::class, 'parteNovedades'])->name('settings.exports.parte_novedades');
    Route::get('/admin/settings/exports/bitacora', [ExportController::class, 'bitacora'])->name('settings.exports.bitacora');
    Route::get('/admin/settings/exports/mini-parte', [ExportController::class, 'miniParte'])->name('settings.exports.mini_parte');
    Route::get('/exports/bitacora-turno', [ExportController::class, 'bitacoraTurno'])->name('settings.exports.bitacora_turno');

    Route::prefix('estadisticas-seguridad-vial')->middleware(['auth','can:ver estadisticas'])->group(function () {
        Route::get('/', [EstadisticasSeguridadVialController::class, 'index'])->name('estadisticas_seguridad_vial.index');

        Route::get('/caratula', [EstadisticasSeguridadVialController::class, 'caratula'])->name('estadisticas_seguridad_vial.caratula');

        Route::get('/comparativa-municipios', [EstadisticasSeguridadVialController::class, 'comparativaCiudades'])->name('estadisticas_seguridad_vial.comparativa_municipios');
        Route::get('/comparativa-ciudades', [EstadisticasSeguridadVialController::class, 'comparativaCiudades'])->name('estadisticas_seguridad_vial.comparativa_ciudades');

        Route::get('/data/comparativa-municipios', [EstadisticasSeguridadVialController::class, 'dataComparativaCiudades'])->name('estadisticas_seguridad_vial.data.comparativa_municipios');
        Route::get('/data/comparativa-ciudades', [EstadisticasSeguridadVialController::class, 'dataComparativaCiudades'])->name('estadisticas_seguridad_vial.data.comparativa_ciudades');
        Route::get('/data/mapa-calor-morelia', [EstadisticasSeguridadVialController::class, 'dataMapaCalorMorelia'])->name('estadisticas_seguridad_vial.data.mapa_calor_morelia');
        Route::get('/powerpoint', [EstadisticasSeguridadVialController::class, 'descargarPowerPoint'])->name('estadisticas_seguridad_vial.powerpoint');
    });


});

Route::get('/estadisticas-delegaciones/control-inegi', [EstadisticasDelegacionesSettingsController::class, 'controlInegi'])
    ->middleware(['auth', 'can:menu-estadisticas-delegaciones'])
    ->name('estadisticas_delegaciones.control_inegi');

Route::prefix('admin/settings/estadisticas-vialidad')->middleware(['auth'])->group(function () {
    Route::get('/', [EstadisticasVialidadSettingsController::class, 'index'])->name('settings.estadisticas_vialidad.index');
    Route::get('/excel-diario', [EstadisticasVialidadSettingsController::class, 'excelDiario'])->name('settings.estadisticas_vialidad.excel_diario');
    Route::post('/excel-diario/generar', [EstadisticasVialidadSettingsController::class, 'generarExcelDiario'])->name('settings.estadisticas_vialidad.excel_diario.generar');
    Route::get('/excel-diario/descargar/{fecha}', [EstadisticasVialidadSettingsController::class, 'descargarExcelDiario'])->name('settings.estadisticas_vialidad.excel_diario.descargar');
    Route::get('/informe-gestion', [EstadisticasVialidadSettingsController::class, 'informeGestion'])->name('settings.estadisticas_vialidad.informe_gestion');
    Route::get('/informe-gestion/descargar/{fecha}', [EstadisticasVialidadSettingsController::class, 'descargarInformeGestion'])->name('settings.estadisticas_vialidad.informe_gestion.descargar');
});

Route::prefix('admin/settings/estadisticas-fomento')->middleware(['auth'])->group(function () {
    Route::get('/', [EstadisticasFomentoSettingsController::class, 'index'])->name('settings.estadisticas_fomento.index');
    Route::get('/excel-diario', [EstadisticasFomentoSettingsController::class, 'excelDiario'])->name('settings.estadisticas_fomento.excel_diario');
    Route::post('/excel-diario/generar', [EstadisticasFomentoSettingsController::class, 'generarExcelDiario'])->name('settings.estadisticas_fomento.excel_diario.generar');
    Route::get('/excel-diario/descargar/{fecha}', [EstadisticasFomentoSettingsController::class, 'descargarExcelDiario'])->name('settings.estadisticas_fomento.excel_diario.descargar');
    Route::get('/municipios-atendidos', [EstadisticasFomentoSettingsController::class, 'municipiosAtendidos'])->name('settings.estadisticas_fomento.municipios_atendidos');
    Route::get('/municipios-atendidos/exportar', [EstadisticasFomentoSettingsController::class, 'exportarMunicipiosAtendidos'])->name('settings.estadisticas_fomento.municipios_atendidos.exportar');
    Route::get('/servicios-personal', [EstadisticasFomentoSettingsController::class, 'serviciosPersonal'])->name('settings.estadisticas_fomento.servicios_personal');
});

Route::get('/prueba-404', function () { return response()->view('errors.404', [], 404); });

Route::view('/privacy-policy', 'privacy_policy')->name('privacy.policy');
