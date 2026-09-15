<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\DelegacionActividadFisicaController;
use App\Http\Controllers\Api\DelegacionesHomeController;
use App\Http\Controllers\Api\DelegacionesExcelRevisionController;
use App\Http\Controllers\Api\DocumentoHechoController;
use App\Http\Controllers\Api\GruaController;
use App\Http\Controllers\Api\HechoController;
use App\Http\Controllers\Api\LesionadoController;
use App\Http\Controllers\Api\LocationController;
use App\Http\Controllers\Api\MapaPatrullasController;
use App\Http\Controllers\Api\PersonalController;
use App\Http\Controllers\Api\VehiculoController;
use App\Http\Controllers\Api\AppVersionController;
use App\Http\Controllers\Api\EstadisticasActividadesController;
use App\Http\Controllers\Api\DictamenController;
use App\Http\Controllers\Api\AlertController;
use App\Http\Controllers\Api\ActividadController;
use App\Http\Controllers\Api\FeedController;
use App\Http\Controllers\Api\DeviceTokenController;
use App\Http\Controllers\Api\DirectorioRedApoyoController;
use App\Http\Controllers\Api\MapaIncidenciasController;
use App\Http\Controllers\Api\PendientesCortesController;
use App\Http\Controllers\Api\WhatsAppWebhookController;
use App\Http\Controllers\Api\WhatsAppWebReaderController;
use App\Http\Controllers\Api\C5IInboundController;
use App\Http\Controllers\Api\BotC5IController;
use App\Http\Controllers\Api\WabotIncomingController;
use App\Http\Controllers\Api\WazeFeedController;
use App\Http\Controllers\Api\PeritoHomeController;
use App\Http\Controllers\Api\GuardianesCaminoController as ApiGuardianesCaminoController;
use App\Http\Controllers\Api\GuardianesCaminoDispositivoController as ApiGuardianesCaminoDispositivoController;
use App\Http\Controllers\Api\AgenteUpecHomeController;
use App\Http\Controllers\Api\AgenteVialHomeController;
use App\Http\Controllers\Api\PuestaDisposicionController;
use App\Http\Controllers\Api\CroquisController;
use App\Http\Controllers\Api\CulturaVialController;
use App\Http\Controllers\Api\ChoquesDiariosController;
use App\Http\Controllers\Api\ChoquesDiariosInegiController;
use App\Http\Controllers\Api\ConstanciaManejoController as ApiConstanciaManejoController;
use App\Http\Controllers\Api\ModuloExamenDiarioController as ApiModuloExamenDiarioController;
use App\Http\Controllers\Api\UserController as ApiUserController;
use App\Http\Controllers\Api\SettingsPersonalController;
use App\Http\Controllers\Api\SettingsStatisticsFilesController;
use App\Http\Controllers\Api\TutorialController;
use App\Http\Controllers\Api\LicenciaPuntosController as ApiLicenciaPuntosController;
use App\Http\Controllers\Api\ConduceLegalidadController as ApiConduceLegalidadController;
use App\Http\Controllers\Api\UserNoteController;
use App\Http\Controllers\Api\ComunicacionController as ApiComunicacionController;
use App\Http\Controllers\Api\ControlSemaforicoController;
use App\Http\Controllers\Api\CaleaController as ApiCaleaController;
use App\Http\Controllers\Api\CaleaEncuestaController;
use App\Http\Controllers\Api\AccountSettingsController;

Route::post('/wabot/incoming',[WabotIncomingController::class,'handle']);
Route::post('/bot/c5i/reco',[BotC5IController::class,'recommend']);
Route::post('/c5i/report',[C5IInboundController::class,'handle']);
Route::get('/whatsapp/webhook',[WhatsAppWebhookController::class,'verify']);
Route::post('/whatsapp/webhook',[WhatsAppWebhookController::class,'handle']);
Route::prefix('whatsapp-web-reader')->group(function () {
    Route::post('/groups', [WhatsAppWebReaderController::class, 'syncGroups']);
    Route::post('/messages', [WhatsAppWebReaderController::class, 'storeMessage']);
});

Route::post('/login', [AuthController::class, 'login']);

Route::get('/waze/incidents', [WazeFeedController::class, 'incidents']);

Route::prefix('choques-diarios')->group(function () {
    Route::get('/', [ChoquesDiariosController::class, 'index'])->name('api.choques_diarios.index');
    Route::get('/fecha/{fecha}', [ChoquesDiariosController::class, 'porFecha'])->where('fecha', '[0-9]{4}-[0-9]{2}-[0-9]{2}')->name('api.choques_diarios.fecha');
    Route::get('/hoy', [ChoquesDiariosController::class, 'hoy'])->name('api.choques_diarios.hoy');
    Route::get('/rango', [ChoquesDiariosController::class, 'rango'])->name('api.choques_diarios.rango');
    Route::get('/{hecho}', [ChoquesDiariosController::class, 'show'])->whereNumber('hecho')->name('api.choques_diarios.show');
    Route::get('/eliminados/fecha/{fecha}', [ChoquesDiariosController::class, 'eliminadosPorFecha'])->where('fecha', '[0-9]{4}-[0-9]{2}-[0-9]{2}')->name('api.choques_diarios.eliminados.fecha');
    Route::get('/eliminados/rango', [ChoquesDiariosController::class, 'eliminadosRango'])->name('api.choques_diarios.eliminados.rango');
});

Route::prefix('calea')->middleware(['auth:sanctum', 'can:ver calea'])->group(function () {
    Route::get('/meta', [ApiCaleaController::class, 'meta'])->name('api.calea.meta');
    Route::get('/buscar', [ApiCaleaController::class, 'buscar'])->name('api.calea.buscar');
    Route::get('/estudio', [ApiCaleaController::class, 'estudio'])->name('api.calea.estudio');
    Route::get('/', [ApiCaleaController::class, 'index'])->name('api.calea.index');
    Route::get('/versiones/{version}/pdf', [ApiCaleaController::class, 'pdf'])->whereNumber('version')->name('api.calea.versiones.pdf');
    Route::get('/{directiva}', [ApiCaleaController::class, 'show'])->whereNumber('directiva')->name('api.calea.show');
});

Route::prefix('calea-encuestas/public')->group(function () {
    Route::get('/{codigo}', [CaleaEncuestaController::class, 'publicShow']);
    Route::post('/{codigo}/iniciar', [CaleaEncuestaController::class, 'publicStart'])->middleware('throttle:20,1');
    Route::get('/intentos/{uuid}', [CaleaEncuestaController::class, 'intento']);
    Route::put('/intentos/{uuid}/respuesta', [CaleaEncuestaController::class, 'guardarRespuesta'])->middleware('throttle:120,1');
    Route::post('/intentos/{uuid}/finalizar', [CaleaEncuestaController::class, 'finalizar']);
    Route::post('/intentos/{uuid}/cancelar', [CaleaEncuestaController::class, 'cancelar']);
});

