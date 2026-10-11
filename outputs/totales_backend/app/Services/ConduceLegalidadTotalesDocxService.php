<?php

namespace App\Services;

use App\Models\ConduceLegalidadCaptura;
use App\Models\ConduceLegalidadOperativo;
use Carbon\Carbon;
use DOMDocument;
use DOMElement;
use DOMNode;
use DOMXPath;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use RuntimeException;
use ZipArchive;

class ConduceLegalidadTotalesDocxService
{
    private const WORD_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
    private const WORD_2010_NS = 'http://schemas.microsoft.com/office/word/2010/wordml';

    public function generar(ConduceLegalidadOperativo $operativo, iterable $capturas): array
    {
        $fecha = $this->fechaOperativo($operativo);
        $registros = $this->registrosVehiculos($operativo, $capturas);
        $nombre = sprintf(
            'TOTALES_CONDUCE_LEGALIDAD_%d_%s.docx',
            $operativo->id,
            $fecha->format('Y-m-d')
        );
        $relativePath = 'conduce_legalidad/reportes/' . $nombre;
        $destino = storage_path('app/public/' . $relativePath);

        $resultado = $this->generarConDatos(
            [
                'dia' => $fecha->format('d'),
                'mesletra' => $this->mesEnEspanol((int) $fecha->format('n')),
                'year' => $fecha->format('Y'),
                'mesnumero' => $fecha->format('m'),
                'hora' => $this->horaCorta($operativo->hora_inicio),
                'lugar' => $this->lugarOperativo($operativo),
                'totalvehiculo' => (string) count($registros),
                'horatermino' => $this->horaTermino($operativo, $capturas),
            ],
            $registros,
            $destino
        );

        $resultado['relative_path'] = $relativePath;

        return $resultado;
    }

    public function generarConDatos(array $variables, array $vehiculos, string $destino): array
    {
        $plantilla = public_path('TOTALES.docx');
        if (!is_file($plantilla)) {
            throw new RuntimeException('No se encontró la plantilla TOTALES.docx.');
        }

        File::ensureDirectoryExists(dirname($destino));
        if (!copy($plantilla, $destino)) {
            throw new RuntimeException('No se pudo copiar la plantilla de totales.');
        }

        $this->reemplazarContenido($destino, $variables, $vehiculos);

        return [
            'path' => $destino,
            'name' => basename($destino),
            'sha256' => hash_file('sha256', $destino),
            'size' => filesize($destino),
        ];
    }

    private function reemplazarContenido(string $archivo, array $variables, array $vehiculos): void
    {
        $reemplazos = [];
        foreach ($variables as $variable => $valor) {
            $reemplazos['$' . ltrim((string) $variable, '$')] = (string) ($valor ?? '');
        }

        $zip = new ZipArchive();
        if ($zip->open($archivo) !== true) {
            throw new RuntimeException('No se pudo abrir el documento de totales.');
        }

        try {
            $xml = $zip->getFromName('word/document.xml');
            if ($xml === false) {
                throw new RuntimeException('La plantilla no contiene word/document.xml.');
            }

            $dom = new DOMDocument();
            $dom->preserveWhiteSpace = true;
            $dom->formatOutput = false;
            if (!$dom->loadXML($xml, LIBXML_NONET)) {
                throw new RuntimeException('El XML principal de la plantilla no es válido.');
            }

            $xpath = new DOMXPath($dom);
            $xpath->registerNamespace('w', self::WORD_NS);
            $parrafoTotales = $this->buscarParrafoMarcador($xpath, '$totales');
            if (!$parrafoTotales) {
                throw new RuntimeException('La plantilla no contiene el marcador $totales.');
            }

            $this->insertarVehiculos($dom, $xpath, $parrafoTotales, $vehiculos);
            $reemplazos['$totales'] = '';

            foreach ($xpath->query('//w:t') as $texto) {
                $texto->nodeValue = strtr($texto->textContent, $reemplazos);
            }

            $xmlFinal = $dom->saveXML();
            if (preg_match('/\$[A-Za-z][A-Za-z0-9_]*/', $xmlFinal, $pendiente)) {
                throw new RuntimeException(
                    'Quedó una variable sin reemplazar en la plantilla: ' . $pendiente[0]
                );
            }

            if (!$zip->addFromString('word/document.xml', $xmlFinal)) {
                throw new RuntimeException('No se pudo actualizar el documento de totales.');
            }
        } finally {
            $zip->close();
        }
    }

