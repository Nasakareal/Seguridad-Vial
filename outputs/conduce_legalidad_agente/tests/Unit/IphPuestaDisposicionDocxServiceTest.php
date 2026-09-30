<?php

namespace Tests\Unit;

use App\Models\Hechos;
use App\Services\IphPuestaDisposicionDocxService;
use DOMDocument;
use Tests\TestCase;
use ZipArchive;

class IphPuestaDisposicionDocxServiceTest extends TestCase
{
    public function test_barandillas_no_confunde_al_agente_con_la_persona_detenida(): void
    {
        if (!class_exists(ZipArchive::class)) {
            $this->markTestSkipped('ZipArchive is required to inspect generated DOCX files.');
        }

        $hecho = new Hechos([
            'id' => 901,
            'folio_c5i' => 'CL-77-901',
        ]);
        $mapeo = [
            'hecho' => [
                'folio_c5i' => 'CL-77-901',
                'fecha' => '2026-09-29',
                'hora' => '14:30',
                'creador_nombre' => 'Juan Bautista Gonzalez',
                'unidad_org_nombre' => 'Unidad de Protección en Vialidades Urbanas',
                'ubicacion' => [],
            ],
            'puesta_disposicion' => [
                'nombre_policia' => 'Juan Bautista Gonzalez',
                'agente_nombres' => 'Juan',
                'agente_apellido_paterno' => 'Bautista',
                'agente_apellido_materno' => 'Gonzalez',
            ],
            'vehiculos_hecho' => [[
                'marca' => 'AJP',
                'linea' => 'Prueba',
                'grua_nombre' => 'Grúas Morelia',
                'grua_direccion' => 'Autopista 123',
                'corralon' => 'Corralón Autopista',
            ]],
            'lesionados_hecho' => [],
            'objetos' => [],
            'anexos' => [],
            'personas' => [[
                'nombre_completo' => 'Enrique Velazquez Navarro',
            ]],
        ];

        [$path] = app(IphPuestaDisposicionDocxService::class)
            ->generarConduceLegalidadBarandillas($hecho, $mapeo);

        try {
            $texto = $this->textoDocx($path);
            $agente = 'BAUTISTAGONZALEZJUAN';
            $persona = 'VelazquezNavarroEnrique';

            $this->assertStringContainsString($agente, $texto);
            $this->assertStringContainsString($persona, $texto);
            $this->assertLessThan(strpos($texto, $persona), strpos($texto, $agente));
            $this->assertSame(1, substr_count($texto, $agente));
            $this->assertSame(1, substr_count($texto, $persona));
            $this->assertStringContainsString(
                'grúa particular Grúas Morelia, resguardándolo en sus propias instalaciones, ubicadas en Autopista 123',
                $texto
            );
            $this->assertStringNotContainsString('$grua', $texto);
            $this->assertSame(4, substr_count($texto, '29092026'));
            $this->assertSame(3, substr_count($texto, '14:30'));
            $fechaNacimientoInicio = strpos($texto, 'Fecha de nacimiento:');
            $fechaNacimientoFin = strpos($texto, 'Firma:', $fechaNacimientoInicio);
            $this->assertNotFalse($fechaNacimientoInicio);
            $this->assertNotFalse($fechaNacimientoFin);
            $this->assertStringNotContainsString(
                '29092026',
                substr($texto, $fechaNacimientoInicio, $fechaNacimientoFin - $fechaNacimientoInicio)
            );
            $this->assertStringNotContainsString('$d', $texto);
            $this->assertStringNotContainsString('$me', $texto);
            $this->assertStringNotContainsString('$ye', $texto);
            $this->assertStringNotContainsString('$ho', $texto);
            $this->assertStringNotContainsString('$min', $texto);
        } finally {
            if (is_file($path)) {
                @unlink($path);
            }
        }
    }