Route::prefix('calea-encuestas')->middleware('auth:sanctum')->group(function () {
    Route::get('/activas', [CaleaEncuestaController::class, 'activas']);
    Route::get('/administrar', [CaleaEncuestaController::class, 'administrar']);
    Route::get('/catalogos', [CaleaEncuestaController::class, 'catalogos']);
    Route::post('/', [CaleaEncuestaController::class, 'store']);
    Route::get('/{encuesta}/resultados', [CaleaEncuestaController::class, 'resultados']);
    Route::post('/{encuesta}/iniciar', [CaleaEncuestaController::class, 'iniciar']);
    Route::get('/intentos/{uuid}', [CaleaEncuestaController::class, 'intento']);
    Route::put('/intentos/{uuid}/respuesta', [CaleaEncuestaController::class, 'guardarRespuesta']);
    Route::post('/intentos/{uuid}/finalizar', [CaleaEncuestaController::class, 'finalizar']);
    Route::post('/intentos/{uuid}/cancelar', [CaleaEncuestaController::class, 'cancelar']);
    Route::post('/{encuesta}/usuarios/{user}/reautorizar', [CaleaEncuestaController::class, 'reautorizar']);
});

Route::prefix('choques-diarios-inegi')->group(function () {
    Route::get('/', [ChoquesDiariosInegiController::class, 'index'])->name('api.choques_diarios_inegi.index');
    Route::get('/fecha/{fecha}', [ChoquesDiariosInegiController::class, 'porFecha'])->where('fecha', '[0-9]{4}-[0-9]{2}-[0-9]{2}')->name('api.choques_diarios_inegi.fecha');
    Route::get('/hoy', [ChoquesDiariosInegiController::class, 'hoy'])->name('api.choques_diarios_inegi.hoy');
    Route::get('/rango', [ChoquesDiariosInegiController::class, 'rango'])->name('api.choques_diarios_inegi.rango');
    Route::get('/{hecho}', [ChoquesDiariosInegiController::class, 'show'])->whereNumber('hecho')->name('api.choques_diarios_inegi.show');
    Route::get('/eliminados/fecha/{fecha}', [ChoquesDiariosInegiController::class, 'eliminadosPorFecha'])->where('fecha', '[0-9]{4}-[0-9]{2}-[0-9]{2}')->name('api.choques_diarios_inegi.eliminados.fecha');
    Route::get('/eliminados/rango', [ChoquesDiariosInegiController::class, 'eliminadosRango'])->name('api.choques_diarios_inegi.eliminados.rango');
});

Route::prefix('cultura-vial/public')->group(function () {
    Route::get('/salas/{codigo}', [CulturaVialController::class, 'publicRoom'])->name('api.cultura_vial.public.salas.show');
    Route::post('/salas/{codigo}/participantes', [CulturaVialController::class, 'join'])->name('api.cultura_vial.public.participantes.store');
    Route::post('/participantes/{participante}/intentos', [CulturaVialController::class, 'storeAttempt'])->whereNumber('participante')->name('api.cultura_vial.public.intentos.store');
});