    private function buscarParrafoMarcador(DOMXPath $xpath, string $marcador): ?DOMElement
    {
        foreach ($xpath->query('//w:p') as $parrafo) {
            $texto = '';
            foreach ($xpath->query('.//w:t', $parrafo) as $nodoTexto) {
                $texto .= $nodoTexto->textContent;
            }
            if (strpos($texto, $marcador) !== false) {
                return $parrafo;
            }
        }

        return null;
    }

    private function insertarVehiculos(
        DOMDocument $dom,
        DOMXPath $xpath,
        DOMElement $marcador,
        array $vehiculos
    ): void {
        $padre = $marcador->parentNode;
        if (!$padre) {
            throw new RuntimeException('El marcador $totales no tiene un contenedor válido.');
        }

        if ($vehiculos === []) {
            $padre->insertBefore(
                $this->crearParrafo($dom, $xpath, $marcador, 'Sin vehículos registrados.', false),
                $marcador
            );
            return;
        }

        foreach ($vehiculos as $indice => $vehiculo) {
            $lineas = [
                [(string) ($indice + 1) . '.', true],
                ['Placas: ' . $this->dato($vehiculo['placas'] ?? null, 'Sin placas'), false],
                ['Vehículo: ' . $this->dato($vehiculo['vehiculo'] ?? null), false],
                ['Tipo: ' . $this->dato($vehiculo['tipo'] ?? null), false],
                ['Color: ' . $this->dato($vehiculo['color'] ?? null), false],
                ['Seguro: ' . $this->dato($vehiculo['seguro'] ?? null, 'No'), false],
                ['Folio Conduce: ' . $this->dato($vehiculo['folio'] ?? null), false],
                ['Inventario: ' . $this->dato($vehiculo['inventario'] ?? null), false],
                ['Corralón: ' . $this->dato($vehiculo['corralon'] ?? null), false],
                ['Fecha: ' . $this->dato($vehiculo['fecha'] ?? null), false],
            ];

            foreach ($lineas as $lineaIndice => [$texto, $negrita]) {
                $padre->insertBefore(
                    $this->crearParrafo(
                        $dom,
                        $xpath,
                        $marcador,
                        $texto,
                        $negrita,
                        $lineaIndice < count($lineas) - 1
                    ),
                    $marcador
                );
            }

            $numeroVehiculo = $indice + 1;
            $totalVehiculos = count($vehiculos);
            $saltoPaginaDespues = $numeroVehiculo === 4 && $totalVehiculos > 4;
            $saltoColumnaDespues = false;

            if ($numeroVehiculo > 4) {
                $inicioPagina = 5 + intdiv($numeroVehiculo - 5, 8) * 8;
                $finPagina = min($inicioPagina + 7, $totalVehiculos);
                $cantidadPagina = $finPagina - $inicioPagina + 1;
                $saltoColumnaDespues = $cantidadPagina > 1
                    && $numeroVehiculo === $inicioPagina + (int) ceil($cantidadPagina / 2) - 1;
                $saltoPaginaDespues = $numeroVehiculo === $finPagina && $finPagina < $totalVehiculos;
            }

            if ($saltoPaginaDespues) {
                $padre->insertBefore(
                    $this->crearSaltoPagina($dom, $xpath, $marcador),
                    $marcador
                );
                for ($espacio = 0; $espacio < 8; $espacio++) {
                    $padre->insertBefore(
                        $this->crearParrafo($dom, $xpath, $marcador, '', false),
                        $marcador
                    );
                }
            } elseif ($saltoColumnaDespues) {
                $padre->insertBefore(
                    $this->crearSaltoColumna($dom, $xpath, $marcador),
                    $marcador
                );
                for ($espacio = 0; $espacio < 8; $espacio++) {
                    $padre->insertBefore(
                        $this->crearParrafo($dom, $xpath, $marcador, '', false),
                        $marcador
                    );
                }
            } elseif ($indice < count($vehiculos) - 1) {
                $padre->insertBefore(
                    $this->crearParrafo($dom, $xpath, $marcador, '', false),
                    $marcador
                );
            }
        }
    }

