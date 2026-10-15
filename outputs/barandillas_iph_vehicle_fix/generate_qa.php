<?php

chdir('C:/wamp64/www/sistemaEstadistico');
require 'vendor/autoload.php';

$app = require 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$hecho = new App\Models\Hechos([
    'id' => 903,
    'folio_c5i' => 'CL-77-903',
]);

$mapeo = [
    'hecho' => [
        'folio_c5i' => 'CL-77-903',
        'fecha' => '2026-10-14',
        'hora' => '10:45',
        'creador_nombre' => 'Agente del resguardo',
        'unidad_org_nombre' => 'Unidad de Protección en Vialidades Urbanas',
        'ubicacion' => [
            'calle' => 'Avenida Madero 100',
            'colonia' => 'Centro',
            'municipio' => 'Morelia',
            'codigo_postal' => '58000',
            'lat' => '19.7020',
            'lng' => '-101.1920',
        ],
        'narrativa_operativa' => 'Vehículo remitido durante el operativo Conduce con Legalidad.',
    ],
    'puesta_disposicion' => [
        'nombre_policia' => 'Agente del resguardo',
        'agente_nombres' => 'Agente',
        'agente_apellido_paterno' => 'Del',
        'agente_apellido_materno' => 'Resguardo',
        'firmante_iph_nombres' => 'Laura Beatriz',
        'firmante_iph_apellido_paterno' => 'Ramírez',
        'firmante_iph_apellido_materno' => 'Torres',
    ],
    'vehiculos_hecho' => [[
        'marca' => 'Honda',
        'linea' => 'Cargo',
        'modelo' => '2025',
        'color' => 'Rojo',
        'placas' => 'ABC123',
        'serie' => 'QA1234567890',
        'grua_nombre' => 'Grúas Morelia',
        'grua_direccion' => 'Patio de resguardo de prueba',
        'conductores' => [[
            'nombre_completo' => 'Persona Conductora Prueba',
        ]],
    ]],
    'vehiculos' => [[
        'marca' => 'Honda',
        'linea' => 'Cargo',
        'modelo' => '2025',
        'color' => 'Rojo',
        'placas' => 'ABC123',
        'serie' => 'QA1234567890',
        'grua_nombre' => 'Grúas Morelia',
        'grua_direccion' => 'Patio de resguardo de prueba',
        'conductores' => [[
            'nombre_completo' => 'Persona Conductora Prueba',
        ]],
    ]],
    'conductores_hecho' => [[
        'nombre_completo' => 'Persona Conductora Prueba',
    ]],
    'personas' => [[
        'nombre_completo' => 'Persona Conductora Prueba',
    ]],
    'lesionados_hecho' => [],
    'objetos' => [],
    'anexos' => [],
];

[$generated, $filename] = $app->make(App\Services\IphPuestaDisposicionDocxService::class)
    ->generarConduceLegalidadBarandillasSoloVehiculo($hecho, $mapeo);

$target = 'C:/Users/naasa/seguridad_vial_app/output/barandillas_iph_vehicle_qa.docx';
if (!is_dir(dirname($target))) {
    mkdir(dirname($target), 0777, true);
}
if (!copy($generated, $target)) {
    throw new RuntimeException('No se pudo copiar el DOCX de control.');
}
@unlink($generated);

echo $target . PHP_EOL;
echo $filename . PHP_EOL;