Route::get('/licencias-puntos/public/numero/{numeroLicencia}', [ApiLicenciaPuntosController::class, 'showPublicByNumero'])
    ->name('api.licencias_puntos.public.numero.show');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/account/settings', [AccountSettingsController::class, 'show'])->name('api.account.settings.show');
    Route::put('/account/settings', [AccountSettingsController::class, 'update'])->name('api.account.settings.update');


    Route::prefix('control-semaforico')->group(function () {
        Route::get('/nodos', [ControlSemaforicoController::class, 'index']);
        Route::get('/nodos/{semaforoNodo}', [ControlSemaforicoController::class, 'show'])->whereNumber('semaforoNodo');
        Route::post('/nodos/sincronizar', [ControlSemaforicoController::class, 'sync']);
    });

    Route::prefix('comunicaciones')->group(function () {
        Route::get('/', [ApiComunicacionController::class, 'index'])->name('api.comunicaciones.index');
        Route::post('/', [ApiComunicacionController::class, 'store'])->name('api.comunicaciones.store');
        Route::get('/destinatarios', [ApiComunicacionController::class, 'destinatarios'])->name('api.comunicaciones.destinatarios');

        Route::get('/catalogos', [ApiComunicacionController::class, 'catalogos'])
            ->name('api.comunicaciones.catalogos');

        Route::get('/no-leidas/count', [ApiComunicacionController::class, 'countNoLeidas'])
            ->name('api.comunicaciones.no_leidas.count');

        Route::get('/conversacion/{user}', [ApiComunicacionController::class, 'conversacion'])
            ->whereNumber('user')
            ->name('api.comunicaciones.conversacion');

        Route::get('/adjuntos/{adjunto}', [ApiComunicacionController::class, 'verAdjunto'])
            ->whereNumber('adjunto')
            ->name('api.comunicaciones.adjuntos.show');

        Route::get('/{comunicacion}', [ApiComunicacionController::class, 'show'])
            ->whereNumber('comunicacion')
            ->name('api.comunicaciones.show');

        Route::post('/{comunicacion}/leer', [ApiComunicacionController::class, 'marcarLeido'])
            ->whereNumber('comunicacion')
            ->name('api.comunicaciones.leer');

        Route::post('/{comunicacion}/enterado', [ApiComunicacionController::class, 'marcarEnterado'])
            ->whereNumber('comunicacion')
            ->name('api.comunicaciones.enterado');
    });

    Route::prefix('notes')->group(function () {
        Route::get('/', [UserNoteController::class, 'index'])->name('api.notes.index');
        Route::post('/', [UserNoteController::class, 'store'])->name('api.notes.store');
        Route::put('/{note}', [UserNoteController::class, 'update'])->whereNumber('note')->name('api.notes.update');
        Route::delete('/{note}', [UserNoteController::class, 'destroy'])->whereNumber('note')->name('api.notes.destroy');
    });

    Route::prefix('perito-home')->middleware(['role:Perito', 'unidad:siniestros'])->group(function () {
        Route::get('/mapa', [PeritoHomeController::class, 'mapa'])->name('api.perito_home.mapa');
        Route::get('/filtros', [PeritoHomeController::class, 'filtros'])->name('api.perito_home.filtros');
        Route::get('/hechos/{hecho}', [PeritoHomeController::class, 'show'])->name('api.perito_home.hechos.show');
    });

    Route::prefix('agente-upec-home')->middleware(['role:Agente Upec'])->group(function () {
        Route::get('/mapa', [AgenteUpecHomeController::class, 'mapa'])->name('api.agente_upec_home.mapa');
        Route::get('/filtros', [AgenteUpecHomeController::class, 'filtros'])->name('api.agente_upec_home.filtros');
        Route::get('/alertas/{id}', [AgenteUpecHomeController::class, 'show'])->name('api.agente_upec_home.alertas.show');
    });

    Route::prefix('agente-vial-home')->middleware(['role:Agente Vial', 'unidad:vialidades-urbanas'])->group(function () {
        Route::get('/mapa', [AgenteVialHomeController::class, 'mapa'])->name('api.agente_vial_home.mapa');
        Route::get('/filtros', [AgenteVialHomeController::class, 'filtros'])->name('api.agente_vial_home.filtros');
        Route::get('/alertas/{id}', [AgenteVialHomeController::class, 'show'])->name('api.agente_vial_home.alertas.show');
    });

    Route::prefix('delegaciones-home')->group(function () {
        Route::get('/mapa', [DelegacionesHomeController::class, 'mapa'])->name('api.delegaciones_home.mapa');
        Route::get('/filtros', [DelegacionesHomeController::class, 'filtros'])->name('api.delegaciones_home.filtros');
    });

    Route::prefix('delegaciones/actividades-fisicas')->group(function () {
        Route::get('/tipos', [DelegacionActividadFisicaController::class, 'tipos'])->name('api.delegaciones.actividades_fisicas.tipos');
        Route::get('/', [DelegacionActividadFisicaController::class, 'index'])->name('api.delegaciones.actividades_fisicas.index');
        Route::post('/', [DelegacionActividadFisicaController::class, 'store'])->name('api.delegaciones.actividades_fisicas.store');
        Route::get('/{actividadFisica}', [DelegacionActividadFisicaController::class, 'show'])->whereNumber('actividadFisica')->name('api.delegaciones.actividades_fisicas.show');
    });

    Route::prefix('directorio-red-apoyo')->middleware('can:ver directorio red apoyo')->group(function () {
        Route::get('/meta', [DirectorioRedApoyoController::class, 'meta'])->name('api.directorio_red_apoyo.meta');
        Route::get('/', [DirectorioRedApoyoController::class, 'index'])->name('api.directorio_red_apoyo.index');
        Route::get('/{redApoyo}', [DirectorioRedApoyoController::class, 'show'])->whereNumber('redApoyo')->name('api.directorio_red_apoyo.show');
    });

    Route::prefix('constancias-manejo')->middleware('can:ver modulo examenes')->group(function () {
        Route::get('/', [ApiConstanciaManejoController::class, 'index'])->name('api.constancias_manejo.index');
        Route::get('/modulos', [ApiConstanciaManejoController::class, 'modulos'])->name('api.constancias_manejo.modulos');
        Route::post('/', [ApiConstanciaManejoController::class, 'store'])->middleware('can:crear modulo examenes')->name('api.constancias_manejo.store');
        Route::post('/examenes', [ApiConstanciaManejoController::class, 'storeExamen'])->middleware('can:editar modulo examenes')->name('api.constancias_manejo.examenes.store');
        Route::get('/examenes/qr/{token}', [ApiConstanciaManejoController::class, 'buscarExamenPorQr'])->name('api.constancias_manejo.examenes.qr');
        Route::get('/examenes/{solicitud}/qr', [ApiConstanciaManejoController::class, 'examenSolicitudQr'])->whereNumber('solicitud')->name('api.constancias_manejo.examenes.qr_png');
        Route::post('/examenes/{solicitud}/capturar-impreso', [ApiConstanciaManejoController::class, 'capturarExamenSolicitudImpresa'])->middleware('can:editar modulo examenes')->whereNumber('solicitud')->name('api.constancias_manejo.examenes.capturar_impreso');
        Route::post('/examenes/{solicitud}/activar-constancia', [ApiConstanciaManejoController::class, 'activarConExamen'])->middleware('can:editar modulo examenes')->whereNumber('solicitud')->name('api.constancias_manejo.examenes.activar_constancia');
        Route::get('/qr/{token}', [ApiConstanciaManejoController::class, 'buscarPorQr'])->name('api.constancias_manejo.qr');
        Route::get('/examen-escrito/{token}', [ApiConstanciaManejoController::class, 'buscarExamenEscritoPorQr'])->name('api.constancias_manejo.examen_escrito_qr');
        Route::get('/{constancia}', [ApiConstanciaManejoController::class, 'show'])->whereNumber('constancia')->name('api.constancias_manejo.show');
        Route::get('/{constancia}/acceso-qr', [ApiConstanciaManejoController::class, 'accesoQr'])->whereNumber('constancia')->name('api.constancias_manejo.acceso_qr');
        Route::get('/{constancia}/examen-escrito-qr', [ApiConstanciaManejoController::class, 'examenEscritoQr'])->whereNumber('constancia')->name('api.constancias_manejo.examen_escrito_qr_png');
        Route::post('/{constancia}/generar-acceso', [ApiConstanciaManejoController::class, 'generarAcceso'])->middleware('can:editar modulo examenes')->whereNumber('constancia')->name('api.constancias_manejo.generar_acceso');
        Route::post('/{constancia}/generar-examen-escrito', [ApiConstanciaManejoController::class, 'generarExamenEscrito'])->middleware('can:editar modulo examenes')->whereNumber('constancia')->name('api.constancias_manejo.generar_examen_escrito');
        Route::post('/{constancia}/capturar-impreso', [ApiConstanciaManejoController::class, 'capturarImpreso'])->middleware('can:editar modulo examenes')->whereNumber('constancia')->name('api.constancias_manejo.capturar_impreso');
        Route::post('/{constancia}/activar', [ApiConstanciaManejoController::class, 'activar'])->middleware('can:editar modulo examenes')->whereNumber('constancia')->name('api.constancias_manejo.activar');
        Route::post('/{constancia}/cancelar-acceso', [ApiConstanciaManejoController::class, 'cancelarAcceso'])->middleware('can:editar modulo examenes')->whereNumber('constancia')->name('api.constancias_manejo.cancelar_acceso');
    });

    Route::prefix('modulo-examenes-diarios')->middleware('can:ver modulo examenes')->group(function () {
        Route::get('/', [ApiModuloExamenDiarioController::class, 'index'])->name('api.modulo_examenes_diarios.index');
        Route::post('/', [ApiModuloExamenDiarioController::class, 'store'])->middleware('can:crear modulo examenes')->name('api.modulo_examenes_diarios.store');
        Route::get('/{registro}', [ApiModuloExamenDiarioController::class, 'show'])->whereNumber('registro')->name('api.modulo_examenes_diarios.show');
        Route::put('/{registro}', [ApiModuloExamenDiarioController::class, 'update'])->whereNumber('registro')->middleware('can:editar modulo examenes')->name('api.modulo_examenes_diarios.update');
        Route::delete('/{registro}', [ApiModuloExamenDiarioController::class, 'destroy'])->whereNumber('registro')->middleware('can:eliminar modulo examenes')->name('api.modulo_examenes_diarios.destroy');
    });

    Route::prefix('licencias-puntos')->middleware('can:ver puntos licencias')->group(function () {
        Route::get('/meta', [ApiLicenciaPuntosController::class, 'meta'])->name('api.licencias_puntos.meta');
        Route::get('/', [ApiLicenciaPuntosController::class, 'index'])->name('api.licencias_puntos.index');
        Route::get('/catalogo-infracciones', [ApiLicenciaPuntosController::class, 'catalogoInfracciones'])->name('api.licencias_puntos.infracciones.catalogo');
        Route::post('/', [ApiLicenciaPuntosController::class, 'store'])->middleware('can:registrar infracciones puntos licencias')->name('api.licencias_puntos.store');
        Route::post('/infracciones', [ApiLicenciaPuntosController::class, 'registrarInfraccion'])->middleware('can:registrar infracciones puntos licencias')->name('api.licencias_puntos.infracciones.store');
        Route::get('/numero/{numeroLicencia}', [ApiLicenciaPuntosController::class, 'showByNumero'])->name('api.licencias_puntos.numero.show');
        Route::get('/{cuenta}', [ApiLicenciaPuntosController::class, 'show'])->whereNumber('cuenta')->name('api.licencias_puntos.show');
        Route::post('/{cuenta}/infracciones', [ApiLicenciaPuntosController::class, 'registrarInfraccionCuenta'])->whereNumber('cuenta')->middleware('can:registrar infracciones puntos licencias')->name('api.licencias_puntos.cuenta.infracciones.store');
        Route::post('/{cuenta}/capacitacion', [ApiLicenciaPuntosController::class, 'acreditarCapacitacion'])->whereNumber('cuenta')->middleware('can:acreditar capacitacion puntos licencias')->name('api.licencias_puntos.capacitacion.store');
    });

    Route::prefix('conduce-legalidad')->group(function () {
        Route::get('/meta', [ApiConduceLegalidadController::class, 'meta'])->name('api.conduce_legalidad.meta');
        Route::get('/gruas-siniestros', [ApiConduceLegalidadController::class, 'gruasSiniestros'])->name('api.conduce_legalidad.gruas_siniestros');
        Route::get('/buscar', [ApiConduceLegalidadController::class, 'buscar'])->name('api.conduce_legalidad.buscar');
        Route::get('/operativos', [ApiConduceLegalidadController::class, 'index'])->name('api.conduce_legalidad.operativos.index');
        Route::post('/operativos', [ApiConduceLegalidadController::class, 'storeOperativo'])->name('api.conduce_legalidad.operativos.store');
        Route::get('/operativos/{operativo}', [ApiConduceLegalidadController::class, 'show'])->whereNumber('operativo')->name('api.conduce_legalidad.operativos.show');
        Route::get('/operativos/{operativo}/native-share', [ApiConduceLegalidadController::class, 'nativeShareOperativo'])->whereNumber('operativo')->name('api.conduce_legalidad.operativos.native_share');
        Route::put('/operativos/{operativo}', [ApiConduceLegalidadController::class, 'updateOperativo'])->whereNumber('operativo')->name('api.conduce_legalidad.operativos.update');
        Route::delete('/operativos/{operativo}', [ApiConduceLegalidadController::class, 'destroyOperativo'])->whereNumber('operativo')->name('api.conduce_legalidad.operativos.destroy');
        Route::post('/operativos/{operativo}/rnd-chatbot', [ApiConduceLegalidadController::class, 'sendRndChatbot'])->whereNumber('operativo')->name('api.conduce_legalidad.rnd_chatbot');
        Route::post('/operativos/{operativo}/capturas', [ApiConduceLegalidadController::class, 'storeCaptura'])->whereNumber('operativo')->name('api.conduce_legalidad.capturas.store');
        Route::put('/operativos/{operativo}/capturas/{captura}', [ApiConduceLegalidadController::class, 'updateCaptura'])->whereNumber('operativo')->whereNumber('captura')->name('api.conduce_legalidad.capturas.update');
        Route::delete('/operativos/{operativo}/capturas/{captura}', [ApiConduceLegalidadController::class, 'destroyCaptura'])->whereNumber('operativo')->whereNumber('captura')->name('api.conduce_legalidad.capturas.destroy');
        Route::get('/operativos/{operativo}/capturas/{captura}/native-share', [ApiConduceLegalidadController::class, 'nativeShareCaptura'])->whereNumber('operativo')->whereNumber('captura')->name('api.conduce_legalidad.capturas.native_share');
        Route::get('/operativos/{operativo}/capturas/{captura}/iph-puesta-disposicion', [ApiConduceLegalidadController::class, 'descargarIphCaptura'])->whereNumber('operativo')->whereNumber('captura')->name('api.conduce_legalidad.capturas.iph_puesta_disposicion');
    });

    Route::prefix('guardianes-camino')->middleware(['unidad:carreteras'])->group(function () {
        Route::get('/', [ApiGuardianesCaminoController::class, 'index'])->name('api.guardianes_camino.index');
        Route::get('/resumen', [ApiGuardianesCaminoController::class, 'resumen'])->name('api.guardianes_camino.resumen');
        Route::get('/whatsapp', [ApiGuardianesCaminoController::class, 'whatsapp'])->name('api.guardianes_camino.whatsapp');

        Route::prefix('dispositivos')->group(function () {
            Route::get('/create', [ApiGuardianesCaminoDispositivoController::class, 'create'])->name('api.guardianes_camino.dispositivos.create');
            Route::get('/', [ApiGuardianesCaminoDispositivoController::class, 'index'])->name('api.guardianes_camino.dispositivos.index');
            Route::post('/', [ApiGuardianesCaminoDispositivoController::class, 'store'])->name('api.guardianes_camino.dispositivos.store');
            Route::post('/fotos', [ApiGuardianesCaminoDispositivoController::class, 'storeFotos'])->name('api.guardianes_camino.dispositivos.fotos.store_por_cliente');
            Route::post('/relacionados', [ApiGuardianesCaminoDispositivoController::class, 'storeRelacionados'])->name('api.guardianes_camino.dispositivos.relacionados.store_por_cliente');
            Route::get('/pendientes-revision', [ApiGuardianesCaminoDispositivoController::class, 'pendientesRevision'])->middleware('can:editar operativos carreteras')->name('api.guardianes_camino.dispositivos.pendientes_revision');
            Route::get('/count-pendientes-revision', [ApiGuardianesCaminoDispositivoController::class, 'countPendientesRevision'])->middleware('can:editar operativos carreteras')->name('api.guardianes_camino.dispositivos.count_pendientes_revision');
            Route::post('/{dispositivo}/fotos', [ApiGuardianesCaminoDispositivoController::class, 'storeFotos'])->name('api.guardianes_camino.dispositivos.fotos.store');
            Route::post('/{dispositivo}/relacionados', [ApiGuardianesCaminoDispositivoController::class, 'storeRelacionados'])->name('api.guardianes_camino.dispositivos.relacionados.store');
            Route::post('/{dispositivo}/aprobar-revision', [ApiGuardianesCaminoDispositivoController::class, 'aprobarRevision'])->middleware('can:editar operativos carreteras')->name('api.guardianes_camino.dispositivos.aprobar_revision');
            Route::post('/{dispositivo}/rechazar-revision', [ApiGuardianesCaminoDispositivoController::class, 'rechazarRevision'])->middleware('can:editar operativos carreteras')->name('api.guardianes_camino.dispositivos.rechazar_revision');
            Route::get('/{dispositivo}', [ApiGuardianesCaminoDispositivoController::class, 'show'])->name('api.guardianes_camino.dispositivos.show');
            Route::put('/{dispositivo}', [ApiGuardianesCaminoDispositivoController::class, 'update'])->middleware('can:editar operativos carreteras')->name('api.guardianes_camino.dispositivos.update');
            Route::delete('/{dispositivo}', [ApiGuardianesCaminoDispositivoController::class, 'destroy'])->middleware('can:eliminar operativos carreteras')->name('api.guardianes_camino.dispositivos.destroy');
            Route::get('/{dispositivo}/whatsapp', [ApiGuardianesCaminoDispositivoController::class, 'whatsapp'])->name('api.guardianes_camino.dispositivos.whatsapp');
        });
    });


    Route::get('/home', [DashboardController::class, 'home'])->name('api.home');
    Route::post('/device-tokens', [DeviceTokenController::class, 'store']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::get('/profile', [AuthController::class, 'profile']);
    Route::put('/profile/password', [AuthController::class, 'changePassword']);
    Route::get('/permissions', [AuthController::class, 'permissions']);
    Route::get('/feed', [FeedController::class, 'index'])->name('api.feed.index');
    Route::get('/tutoriales', [TutorialController::class, 'index'])->name('api.tutoriales.index');
    Route::get('/delegaciones/excel-revision', [DelegacionesExcelRevisionController::class, 'show'])
        ->name('api.delegaciones.excel_revision.show');

    Route::prefix('settings/users')->middleware('can:ver usuarios')->group(function () {
        Route::get('/meta', [ApiUserController::class, 'meta'])->name('api.settings.users.meta');
        Route::get('/', [ApiUserController::class, 'index'])->name('api.settings.users.index');
        Route::post('/', [ApiUserController::class, 'store'])->middleware('can:crear usuarios')->name('api.settings.users.store');
        Route::get('/{user}', [ApiUserController::class, 'show'])->whereNumber('user')->name('api.settings.users.show');
        Route::put('/{user}', [ApiUserController::class, 'update'])->middleware('can:editar usuarios')->whereNumber('user')->name('api.settings.users.update');
    });

    Route::prefix('settings/personal')->middleware('can:ver personal')->group(function () {
        Route::get('/meta', [SettingsPersonalController::class, 'meta'])->name('api.settings.personal.meta');
        Route::get('/', [SettingsPersonalController::class, 'index'])->name('api.settings.personal.index');
        Route::get('/{personal}', [SettingsPersonalController::class, 'show'])->whereNumber('personal')->name('api.settings.personal.show');
        Route::post('/{personal}/incidencias', [SettingsPersonalController::class, 'storeIncidencia'])->middleware('can:editar personal')->whereNumber('personal')->name('api.settings.personal.incidencias.store');
    });

    Route::prefix('settings/statistics-files')->group(function () {
        Route::get('/', [SettingsStatisticsFilesController::class, 'index'])->name('api.settings.statistics_files.index');
        Route::get('/{module}/{report}/{date}/download', [SettingsStatisticsFilesController::class, 'download'])
            ->where('module', 'siniestros|delegaciones|vialidades|fomento')
            ->where('report', '[A-Za-z0-9_-]+')
            ->where('date', '\d{4}-\d{2}(?:-\d{2})?')
            ->name('api.settings.statistics_files.download');
    });

    Route::prefix('cultura-vial')->middleware(['unidad:cultura-vial'])->group(function () {
        Route::get('/salas', [CulturaVialController::class, 'index'])->name('api.cultura_vial.salas.index');
        Route::post('/salas', [CulturaVialController::class, 'store'])->name('api.cultura_vial.salas.store');
        Route::get('/salas/{sala}', [CulturaVialController::class, 'show'])->whereNumber('sala')->name('api.cultura_vial.salas.show');
        Route::post('/salas/{sala}/cerrar', [CulturaVialController::class, 'close'])->whereNumber('sala')->name('api.cultura_vial.salas.close');
        Route::get('/salas/{sala}/qr', [CulturaVialController::class, 'qr'])->whereNumber('sala')->name('api.cultura_vial.salas.qr');
    });

    Route::middleware('can:ver mapa')->group(function () {
        Route::get('/mapa-incidencias', [MapaIncidenciasController::class, 'index'])->name('api.mapa.incidencias.index');
        Route::get('/mapa-incidencias/data', [MapaIncidenciasController::class, 'data'])->name('api.mapa.incidencias.data');
    });

    Route::prefix('pendientes')->middleware('can:ver hechos')->group(function () {
        Route::get('/cortes', [PendientesCortesController::class, 'index'])->name('api.hechos.pendientes.cortes.index');
        Route::get('/cortes/{corte}', [PendientesCortesController::class, 'show'])->whereNumber('corte')->name('api.hechos.pendientes.cortes.show');
        Route::get('/delegaciones/cortes', [PendientesCortesController::class, 'indexDelegaciones'])->name('api.hechos.pendientes.delegaciones.cortes.index');
        Route::get('/delegaciones/cortes/{corte}', [PendientesCortesController::class, 'showDelegaciones'])->whereNumber('corte')->name('api.hechos.pendientes.delegaciones.cortes.show');
    });

    Route::prefix('actividades')->group(function () {
        Route::get('/categorias', [ActividadController::class, 'categorias'])->name('api.actividades.categorias');
        Route::get('/subcategorias/{categoria}', [ActividadController::class, 'subcategorias'])->whereNumber('categoria')->name('api.actividades.subcategorias');
        Route::get('/informe/diario', [ActividadController::class, 'informeDiario'])->name('api.actividades.informe.diario');
        Route::get('/informe/fecha/{fecha}', [ActividadController::class, 'informeFecha'])->name('api.actividades.informe.fecha');
        Route::get('/compartir-totales-whatsapp', [ActividadController::class, 'compartirTotalesWhatsapp'])->name('api.actividades.compartir_totales');
        Route::get('/{actividad}/compartir', [ActividadController::class, 'compartir'])->whereNumber('actividad')->name('api.actividades.compartir');
        Route::get('/', [ActividadController::class, 'index'])->name('api.actividades.index');
        Route::post('/', [ActividadController::class, 'store'])->middleware('can:crear actividades')->name('api.actividades.store');
        Route::get('/{actividad}', [ActividadController::class, 'show'])->whereNumber('actividad')->name('api.actividades.show');
        Route::put('/{actividad}', [ActividadController::class, 'update'])->whereNumber('actividad')->middleware('can:editar actividades')->name('api.actividades.update');
        Route::delete('/{actividad}', [ActividadController::class, 'destroy'])->whereNumber('actividad')->middleware('can:eliminar actividades')->name('api.actividades.destroy');
        Route::post('/{actividad}/vehiculos', [ActividadController::class, 'storeVehiculo'])->whereNumber('actividad')->middleware('can:editar actividades')->name('api.actividades.vehiculos.store');
        Route::put('/{actividad}/vehiculos/{vehiculo}', [ActividadController::class, 'updateVehiculo'])->whereNumber('actividad')->whereNumber('vehiculo')->middleware('can:editar actividades')->name('api.actividades.vehiculos.update');
        Route::delete('/{actividad}/vehiculos/{vehiculo}', [ActividadController::class, 'destroyVehiculo'])->whereNumber('actividad')->whereNumber('vehiculo')->middleware('can:editar actividades')->name('api.actividades.vehiculos.destroy');
    });

    Route::prefix('vialidades-urbanas')->middleware(['can:ver operativos vialidades'])->group(function () {
        Route::get('/', [\App\Http\Controllers\Api\VialidadesUrbanasController::class, 'index'])->name('api.vialidades_urbanas.index');
        Route::post('/', [\App\Http\Controllers\Api\VialidadesUrbanasController::class, 'store'])->middleware('can:crear operativos vialidades')->name('api.vialidades_urbanas.store');
        Route::get('/{vialidadUrbana}', [\App\Http\Controllers\Api\VialidadesUrbanasController::class, 'show'])->name('api.vialidades_urbanas.show');
        Route::put('/{vialidadUrbana}', [\App\Http\Controllers\Api\VialidadesUrbanasController::class, 'update'])->middleware('can:editar operativos vialidades')->name('api.vialidades_urbanas.update');
        Route::delete('/{vialidadUrbana}', [\App\Http\Controllers\Api\VialidadesUrbanasController::class, 'destroy'])->middleware('can:eliminar operativos vialidades')->name('api.vialidades_urbanas.destroy');

        Route::get('/{vialidadUrbana}/resumen', [\App\Http\Controllers\Api\VialidadesUrbanasController::class, 'resumen'])->name('api.vialidades_urbanas.resumen');
        Route::get('/{vialidadUrbana}/whatsapp', [\App\Http\Controllers\Api\VialidadesUrbanasController::class, 'whatsapp'])->name('api.vialidades_urbanas.whatsapp');

        Route::prefix('{vialidadUrbana}/dispositivos')->group(function () {
            Route::get('/{dispositivo}', [\App\Http\Controllers\Api\VialidadesUrbanasDispositivoController::class, 'index'])->name('api.vialidades_urbanas.dispositivos.index');
            Route::post('/{dispositivo}', [\App\Http\Controllers\Api\VialidadesUrbanasDispositivoController::class, 'store'])->name('api.vialidades_urbanas.dispositivos.store');
            Route::get('/{dispositivo}/show', [\App\Http\Controllers\Api\VialidadesUrbanasDispositivoController::class, 'show'])->name('api.vialidades_urbanas.dispositivos.show');
            Route::put('/{dispositivo}', [\App\Http\Controllers\Api\VialidadesUrbanasDispositivoController::class, 'update'])->name('api.vialidades_urbanas.dispositivos.update');
            Route::delete('/{dispositivo}/{detalle}', [\App\Http\Controllers\Api\VialidadesUrbanasDispositivoController::class, 'destroy'])->name('api.vialidades_urbanas.dispositivos.destroy');
            Route::get('/{dispositivo}/whatsapp', [\App\Http\Controllers\Api\VialidadesUrbanasDispositivoController::class, 'whatsapp'])->name('api.vialidades_urbanas.dispositivos.whatsapp');
        });
    });


    Route::get('/alerts', [AlertController::class, 'index']);
    Route::post('/alerts/{alert}/read', [AlertController::class, 'markRead']);
    Route::post('/alerts/read-all', [AlertController::class, 'markReadAll']);

    Route::get('/dictamenes/buscar', [DictamenController::class, 'buscar'])->middleware('can:ver dictamenes')->name('api.dictamenes.buscar');
    Route::get('/dictamenes', [DictamenController::class, 'index'])->middleware('can:ver dictamenes')->name('api.dictamenes.index');
    Route::post('/dictamenes', [DictamenController::class, 'store'])->middleware('can:crear dictamenes')->name('api.dictamenes.store');
    Route::get('/dictamenes/{dictamen}/archivo', [DictamenController::class, 'archivo'])->middleware('can:ver dictamenes')->name('api.dictamenes.archivo');
    Route::get('/dictamenes/{dictamen}', [DictamenController::class, 'show'])->middleware('can:ver dictamenes')->name('api.dictamenes.show');
    Route::put('/dictamenes/{dictamen}', [DictamenController::class, 'update'])->middleware('can:editar dictamenes')->name('api.dictamenes.update');
    Route::delete('/dictamenes/{dictamen}', [DictamenController::class, 'destroy'])->middleware('can:eliminar dictamenes')->name('api.dictamenes.destroy');

    Route::prefix('puestas-disposicion')->group(function () {
        Route::get('/', [PuestaDisposicionController::class, 'index'])->middleware('can:ver puestas a disposicion')->name('api.puestas_disposicion.index');
        Route::post('/', [PuestaDisposicionController::class, 'store'])->middleware('can:crear puestas a disposicion')->name('api.puestas_disposicion.store');
        Route::get('/{puestaDisposicion}/archivo', [PuestaDisposicionController::class, 'archivo'])->whereNumber('puestaDisposicion')->middleware('can:ver puestas a disposicion')->name('api.puestas_disposicion.archivo');
        Route::get('/{puestaDisposicion}/uso-fuerza', [PuestaDisposicionController::class, 'archivoUsoFuerzaGeneral'])->whereNumber('puestaDisposicion')->middleware('can:ver puestas a disposicion')->name('api.puestas_disposicion.uso_fuerza');
        Route::get('/{puestaDisposicion}/personas/{persona}/uso-fuerza', [PuestaDisposicionController::class, 'archivoUsoFuerza'])->whereNumber('puestaDisposicion')->whereNumber('persona')->middleware('can:ver puestas a disposicion')->name('api.puestas_disposicion.personas.uso_fuerza');
        Route::get('/{puestaDisposicion}', [PuestaDisposicionController::class, 'show'])->whereNumber('puestaDisposicion')->middleware('can:ver puestas a disposicion')->name('api.puestas_disposicion.show');
        Route::put('/{puestaDisposicion}', [PuestaDisposicionController::class, 'update'])->whereNumber('puestaDisposicion')->middleware('can:editar puestas a disposicion')->name('api.puestas_disposicion.update');
        Route::delete('/{puestaDisposicion}', [PuestaDisposicionController::class, 'destroy'])->whereNumber('puestaDisposicion')->middleware('can:eliminar puestas a disposicion')->name('api.puestas_disposicion.destroy');
    });

    Route::get('/gruas', [GruaController::class, 'index'])->middleware('can:ver gruas');
    Route::get('/gruas/listado', [GruaController::class, 'listado'])->middleware('can:ver gruas');
    Route::get('/gruas/delegaciones', [GruaController::class, 'delegaciones'])->middleware('can:ver estadisticas');
    Route::get('/gruas/grafica-semanal', [GruaController::class, 'graficaSemanal'])->middleware('can:ver estadisticas');
    Route::get('/gruas/resumen-semanal', [GruaController::class, 'resumenSemanal'])->middleware('can:ver estadisticas');
    Route::get('/gruas/resumen-semanal-detallado', [GruaController::class, 'resumenSemanalDetallado'])->middleware('can:ver estadisticas');

    Route::get('/hechos/buscar', [HechoController::class, 'buscar'])->middleware('can:ver hechos');
    Route::get('/hechos/seguimiento', [HechoController::class, 'seguimiento'])->middleware('can:ver hechos');
    Route::get('/hechos', [HechoController::class, 'index'])->middleware('can:ver hechos');
    Route::post('/hechos', [HechoController::class, 'store'])->middleware('can:crear hechos');
    Route::get('/hechos/{hecho}', [HechoController::class, 'show'])->middleware('can:ver hechos');
    Route::put('/hechos/{hecho}', [HechoController::class, 'update']);
    Route::delete('/hechos/{hecho}', [HechoController::class, 'destroy'])->middleware('can:eliminar hechos');
    Route::post('/hechos/{hecho}/descargo', [HechoController::class, 'subirDescargo']);
    Route::post('/hechos/{hecho}/iph-delegacion', [HechoController::class, 'subirIphDelegacion']);
    Route::post('/hechos/{hecho}/dictamen-delegacion', [HechoController::class, 'subirIphDelegacion']);
    Route::get('/hechos/{hecho}/native-share', [HechoController::class, 'nativeShare'])->middleware('can:ver hechos');
    Route::get('/hechos/{hecho}/whatsapp-link', [HechoController::class, 'whatsappLink'])->middleware('can:ver hechos');

    Route::get('/hechos/{hecho}/vehiculos', [VehiculoController::class, 'index']);
    Route::post('/hechos/{hecho}/vehiculos', [VehiculoController::class, 'store']);
    Route::post('/vehiculos', [VehiculoController::class, 'store']);
    Route::get('/hechos/{hecho}/vehiculos/{vehiculo}', [VehiculoController::class, 'show']);
    Route::put('/hechos/{hecho}/vehiculos/{vehiculo}', [VehiculoController::class, 'update']);
    Route::delete('/hechos/{hecho}/vehiculos/{vehiculo}', [VehiculoController::class, 'destroy']);
    Route::get('/hechos/{hecho}/vehiculos/{vehiculo}/foto', [VehiculoController::class, 'foto']);
    Route::post('/hechos/{hecho}/vehiculos/{vehiculo}/foto', [VehiculoController::class, 'fotoUpdate']);
    Route::delete('/hechos/{hecho}/vehiculos/{vehiculo}/foto', [VehiculoController::class, 'fotoDestroy']);

    Route::get('/hechos/{hecho}/vehiculos/{vehiculo}/inventario-grua', [VehiculoController::class, 'inventarioGrua']);
    Route::post('/hechos/{hecho}/vehiculos/{vehiculo}/inventario-grua', [VehiculoController::class, 'inventarioGruaUpdate']);
    Route::delete('/hechos/{hecho}/vehiculos/{vehiculo}/inventario-grua', [VehiculoController::class, 'inventarioGruaDestroy']);

    Route::get('/hechos/{hecho}/lesionados', [LesionadoController::class, 'index'])->middleware('can:ver lesionados');
    Route::post('/hechos/{hecho}/lesionados', [LesionadoController::class, 'store'])->middleware('can:crear lesionados');
    Route::post('/lesionados', [LesionadoController::class, 'store'])->middleware('can:crear lesionados');
    Route::get('/hechos/{hecho}/lesionados/{lesionado}', [LesionadoController::class, 'show'])->middleware('can:ver lesionados');
    Route::put('/hechos/{hecho}/lesionados/{lesionado}', [LesionadoController::class, 'update'])->middleware('can:editar lesionados');
    Route::delete('/hechos/{hecho}/lesionados/{lesionado}', [LesionadoController::class, 'destroy'])->middleware('can:eliminar lesionados');

    Route::get('/hechos/{hecho}/croquis', [CroquisController::class, 'show'])->middleware('can:ver hechos');
    Route::get('/hechos/{hecho}/croquis/preview', [CroquisController::class, 'preview'])->middleware('can:ver hechos')->name('api.croquis.preview');
    Route::post('/hechos/{hecho}/croquis', [CroquisController::class, 'store']);
    Route::put('/hechos/{hecho}/croquis', [CroquisController::class, 'update']);
    Route::delete('/hechos/{hecho}/croquis', [CroquisController::class, 'destroy']);

    Route::post('/location/response-route', [\App\Http\Controllers\Api\C5iRouteController::class, 'store']);
    Route::post('/location', [LocationController::class, 'store']);
    Route::post('/suspicious-place-events', [LocationController::class, 'storeSuspiciousPlaceEvent']);
    Route::get('/location/last', [LocationController::class, 'last']);
    Route::get('/users/{user}/location/last', [LocationController::class, 'lastByUser']);
    Route::get('/locations', [LocationController::class, 'index']);

    Route::get('/dashboard/accidentes-hoy', [DashboardController::class, 'accidentesHoy'])->middleware('can:ver estadisticas');
    Route::get('/dashboard/gruas-hoy', [DashboardController::class, 'gruasHoy'])->middleware('can:ver estadisticas');

    Route::get('/mapa/patrullas', [MapaPatrullasController::class, 'data'])->middleware('can:ver mapa');

    Route::get('/hechos/{hecho}/reporte-doc', [DocumentoHechoController::class, 'descargarDoc'])->middleware('can:ver hechos');

    Route::prefix('estadisticas-globales')->middleware('can:ver estadisticas globales')->group(function () {
        Route::get('/kpis', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'kpis']);
        Route::get('/series/hechos', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesHechos']);
        Route::get('/series/lesionados', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesLesionados']);
        Route::get('/series/tipo-hecho', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesTipoHecho']);
        Route::get('/series/sector', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesSector']);
        Route::get('/series/municipio', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesMunicipio']);
        Route::get('/series/tiempo', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesTiempo']);
        Route::get('/series/clima', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesClima']);
        Route::get('/series/condiciones', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesCondiciones']);
        Route::get('/series/control-transito', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesControlTransito']);
        Route::get('/series/vehiculos/tipo', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesVehiculosTipo']);
        Route::get('/series/vehiculos/marca', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesVehiculosMarca']);
        Route::get('/series/vehiculos/modelo', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'seriesVehiculosModelo']);
        Route::get('/hechos', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'hechos']);
        Route::get('/export/hechos', [\App\Http\Controllers\Api\EstadisticasGlobalesController::class, 'exportHechos']);
    });

    Route::prefix('estadisticas-actividades')->middleware('can:ver estadisticas actividades')->group(function () {
        Route::get('/', [EstadisticasActividadesController::class, 'index'])->name('api.estadisticas_actividades.index');
        Route::get('/kpis', [EstadisticasActividadesController::class, 'kpis'])->name('api.estadisticas_actividades.kpis');
        Route::get('/series/actividades', [EstadisticasActividadesController::class, 'seriesActividades'])->name('api.estadisticas_actividades.series.actividades');
        Route::get('/series/categoria', [EstadisticasActividadesController::class, 'seriesCategoria'])->name('api.estadisticas_actividades.series.categoria');
        Route::get('/resumen/categorias', [EstadisticasActividadesController::class, 'resumenCategorias'])->name('api.estadisticas_actividades.resumen.categorias');
        Route::get('/series/subcategoria', [EstadisticasActividadesController::class, 'seriesSubcategoria'])->name('api.estadisticas_actividades.series.subcategoria');
        Route::get('/series/unidad', [EstadisticasActividadesController::class, 'seriesUnidad'])->name('api.estadisticas_actividades.series.unidad');
        Route::get('/series/delegacion', [EstadisticasActividadesController::class, 'seriesDelegacion'])->name('api.estadisticas_actividades.series.delegacion');
        Route::get('/series/destacamento', [EstadisticasActividadesController::class, 'seriesDestacamento'])->name('api.estadisticas_actividades.series.destacamento');
        Route::get('/series/municipio', [EstadisticasActividadesController::class, 'seriesMunicipio'])->name('api.estadisticas_actividades.series.municipio');
        Route::get('/series/carretera', [EstadisticasActividadesController::class, 'seriesCarretera'])->name('api.estadisticas_actividades.series.carretera');
        Route::get('/series/tiempo', [EstadisticasActividadesController::class, 'seriesTiempo'])->name('api.estadisticas_actividades.series.tiempo');
        Route::get('/series/revision', [EstadisticasActividadesController::class, 'seriesRevision'])->name('api.estadisticas_actividades.series.revision');
        Route::get('/series/personas-alcanzadas', [EstadisticasActividadesController::class, 'seriesPersonasAlcanzadas'])->name('api.estadisticas_actividades.series.personas_alcanzadas');
        Route::get('/series/personas-participantes', [EstadisticasActividadesController::class, 'seriesPersonasParticipantes'])->name('api.estadisticas_actividades.series.personas_participantes');
        Route::get('/series/personas-detenidas', [EstadisticasActividadesController::class, 'seriesPersonasDetenidas'])->name('api.estadisticas_actividades.series.personas_detenidas');
        Route::get('/series/km-recorridos', [EstadisticasActividadesController::class, 'seriesKmRecorridos'])->name('api.estadisticas_actividades.series.km_recorridos');
        Route::get('/puestas-disposicion', [EstadisticasActividadesController::class, 'puestasDisposicion'])->name('api.estadisticas_actividades.puestas_disposicion');
        Route::get('/series/personas-actividad-edades', [EstadisticasActividadesController::class, 'seriesActividadPersonasEdad'])->name('api.estadisticas_actividades.series.personas_actividad_edades');
        Route::get('/series/articulos', [EstadisticasActividadesController::class, 'seriesArticulos'])->name('api.estadisticas_actividades.series.articulos');
        Route::get('/actividades', [EstadisticasActividadesController::class, 'actividades'])->name('api.estadisticas_actividades.actividades');
        Route::get('/catalogos/categorias', [EstadisticasActividadesController::class, 'catalogoCategorias'])->name('api.estadisticas_actividades.catalogos.categorias');
        Route::get('/catalogos/subcategorias', [EstadisticasActividadesController::class, 'catalogoSubcategorias'])->name('api.estadisticas_actividades.catalogos.subcategorias');
        Route::get('/catalogos/unidades', [EstadisticasActividadesController::class, 'catalogoUnidades'])->name('api.estadisticas_actividades.catalogos.unidades');
        Route::get('/catalogos/delegaciones', [EstadisticasActividadesController::class, 'catalogoDelegaciones'])->name('api.estadisticas_actividades.catalogos.delegaciones');
        Route::get('/catalogos/destacamentos', [EstadisticasActividadesController::class, 'catalogoDestacamentos'])->name('api.estadisticas_actividades.catalogos.destacamentos');
        Route::get('/catalogos/articulos', [EstadisticasActividadesController::class, 'catalogoArticulos'])->name('api.estadisticas_actividades.catalogos.articulos');
        Route::get('/export/actividades', [EstadisticasActividadesController::class, 'exportActividades'])->name('api.estadisticas_actividades.export.actividades');
        Route::get('/export/mensual', [EstadisticasActividadesController::class, 'exportMensual'])->name('api.estadisticas_actividades.export.mensual');
        Route::get('/export/fomento-cultura-vial', [EstadisticasActividadesController::class, 'exportFomentoCulturaVial'])->name('api.estadisticas_actividades.export.fomento_cultura_vial');
        Route::get('/export/puestas-disposicion', [EstadisticasActividadesController::class, 'exportPuestasDisposicion'])->name('api.estadisticas_actividades.export.puestas_disposicion');
    });

    Route::get('/mi-personal', [PersonalController::class, 'index'])->middleware('can:ver personal turno');
    Route::post('/mi-personal/{user}/ubicacion', [PersonalController::class, 'toggleUbicacion'])->middleware('can:gestionar ubicaciones turno');
    Route::post('/mi-personal/ubicacion/todos', [PersonalController::class, 'toggleUbicacionTodos'])->middleware('can:gestionar ubicaciones turno');
    Route::post('/mi-personal/{user}/ubicacion/limpiar', [PersonalController::class, 'limpiarUbicacionUsuario'])->middleware('can:gestionar ubicaciones turno');
    Route::post('/mi-personal/ubicacion/limpiar-todos', [PersonalController::class, 'limpiarUbicacionTodos'])->middleware('can:gestionar ubicaciones turno');

    Route::get('/app/version', [AppVersionController::class, 'show']);
});