    public function test_folio_del_ticket_se_reparte_en_las_casillas_del_expediente_de_barandillas(): void
    {
        if (!class_exists(ZipArchive::class)) {
            $this->markTestSkipped('ZipArchive is required to inspect generated DOCX files.');
        }

        foreach ([false, true] as $conPersona) {
            $hecho = new Hechos([
                'id' => 125,
                'folio_c5i' => 'CL-11-125',
            ]);
            $mapeo = [
                'hecho' => [
                    'folio_c5i' => 'CL-11-125',
                    'fecha' => '2026-09-23',
                    'hora' => '18:08',
                    'creador_nombre' => 'MARIO BAUTISTA R.',
                    'ubicacion' => [],
                ],
                'puesta_disposicion' => [],
                'vehiculos_hecho' => [],
                'lesionados_hecho' => [],
                'objetos' => [],
                'anexos' => [],
                'personas' => $conPersona ? [['nombre_completo' => 'MARIO DANTE BAUTISTA REBOLLAR']] : [],
            ];

            [$path] = app(IphPuestaDisposicionDocxService::class)
                ->generarConduceLegalidadBarandillas($hecho, $mapeo);

            try {
                $texto = $this->textoDocx($path);

                $this->assertStringContainsString('CL-11-125No. Expediente', $texto);
                $this->assertStringNotContainsString('$foc', $texto);
                $this->assertStringNotContainsString('CL-11-125CL-', $texto);
            } finally {
                if (is_file($path)) {
                    @unlink($path);
                }
            }
        }
    }