    private function crearParrafo(
        DOMDocument $dom,
        DOMXPath $xpath,
        DOMElement $plantilla,
        string $texto,
        bool $negrita,
        bool $mantenerConSiguiente = false
    ): DOMElement {
        $parrafo = $plantilla->cloneNode(true);
        if (!$parrafo instanceof DOMElement) {
            throw new RuntimeException('No se pudo clonar el párrafo de la plantilla.');
        }

        $parrafo->removeAttributeNS(self::WORD_2010_NS, 'paraId');
        $parrafo->removeAttributeNS(self::WORD_2010_NS, 'textId');

        foreach (iterator_to_array($xpath->query('./w:r', $parrafo)) as $run) {
            $parrafo->removeChild($run);
        }
        foreach (iterator_to_array($xpath->query('./w:pPr/w:sectPr', $parrafo)) as $sectPr) {
            $sectPr->parentNode->removeChild($sectPr);
        }
        if (!$negrita) {
            foreach (iterator_to_array($xpath->query('./w:pPr/w:rPr/w:b | ./w:pPr/w:rPr/w:bCs', $parrafo)) as $bold) {
                $bold->parentNode->removeChild($bold);
            }
        }
        if ($mantenerConSiguiente) {
            $pPr = $xpath->query('./w:pPr', $parrafo)->item(0);
            if ($pPr) {
                $pPr->appendChild($dom->createElementNS(self::WORD_NS, 'w:keepNext'));
                $pPr->appendChild($dom->createElementNS(self::WORD_NS, 'w:keepLines'));
            }
        }

        if ($texto === '') {
            return $parrafo;
        }

        $run = $dom->createElementNS(self::WORD_NS, 'w:r');
        $runProperties = $dom->createElementNS(self::WORD_NS, 'w:rPr');
        $fonts = $dom->createElementNS(self::WORD_NS, 'w:rFonts');
        $fonts->setAttributeNS(self::WORD_NS, 'w:ascii', 'Arial');
        $fonts->setAttributeNS(self::WORD_NS, 'w:hAnsi', 'Arial');
        $fonts->setAttributeNS(self::WORD_NS, 'w:cs', 'Arial');
        $runProperties->appendChild($fonts);
        if ($negrita) {
            $runProperties->appendChild($dom->createElementNS(self::WORD_NS, 'w:b'));
            $runProperties->appendChild($dom->createElementNS(self::WORD_NS, 'w:bCs'));
        }
        foreach (['w:sz', 'w:szCs'] as $tag) {
            $size = $dom->createElementNS(self::WORD_NS, $tag);
            $size->setAttributeNS(self::WORD_NS, 'w:val', '22');
            $runProperties->appendChild($size);
        }
        $run->appendChild($runProperties);

        $textNode = $dom->createElementNS(self::WORD_NS, 'w:t');
        $textNode->appendChild($dom->createTextNode($texto));
        $run->appendChild($textNode);
        $parrafo->appendChild($run);

        return $parrafo;
    }

    private function crearSaltoPagina(
        DOMDocument $dom,
        DOMXPath $xpath,
        DOMElement $plantilla
    ): DOMElement {
        $parrafo = $this->crearParrafo($dom, $xpath, $plantilla, '', false);
        $run = $dom->createElementNS(self::WORD_NS, 'w:r');
        $salto = $dom->createElementNS(self::WORD_NS, 'w:br');
        $salto->setAttributeNS(self::WORD_NS, 'w:type', 'page');
        $run->appendChild($salto);
        $parrafo->appendChild($run);
        return $parrafo;
    }

    private function crearSaltoColumna(
        DOMDocument $dom,
        DOMXPath $xpath,
        DOMElement $plantilla
    ): DOMElement {
        $parrafo = $this->crearParrafo($dom, $xpath, $plantilla, '', false);
        $run = $dom->createElementNS(self::WORD_NS, 'w:r');
        $salto = $dom->createElementNS(self::WORD_NS, 'w:br');
        $salto->setAttributeNS(self::WORD_NS, 'w:type', 'column');
        $run->appendChild($salto);
        $parrafo->appendChild($run);
        return $parrafo;
    }

