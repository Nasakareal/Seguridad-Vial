<?php

// Agregar antes de la ruta POST /operativos/{operativo}/capturas para evitar
// que "reservar-folio" sea interpretado como el parámetro {captura}.
Route::post(
    '/operativos/{operativo}/capturas/reservar-folio',
    [ApiConduceLegalidadController::class, 'reservarFolioCaptura']
)->whereNumber('operativo')->name('api.conduce_legalidad.capturas.reservar_folio');

Route::post(
    '/operativos/{operativo}/inventarios/reservar-folio',
    [ApiConduceLegalidadController::class, 'reservarFolioInventario']
)->whereNumber('operativo')->name('api.conduce_legalidad.inventarios.reservar_folio');