    public function test_descripcion_de_vehiculos_incluye_tarjeta_conductor_y_licencia_en_docx(): void
    {
        if (!class_exists(ZipArchive::class)) {
            $this->markTestSkipped('ZipArchive is required to inspect generated DOCX files.');
        }

        $hecho = new Hechos([
            'id' => 777,
            'folio_c5i' => 'TEST-IPH',
        ]);
        $service = app(IphPuestaDisposicionDocxService::class);

        [$path] = $service->generar($hecho, [
            'hecho' => [
                'folio_c5i' => 'TEST-IPH',
                'fecha' => '2026-03-11',
                'hora' => '12:30',
                'tipo_hecho' => 'CHOQUE',
                'causas' => 'FALTA DE PRECAUCION Y CUIDADO',
                'lesionados_count' => 0,
                'fallecidos_count' => 0,
                'unidad_org_id' => 2,
                'unidad_org_nombre' => 'Unidad de Delegaciones',
                'creador_nombre' => 'MENDEZ SAENZ JOSE RUBEN',
                'ubicacion' => [
                    'calle' => 'AVENIDA TEST',
                    'colonia' => 'CENTRO',
                    'entre_calles' => 'CALLE UNO Y CALLE DOS',
                    'municipio' => 'MORELIA',
                    'lat' => '19.7000000',
                    'lng' => '-101.1900000',
                ],
            ],
            'puesta_disposicion' => [
                'fecha_puesta' => '2026-03-11',
                'hora_puesta' => '13:05',
                'nombre_policia' => 'MENDEZ SAENZ JOSE RUBEN',
                'autoridad_receptora' => 'MINISTERIO PUBLICO',
            ],
            'vehiculos_hecho' => [
                [
                    'tipo' => 'Sedán',
                    'marca' => 'Chevrolet',
                    'linea' => 'Aveo',
                    'modelo' => '2011',
                    'color' => 'Rojo',
                    'capacidad_personas' => '5',
                    'placas' => 'PKP853B',
                    'estado_placas' => 'esta entidad federativa',
                    'serie' => '3G1TC5CF5BL147401',
                    'tipo_servicio' => 'PARTICULAR',
                    'tarjeta_circulacion_nombre' => 'BRYAN BULMARO SOLORIO PAQUE',
                    'partes_danadas' => 'ÁNGULO FRONTAL DERECHO',
                    'monto_danos' => 3000,
                    'grua_nombre' => 'Serví-Grúas Profesionales',
                    'grua_direccion' => 'Carretera Morelia - Salamanca Km. 7.5, colonia Erandeni',
                    'conductores' => [
                        [
                            'nombre' => 'NOE PEREZ CRUZ',
                            'edad' => '55',
                            'sexo' => 'M',
                            'domicilio' => 'Lomas de las Villas # 187-B',
                            'estado_licencia' => 'MICHOACAN',
                            'tipo_licencia' => null,
                            'numero_licencia' => null,
                        ],
                    ],
                ],
                [
                    'tipo' => 'Hatchback',
                    'marca' => 'Nissan',
                    'linea' => 'March',
                    'modelo' => '2019',
                    'color' => 'Rojo',
                    'capacidad_personas' => '5',
                    'placas' => 'PMB497C',
                    'estado_placas' => 'esta entidad federativa',
                    'serie' => '3N1CK3CD0KL212607',
                    'tipo_servicio' => 'PARTICULAR',
                    'tarjeta_circulacion_nombre' => 'MARIA DEL ROCIO TAPIA ZENTENO',
                    'partes_danadas' => 'COSTADO POSTERIOR IZQUIERDO',
                    'monto_danos' => 8000,
                    'grua_nombre' => 'Serví-Grúas Profesionales',
                    'grua_direccion' => 'Carretera Morelia - Salamanca Km. 7.5, colonia Erandeni',
                    'conductores' => [],
                ],
            ],
            'lesionados_hecho' => [],
            'objetos' => [],
            'anexos' => [],
        ]);

        try {
            $texto = $this->textoDocx($path);

            $this->assertStringContainsString('NO. DE REFERENCIA', $texto);
            $this->assertStringContainsString('NO. DE FOLIO ASIGNADO POR EL SISTEMA', $texto);
            $this->assertStringContainsString('Fiscalía/Autoridad:FISCALÍA GENERAL DEL ESTADO', $texto);
            $this->assertStringContainsString('MENDEZPrimer apellidoSAENZSegundo apellidoJOSE RUBENNombre (s)', $texto);
            $this->assertStringContainsString('[ X ] Policía Estatal', $texto);
            $this->assertStringContainsString('No [ X ]', $texto);
            $this->assertStringContainsString('SECCIÓN 4. LUGAR DE LA INTERVENCIÓN', $texto);
            $this->assertStringContainsString('Calle/Tramo carretero:   AVENIDA TEST', $texto);
            $this->assertStringContainsString('Referencias:   CALLE UNO Y CALLE DOS', $texto);
            $this->assertStringContainsString('Latitud   19.7000000', $texto);
            $this->assertStringContainsString('Longitud:   -101.1900000', $texto);
            $this->assertMatchesRegularExpression('/Conocimiento del hechoFecha:\s+\[ 1 \]\s+\[ 1 \]\s+\[ 0 \]\s+\[ 3 \]\s+\[ 2 \]\s+\[ 0 \]\s+\[ 2 \]\s+\[ 6 \].*Hora:\s+\[ 1 \]\s+\[ 1 \]\s+:\s+\[ 5 \]\s+\[ 5 \].*Arribo al lugarFecha:\s+\[ 1 \]\s+\[ 1 \]\s+\[ 0 \]\s+\[ 3 \]\s+\[ 2 \]\s+\[ 0 \]\s+\[ 2 \]\s+\[ 6 \].*Hora:\s+\[ 1 \]\s+\[ 2 \]\s+:\s+\[ 3 \]\s+\[ 0 \]/s', $texto);
            $this->assertStringContainsString('Apartado 4.2 Inspección del lugar', $texto);
            $this->assertStringContainsString('Llene el anexo D', $texto);
            $this->assertStringContainsString('Tipo de riesgo presentado:', $texto);
            $this->assertStringContainsString('Sociales [ X ]', $texto);
            $this->assertStringContainsString('Naturales [    ]', $texto);
            $this->assertStringContainsString('Capacidad para 5 Personas', $texto);
            $this->assertStringContainsString('Placas para circular PKP853B del servicio particular de esta entidad federativa', $texto);
            $this->assertStringContainsString('Serie 3G1TC5CF5BL147401', $texto);
            $this->assertStringContainsString('tarjeta de circulación a nombre de BRYAN BULMARO SOLORIO PAQUE', $texto);
            $this->assertStringContainsString('el C. NOE PEREZ CRUZ de 55 años de edad', $texto);
            $this->assertStringContainsString('con domicilio en Lomas de las Villas # 187-B, en esta ciudad', $texto);
            $this->assertStringContainsString('me manifestó ir a bordo del vehículo, presentó licencia', $texto);
            $this->assertStringContainsString('De este hecho de tránsito no se manifestaron ante el suscrito.', $texto);
            $this->assertStringContainsString('VEHÍCULO (A).- Presenta daños en su Ángulo Frontal Derecho, se estiman en la cantidad aproximada para su reparación de $ 3,000.00 (TRES MIL PESOS 00/100 M.N.).', $texto);
            $this->assertStringContainsString('VEHÍCULO (B).- Presenta daños en su Costado Posterior Izquierdo, se estiman en la cantidad aproximada para su reparación de $ 8,000.00 (OCHO MIL PESOS 00/100 M.N.).', $texto);
            $this->assertStringContainsString('Estos daños fueron estimados y calculados a simple vista', $texto);
            $this->assertStringContainsString('Ambos vehículos fueron resguardados por su propia tracción en las instalaciones de Serví-Grúas Profesionales', $texto);
            $this->assertStringContainsString('ÚNICA.- La causa que da origen al hecho de tránsito que nos ocupa se refiere a falta de precaucion y cuidado por parte del conductor del vehículo (A), en consecuencia ocasionar daños materiales', $texto);
            $this->assertStringContainsString('Con base en lo dispuesto en el artículo 59 de la Ley de Tránsito y Vialidad vigente en el Estado, Pongo a su disposición ambos vehículos', $texto);
            $this->assertStringContainsString('tuvo conocimiento por medio del folio C5i TEST-IPH', $texto);
            $this->assertStringContainsString('arribando aproximadamente a las 12:30 horas', $texto);
            $this->assertStringContainsString('Al arribar al lugar de intervención se localizaron 2 vehículos', $texto);
            $this->assertStringContainsString('Conductor registrado: NOE PEREZ CRUZ', $texto);
            $this->assertStringContainsString('Queda pendiente que el elemento actuante complemente de manera cronológica y detallada', $texto);
            $this->assertStringContainsString('ANEXO C. INSPECCIÓN DE VEHÍCULO', $texto);
            $this->assertStringContainsString('Vehículo:  [ 0 ][ 0 ][ 1 ]', $texto);
            $this->assertStringContainsString('Apartado C.2 Datos generales del vehículo inspeccionado', $texto);
            $this->assertStringContainsString('Placa/Matrícula:', $texto);
            $this->assertStringContainsString('No. de serie:', $texto);
            $this->assertStringContainsString('Situación:   [    ] Con reporte de robo          [    ] Sin reporte de robo          [ X ] No es posible saberlo', $texto);
            $this->assertStringContainsString('Apartado C.4 Datos del primer respondiente', $texto);
            $this->assertStringContainsString('ATENTAMENTE.PERITO DE TRÁNSITO.MENDEZ SAENZ JOSE RUBEN', $texto);

            $this->assertStringContainsString('w:val="es-MX"', $this->xmlDocx($path, 'word/settings.xml'));
            $this->assertStringContainsString('w:val="es-MX"', $this->xmlDocx($path, 'word/styles.xml'));
        } finally {
            if (is_file($path)) {
                @unlink($path);
            }
        }
    }

    private function textoDocx(string $path): string
    {
        $xml = $this->xmlDocx($path, 'word/document.xml');

        $previous = libxml_use_internal_errors(true);
        $dom = new DOMDocument();
        $dom->loadXML($xml);
        libxml_clear_errors();
        libxml_use_internal_errors($previous);

        $texto = '';

        foreach ($dom->getElementsByTagName('t') as $node) {
            $texto .= $node->textContent;
        }

        return $texto;
    }

    private function xmlDocx(string $path, string $entry): string
    {
        $zip = new ZipArchive();
        $this->assertTrue($zip->open($path) === true);
        $xml = $zip->getFromName($entry);
        $zip->close();
        $this->assertIsString($xml);

        return $xml;
    }
}
