<?php

namespace Tests\Unit;

use App\Services\ConduceLegalidadTotalesDocxService;
use DOMDocument;
use DOMXPath;
use Tests\TestCase;
use ZipArchive;

class ConduceLegalidadTotalesDocxServiceTest extends TestCase
{
    public function test_genera_el_formato_de_totales_y_preserva_la_plantilla(): void
    {
        $plantilla = public_path('TOTALES.docx');
        $this->assertFileExists($plantilla);
        $hashOriginal = hash_file('sha256', $plantilla);
        $destino = storage_path('framework/testing/totales_conduce_' . uniqid('', true) . '.docx');

        try {
            $resultado = app(ConduceLegalidadTotalesDocxService::class)->generarConDatos(
                [
                    'dia' => '08',
                    'mesletra' => 'Octubre',
                    'year' => '2026',
                    'mesnumero' => '10',
                    'hora' => '18:00',
                    'lugar' => 'Glorieta principal de Torreón Nuevo',
                    'totalvehiculo' => '2',
                    'horatermino' => '20:35',
                ],
                [
                    [
                        'placas' => null,
                        'vehiculo' => 'ITALIKA FT150 2022',
                        'tipo' => 'motocicleta',
                        'color' => 'Rojo',
                        'seguro' => 'No',
                        'folio' => 'CL-22-1',
                        'inventario' => '0801',
                        'corralon' => 'GALVAN',
                        'fecha' => '2026-10-08 18:10:00',
                    ],
                    [
                        'placas' => 'ABC123',
                        'vehiculo' => 'VENTO 250 2025',
                        'tipo' => 'motocicleta',
                        'color' => 'Negro',
                        'seguro' => 'Sí - EJEMPLO',
                        'folio' => 'CL-22-2',
                        'inventario' => '0802',
                        'corralon' => 'GALVAN',
                        'fecha' => '2026-10-08 18:20:00',
                    ],
                ],
                $destino
            );

            $this->assertSame($destino, $resultado['path']);
            $this->assertFileExists($destino);
            $this->assertSame($hashOriginal, hash_file('sha256', $plantilla));

            $xml = $this->leerParte($destino, 'word/document.xml');
            $texto = $this->textoDocumento($xml);

            $this->assertStringContainsString('Morelia, Michoacán a 08 de Octubre de 2026', $texto);
            $this->assertStringContainsString('Fecha del operativo: 08/10/2026', $texto);
            $this->assertStringContainsString('2 motocicletas retenidas', $texto);
            $this->assertStringContainsString('Vehículo: ITALIKA FT150 2022', $texto);
            $this->assertStringContainsString('Placas: ABC123', $texto);
            $this->assertStringContainsString('Folio Conduce: CL-22-2', $texto);
            $this->assertStringContainsString('Fecha y hora del término del operativo: 08/10/2026 a las 20:35 horas.', $texto);
            $this->assertDoesNotMatchRegularExpression('/\$[A-Za-z][A-Za-z0-9_]*/', $xml);
            $this->assertSame(3, substr_count($xml, '<w:sectPr'));
            $this->assertStringContainsString('<w:cols w:num="2"', $xml);

            $this->assertPartesPreservadas($plantilla, $destino);
        } finally {
            if (is_file($destino)) {
                unlink($destino);
            }
        }
    }

    private function textoDocumento(string $xml): string
    {
        $dom = new DOMDocument();
        $this->assertTrue($dom->loadXML($xml, LIBXML_NONET));
        $xpath = new DOMXPath($dom);
        $xpath->registerNamespace(
            'w',
            'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
        );

        $parrafos = [];
        foreach ($xpath->query('//w:p') as $parrafo) {
            $linea = '';
            foreach ($xpath->query('.//w:t', $parrafo) as $texto) {
                $linea .= $texto->textContent;
            }
            if (trim($linea) !== '') {
                $parrafos[] = $linea;
            }
        }

        return implode("\n", $parrafos);
    }

    private function assertPartesPreservadas(string $plantilla, string $resultado): void
    {
        $origen = new ZipArchive();
        $salida = new ZipArchive();
        $this->assertTrue($origen->open($plantilla) === true);
        $this->assertTrue($salida->open($resultado) === true);

        try {
            $this->assertSame($origen->numFiles, $salida->numFiles);
            for ($indice = 0; $indice < $origen->numFiles; $indice++) {
                $nombre = $origen->getNameIndex($indice);
                $this->assertNotFalse($salida->locateName($nombre), $nombre);
                if ($nombre !== 'word/document.xml') {
                    $this->assertSame(
                        $origen->getFromName($nombre),
                        $salida->getFromName($nombre),
                        $nombre
                    );
                }
            }
        } finally {
            $origen->close();
            $salida->close();
        }
    }

    private function leerParte(string $archivo, string $parte): string
    {
        $zip = new ZipArchive();
        $this->assertTrue($zip->open($archivo) === true);
        try {
            $contenido = $zip->getFromName($parte);
            $this->assertNotFalse($contenido);
            return $contenido;
        } finally {
            $zip->close();
        }
    }
}