    private function registrosVehiculos(ConduceLegalidadOperativo $operativo, iterable $capturas): array
    {
        $registros = [];
        foreach ($capturas as $captura) {
            foreach ($captura->vehiculos as $vehiculo) {
                $aseguradora = trim((string) ($vehiculo->aseguradora ?? ''));
                $registros[] = [
                    'placas' => $vehiculo->placas,
                    'vehiculo' => $this->unir([
                        $vehiculo->marca,
                        $vehiculo->linea,
                        $vehiculo->modelo,
                    ]),
                    'tipo' => $vehiculo->tipo_general ?: $vehiculo->tipo,
                    'color' => $vehiculo->color,
                    'seguro' => $aseguradora !== '' ? 'Sí - ' . $aseguradora : 'No',
                    'folio' => 'CL-' . $operativo->id . '-' . $captura->id,
                    'inventario' => $vehiculo->numero_inventario,
                    'corralon' => $vehiculo->corralon,
                    'fecha' => $this->fechaCaptura($captura),
                    '_orden' => $this->ordenCaptura($captura),
                ];
            }
        }

        usort($registros, fn (array $a, array $b) => strcmp($b['_orden'], $a['_orden']));
        foreach ($registros as &$registro) {
            unset($registro['_orden']);
        }
        unset($registro);

        return $registros;
    }

    private function fechaOperativo(ConduceLegalidadOperativo $operativo): Carbon
    {
        $valor = $operativo->fecha ?: $operativo->created_at ?: now();
        return Carbon::parse($valor);
    }

    private function fechaCaptura(ConduceLegalidadCaptura $captura): string
    {
        if ($captura->created_at) {
            return Carbon::parse($captura->created_at)->format('Y-m-d H:i:s');
        }

        $fecha = $captura->fecha ? Carbon::parse($captura->fecha)->format('Y-m-d') : '';
        $hora = trim((string) ($captura->hora ?? ''));
        return trim($fecha . ' ' . $hora);
    }

    private function ordenCaptura(ConduceLegalidadCaptura $captura): string
    {
        $fecha = $captura->fecha ? Carbon::parse($captura->fecha)->format('Y-m-d') : '0000-00-00';
        $hora = $this->horaCorta($captura->hora);
        return sprintf('%s %s %010d', $fecha, $hora, (int) $captura->id);
    }

    private function horaTermino(ConduceLegalidadOperativo $operativo, iterable $capturas): string
    {
        $cierre = $this->horaCorta($operativo->hora_cierre);
        if ($cierre !== '') {
            return $cierre;
        }

        $ultima = '';
        foreach ($capturas as $captura) {
            $orden = $this->ordenCaptura($captura);
            if ($orden > $ultima) {
                $ultima = $orden;
            }
        }

        return $ultima !== '' ? substr($ultima, 11, 5) : $this->horaCorta($operativo->hora_inicio);
    }

    private function horaCorta($valor): string
    {
        $texto = trim((string) ($valor ?? ''));
        if ($texto === '') {
            return '';
        }
        try {
            return Carbon::parse($texto)->format('H:i');
        } catch (\Throwable $e) {
            return substr($texto, 0, 5);
        }
    }

    private function lugarOperativo(ConduceLegalidadOperativo $operativo): string
    {
        $lugar = trim((string) ($operativo->lugar ?? ''));
        $numero = trim((string) ($operativo->numero ?? ''));
        if ($numero !== '' && !Str::contains(Str::lower($lugar), Str::lower($numero))) {
            $lugar = trim($lugar . ' ' . $numero);
        }
        return $lugar;
    }

    private function mesEnEspanol(int $mes): string
    {
        $meses = [
            1 => 'Enero', 2 => 'Febrero', 3 => 'Marzo', 4 => 'Abril',
            5 => 'Mayo', 6 => 'Junio', 7 => 'Julio', 8 => 'Agosto',
            9 => 'Septiembre', 10 => 'Octubre', 11 => 'Noviembre', 12 => 'Diciembre',
        ];
        return $meses[$mes] ?? '';
    }

    private function unir(array $valores): string
    {
        return collect($valores)
            ->map(fn ($valor) => trim((string) ($valor ?? '')))
            ->filter()
            ->unique(fn ($valor) => mb_strtoupper($valor, 'UTF-8'))
            ->implode(' ');
    }

    private function dato($valor, string $fallback = 'Sin dato'): string
    {
        $texto = trim((string) ($valor ?? ''));
        return $texto !== '' ? $texto : $fallback;
    }
}
