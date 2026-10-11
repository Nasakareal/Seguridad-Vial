<?php

$backend = 'C:/wamp64/www/sistemaEstadistico';
require $backend . '/vendor/autoload.php';
$app = require $backend . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$vehiculos = [];
for ($indice = 1; $indice <= 34; $indice++) {
    $vehiculos[] = [
        'placas' => $indice % 3 === 0 ? null : sprintf('L%dN%02dP', $indice % 10, $indice),
        'vehiculo' => $indice % 4 === 0
            ? 'MB MOTORS HORNET 300CC 2025'
            : 'ITALIKA FT150 2024',
        'tipo' => 'motocicleta',
        'color' => $indice % 2 === 0 ? 'Negro' : 'Rojo',
        'seguro' => 'No',
        'folio' => 'CL-22-' . $indice,
        'inventario' => str_pad((string) (800 + $indice), 4, '0', STR_PAD_LEFT),
        'corralon' => 'GALVAN',
        'fecha' => sprintf('2026-10-08 %02d:%02d:00', 18 + intdiv($indice, 20), $indice % 60),
    ];
}

$destino = 'C:/Users/naasa/seguridad_vial_app/outputs/totales_docx_analysis/TOTALES_QA6.docx';
$resultado = app(App\Services\ConduceLegalidadTotalesDocxService::class)->generarConDatos(
    [
        'dia' => '08',
        'mesletra' => 'Octubre',
        'year' => '2026',
        'mesnumero' => '10',
        'hora' => '18:00',
        'lugar' => 'Glorieta principal de la colonia Torreón Nuevo en Morelia, Michoacán.',
        'totalvehiculo' => '34',
        'horatermino' => '20:35',
    ],
    $vehiculos,
    $destino
);

echo json_encode($resultado, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . PHP_EOL;
