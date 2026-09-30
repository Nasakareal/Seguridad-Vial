<?php

namespace App\Services;

use App\Models\Hechos;
use App\Services\Croquis\CroquisArchivoStorage;
use App\Services\Fotos\HechoFotoStorage;
use Carbon\Carbon;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use PhpOffice\PhpWord\IOFactory;
use PhpOffice\PhpWord\PhpWord;
use PhpOffice\PhpWord\Settings;
use PhpOffice\PhpWord\Shared\Converter;
use PhpOffice\PhpWord\SimpleType\Jc;
use PhpOffice\PhpWord\SimpleType\JcTable;
use PhpOffice\PhpWord\SimpleType\TblWidth;
use PhpOffice\PhpWord\Style\Language;
use PhpOffice\PhpWord\Style\Table;

class IphPuestaDisposicionDocxService
{
    private const INK = '1F2933';
    private const CREAM = 'EEE2C8';
    private const GREY = 'E7E7E7';
    private const GREEN = '385C46';
    private const LEGAL_W = 12240;
    private const LEGAL_H = 20160;
    private const LETTER_W = 12240;
    private const LETTER_H = 15840;
    private const MARGIN = 567;
    private const CONTENT_W = 11106;
    private const PARTE_TAB_PREFIX = "\t\t";
    private const PARTE_BULLET_LEFT = 2160;
    private const PARTE_BULLET_HANGING = 260;

    private $tempFiles = [];

    public function generar(Hechos $hecho, array $mapeo): array
    {
        Settings::setOutputEscapingEnabled(true);

        $data = $this->prepararDatos($hecho, $mapeo);
        $phpWord = new PhpWord();
        $phpWord->setDefaultFontName('Arial');
        $phpWord->setDefaultFontSize(10);
        $phpWord->getSettings()->setThemeFontLang((new Language('es-MX', 'es-MX', 'es-MX'))->setLangId(2058));
        $this->registrarEstilos($phpWord);

        if ($data['incluir_parte_informativo']) {
            $this->agregarParteInformativo($phpWord, $data);
        }

        $this->agregarIph($phpWord, $data);
        $this->agregarCadenaCustodia($phpWord, $data);

        $directorio = storage_path('app/temp');
        File::ensureDirectoryExists($directorio);

        $path = $directorio . DIRECTORY_SEPARATOR . uniqid('iph_puesta_disposicion_', true) . '.docx';

        try {
            IOFactory::createWriter($phpWord, 'Word2007')->save($path);
            $this->normalizarImagenesDocx($path);
        } finally {
            $this->limpiarTemporales();
        }

        $folio = Str::slug((string) ($hecho->folio_c5i ?: $hecho->id), '_') ?: (string) $hecho->id;

        return [$path, "iph_puesta_disposicion_{$folio}.docx"];
    }

    public function generarConduceLegalidadBarandillas(Hechos $hecho, array $mapeo): array
    {
        Settings::setOutputEscapingEnabled(true);

        $data = $this->prepararDatos($hecho, $mapeo);
        $data['personas'] = $this->arrayBarandillas($mapeo['personas'] ?? []);
        $data['conductores'] = $this->arrayBarandillas($mapeo['conductores_hecho'] ?? []);
        $data['vehiculos_puesta'] = $this->arrayBarandillas($mapeo['vehiculos'] ?? []);

        $template = $this->templateBarandillasConduce($data);

        if (!File::exists($template)) {
            throw new \RuntimeException('No se encontró la plantilla IPH de Barandillas: ' . basename($template));
        }

        $directorio = storage_path('app/temp');
        File::ensureDirectoryExists($directorio);

        $path = $directorio . DIRECTORY_SEPARATOR . uniqid('iph_barandillas_conduce_', true) . '.docx';

        if (!File::copy($template, $path)) {
            throw new \RuntimeException('No se pudo preparar la plantilla IPH de Barandillas.');
        }

        $values = $this->valoresBarandillasConduce($data);
        $this->reemplazarNombresBarandillasDocx($path, $data);
        $this->reemplazarGruaBarandillasDocx($path, $data);
        unset(
            $values['$apellidoPaterno'],
            $values['$apellidoMaterno'],
            $values['$nombre'],
            $values['$grua']
        );
        $this->reemplazarVariablesDocx($path, $values);
        $this->normalizarImagenesDocx($path);

        $folio = Str::slug((string) ($hecho->folio_c5i ?: $hecho->id), '_') ?: (string) $hecho->id;
        $tipo = $this->personaBarandillas($data) ? 'persona_vehiculo' : 'vehiculo';

        return [$path, "iph_barandillas_conduce_{$tipo}_{$folio}.docx"];
    }

    private function templateBarandillasConduce(array $data): string
    {
        return public_path($this->personaBarandillas($data)
            ? 'IPH_BARANDILLAS_PERSONA.docx'
            : 'IPH_BARANDILLAS_VEHICULO.docx');
    }

    private function valoresBarandillasConduce(array $data): array
    {
        $persona = $this->personaBarandillas($data) ?: ['nombre_completo' => $data['nombre_policia'] ?? ''];
        $vehiculo = $this->vehiculoBarandillas($data) ?: [];
        $nombrePartes = $this->partesNombreBarandillas($persona['nombre_completo'] ?? ($persona['nombre'] ?? ''));
        $fecha = $this->fechaBarandillas($data['fecha_hecho'] ?? null);
        $hora = $this->horaBarandillas($data['hora_hecho'] ?? null);
        $ubicacion = $data['ubicacion'] ?? [];
        $lugar = $this->clean($ubicacion['calle'] ?? null) ?: $this->clean($data['lugar'] ?? null);
        $colonia = $this->clean($ubicacion['colonia'] ?? null) ?: $this->clean($data['colonia_parte'] ?? null);
        $cp = $this->clean($ubicacion['codigo_postal'] ?? ($ubicacion['cp'] ?? null));
        $nacionalidad = $this->clean($persona['nacionalidad'] ?? null);
        $esMexicana = $this->esNacionalidadMexicana($nacionalidad);
        $esExtranjera = $this->esNacionalidadExtranjera($nacionalidad);
        $placas = $this->clean($vehiculo['placas'] ?? null);
        $placaExtranjera = $this->placaExtranjeraBarandillas($vehiculo['estado_placas'] ?? null);
        $servicioPublico = $this->servicioPublicoBarandillas($vehiculo['tipo_servicio'] ?? null);
        $grua = $this->valorGrua($vehiculo['grua_nombre'] ?? null)
            ?: $this->valorGrua($vehiculo['grua'] ?? null)
            ?: $this->valorGrua($vehiculo['corralon'] ?? null);

        return [
            '$descripciónfisica' => $this->descripcionFisicaBarandillas($persona),
            '$apellidoPaterno' => $nombrePartes['apellido_paterno'],
            '$apellidoMaterno' => $nombrePartes['apellido_materno'],
            '$apellido' => trim($nombrePartes['apellido_paterno'] . ' ' . $nombrePartes['apellido_materno']),
            '$narrativa' => $this->clean($data['narrativa_operativa'] ?? null) ?: $this->clean($data['dinamica_hecho'] ?? null),
            '$nombre' => $nombrePartes['nombre'],
            '$unidad' => $this->clean($data['hecho']['unidad_org_nombre'] ?? null) ?: $this->clean($data['puesta']['unidad_nombre'] ?? null) ?: $this->clean($data['oficina'] ?? null),
            '$lugar (lugar)' => $lugar,
            '$lugar' => $lugar,
            '$colonia' => $colonia,
            '$lat' => $this->clean($ubicacion['lat'] ?? null),
            '$lng' => $this->clean($ubicacion['lng'] ?? null),
            '$cp' => $cp,
            '$alias' => $this->clean($persona['alias'] ?? null),
            '$sf' => $this->marcaSexoBarandillas($persona['sexo'] ?? null, 'femenino'),
            '$sm' => $this->marcaSexoBarandillas($persona['sexo'] ?? null, 'masculino'),
            '$nac' => $esMexicana ? 'X' : '',
            '$ext' => $esExtranjera ? 'X' : '',
            '$extcu' => $esExtranjera ? $nacionalidad : '',
            '$marca' => $this->clean($vehiculo['marca'] ?? null),
            '$linea' => $this->clean($vehiculo['linea'] ?? ($vehiculo['submarca'] ?? null)),
            '$modelo' => $this->clean($vehiculo['modelo'] ?? null),
            '$color' => $this->clean($vehiculo['color'] ?? null),
            '$placas' => $placas,
            '$serie' => $this->clean($vehiculo['serie'] ?? null),
            '$upa' => ($placas && !$servicioPublico) ? 'X' : '',
            '$upu' => ($placas && $servicioPublico) ? 'X' : '',
            '$prona' => ($placas && !$placaExtranjera) ? 'X' : '',
            '$proex' => ($placas && $placaExtranjera) ? 'X' : '',
            '$grua' => $grua ?: '',
            '$foc' => $this->clean($data['folio'] ?? null),
            '$d' => $fecha['dia'],
            '$me' => $fecha['mes'],
            '$m' => '',
            '$ye' => $fecha['anio'],
            '$ho' => $hora['hora'],
            '$min' => $hora['minuto'],
        ];
    }

    private function reemplazarVariablesDocx(string $path, array $values): void
    {
        $zip = new \ZipArchive();

        if ($zip->open($path) !== true) {
            throw new \RuntimeException('No se pudo abrir el DOCX generado para reemplazar variables.');
        }

        uksort($values, fn ($a, $b) => mb_strlen($b, 'UTF-8') <=> mb_strlen($a, 'UTF-8'));
        $mergePlaceholders = array_values(array_filter(array_keys($values), fn ($key) => $key !== '$m'));

        for ($i = 0; $i < $zip->numFiles; $i++) {
            $name = $zip->getNameIndex($i);

            if (!$name || !preg_match('/^word\/.+\.xml$/', $name)) {
                continue;
            }

            $xml = $zip->getFromIndex($i);

            if ($xml === false || strpos($xml, '$') === false) {
                continue;
            }

            $xml = $this->unirVariablesPartidasDocx($xml, $mergePlaceholders);

            foreach ($values as $placeholder => $value) {
                $xml = $this->reemplazarVariableDocx($xml, $placeholder, $value);
            }

            $xml = preg_replace('/\$[A-Za-zÁÉÍÓÚÜÑáéíóúüñ_][A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9_]*/u', '', $xml) ?? $xml;
            $zip->addFromString($name, $xml);
        }

        $zip->close();
    }

    private function reemplazarNombresBarandillasDocx(string $path, array $data): void
    {
        $zip = new \ZipArchive();

        if ($zip->open($path) !== true) {
            throw new \RuntimeException('No se pudo abrir el DOCX para separar agente y persona detenida.');
        }

        $entry = 'word/document.xml';
        $xml = $zip->getFromName($entry);
        if ($xml === false) {
            $zip->close();
            throw new \RuntimeException('La plantilla IPH no contiene word/document.xml.');
        }

        $placeholders = ['$apellidoPaterno', '$apellidoMaterno', '$nombre'];
        $xml = $this->unirVariablesPartidasDocx($xml, $placeholders);

        $agenteIph = $this->partesPoliciaIph($data);
        $agente = [
            'apellido_paterno' => $agenteIph['primer_apellido'] ?? '',
            'apellido_materno' => $agenteIph['segundo_apellido'] ?? '',
            'nombre' => $agenteIph['nombres'] ?? '',
        ];
        $personaData = $this->personaBarandillas($data);
        $persona = $personaData
            ? $this->partesNombreBarandillas($personaData['nombre_completo'] ?? ($personaData['nombre'] ?? ''))
            : null;

        $sequences = [
            '$apellidoPaterno' => [
                $agente['apellido_paterno'],
                $persona['apellido_paterno'] ?? '',
                '',
                '',
            ],
            '$apellidoMaterno' => [
                $agente['apellido_materno'],
                $persona['apellido_materno'] ?? '',
                '',
                '',
            ],
            '$nombre' => [
                $agente['nombre'],
                $persona['nombre'] ?? '',
                '',
                '',
            ],
        ];

        foreach ($sequences as $placeholder => $values) {
            $index = 0;
            $pattern = '/' . preg_quote($placeholder, '/') . '/u';
            $xml = preg_replace_callback($pattern, function () use (&$index, $values) {
                $value = $values[$index] ?? '';
                $index++;

                return $this->escapeDocxText($value);
            }, $xml) ?? $xml;
        }

        $zip->addFromString($entry, $xml);
        $zip->close();
    }

    private function reemplazarGruaBarandillasDocx(string $path, array $data): void
    {
        $vehiculo = $this->vehiculoBarandillas($data) ?: [];
        $nombre = $this->valorGrua($vehiculo['grua_nombre'] ?? null)
            ?: $this->valorGrua($vehiculo['grua'] ?? null)
            ?: $this->valorGrua($vehiculo['corralon'] ?? null)
            ?: '';
        $ubicacion = $this->valorGrua($vehiculo['grua_direccion'] ?? null)
            ?: $this->valorGrua($vehiculo['grua_ubicacion_corralon'] ?? null)
            ?: $this->valorGrua($vehiculo['corralon'] ?? null)
            ?: $nombre;

        $zip = new \ZipArchive();
        if ($zip->open($path) !== true) {
            throw new \RuntimeException('No se pudo abrir el DOCX para insertar la grúa.');
        }

        $entry = 'word/document.xml';
        $xml = $zip->getFromName($entry);
        if ($xml === false) {
            $zip->close();
            throw new \RuntimeException('La plantilla IPH no contiene word/document.xml.');
        }

        $placeholder = '$grua';
        $xml = $this->unirVariablesPartidasDocx($xml, [$placeholder]);
        $values = [$nombre, $ubicacion];
        $index = 0;
        $pattern = '/' . preg_quote($placeholder, '/') . '/u';
        $xml = preg_replace_callback($pattern, function () use (&$index, $values) {
            $value = $values[$index] ?? '';
            $index++;

            return $this->escapeDocxText($value);
        }, $xml) ?? $xml;

        $zip->addFromString($entry, $xml);
        $zip->close();
    }

    private function reemplazarVariableDocx(string $xml, string $placeholder, $value): string
    {
        if ($this->debeRepartirVariableDocx($xml, $placeholder, $value)) {
            return $this->reemplazarVariablePorCaracteresDocx($xml, $placeholder, $value);
        }

        return str_replace($placeholder, $this->escapeDocxText($value), $xml);
    }

    private function debeRepartirVariableDocx(string $xml, string $placeholder, $value): bool
    {
        if (!in_array($placeholder, ['$foc', '$d', '$me', '$ye', '$ho', '$min'], true)) {
            return false;
        }

        $text = $this->textoSecuencialDocx($value);

        return mb_strlen($text, 'UTF-8') > 1
            && substr_count($xml, $placeholder) > 1;
    }

    private function reemplazarVariablePorCaracteresDocx(string $xml, string $placeholder, $value): string
    {
        $chars = preg_split('//u', $this->textoSecuencialDocx($value), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $total = count($chars);

        if ($total <= 1) {
            return str_replace($placeholder, $this->escapeDocxText($value), $xml);
        }

        $index = 0;
        $pattern = '/' . preg_quote($placeholder, '/') . '/u';
        $occurrences = substr_count($xml, $placeholder);

        return preg_replace_callback($pattern, function () use (&$index, $chars, $placeholder, $occurrences) {
            $isFechaNacimiento = (
                in_array($placeholder, ['$d', '$me'], true)
                && $occurrences === 10
                && $index >= 6
                && $index <= 7
            ) || (
                $placeholder === '$ye'
                && $occurrences === 20
                && $index >= 12
                && $index <= 15
            );
            if ($isFechaNacimiento) {
                $index++;

                return '';
            }

            $char = $placeholder === '$foc'
                ? ($chars[$index] ?? '')
                : ($chars[$index % count($chars)] ?? '');
            $index++;

            return $this->escapeDocxText($char);
        }, $xml) ?? $xml;
    }

    private function textoSecuencialDocx($value): string
    {
        return trim(preg_replace('/\s+/u', '', (string) $value) ?? '');
    }

    private function unirVariablesPartidasDocx(string $xml, array $placeholders): string
    {
        $previous = libxml_use_internal_errors(true);
        $dom = new \DOMDocument();
        $loaded = $dom->loadXML($xml, LIBXML_NONET);
        libxml_clear_errors();
        libxml_use_internal_errors($previous);

        if (!$loaded) {
            return $xml;
        }

        usort($placeholders, fn ($a, $b) => mb_strlen($b, 'UTF-8') <=> mb_strlen($a, 'UTF-8'));
        $xpath = new \DOMXPath($dom);
        $xpath->registerNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        $nodeList = $xpath->query('//w:t');
        if ($nodeList === false || $nodeList->length === 0) {
            return $xml;
        }

        $nodes = iterator_to_array($nodeList);
        $count = count($nodes);
        $changed = false;

        for ($i = 0; $i < $count; $i++) {
            $initial = (string) $nodes[$i]->textContent;
            if (strpos($initial, '$') === false) {
                continue;
            }

            $dollarPosition = mb_strrpos($initial, '$', 0, 'UTF-8');
            if ($dollarPosition === false) {
                continue;
            }

            $prefix = mb_substr($initial, 0, $dollarPosition, 'UTF-8');
            $combined = mb_substr($initial, $dollarPosition, null, 'UTF-8');
            $indices = [];

            for ($j = $i + 1; $j < min($count, $i + 6); $j++) {
                $combined .= (string) $nodes[$j]->textContent;
                $indices[] = $j;

                if (in_array($combined, $placeholders, true)) {
                    $nodes[$i]->nodeValue = $prefix . $combined;
                    foreach ($indices as $idx) {
                        $nodes[$idx]->nodeValue = '';
                    }
                    $changed = true;
                    break;
                }

                $isPrefix = false;

                foreach ($placeholders as $placeholder) {
                    if (strpos($placeholder, $combined) === 0) {
                        $isPrefix = true;
                        break;
                    }
                }

                if (!$isPrefix) {
                    break;
                }
            }
        }

        if (!$changed) {
            return $xml;
        }

        return $dom->saveXML() ?: $xml;
    }

    private function escapeDocxText($value): string
    {
        $text = trim(preg_replace('/\s+/u', ' ', (string) $value) ?? '');

        return htmlspecialchars($text, ENT_QUOTES | ENT_XML1, 'UTF-8');
    }

    private function personaBarandillas(array $data): ?array
    {
        foreach ([$data['personas'] ?? [], $data['conductores'] ?? []] as $personas) {
            foreach ($personas as $persona) {
                if (is_array($persona) && $this->clean($persona['nombre_completo'] ?? ($persona['nombre'] ?? null))) {
                    return $persona;
                }
            }
        }

        foreach ($data['vehiculos'] ?? [] as $vehiculo) {
            foreach (($vehiculo['conductores'] ?? []) as $persona) {
                if (is_array($persona) && $this->clean($persona['nombre_completo'] ?? ($persona['nombre'] ?? null))) {
                    return $persona;
                }
            }
        }

        return null;
    }

    private function vehiculoBarandillas(array $data): ?array
    {
        foreach ([$data['vehiculos'] ?? [], $data['vehiculos_puesta'] ?? []] as $vehiculos) {
            foreach ($vehiculos as $vehiculo) {
                if (is_array($vehiculo)) {
                    return $vehiculo;
                }
            }
        }

        return null;
    }

    private function partesNombreBarandillas($nombre): array
    {
        $partes = preg_split('/\s+/u', trim((string) $nombre)) ?: [];
        $partes = array_values(array_filter($partes, fn ($parte) => $parte !== ''));

        if (count($partes) >= 3) {
            $apellidoMaterno = array_pop($partes);
            $apellidoPaterno = array_pop($partes);

            return [
                'nombre' => implode(' ', $partes),
                'apellido_paterno' => $apellidoPaterno,
                'apellido_materno' => $apellidoMaterno,
            ];
        }

        if (count($partes) === 2) {
            return [
                'nombre' => $partes[0],
                'apellido_paterno' => $partes[1],
                'apellido_materno' => '',
            ];
        }

        return [
            'nombre' => $partes[0] ?? '',
            'apellido_paterno' => '',
            'apellido_materno' => '',
        ];
    }

    private function descripcionFisicaBarandillas(array $persona): string
    {
        $edad = $this->clean($persona['edad_aproximada'] ?? null) ?: $this->clean($persona['edad'] ?? null);
        $mediaFiliacion = [];
        $vestimenta = [];
        $rasgos = $this->listaTextoBarandillas($persona['rasgos_visibles'] ?? []);

        foreach ([
            'complexion' => 'complexión',
            'estatura' => 'estatura',
            'tez' => 'tez',
            'cabello' => 'cabello',
        ] as $key => $label) {
            if ($value = $this->clean($persona[$key] ?? null)) {
                $mediaFiliacion[] = $label . ' ' . $value;
            }
        }

        foreach ([
            ['prenda_superior', 'color_superior', 'parte superior'],
            ['prenda_inferior', 'color_inferior', 'parte inferior'],
            ['calzado', 'color_calzado', 'calzado'],
        ] as [$prendaKey, $colorKey, $label]) {
            $prenda = $this->clean($persona[$prendaKey] ?? null);
            $color = $this->clean($persona[$colorKey] ?? null);

            if ($prenda || $color) {
                $vestimenta[] = trim($label . ': ' . trim($prenda . ($color ? ' color ' . $color : '')));
            }
        }

        $lineas = [];

        if ($edad) {
            $lineas[] = 'Edad aproximada: ' . (is_numeric($edad) ? $edad . ' años' : $edad);
        }

        if ($mediaFiliacion) {
            $lineas[] = 'Media filiación: ' . implode(', ', $mediaFiliacion);
        }

        if ($vestimenta) {
            $lineas[] = 'Vestimenta: ' . implode('; ', $vestimenta);
        }

        if ($rasgos) {
            $lineas[] = 'Rasgos visibles: ' . implode(', ', $rasgos);
        }

        return implode('. ', $lineas) ?: $this->clean($persona['observaciones'] ?? null);
    }

    private function listaTextoBarandillas($value): array
    {
        if (is_string($value)) {
            $decoded = json_decode($value, true);
            $value = is_array($decoded) ? $decoded : preg_split('/[,;]+/u', $value);
        }

        if (!is_array($value)) {
            return [];
        }

        return array_values(array_filter(array_map(fn ($item) => $this->clean($item), $value)));
    }

    private function marcaSexoBarandillas($sexo, string $expected): string
    {
        $clave = $this->normalizarClaveIph($sexo);

        if ($expected === 'femenino') {
            return in_array($clave, ['F', 'FEMENINO', 'MUJER'], true) ? 'X' : '';
        }

        if ($expected === 'masculino') {
            return in_array($clave, ['M', 'MASCULINO', 'HOMBRE'], true) ? 'X' : '';
        }

        return '';
    }

    private function esNacionalidadMexicana(?string $nacionalidad): bool
    {
        $clave = $this->normalizarClaveIph($nacionalidad);

        return $clave !== '' && (strpos($clave, 'MEXICO') !== false || strpos($clave, 'MEXIC') !== false);
    }

    private function esNacionalidadExtranjera(?string $nacionalidad): bool
    {
        $clave = $this->normalizarClaveIph($nacionalidad);

        return $clave !== ''
            && !$this->esNacionalidadMexicana($nacionalidad)
            && !in_array($clave, ['NOAPRECIABLE', 'SINDATO', 'NOESPECIFICADO'], true);
    }

    private function placaExtranjeraBarandillas($estadoPlacas): bool
    {
        $clave = $this->normalizarClaveIph($estadoPlacas);

        foreach (['EXTRANJER', 'USA', 'EUA', 'EEUU', 'ESTADOSUNIDOS', 'FOREIGN'] as $fragmento) {
            if (strpos($clave, $fragmento) !== false) {
                return true;
            }
        }

        return false;
    }

    private function servicioPublicoBarandillas($tipoServicio): bool
    {
        $clave = $this->normalizarClaveIph($tipoServicio);

        return strpos($clave, 'PUBLIC') !== false || strpos($clave, 'TRANSPORTEPUBLICO') !== false;
    }

    private function fechaBarandillas($fecha): array
    {
        try {
            $carbon = $fecha ? Carbon::parse($fecha, 'America/Mexico_City') : null;
        } catch (\Throwable $e) {
            $carbon = null;
        }

        return [
            'dia' => $carbon ? $carbon->format('d') : '',
            'mes' => $carbon ? $carbon->format('m') : '',
            'anio' => $carbon ? $carbon->format('Y') : '',
        ];
    }

    private function horaBarandillas($hora): array
    {
        $hora = substr(trim((string) $hora), 0, 5);
        $partes = preg_match('/^(\d{1,2}):(\d{2})$/', $hora, $match) ? $match : null;

        return [
            'hora' => $partes ? str_pad($partes[1], 2, '0', STR_PAD_LEFT) : '',
            'minuto' => $partes ? $partes[2] : '',
        ];
    }

    private function arrayBarandillas($value): array
    {
        return is_array($value) ? array_values($value) : [];
    }
    private function prepararDatos(Hechos $hecho, array $mapeo): array
    {
        $hechoIph = $mapeo['hecho'] ?? [];
        $puesta = $mapeo['puesta_disposicion'] ?? [];
        $ubicacion = $hechoIph['ubicacion'] ?? [];
        $vehiculos = $mapeo['vehiculos_hecho'] ?? [];
        $lesionados = $mapeo['lesionados_hecho'] ?? [];
        $anexos = $mapeo['anexos'] ?? [];
        $opciones = $mapeo['opciones'] ?? [];

        $fechaHecho = trim((string) ($hechoIph['fecha'] ?? ''));
        $horaHecho = trim((string) ($hechoIph['hora'] ?? ''));
        $fechaPuesta = trim((string) ($puesta['fecha_puesta'] ?? '')) ?: now('America/Mexico_City')->format('Y-m-d');
        $horaPuesta = trim((string) ($puesta['hora_puesta'] ?? '')) ?: now('America/Mexico_City')->format('H:i');
        $fechaHoraHecho = $this->carbon($fechaHecho, $horaHecho);
        $conocimiento = $fechaHoraHecho ? $fechaHoraHecho->copy()->subMinutes(35) : null;
        $arribo = $fechaHoraHecho ? $fechaHoraHecho->copy() : null;
        $recoleccion = $fechaHoraHecho ? $fechaHoraHecho->copy()->addMinutes(35) : now('America/Mexico_City')->addMinutes(35);
        $lugar = collect([$ubicacion['calle'] ?? null, $ubicacion['colonia'] ?? null, $ubicacion['municipio'] ?? null])
            ->map(fn ($dato) => trim((string) $dato))
            ->filter()
            ->implode(', ');

        if ($lugar === '') {
            $lugar = trim((string) ($ubicacion['ubicacion_formateada'] ?? ''));
        }

        $unidadId = (int) ($hechoIph['unidad_org_id'] ?? ($puesta['unidad_id'] ?? 0));
        $unidadNombre = $this->valor($hechoIph['unidad_org_nombre'] ?? ($puesta['unidad_nombre'] ?? null), '');
        $oficina = $this->nombreOficina($unidadId, $unidadNombre);
        $municipio = $this->title($ubicacion['municipio'] ?? 'Lazaro Cárdenas');
        $folio = preg_replace('/\s+/', '', (string) ($hechoIph['folio_c5i'] ?? '')) ?: (string) ($hecho->id ?? '');
        $nombrePolicia = $this->valor($puesta['nombre_policia'] ?? ($hechoIph['creador_nombre'] ?? ($hechoIph['perito'] ?? null)), '');
        $adscripcion = mb_strtoupper($oficina, 'UTF-8');
        $unidadArribo = trim((string) ($hechoIph['unidad_numero_economico'] ?? ($hechoIph['unidad'] ?? '')));
        $tipoHechoParte = mb_strtoupper(trim((string) ($hechoIph['tipo_hecho'] ?? '')), 'UTF-8');
        $causasParte = mb_strtoupper(trim((string) ($hechoIph['causas'] ?? '')), 'UTF-8');
        $modalidadParte = trim(collect([
            $tipoHechoParte,
            $causasParte !== '' ? 'POR ' . $causasParte : null,
        ])->filter()->implode(' '));
        $modalidadParte = $modalidadParte !== '' ? $modalidadParte : 'HECHO DE TRÁNSITO';
        $calle = $this->valor($ubicacion['calle'] ?? $lugar, 'el lugar de intervención');
        $colonia = $this->valor($ubicacion['colonia'] ?? null, 'la colonia señalada');
        $ubicacionIph = [
            'calle_tramo' => mb_strtoupper($this->valor($ubicacion['calle'] ?? ($ubicacion['ubicacion_formateada'] ?? $lugar), ''), 'UTF-8'),
            'no_exterior' => mb_strtoupper($this->valor($ubicacion['numero_exterior'] ?? ($ubicacion['no_exterior'] ?? null), 'SIN NÚMERO'), 'UTF-8'),
            'no_interior' => mb_strtoupper($this->valor($ubicacion['numero_interior'] ?? ($ubicacion['no_interior'] ?? null), ''), 'UTF-8'),
            'codigo_postal' => mb_strtoupper($this->valor($ubicacion['codigo_postal'] ?? ($ubicacion['cp'] ?? null), ''), 'UTF-8'),
            'colonia_localidad' => mb_strtoupper($this->valor($ubicacion['colonia'] ?? null, ''), 'UTF-8'),
            'municipio' => mb_strtoupper($municipio, 'UTF-8'),
            'entidad' => mb_strtoupper($this->valor($ubicacion['estado'] ?? ($ubicacion['entidad'] ?? null), 'MICHOACÁN'), 'UTF-8'),
            'referencias' => mb_strtoupper($this->valor($ubicacion['entre_calles'] ?? ($ubicacion['referencias'] ?? null), ''), 'UTF-8'),
            'latitud' => trim((string) ($ubicacion['lat'] ?? '')),
            'longitud' => trim((string) ($ubicacion['lng'] ?? '')),
        ];
        $horaEntera = is_string($horaHecho) ? (int) substr($horaHecho, 0, 2) : null;
        $momentoDia = 'Durante el día';

        if ($horaEntera !== null) {
            if ($horaEntera < 6) {
                $momentoDia = 'De madrugada';
            } elseif ($horaEntera < 12) {
                $momentoDia = 'De mañana';
            } elseif ($horaEntera < 19) {
                $momentoDia = 'De tarde';
            } else {
                $momentoDia = 'De noche';
            }
        }

        $clima = mb_strtolower(trim((string) ($hechoIph['clima'] ?? '')), 'UTF-8');
        $descripcionClima = in_array($clima, ['', 'bueno'], true) ? 'sin alteración meteorológica' : 'con clima ' . $clima;
        $tiempo = mb_strtolower(trim((string) ($hechoIph['tiempo'] ?? '')), 'UTF-8');
        $condicionesIluminacion = in_array($tiempo, ['noche'], true) || ($horaEntera !== null && ($horaEntera < 7 || $horaEntera >= 19))
            ? 'Prevalecía luz artificial, emitida por las lámparas de alumbrado público que hay en el lugar.'
            : 'Prevalecía luz natural en el lugar.';
        $gruas = collect($vehiculos)->map(function (array $vehiculo) {
            $nombre = $this->valorGrua($vehiculo['grua_nombre'] ?? null) ?: $this->valorGrua($vehiculo['grua'] ?? null);
            $direccion = $this->valorGrua($vehiculo['grua_direccion'] ?? null)
                ?: $this->valorGrua($vehiculo['grua_ubicacion_corralon'] ?? null)
                ?: $this->valorGrua($vehiculo['corralon'] ?? null);

            return (!$nombre && !$direccion) ? null : ['nombre' => $nombre, 'direccion' => $direccion];
        })->filter()->unique(fn ($grua) => mb_strtoupper(($grua['nombre'] ?? '') . '|' . ($grua['direccion'] ?? ''), 'UTF-8'))->values();
        $ubicacionCadena = mb_strtoupper($lugar, 'UTF-8');

        if (($ubicacion['lat'] ?? null) && ($ubicacion['lng'] ?? null)) {
            $ubicacionCadena .= ' CON COORDENADAS ' . $ubicacion['lat'] . ', ' . $ubicacion['lng'];
        }

        $lugarEntrega = collect([
            $gruas->pluck('nombre')->filter()->first(),
            $gruas->pluck('direccion')->filter()->first(),
            $ubicacionCadena,
        ])->filter()->first() ?: $ubicacionCadena;
        $fotos = [];

        if ($foto = $this->resolverImagen($anexos['foto_lugar'] ?? null)) {
            $fotos[] = ['path' => $foto, 'caption' => 'Fijación fotográfica 1 del lugar de intervención'];
        }

        if ($foto = $this->resolverImagen($anexos['foto_lugar_2'] ?? null)) {
            $fotos[] = ['path' => $foto, 'caption' => 'Fijación fotográfica 2 del lugar de intervención'];
        }

        foreach ($vehiculos as $i => $vehiculo) {
            if ($foto = $this->resolverImagen($vehiculo['foto'] ?? null)) {
                $fotos[] = ['path' => $foto, 'caption' => 'Fijación fotográfica del vehículo ' . $this->letraIndice($i)];
            }
        }

        return [
            'hecho' => $hechoIph,
            'puesta' => $puesta ?: [],
            'incluir_parte_informativo' => ($opciones['incluir_parte_informativo'] ?? true) !== false,
            'ubicacion' => $ubicacion,
            'vehiculos' => $vehiculos,
            'lesionados' => $lesionados,
            'objetos' => $mapeo['objetos'] ?? [],
            'unidad_id' => $unidadId,
            'folio' => $folio,
            'fecha_hecho' => $fechaHecho,
            'hora_hecho' => $horaHecho,
            'fecha_puesta' => $fechaPuesta,
            'hora_puesta' => $horaPuesta,
            'fecha_texto' => $this->fechaTexto($fechaHecho),
            'fecha_puesta_texto' => $this->fechaTexto($fechaPuesta),
            'fecha_encabezado' => now('America/Mexico_City')->format('d-m-Y'),
            'fecha_intervencion_cadena' => $fechaHoraHecho ? $fechaHoraHecho->format('d-m-Y') : $this->fechaCorta($fechaHecho),
            'hora_intervencion_cadena' => $fechaHoraHecho ? $fechaHoraHecho->format('H:i') : substr($horaHecho, 0, 5),
            'hora_recoleccion_cadena' => $recoleccion->format('H:i'),
            'conocimiento' => $conocimiento,
            'arribo' => $arribo,
            'lugar' => $lugar,
            'ubicacion_iph' => $ubicacionIph,
            'ubicacion_cadena' => $ubicacionCadena,
            'lugar_entrega' => mb_strtoupper($lugarEntrega, 'UTF-8'),
            'oficina' => $oficina,
            'municipio' => $municipio,
            'municipio_mayus' => mb_strtoupper($municipio, 'UTF-8'),
            'oficio' => $this->valor($puesta['oficio'] ?? ($hechoIph['oficio_mp'] ?? null), ''),
            'expediente' => $this->valor($puesta['carpeta_investigacion'] ?? null, ''),
            'nombre_policia' => $nombrePolicia,
            'nombre_policia_mayus' => mb_strtoupper($nombrePolicia, 'UTF-8'),
            'agente_nombres' => mb_strtoupper($this->clean($puesta['agente_nombres'] ?? null), 'UTF-8'),
            'agente_apellido_paterno' => mb_strtoupper($this->clean($puesta['agente_apellido_paterno'] ?? null), 'UTF-8'),
            'agente_apellido_materno' => mb_strtoupper($this->clean($puesta['agente_apellido_materno'] ?? null), 'UTF-8'),
            'agente_numero_placa' => $this->clean($puesta['agente_numero_placa'] ?? null),
            'adscripcion' => $adscripcion,
            'unidad_arribo' => mb_strtoupper($unidadArribo, 'UTF-8'),
            'autoridad_portada_iph' => 'FISCALÍA GENERAL DEL ESTADO',
            'autoridad' => mb_strtoupper($this->valor($puesta['autoridad_receptora'] ?? 'DIRECCIÓN DE CARPETAS DE INVESTIGACIÓN DE LA FISCALÍA GENERAL DE JUSTICIA EN EL ESTADO', ''), 'UTF-8'),
            'tipo_hecho' => mb_strtoupper($this->valor($hechoIph['tipo_hecho'] ?? 'HECHO DE TRÁNSITO', 'HECHO DE TRÁNSITO'), 'UTF-8'),
            'causas' => mb_strtoupper($this->valor($hechoIph['causas'] ?? null, ''), 'UTF-8'),
            'modalidad_parte' => $modalidadParte,
            'dinamica_hecho' => $this->valor($hechoIph['dinamica_hecho'] ?? ($puesta['narrativa'] ?? null), ''),
            'narrativa_operativa' => $this->valor($hechoIph['narrativa_operativa'] ?? ($puesta['narrativa_operativa'] ?? null), ''),
            'conclusion_causa' => $this->valor($hechoIph['conclusion_causa'] ?? ($puesta['conclusion_causa'] ?? null), ''),
            'conclusion_disposicion' => $this->valor($hechoIph['conclusion_disposicion'] ?? ($puesta['conclusion_disposicion'] ?? null), ''),
            'calle_parte' => $calle,
            'colonia_parte' => $colonia,
            'condiciones_climatologicas' => $momentoDia . ', ' . $descripcionClima . '.',
            'condiciones_iluminacion' => $condicionesIluminacion,
            'croquis' => $this->resolverImagen($anexos['croquis_preview'] ?? null),
            'fotos' => array_values(array_unique($fotos, SORT_REGULAR)),
        ];
    }

    private function registrarEstilos(PhpWord $phpWord): void
    {
        $phpWord->addTitleStyle(1, ['bold' => true, 'size' => 12], ['alignment' => Jc::CENTER, 'spaceAfter' => 80]);
        $phpWord->addTableStyle('HeaderInfo', ['borderSize' => 0, 'cellMargin' => 35, 'alignment' => JcTable::CENTER, 'layout' => Table::LAYOUT_FIXED, 'unit' => TblWidth::TWIP]);
        $phpWord->addTableStyle('Clean', ['borderSize' => 0, 'cellMargin' => 40, 'alignment' => JcTable::CENTER, 'layout' => Table::LAYOUT_FIXED, 'unit' => TblWidth::TWIP]);
        $phpWord->addTableStyle('FormTable', ['borderSize' => 6, 'borderColor' => self::INK, 'cellMargin' => 45, 'alignment' => JcTable::CENTER, 'layout' => Table::LAYOUT_FIXED, 'unit' => TblWidth::TWIP]);
        $phpWord->addTableStyle('NoBorder', ['borderSize' => 1, 'borderColor' => 'FFFFFF', 'cellMargin' => 20, 'alignment' => JcTable::CENTER, 'layout' => Table::LAYOUT_FIXED, 'unit' => TblWidth::TWIP]);
    }

    private function agregarParteInformativo(PhpWord $phpWord, array $d): void
    {
        $section = $this->seccion($phpWord, 'legal');
        $this->membreteParte($section, $d);
        foreach ($this->lineasAutoridadParte($d['autoridad']) as $index => $linea) {
            $this->texto($section, $linea, ['bold' => true, 'size' => 11], [
                'spaceBefore' => $index === 0 ? 90 : 0,
                'spaceAfter' => 0,
                'lineHeight' => 1.05,
            ]);
        }

        $this->texto($section, 'P R E S E N T E .', ['bold' => true, 'size' => 11, 'spacing' => 4], [
            'spaceAfter' => 360,
            'lineHeight' => 1.05,
        ]);
        $this->parrafoParteConNombre($section, $d);
        $this->texto($section, 'PARTE INFORMATIVO', ['bold' => true, 'size' => 16], ['alignment' => Jc::CENTER, 'spaceBefore' => 260, 'spaceAfter' => 260]);
        $this->encabezadoParte($section, 'I.', 'PLANTEAMIENTO DEL PROBLEMA:');
        $this->parrafoProblemaParte($section, $d);
        $this->encabezadoParte($section, 'II.', 'METODOLOGÍA APLICADA AL PRESENTE INFORME PERICIAL:');
        $this->parrafoParte($section, 'La metodología propuesta por el método científico, en cuanto al planteamiento del problema, la recopilación de datos por medio de la observación metódica y directa.');
        $this->parrafoParte($section, 'Para realizar el presente Parte Informativo aplicaremos:');
        $this->vinetaParte($section, 'Método inductivo es un método del que se obtienen conclusiones generales a partir de las premisas particulares.');
        $this->vinetaParte($section, 'Método deductivo un método el cual se utiliza para interpretar hechos particulares a través de una ley general establecida y se deriva de hechos similares, al del objeto de estudio.');
        $this->encabezadoParte($section, 'III.', 'MATERIAL UTILIZADO:');
        foreach (['Libreta de anotaciones, lapicero de punto medio.', 'Cámara fotográfica digital.', 'Cinta métrica.', 'Brújula Digital para señalar la orientación.'] as $item) {
            $this->vinetaParte($section, $item);
        }
        $this->encabezadoParte($section, 'IV.', 'OBJETIVOS:');
        $this->parrafoParte($section, 'Contribuir con información sobre los datos e indicios recabados en el lugar.');
        $this->encabezadoParte($section, 'V.', 'FIJACIÓN DEL LUGAR DE LA INTERVENCIÓN:');
        foreach (['Fotográfica', 'Escrita', 'Planimetría'] as $item) {
            $this->vinetaParte($section, $item);
        }

        $this->encabezadoParte($section, 'VI.', 'CONDICIONES CLIMATOLÓGICAS:');
        $this->parrafoParte($section, $d['condiciones_climatologicas']);
        $this->encabezadoParte($section, 'VII.', 'CONDICIONES DE ILUMINACIÓN:');
        $this->parrafoParte($section, $d['condiciones_iluminacion']);
        $this->encabezadoParte($section, 'VIII.', 'DESCRIPCIÓN DEL LUGAR DE LOS HECHOS:');
        $this->parrafoParte($section, 'Corresponde a ' . $d['calle_parte'] . ', la cual se encuentra construida por una superficie de concreto, en buen estado de conservación, tramo a nivel, cuenta con paramentos a sus costados, tiene capacidad para dos carriles de circulación, uno para cada sentido, orientados de oriente a poniente y viceversa, a la hora de la intervención la superficie de rodamiento se encontraba limpia y seca.');

        $this->encabezadoParte($section, 'IX.', 'DESCRIPCIÓN DE VEHÍCULOS:');

        foreach ($d['vehiculos'] as $i => $vehiculo) {
            $this->parrafoVehiculoParte($section, $vehiculo, $i);
        }

        if (empty($d['vehiculos'])) {
            $this->parrafoParte($section, 'No se cuenta con vehículos registrados en el hecho.');
        }

        $section->addPageBreak();
        $this->encabezadoParte($section, 'X.', 'DINÁMICA DEL HECHO DE TRÁNSITO:');
        $this->parrafoParte($section, $d['dinamica_hecho'] ?: 'Por los datos e informes recabados en el lugar del hecho, mediante la inspección ocular realizada por los suscritos, se hace constar de manera preliminar la intervención correspondiente al hecho de tránsito descrito en el presente informe, quedando la narrativa pormenorizada sujeta a la complementación por el personal actuante conforme a los datos obtenidos en campo.');

        $this->encabezadoParte($section, 'XI.', 'DIAGRAMA ILUSTRATIVO NO HECHO A ESCALA.');
        $this->imagenEnMarco($section, $d['croquis'], 640, 720, 'Sin croquis registrado en el sistema.');
        $section->addPageBreak();

        foreach ($d['fotos'] as $foto) {
            $this->encabezadoParte($section, 'XII.', 'FIJACIÓN FOTOGRÁFICA.');
            $this->imagenEnMarco($section, $foto['path'], 600, 520, 'Sin imagen disponible.');
        }

        if (!empty($d['fotos'])) {
            $section->addPageBreak();
        }

        $this->encabezadoParte($section, 'XIII.-', 'VÍCTIMAS:');

        if (empty($d['lesionados'])) {
            $this->parrafoParte($section, 'De este hecho de tránsito no se manifestaron ante el suscrito.');
        } else {
            foreach ($d['lesionados'] as $lesionado) {
                $this->parrafoParte($section, $this->descripcionVictimaParte($lesionado));
            }
        }

        $this->encabezadoParte($section, 'XIV.-', 'DAÑOS:');

        foreach ($d['vehiculos'] as $i => $vehiculo) {
            $this->parrafoParte($section, $this->daniosVehiculo($vehiculo, $i));
        }

        if (empty($d['vehiculos'])) {
            $this->parrafoParte($section, 'No se cuenta con vehículos registrados para estimación de daños.');
        } else {
            $this->parrafoParte($section, 'Estos daños fueron estimados y calculados a simple vista y será salvo el presupuesto real que le sea presentado ante usted por las partes involucradas una vez que hayan sido desarmadas todas y cada una de las piezas dañadas.');
        }

        $this->encabezadoParte($section, 'XV.-', 'OBSERVACIONES:');
        $this->parrafoParte($section, $this->observacionesGruas($d['vehiculos']));
        $this->parrafoParte($section, 'De lo anteriormente expuesto y formulado se llega a las siguientes:');
        $this->texto($section, 'CONCLUSIONES:', ['bold' => true, 'size' => 16], ['alignment' => Jc::CENTER, 'spaceBefore' => 420, 'spaceAfter' => 220]);
        $this->parrafoParte($section, $this->conclusionCausaParte($d));
        $this->parrafoParte($section, $this->conclusionDisposicionParte($d));
        $this->firmaParte($section, $d);
    }

    private function agregarIph(PhpWord $phpWord, array $d): void
    {
        $section = $this->seccion($phpWord, 'letter');
        $this->iphPortada($section, $d);

        $section = $this->seccion($phpWord, 'letter');
        $this->iphPrimerRespondiente($section, $d);

        $section = $this->seccion($phpWord, 'letter');
        $this->iphCroquisInspeccion($section, $d);

        $section = $this->seccion($phpWord, 'letter');
        $this->iphNarrativa($section, $d);

        foreach ($d['vehiculos'] as $i => $vehiculo) {
            $section = $this->seccion($phpWord, 'letter');
            $this->iphVehiculo($section, $d, $vehiculo, $i);
        }
    }

    private function agregarCadenaCustodia(PhpWord $phpWord, array $d): void
    {
        $section = $this->seccion($phpWord, 'letter');
        $this->cadenaRegistro($section, $d);

        $section = $this->seccion($phpWord, 'letter');
        $this->cadenaEntregaRecepcion($section, $d);
    }

    private function membreteParte($section, array $d): void
    {
        $membrete = $this->imagenMembreteParte($d);

        if ($membrete) {
            $this->addImageFit($section, $membrete, 535, 165, Jc::CENTER);
        }

        $this->texto($section, $this->municipioFecha($d['municipio']) . ' Michoacán a ' . $d['fecha_encabezado'] . '.', ['size' => 12], [
            'alignment' => Jc::RIGHT,
            'spaceBefore' => 90,
            'spaceAfter' => 220,
        ]);
    }

    private function imagenMembreteParte(array $d): ?string
    {
        $unidadId = (int) ($d['unidad_id'] ?? 0);
        $archivo = $unidadId === 2 ? 'encabezado2.png' : 'encabezado1.png';
        $path = public_path('img/' . $archivo);

        if (is_file($path)) {
            return $path;
        }

        return null;
    }

    private function municipioFecha(string $municipio): string
    {
        return str_ireplace('Lazaro Cardenas', 'Lazaro Cárdenas', $municipio);
    }

    private function nombreOficina(int $unidadId, string $unidadNombre): string
    {
        $nombre = mb_strtoupper($this->plain($unidadNombre), 'UTF-8');

        if ($unidadId === 1 || str_contains($nombre, 'SINIESTROS')) {
            return 'Unidad de Atención a Siniestros';
        }

        if ($unidadId === 2 || str_contains($nombre, 'DELEGACIONES')) {
            return 'Unidad de Delegaciones';
        }

        if ($unidadId === 3 || str_contains($nombre, 'SEGURIDAD VIAL')) {
            return 'Agrupamiento de Seguridad Vial';
        }

        if ($unidadId === 4 || str_contains($nombre, 'CARRETERAS')) {
            return 'División de Seguridad en Carreteras';
        }

        if ($unidadId === 5 || str_contains($nombre, 'VIALIDADES URBANAS')) {
            return 'División de Seguridad en Vialidades Urbanas';
        }

        if ($unidadId === 6 || str_contains($nombre, 'CULTURA VIAL')) {
            return 'Dirección de Fomento a la Cultura Vial';
        }

        return $unidadNombre !== '' ? $this->title($unidadNombre) : 'Unidad de Atención a Siniestros';
    }

    private function lineasAutoridadParte(string $autoridad): array
    {
        $autoridad = trim(preg_replace('/\s+/', ' ', $this->plain($autoridad)));

        if ($autoridad === '') {
            return [];
        }

        $pos = mb_stripos($autoridad, ' FISCAL', 0, 'UTF-8');

        if ($pos !== false) {
            return [
                trim(mb_substr($autoridad, 0, $pos, 'UTF-8')),
                trim(mb_substr($autoridad, $pos + 1, null, 'UTF-8')),
            ];
        }

        return explode("\n", wordwrap($autoridad, 54, "\n", false));
    }

    private function iphPortada($section, array $d): void
    {
        $this->texto($section, $d['municipio_mayus'] . ' - ' . $d['municipio_mayus'], ['bold' => true, 'size' => 10], ['alignment' => Jc::CENTER, 'spaceAfter' => 20]);
        $this->iphEncabezadoOficial($section, $d);

        $title = $section->addTextRun(['alignment' => Jc::CENTER, 'spaceBefore' => 150, 'spaceAfter' => 35]);
        $title->addText('INFORME POLICIAL HOMOLOGADO (IPH', ['bold' => true, 'size' => 12]);
        $title->addText('2019', ['bold' => true, 'size' => 8, 'subScript' => true]);
        $title->addText(')', ['bold' => true, 'size' => 12]);
        $this->barra($section, 'HECHO PROBABLEMENTE DELICTIVO', self::CREAM, '000000');
        $this->texto($section, 'SECCIÓN 1. PUESTA A DISPOSICIÓN', ['bold' => true, 'size' => 9], ['spaceBefore' => 120, 'spaceAfter' => 25]);
        $this->barra($section, 'Apartado 1.1. Fecha y hora de la puesta a disposición.', self::CREAM, '000000', true);
        $this->iphFechaHoraPuesta($section, $d);
        $this->iphAnexosPuesta($section, $d);
        $this->iphPersonaLineas($section, 'Datos de quien realiza la puesta a disposición', $this->partesPoliciaIph($d), [
            'Adscripción:' => $d['adscripcion'],
            'Cargo/grado:' => 'POLICÍA',
            'Firma:' => '',
        ]);
        $this->iphPersonaLineas($section, 'Fiscal/Autoridad que recibe la puesta a disposición', $this->partesNombreIph(''), [
            'Fiscalía/Autoridad:' => $d['autoridad_portada_iph'],
            'Cargo:' => '',
            'Firma:' => '',
        ]);
    }

    private function iphPrimerRespondiente($section, array $d): void
    {
        $nombre = $this->partesPoliciaIph($d);

        $this->texto($section, 'SECCIÓN 2. PRIMER RESPONDIENTE.', ['bold' => true, 'size' => 9], ['spaceAfter' => 45]);
        $this->barra($section, 'Apartado 2.1. Datos de identificación', self::CREAM, '000000', true);

        $nombres = $section->addTable([
            'borderSize' => 6,
            'borderColor' => '000000',
            'cellMargin' => 0,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'width' => self::CONTENT_W,
            'unit' => TblWidth::TWIP,
        ]);
        $nombres->addRow(620);
        foreach ([
            [$nombre['primer_apellido'], 'Primer apellido'],
            [$nombre['segundo_apellido'], 'Segundo apellido'],
            [$nombre['nombres'], 'Nombre (s)'],
        ] as [$valor, $etiqueta]) {
            $cell = $nombres->addCell(3702, ['valign' => 'center']);
            $cell->addText($valor, ['bold' => true, 'size' => 10], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
            $cell->addText($etiqueta, ['bold' => true, 'size' => 7], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }

        $tabla = $section->addTable([
            'borderSize' => 6,
            'borderColor' => '000000',
            'cellMargin' => 0,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'width' => self::CONTENT_W,
            'unit' => TblWidth::TWIP,
        ]);
        $tabla->addRow(260);
        $tabla->addCell(self::CONTENT_W, ['gridSpan' => 3])
            ->addText('Seleccione con una "X" la institución a la que pertenece, así como la entidad federativa o municipio de adscripción.', ['bold' => true, 'size' => 8], $this->p0());

        $tabla->addRow(920);
        $cell = $tabla->addCell(2750, ['valign' => 'center']);
        $cell->addText('[    ] Guardia Nacional', ['bold' => true, 'size' => 8], ['spaceAfter' => 0]);
        $cell->addText('[    ] Policía Federal Ministerial', ['bold' => true, 'size' => 8], ['spaceAfter' => 0]);
        $cell = $tabla->addCell(3000, ['valign' => 'center']);
        $cell->addText('[    ] Policía Ministerial', ['bold' => true, 'size' => 8], ['spaceAfter' => 0]);
        $cell->addText('[    ] Policía Mando Único', ['bold' => true, 'size' => 8], ['spaceAfter' => 0]);
        $cell->addText('[ X ] Policía Estatal', ['bold' => true, 'size' => 8], ['spaceAfter' => 0]);
        $cell->addText('Otra autoridad:', ['bold' => true, 'size' => 8], ['spaceAfter' => 0]);
        $adscripcion = $tabla->addCell(5356, ['valign' => 'center']);
        $adscripcion->addText('________________________________________', ['size' => 7], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $adscripcion->addText($d['adscripcion'], ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $adscripcion->addText('________________________________________', ['size' => 7], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);

        $tabla->addRow(360);
        $tabla->addCell(4300, ['valign' => 'center'])
            ->addText('¿Cuál es su grado o cargo?', ['bold' => true, 'size' => 8], $this->p0());
        $tabla->addCell(6806, ['gridSpan' => 2, 'valign' => 'center'])
            ->addText('POLICÍA', ['bold' => true, 'size' => 8], $this->p0());

        $tabla->addRow(360);
        $tabla->addCell(4300, ['valign' => 'center'])
            ->addText('¿En qué unidad arribó al lugar de intervención?', ['bold' => true, 'size' => 8], $this->p0());
        $tabla->addCell(6806, ['gridSpan' => 2, 'valign' => 'center'])
            ->addText($d['unidad_arribo'], ['bold' => true, 'size' => 8], $this->p0());

        $tabla->addRow(360);
        $tabla->addCell(4300, ['valign' => 'center'])
            ->addText('¿Arribó más de un elemento al lugar de la intervención?', ['bold' => true, 'size' => 8], $this->p0());
        $tabla->addCell(6806, ['gridSpan' => 2, 'valign' => 'center'])
            ->addText('Sí [    ]     ¿Cuántos?  ___ ___ ___        No [ X ]', ['bold' => true, 'size' => 8], $this->p0());

        $this->iphConocimientoSeguimiento($section, $d);
        $this->iphLugarIntervencion($section, $d);
    }

    private function iphLugarIntervencion($section, array $d): void
    {
        $ubicacion = $d['ubicacion_iph'] ?? [];

        $this->texto($section, 'SECCIÓN 4. LUGAR DE LA INTERVENCIÓN', ['bold' => true, 'size' => 9], ['spaceBefore' => 160, 'spaceAfter' => 45]);
        $this->barra($section, 'Apartado 4.1 Ubicación geográfica', self::CREAM, '000000', true);

        $tabla = $section->addTable([
            'borderSize' => 0,
            'borderColor' => '000000',
            'cellMargin' => 45,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'width' => self::CONTENT_W,
            'unit' => TblWidth::TWIP,
        ]);

        $this->iphLugarLinea($tabla, 'Calle/Tramo carretero:', $ubicacion['calle_tramo'] ?? '');
        $this->iphLugarLineaMultiple($tabla, [
            ['No. exterior', $ubicacion['no_exterior'] ?? ''],
            ['No. interior:', $ubicacion['no_interior'] ?? ''],
            ['Código Postal:', $ubicacion['codigo_postal'] ?? ''],
        ]);
        $this->iphLugarLinea($tabla, 'Colonia/Localidad:', $ubicacion['colonia_localidad'] ?? '');
        $this->iphLugarLinea($tabla, 'Municipio/Demarcación territorial:', $ubicacion['municipio'] ?? '');
        $this->iphLugarLinea($tabla, 'Entidad federativa:', $ubicacion['entidad'] ?? '');
        $this->iphLugarLinea($tabla, 'Referencias:', $ubicacion['referencias'] ?? '');
        $this->iphLugarCoordenadas($tabla, $ubicacion['latitud'] ?? '', $ubicacion['longitud'] ?? '');
    }

    private function iphLugarLinea($tabla, string $label, string $value): void
    {
        $tabla->addRow(360);
        $cell = $tabla->addCell(self::CONTENT_W, [
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
            'borderRightSize' => 6,
            'borderRightColor' => '000000',
            'borderBottomSize' => 6,
            'borderBottomColor' => '000000',
            'valign' => 'center',
        ]);
        $run = $cell->addTextRun($this->p0());
        $run->addText($label . '   ', ['bold' => true, 'size' => 7]);
        $run->addText($value, ['bold' => true, 'size' => 8]);
    }

    private function iphLugarLineaMultiple($tabla, array $fields): void
    {
        $tabla->addRow(360);
        $cell = $tabla->addCell(self::CONTENT_W, [
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
            'borderRightSize' => 6,
            'borderRightColor' => '000000',
            'borderBottomSize' => 6,
            'borderBottomColor' => '000000',
            'valign' => 'center',
        ]);
        $run = $cell->addTextRun($this->p0());

        foreach (array_values($fields) as $index => $field) {
            [$label, $value] = $field + ['', ''];
            $run->addText($label . '   ', ['bold' => true, 'size' => 7]);
            $run->addText($value, ['bold' => true, 'size' => 8]);

            if ($index < count($fields) - 1) {
                $run->addText('          ', ['size' => 8]);
            }
        }
    }

    private function iphLugarCoordenadas($tabla, string $latitud, string $longitud): void
    {
        $tabla->addRow(430);
        $cell = $tabla->addCell(self::CONTENT_W, [
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
            'borderRightSize' => 6,
            'borderRightColor' => '000000',
            'borderBottomSize' => 6,
            'borderBottomColor' => '000000',
            'valign' => 'center',
        ]);
        $run = $cell->addTextRun($this->p0());
        $run->addText('Anote las coordenadas geográficas   ', ['italic' => true, 'size' => 7]);
        $run->addText('Latitud   ', ['bold' => true, 'size' => 7]);
        $run->addText($latitud, ['bold' => true, 'size' => 8]);
        $run->addText('          ', ['size' => 8]);
        $run->addText('Longitud:   ', ['bold' => true, 'size' => 7]);
        $run->addText($longitud, ['bold' => true, 'size' => 8]);
    }

    private function iphConocimientoSeguimiento($section, array $d): void
    {
        $this->texto($section, 'SECCIÓN 3. CONOCIMIENTO DEL HECHO Y SEGUIMIENTO DE LA ACTUACIÓN DE LA AUTORIDAD', ['bold' => true, 'size' => 9], ['spaceBefore' => 160, 'spaceAfter' => 45]);
        $this->barra($section, 'Apartado 3.1 Conocimiento del hecho por el primer respondiente', self::CREAM, '000000', true);

        $tabla = $section->addTable([
            'borderSize' => 0,
            'borderColor' => '000000',
            'cellMargin' => 45,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'width' => self::CONTENT_W,
            'unit' => TblWidth::TWIP,
        ]);

        $tabla->addRow(260);
        $tabla->addCell(self::CONTENT_W, [
            'gridSpan' => 4,
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
            'borderRightSize' => 6,
            'borderRightColor' => '000000',
        ])->addText('¿Cómo se enteró del hecho?', ['bold' => true, 'size' => 8], $this->p0());

        $tabla->addRow(330);
        $this->iphOpcionConocimiento($tabla, 'Denuncia', false, 2600, false);
        $this->iphOpcionConocimiento($tabla, 'Flagrancia', false, 2600, false);
        $this->iphOpcionConocimiento($tabla, 'Localización', false, 2600, false);
        $this->iphOpcionConocimiento($tabla, 'Mandamiento judicial', false, 3300, true);

        $tabla->addRow(330);
        $this->iphOpcionConocimiento($tabla, 'Llamada de emergencia', true, 2600, false);
        $this->iphOpcionConocimiento($tabla, 'Descubrimiento', false, 2600, false);
        $this->iphOpcionConocimiento($tabla, 'Aportación', false, 2600, false);
        $this->iphOpcionConocimiento($tabla, '', false, 3300, true);

        $tabla->addRow(370);
        $cell = $tabla->addCell(self::CONTENT_W, [
            'gridSpan' => 4,
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
            'borderRightSize' => 6,
            'borderRightColor' => '000000',
            'borderBottomSize' => 6,
            'borderBottomColor' => '000000',
            'valign' => 'center',
        ]);
        $run = $cell->addTextRun($this->p0());
        $run->addText('911 No.   ', ['bold' => true, 'size' => 8]);
        $run->addText($this->celdasTextoIph($d['folio'] ?? '', 18), ['bold' => true, 'size' => 8]);
        $run->addText('       Sólo en caso de contar con él.', ['bold' => true, 'italic' => true, 'size' => 7]);

        $this->barra($section, 'Apartado 3.2 Seguimiento de la actuación de la autoridad', self::CREAM, '000000', true);

        $seguimiento = $section->addTable([
            'borderSize' => 6,
            'borderColor' => '000000',
            'cellMargin' => 70,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'width' => self::CONTENT_W,
            'unit' => TblWidth::TWIP,
        ]);
        $seguimiento->addRow(260);
        $seguimiento->addCell(self::CONTENT_W, ['gridSpan' => 2])
            ->addText('Indique la fecha y hora en cada recuadro.', ['italic' => true, 'size' => 8], $this->p0());

        $seguimiento->addRow(1320);
        $conocimiento = $d['conocimiento'] ?? null;
        $conocimientoFecha = $conocimiento ? $conocimiento->format('Y-m-d') : ($d['fecha_hecho'] ?? null);
        $conocimientoHora = $conocimiento ? $conocimiento->format('H:i') : ($d['hora_hecho'] ?? '');
        $this->iphSeguimientoFechaHora($seguimiento->addCell(5550, ['valign' => 'center']), 'Conocimiento del hecho', $conocimientoFecha, $conocimientoHora);
        $arriboFecha = $d['arribo'] ? $d['arribo']->format('Y-m-d') : null;
        $arriboHora = $d['arribo'] ? $d['arribo']->format('H:i') : '';
        $this->iphSeguimientoFechaHora($seguimiento->addCell(5550, ['valign' => 'center']), 'Arribo al lugar', $arriboFecha, $arriboHora);
    }

    private function iphOpcionConocimiento($tabla, string $label, bool $checked, int $width, bool $edge): void
    {
        $style = ['valign' => 'center'];

        if ($edge) {
            $style['borderRightSize'] = 6;
            $style['borderRightColor'] = '000000';
        }

        if ($label === 'Denuncia' || $label === 'Llamada de emergencia') {
            $style['borderLeftSize'] = 6;
            $style['borderLeftColor'] = '000000';
        }

        $text = $label === '' ? '' : $label . '   ' . $this->checkIph($checked);
        $tabla->addCell($width, $style)
            ->addText($text, ['bold' => true, 'size' => 8], $this->p0());
    }

    private function iphSeguimientoFechaHora($cell, string $titulo, ?string $fecha, string $hora): void
    {
        $fechaPartes = $fecha ? $this->fechaPartesIph($fecha) : ['dia' => '', 'mes' => '', 'anio' => ''];
        $horaPartes = preg_match('/^(\d{2}):(\d{2})/', $hora, $matches)
            ? ['hora' => $matches[1], 'minuto' => $matches[2]]
            : ['hora' => '', 'minuto' => ''];

        $cell->addText($titulo, ['bold' => true, 'italic' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 80]);
        $cell->addText('Fecha:  ' . $this->celdasTextoIph($fechaPartes['dia'] . $fechaPartes['mes'] . $fechaPartes['anio'], 8), ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 35]);
        $cell->addText('        D   D   M   M   A   A   A   A', ['bold' => true, 'size' => 6], ['alignment' => Jc::CENTER, 'spaceAfter' => 80]);
        $cell->addText('Hora:   ' . $this->celdasTextoIph($horaPartes['hora'], 2) . ' : ' . $this->celdasTextoIph($horaPartes['minuto'], 2) . '   (24 horas)', ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 35]);
        $cell->addText('         h   h          m   m', ['bold' => true, 'size' => 6], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
    }

    private function checkIph(bool $checked): string
    {
        return $checked ? '[ X ]' : '[    ]';
    }

    private function celdasTextoIph($value, int $length): string
    {
        return collect($this->charsForBoxes($value, $length))
            ->map(fn ($char) => '[ ' . ($char !== '' ? $char : ' ') . ' ]')
            ->implode(' ');
    }

    private function celdasTextoCompactas($value, int $length): string
    {
        return collect($this->charsForBoxes($value, $length))
            ->map(fn ($char) => '[ ' . ($char !== '' ? $char : ' ') . ' ]')
            ->implode('');
    }

    private function iphCroquisInspeccion($section, array $d): void
    {
        $this->barra($section, 'Croquis del lugar', self::CREAM, '000000', true);
        $this->imagenEnMarco($section, $d['croquis'], 590, 470, '');
        $this->iphInspeccionLugar($section, $d);
    }

    private function iphInspeccionLugar($section, array $d): void
    {
        $objetos = !empty($d['objetos']);

        $this->barra($section, 'Apartado 4.2 Inspección del lugar', self::CREAM, '000000', true);

        $tabla = $section->addTable([
            'borderSize' => 0,
            'borderColor' => '000000',
            'cellMargin' => 60,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'width' => self::CONTENT_W,
            'unit' => TblWidth::TWIP,
        ]);

        $this->iphInspeccionPregunta($tabla, '¿Realizó la inspección del lugar?', true, false);
        $this->iphInspeccionPregunta(
            $tabla,
            'Al momento de realizar la inspección del lugar, ¿encontró algún objeto relacionado con los hechos?',
            $objetos,
            !$objetos,
            'Llene el anexo D'
        );
        $this->iphInspeccionPregunta($tabla, '¿Preservó el lugar de la intervención?', false, true);
        $this->iphInspeccionPregunta($tabla, '¿Llevó a cabo la priorización en el lugar de la intervención?', true, false);

        $riesgo = $section->addTable([
            'borderSize' => 0,
            'borderColor' => '000000',
            'cellMargin' => 60,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'width' => self::CONTENT_W,
            'unit' => TblWidth::TWIP,
        ]);

        $riesgo->addRow(360);
        $cell = $riesgo->addCell(self::CONTENT_W, [
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
            'borderRightSize' => 6,
            'borderRightColor' => '000000',
            'valign' => 'center',
        ]);
        $run = $cell->addTextRun($this->p0());
        $run->addText('Tipo de riesgo presentado:        ', ['bold' => true, 'size' => 8]);
        $run->addText('Sociales ' . $this->checkIph(true), ['size' => 8]);
        $run->addText('                         ', ['size' => 8]);
        $run->addText('Naturales ' . $this->checkIph(false), ['size' => 8]);

        $riesgo->addRow(520);
        $cell = $riesgo->addCell(self::CONTENT_W, [
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
            'borderRightSize' => 6,
            'borderRightColor' => '000000',
            'borderBottomSize' => 6,
            'borderBottomColor' => '000000',
            'valign' => 'center',
        ]);
        $run = $cell->addTextRun($this->p0());
        $run->addText('Especifique:        ', ['bold' => true, 'size' => 8]);
        $run->addText($this->especificacionRiesgoIph($d), ['italic' => true, 'size' => 8]);
    }

    private function iphInspeccionPregunta($tabla, string $pregunta, bool $si, bool $no, string $notaSi = ''): void
    {
        $tabla->addRow(340);
        $tabla->addCell(7900, [
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
            'valign' => 'center',
        ])->addText($pregunta, ['bold' => true, 'size' => 8], $this->p0());

        $siCell = $tabla->addCell(1850, ['valign' => 'center']);
        $siRun = $siCell->addTextRun(['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $siRun->addText('Sí ' . $this->checkIph($si), ['size' => 8]);

        if ($notaSi !== '') {
            $siRun->addText(' ' . $notaSi, ['italic' => true, 'size' => 7]);
        }

        $tabla->addCell(1356, [
            'borderRightSize' => 6,
            'borderRightColor' => '000000',
            'valign' => 'center',
        ])->addText('No ' . $this->checkIph($no), ['size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
    }

    private function especificacionRiesgoIph(array $d): string
    {
        $ubicacion = $d['ubicacion_iph'] ?? [];
        $partes = array_filter([
            $ubicacion['calle_tramo'] ?? null,
            $ubicacion['referencias'] ?? null,
        ], fn ($valor) => trim((string) $valor) !== '');

        $texto = trim(implode(', ', $partes));

        return $texto !== '' ? $texto : 'VÍA DE CIRCULACIÓN EN EL LUGAR DE INTERVENCIÓN';
    }

    private function iphNarrativa($section, array $d): void
    {
        $this->texto($section, 'SECCIÓN 5. NARRATIVA DE LOS HECHOS', ['bold' => true, 'size' => 11], ['alignment' => Jc::CENTER, 'spaceAfter' => 40]);
        $this->barra($section, 'Apartado 5.1 Descripción de los hechos y actuación de la autoridad', self::CREAM, '000000', true);
        $tabla = $section->addTable('FormTable');
        $tabla->addRow();
        $cell = $tabla->addCell(11100);

        foreach ($this->narrativaIphParrafos($d) as $parrafo) {
            $cell->addText($parrafo, ['size' => 10], ['alignment' => Jc::BOTH, 'spaceAfter' => 130]);
        }
    }

    private function iphVehiculo($section, array $d, array $vehiculo, int $i): void
    {
        $numeroVehiculo = str_pad((string) ($i + 1), 3, '0', STR_PAD_LEFT);
        $fechaInspeccion = $d['arribo'] ? $d['arribo']->format('Y-m-d') : ($d['fecha_hecho'] ?? null);
        $fechaPartes = $fechaInspeccion ? $this->fechaPartesIph($fechaInspeccion) : ['dia' => '', 'mes' => '', 'anio' => ''];
        $horaInspeccion = $d['arribo'] ? $d['arribo']->format('H:i') : substr((string) ($d['hora_hecho'] ?? ''), 0, 5);
        $horaPartes = preg_match('/^(\d{2}):(\d{2})/', $horaInspeccion, $matches)
            ? ['hora' => $matches[1], 'minuto' => $matches[2]]
            : ['hora' => '', 'minuto' => ''];
        $tipo = $this->tipoInspeccionVehiculo($vehiculo);
        $procedencia = $this->procedenciaInspeccionVehiculo($vehiculo);
        $servicio = $this->servicioInspeccionVehiculo($vehiculo);
        $placas = preg_replace('/\s+/', '', mb_strtoupper($this->clean($vehiculo['placas'] ?? ''), 'UTF-8')) ?: '';
        $serie = preg_replace('/\s+/', '', mb_strtoupper($this->clean($vehiculo['serie'] ?? ''), 'UTF-8')) ?: '';

        $this->texto($section, 'ANEXO C. INSPECCIÓN DE VEHÍCULO', ['bold' => true, 'size' => 11], ['alignment' => Jc::CENTER, 'spaceAfter' => 20]);
        $this->texto($section, 'Llene este Anexo por cada vehículo inspeccionado', ['bold' => true, 'size' => 8], ['alignment' => Jc::LEFT, 'spaceAfter' => 45]);

        $tabla = $section->addTable([
            'borderSize' => 6,
            'borderColor' => '000000',
            'cellMargin' => 45,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'width' => self::CONTENT_W,
            'unit' => TblWidth::TWIP,
        ]);

        $this->iphVehiculoFilaCompleta($tabla, 'Vehículo:  ' . $this->celdasTextoCompactas($numeroVehiculo, 3) . '     (001, 002, ..., 010, ...)', 330, ['bold' => true, 'size' => 8], ['bgColor' => self::CREAM]);
        $this->iphVehiculoFilaCompleta($tabla, 'Apartado C.1 Fecha y hora de la inspección', 310, ['bold' => true, 'size' => 8], ['bgColor' => self::CREAM]);
        $this->iphVehiculoFilaCompleta($tabla, 'Indique la fecha y la hora en que realizó la inspección', 250, ['italic' => true, 'size' => 7]);

        $tabla->addRow(620);
        $fechaCell = $tabla->addCell(5553, ['gridSpan' => 2, 'valign' => 'center']);
        $fechaCell->addText('Fecha:   ' . $this->celdasTextoCompactas($fechaPartes['dia'] . $fechaPartes['mes'] . $fechaPartes['anio'], 8), ['bold' => true, 'size' => 8], $this->p0());
        $fechaCell->addText('             D   D   M   M   A   A   A   A', ['bold' => true, 'size' => 5], $this->p0());
        $horaCell = $tabla->addCell(5553, ['gridSpan' => 2, 'valign' => 'center']);
        $horaCell->addText('Hora:    ' . $this->celdasTextoCompactas($horaPartes['hora'], 2) . ' : ' . $this->celdasTextoCompactas($horaPartes['minuto'], 2), ['bold' => true, 'size' => 8], $this->p0());
        $horaCell->addText('             h   h        m   m', ['bold' => true, 'size' => 5], $this->p0());

        $this->iphVehiculoFilaCompleta($tabla, 'Apartado C.2 Datos generales del vehículo inspeccionado', 310, ['bold' => true, 'size' => 8], ['bgColor' => self::CREAM]);

        $tabla->addRow(620);
        $tabla->addCell(5553, ['gridSpan' => 2, 'valign' => 'center'])
            ->addText('Tipo:   ' . $this->checkIph($tipo['terrestre']) . ' Terrestre      ' . $this->checkIph($tipo['acuatico']) . ' Acuático      ' . $this->checkIph($tipo['aereo']) . ' Aéreo', ['bold' => true, 'size' => 8], $this->p0());
        $tabla->addCell(5553, ['gridSpan' => 2, 'valign' => 'center'])
            ->addText('Procedencia:   ' . $this->checkIph($procedencia['nacional']) . ' Nacional      ' . $this->checkIph($procedencia['extranjero']) . ' Extranjero', ['bold' => true, 'size' => 8], $this->p0());

        $tabla->addRow(600);
        $this->iphVehiculoCampo($tabla->addCell(2776, ['valign' => 'center']), 'Marca', $vehiculo['marca'] ?? '');
        $this->iphVehiculoCampo($tabla->addCell(2776, ['valign' => 'center']), 'Submarca', $vehiculo['linea'] ?? '');
        $this->iphVehiculoCampo($tabla->addCell(2776, ['valign' => 'center']), 'Modelo', $vehiculo['modelo'] ?? '');
        $this->iphVehiculoCampo($tabla->addCell(2778, ['valign' => 'center']), 'Color', $vehiculo['color'] ?? '');

        $tabla->addRow(540);
        $tabla->addCell(self::CONTENT_W, ['gridSpan' => 4, 'valign' => 'center'])
            ->addText('Uso:      ' . $this->checkIph($servicio['particular']) . ' Particular            ' . $this->checkIph($servicio['publico']) . ' Transporte público            ' . $this->checkIph($servicio['carga']) . ' Carga', ['bold' => true, 'size' => 8], $this->p0());

        $tabla->addRow(470);
        $placasCell = $tabla->addCell(self::CONTENT_W, ['gridSpan' => 4, 'valign' => 'center']);
        $placasCell->addText('Placa/Matrícula:   ' . $this->celdasTextoIph($placas, max(8, mb_strlen($placas, 'UTF-8'))), ['bold' => true, 'size' => 8], $this->p0());
        $tabla->addRow(470);
        $serieCell = $tabla->addCell(self::CONTENT_W, ['gridSpan' => 4, 'valign' => 'center']);
        $serieCell->addText('No. de serie:   ' . $this->celdasTextoIph($serie, max(17, mb_strlen($serie, 'UTF-8'))), ['bold' => true, 'size' => 7], $this->p0());

        $tabla->addRow(500);
        $tabla->addCell(self::CONTENT_W, ['gridSpan' => 4, 'valign' => 'center'])
            ->addText('Situación:   ' . $this->checkIph(false) . ' Con reporte de robo          ' . $this->checkIph(false) . ' Sin reporte de robo          ' . $this->checkIph(true) . ' No es posible saberlo', ['bold' => true, 'size' => 8], $this->p0());

        $tabla->addRow(980);
        $observaciones = $tabla->addCell(self::CONTENT_W, ['gridSpan' => 4, 'valign' => 'top']);
        $observaciones->addText('Observaciones:', ['bold' => true, 'size' => 7], $this->p0());
        $observaciones->addText(mb_strtoupper($this->daniosInspeccion($vehiculo, $i), 'UTF-8'), ['bold' => true, 'size' => 8], ['alignment' => Jc::BOTH, 'spaceAfter' => 0]);

        $tabla->addRow(860);
        $destino = $tabla->addCell(self::CONTENT_W, ['gridSpan' => 4, 'valign' => 'top']);
        $destino->addText('Destino que se le dio:', ['bold' => true, 'size' => 7], $this->p0());
        $destino->addText(mb_strtoupper($this->destinoVehiculo($vehiculo), 'UTF-8'), ['bold' => true, 'size' => 8], ['alignment' => Jc::BOTH, 'spaceAfter' => 0]);

        $this->iphVehiculoFilaCompleta($tabla, 'Apartado C.3 Objetos encontrados en el vehículo inspeccionado', 300, ['bold' => true, 'size' => 8], ['bgColor' => self::CREAM]);
        $this->iphVehiculoFilaCompleta($tabla, '¿Encontró objetos relacionados con los hechos?      Sí ' . $this->checkIph(false) . '    Llene el apartado D             No ' . $this->checkIph(true), 360, ['bold' => true, 'size' => 8]);

        $firmas = $section->addTable([
            'borderSize' => 6,
            'borderColor' => '000000',
            'cellMargin' => 45,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'width' => self::CONTENT_W,
            'unit' => TblWidth::TWIP,
        ]);
        $firmas->addRow(300);
        $firmas->addCell(self::CONTENT_W, ['gridSpan' => 3, 'bgColor' => self::CREAM, 'valign' => 'center'])
            ->addText('Apartado C.4 Datos del primer respondiente que realizó la inspección, sólo si es diferente a quien firmó la puesta a disposición', ['bold' => true, 'size' => 7], $this->p0());
        $firmas->addRow(740);
        $this->iphVehiculoFirmaNombre($firmas->addCell(3702, ['valign' => 'bottom']), '', 'Primer apellido');
        $this->iphVehiculoFirmaNombre($firmas->addCell(3702, ['valign' => 'bottom']), '', 'Segundo apellido');
        $this->iphVehiculoFirmaNombre($firmas->addCell(3702, ['valign' => 'bottom']), '', 'Nombre(s)');

        $firmas->addRow(640);
        $this->iphVehiculoFirmaMeta($firmas->addCell(3702, ['valign' => 'bottom']), 'Adscripción', '');
        $this->iphVehiculoFirmaMeta($firmas->addCell(3702, ['valign' => 'bottom']), 'Cargo/grado', '');
        $this->iphVehiculoFirmaMeta($firmas->addCell(3702, ['valign' => 'bottom']), 'Firma', '');
    }

    private function iphVehiculoFilaCompleta($tabla, string $text, int $height, array $font = [], array $cellStyle = []): void
    {
        $tabla->addRow($height);
        $tabla->addCell(self::CONTENT_W, array_merge(['gridSpan' => 4, 'valign' => 'center'], $cellStyle))
            ->addText($text, array_merge(['size' => 8], $font), $this->p0());
    }

    private function iphVehiculoCampo($cell, string $label, $value): void
    {
        $cell->addText($label . ':', ['bold' => true, 'size' => 7], $this->p0());
        $cell->addText(mb_strtoupper($this->clean($value) ?: '', 'UTF-8'), ['bold' => true, 'size' => 8], $this->p0());
    }

    private function iphVehiculoFirmaNombre($cell, string $value, string $label): void
    {
        $cell->addText(mb_strtoupper($this->clean($value) ?: '', 'UTF-8'), ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $cell->addText('________________________', ['size' => 7], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $cell->addText($label, ['bold' => true, 'size' => 6], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
    }

    private function iphVehiculoFirmaMeta($cell, string $label, string $value): void
    {
        $run = $cell->addTextRun($this->p0());
        $run->addText($label . ': ', ['bold' => true, 'size' => 7]);
        $run->addText(mb_strtoupper($this->clean($value) ?: '____________________', 'UTF-8'), ['bold' => true, 'size' => 7]);
    }

    private function tipoInspeccionVehiculo(array $vehiculo): array
    {
        $tipo = $this->normalizarClaveIph($vehiculo['tipo'] ?? '');

        return [
            'terrestre' => !str_contains($tipo, 'ACUATIC') && !str_contains($tipo, 'AERE'),
            'acuatico' => str_contains($tipo, 'ACUATIC'),
            'aereo' => str_contains($tipo, 'AERE'),
        ];
    }

    private function procedenciaInspeccionVehiculo(array $vehiculo): array
    {
        $estado = $this->normalizarClaveIph($vehiculo['estado_placas'] ?? '');
        $extranjero = str_contains($estado, 'EXTRANJ') || str_contains($estado, 'EXTERIOR');

        return [
            'nacional' => !$extranjero,
            'extranjero' => $extranjero,
        ];
    }

    private function servicioInspeccionVehiculo(array $vehiculo): array
    {
        $texto = $this->normalizarClaveIph(($vehiculo['tipo_servicio'] ?? '') . ' ' . ($vehiculo['tipo'] ?? ''));
        $carga = str_contains($texto, 'CARGA')
            || str_contains($texto, 'CAMION')
            || str_contains($texto, 'TRACTO')
            || str_contains($texto, 'REMOLQUE');
        $publico = !$carga && (
            str_contains($texto, 'PUBLIC')
            || str_contains($texto, 'FEDERAL')
            || str_contains($texto, 'TAXI')
            || str_contains($texto, 'URBANO')
        );

        return [
            'particular' => !$carga && !$publico,
            'publico' => $publico,
            'carga' => $carga,
        ];
    }

    private function cadenaRegistro($section, array $d): void
    {
        $this->texto($section, 'Registro de Cadena de Custodia', ['bold' => true, 'size' => 16], ['spaceAfter' => 40]);
        $this->texto($section, '+No. de referencia: ' . $d['folio'], ['bold' => true, 'size' => 10], ['alignment' => Jc::RIGHT, 'spaceAfter' => 80]);
        $tabla = $section->addTable('FormTable');
        $tabla->addRow(420);
        foreach (['Institución o unidad administrativa', 'Folio o llamado', 'Lugar de intervención', 'Fecha y hora de intervención'] as $head) {
            $tabla->addCell(2775, ['bgColor' => self::GREEN])->addText($head, ['bold' => true, 'color' => 'FFFFFF', 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
        $tabla->addRow(1000);
        $tabla->addCell(2775)->addText($d['adscripcion'], ['bold' => true], $this->p0());
        $tabla->addCell(2775)->addText($d['folio'], ['bold' => true], $this->p0());
        $tabla->addCell(2775)->addText($d['ubicacion_cadena'], ['bold' => true, 'size' => 8], $this->p0());
        $tabla->addCell(2775)->addText($d['fecha_intervencion_cadena'] . "\n" . $d['hora_intervencion_cadena'] . ' HORAS', ['bold' => true], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $this->texto($section, 'Inicio de la cadena de custodia.  Localización X    Descubrimiento ___    Aportación ___', ['bold' => true, 'size' => 11], ['spaceBefore' => 360, 'spaceAfter' => 120]);
        $this->texto($section, '1. Identidad. Número, letra o combinación alfanumérica asignada al indicio o elemento material probatorio.', ['bold' => true], ['spaceAfter' => 80]);
        $tabla = $section->addTable('FormTable');
        $tabla->addRow(420);
        foreach ([2100 => ['Identificación'], 4400 => ['Descripción'], 3200 => ['Ubicación en el lugar'], 1400 => ['Hora de', 'recolección']] as $w => $head) {
            $cell = $tabla->addCell($w, ['bgColor' => self::GREEN]);
            foreach ($head as $line) {
                $cell->addText($line, ['bold' => true, 'color' => 'FFFFFF', 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0, 'lineHeight' => 1]);
            }
        }
        foreach ($d['vehiculos'] as $i => $vehiculo) {
            $tabla->addRow(1300);
            $tabla->addCell(2100)->addText('VEHÍCULO ' . $this->letraIndice($i), ['bold' => true], $this->p0());
            $tabla->addCell(4400)->addText($this->descripcionCadenaVehiculo($vehiculo, $i), ['bold' => true, 'size' => 8], $this->p0());
            $tabla->addCell(3200)->addText($d['ubicacion_cadena'], ['bold' => true, 'size' => 8], $this->p0());
            $tabla->addCell(1400)->addText($d['hora_recoleccion_cadena'] . "\nHORAS", ['bold' => true, 'size' => 8], $this->p0());
        }
        $this->texto($section, '5. Traslado. Vía: Terrestre X    Aérea ___    Marítima ___    Condiciones especiales para traslado: No X    Sí ___', ['bold' => true, 'size' => 9], ['spaceBefore' => 220, 'spaceAfter' => 120]);
        $this->texto($section, '6. Continuidad y trazabilidad.', ['bold' => true, 'size' => 11], ['spaceAfter' => 60]);
        $tabla = $section->addTable('FormTable');
        $tabla->addRow(420);
        foreach ([2300 => 'Fecha y hora de entrega recepción', 5000 => 'Nombre, institución y cargo o identificación de quien entrega', 2500 => 'Actividad/propósito', 1300 => 'Firma'] as $w => $head) {
            $tabla->addCell($w, ['bgColor' => self::GREEN])->addText($head, ['bold' => true, 'color' => 'FFFFFF', 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
        $tabla->addRow(900);
        $tabla->addCell(2300)->addText($d['fecha_intervencion_cadena'] . "\n" . $d['hora_recoleccion_cadena'] . ' HORAS', ['bold' => true, 'size' => 8], $this->p0());
        $tabla->addCell(5000)->addText($d['nombre_policia_mayus'] . "\n" . $d['adscripcion'] . '/POLICÍA ESTATAL', ['bold' => true, 'size' => 8], $this->p0());
        $tabla->addCell(2500)->addText('ENTREGA', ['bold' => true], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $tabla->addCell(1300)->addText('', [], $this->p0());
        $this->pieCadena($section, 'Registro de Cadena de Custodia');
    }

    private function cadenaEntregaRecepcion($section, array $d): void
    {
        $this->texto($section, 'ENTREGA-RECEPCIÓN DE LOS INDICIOS Y/O ELEMENTOS MATERIALES PROBATORIOS', ['size' => 8, 'underline' => 'single'], ['alignment' => Jc::RIGHT, 'spaceAfter' => 160]);
        $top = $section->addTable('Clean');
        $top->addRow();
        $top->addCell(6900)->addText('Entrega-recepción de Indicios o elementos materiales probatorios', ['bold' => true, 'size' => 15], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $top->addCell(4200)->addText('No. de referencia: ' . $d['folio'], ['bold' => true], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $tabla = $section->addTable('FormTable');
        $tabla->addRow(420);
        foreach ([2200 => 'Folio o llamado', 6500 => 'Lugar de la entrega-recepción', 2400 => 'Fecha y hora entrega/recepción'] as $w => $head) {
            $tabla->addCell($w, ['bgColor' => self::GREEN])->addText($head, ['bold' => true, 'color' => 'FFFFFF', 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
        $tabla->addRow(780);
        $tabla->addCell(2200)->addText($d['folio'], ['bold' => true], $this->p0());
        $tabla->addCell(6500)->addText($d['lugar_entrega'], ['bold' => true, 'size' => 13], $this->p0());
        $tabla->addCell(2400)->addText($d['fecha_intervencion_cadena'] . "\n" . $d['hora_recoleccion_cadena'] . ' HORAS', ['bold' => true, 'size' => 8], $this->p0());
        $this->texto($section, '1. Inventario. Escriba el número, letra o combinación alfanumérica con la que se identifica a cada indicio o elemento material probatorio que se entrega.', ['bold' => true, 'size' => 11], ['spaceBefore' => 220, 'spaceAfter' => 60]);
        $tabla = $section->addTable('FormTable');
        $tabla->addRow(420);
        $tabla->addCell(2500, ['bgColor' => self::GREEN])->addText('Identificación', ['bold' => true, 'color' => 'FFFFFF'], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $tabla->addCell(8600, ['bgColor' => self::GREEN])->addText('Descripción', ['bold' => true, 'color' => 'FFFFFF'], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        foreach ($d['vehiculos'] as $i => $vehiculo) {
            $tabla->addRow(900);
            $tabla->addCell(2500)->addText('VEHÍCULO ' . $this->letraIndice($i), ['bold' => true], $this->p0());
            $tabla->addCell(8600)->addText($this->descripcionCadenaVehiculo($vehiculo, $i), ['bold' => true, 'size' => 9], $this->p0());
        }
        for ($i = 0; $i < max(6 - count($d['vehiculos']), 2); $i++) {
            $tabla->addRow(480);
            $tabla->addCell(2500)->addText('', [], $this->p0());
            $tabla->addCell(8600)->addText('', [], $this->p0());
        }
        $this->texto($section, '2. Embalaje. Señale las condiciones en las que se encuentran los embalajes.', ['bold' => true, 'size' => 11], ['spaceBefore' => 220, 'spaceAfter' => 60]);
        $tabla = $section->addTable('FormTable');
        $tabla->addRow(1100);
        $tabla->addCell(11100)->addText('NO SE PUEDE POR SUS DIMENSIONES', ['bold' => true, 'size' => 13], $this->p0());
        $firmas = $section->addTable('FormTable');
        $firmas->addRow(330);
        $firmas->addCell(5350, ['bgColor' => self::GREEN])->addText('Persona que entrega', ['bold' => true, 'color' => 'FFFFFF'], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $firmas->addCell(400, ['borderSize' => 0])->addText('', [], $this->p0());
        $firmas->addCell(5350, ['bgColor' => self::GREEN])->addText('Persona que recibe', ['bold' => true, 'color' => 'FFFFFF'], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $firmas->addRow(1300);
        $firmas->addCell(5350)->addText($d['nombre_policia_mayus'] . "\n" . $d['adscripcion'] . "\nPOLICÍA ESTATAL", ['bold' => true, 'size' => 9], $this->p0());
        $firmas->addCell(400, ['borderSize' => 0])->addText('', [], $this->p0());
        $firmas->addCell(5350)->addText('', [], $this->p0());
        $firmas->addRow(300);
        $firmas->addCell(5350, ['bgColor' => self::GREEN])->addText('Nombre completo, institución, cargo y firma', ['bold' => true, 'color' => 'FFFFFF', 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $firmas->addCell(400, ['borderSize' => 0])->addText('', [], $this->p0());
        $firmas->addCell(5350, ['bgColor' => self::GREEN])->addText('Nombre completo, institución, cargo y firma', ['bold' => true, 'color' => 'FFFFFF', 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $this->pieCadena($section, 'Entrega-Recepción de indicios o elementos materiales probatorios');
    }

    private function referenciaSistema(array $d): string
    {
        return '16 PE 010 000 ' . str_replace('-', ' ', $this->fechaCorta($d['fecha_puesta'])) . ' HH MM';
    }

    private function referenciaIphGrupos(array $d): array
    {
        $fecha = $this->fechaPartesIph($d['fecha_puesta'] ?? null);

        return [
            ['label' => 'EDO', 'value' => '16', 'length' => 2, 'cream' => true],
            ['label' => 'INST', 'value' => 'PE', 'length' => 2, 'cream' => false],
            ['label' => 'GOB', 'value' => '010', 'length' => 3, 'cream' => true],
            ['label' => 'MPIO', 'value' => '000', 'length' => 3, 'cream' => false],
            ['label' => 'DD', 'value' => $fecha['dia'], 'length' => 2, 'cream' => true],
            ['label' => 'MM', 'value' => $fecha['mes'], 'length' => 2, 'cream' => false],
            ['label' => 'AAAA', 'value' => $fecha['anio'], 'length' => 4, 'cream' => true],
            ['label' => 'HH', 'value' => '', 'length' => 2, 'cream' => false],
            ['label' => 'MM', 'value' => '', 'length' => 2, 'cream' => true],
        ];
    }

    private function fechaPartesIph(?string $fecha): array
    {
        if ($fecha && preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $fecha, $matches)) {
            return ['dia' => $matches[3], 'mes' => $matches[2], 'anio' => $matches[1]];
        }

        $ahora = now('America/Mexico_City');

        return ['dia' => $ahora->format('d'), 'mes' => $ahora->format('m'), 'anio' => $ahora->format('Y')];
    }

    private function iphEncabezadoOficial($section, array $d): void
    {
        $this->iphEncabezadoOficialTabla($section, $d);
    }

    private function iphEncabezadoOficialTabla($section, array $d): void
    {
        $groups = $this->referenciaIphGrupos($d);
        $boxWidth = 245;
        $rightWidth = array_sum(array_map(fn ($group) => (int) ($group['length'] ?? 1), $groups)) * $boxWidth;
        $leftWidth = self::CONTENT_W - $rightWidth;

        $table = $section->addTable([
            'borderSize' => 0,
            'cellMargin' => 20,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'unit' => TblWidth::TWIP,
        ]);

        $table->addRow(300);
        $table->addCell($leftWidth, $this->sinBorde(['valign' => 'center']))
            ->addText('SISTEMA NACIONAL DE SEGURIDAD PÚBLICA', ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $table->addCell($rightWidth, [
            'gridSpan' => 22,
            'borderTopSize' => 8,
            'borderTopColor' => '000000',
            'borderRightSize' => 8,
            'borderRightColor' => '000000',
            'borderLeftSize' => 8,
            'borderLeftColor' => '000000',
            'borderBottomSize' => 0,
            'valign' => 'center',
        ])->addText('NO. DE REFERENCIA', ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);

        $table->addRow(290);
        $table->addCell($leftWidth, $this->sinBorde(['valign' => 'center']));
        foreach ($groups as $group) {
            foreach ($this->charsForBoxes($group['value'] ?? '', (int) ($group['length'] ?? 1)) as $char) {
                $table->addCell($boxWidth, [
                    'borderSize' => 8,
                    'borderColor' => '000000',
                    'bgColor' => !empty($group['cream']) ? self::CREAM : 'FFFFFF',
                    'valign' => 'center',
                ])->addText($char, ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
            }
        }

        $table->addRow(180);
        $table->addCell($leftWidth, $this->sinBorde(['valign' => 'center']))
            ->addText('CNSP', ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        foreach ($groups as $group) {
            $length = (int) ($group['length'] ?? 1);
            $table->addCell($boxWidth * $length, [
                'gridSpan' => $length,
                'borderSize' => 0,
                'bgColor' => !empty($group['cream']) ? self::CREAM : 'FFFFFF',
                'valign' => 'center',
            ])->addText($group['label'] ?? '', ['bold' => true, 'size' => 5], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }

        $table->addRow(300);
        $table->addCell($leftWidth, $this->sinBorde());
        $table->addCell($rightWidth, [
            'gridSpan' => 22,
            'borderRightSize' => 8,
            'borderRightColor' => '000000',
            'borderLeftSize' => 8,
            'borderLeftColor' => '000000',
            'borderTopSize' => 0,
            'borderBottomSize' => 0,
            'valign' => 'center',
        ])->addText('NO. DE FOLIO ASIGNADO POR EL SISTEMA', ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);

        $table->addRow(290);
        $table->addCell($leftWidth, $this->sinBorde());
        foreach ($this->charsForBoxes('', 20) as $char) {
            $table->addCell($boxWidth, [
                'borderSize' => 8,
                'borderColor' => '000000',
                'valign' => 'center',
            ])->addText($char, ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
        $table->addCell($boxWidth * 2, [
            'gridSpan' => 2,
            'borderRightSize' => 8,
            'borderRightColor' => '000000',
            'borderBottomSize' => 8,
            'borderBottomColor' => '000000',
            'borderTopSize' => 0,
            'borderLeftSize' => 0,
        ])->addText('', [], $this->p0());
    }

    private function iphAnexosPuesta($section, array $d): void
    {
        $vehiculos = count($d['vehiculos'] ?? []);
        $objetos = count($d['objetos'] ?? []);
        $fotos = count($d['fotos'] ?? []);
        $sinAnexos = $vehiculos === 0 && $objetos === 0;

        $tabla = $section->addTable([
            'borderSize' => 0,
            'borderColor' => '000000',
            'cellMargin' => 0,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'unit' => TblWidth::TWIP,
        ]);

        $tabla->addRow(230);
        $tabla->addCell(self::CONTENT_W, [
            'gridSpan' => 9,
            'borderTopSize' => 6,
            'borderTopColor' => '000000',
            'borderRightSize' => 6,
            'borderRightColor' => '000000',
            'borderBottomSize' => 6,
            'borderBottomColor' => '000000',
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
            'valign' => 'center',
        ])->addText('Señale con una "X" el o los Anexos entregados e indique la cantidad de cada uno de ellos (sólo entregue los Anexos utilizados).', ['bold' => true, 'italic' => true, 'size' => 7], ['spaceAfter' => 0]);

        $this->iphAnexoFila($tabla, ['Anexo A.', 'Detención(es)', false, 0], ['Anexo E.', 'Entrevistas', false, 0]);
        $this->iphAnexoFila($tabla, ['Anexo B.', 'Informe de uso de la fuerza', false, 0], ['Anexo F.', 'Entrega - recepción del lugar de la intervención', false, 0]);
        $this->iphAnexoFila($tabla, ['Anexo C.', 'Inspección de vehículo', $vehiculos > 0, $vehiculos], ['Anexo G.', 'Continuación de la narrativa de los hechos y/o entrevista', false, 0]);
        $this->iphAnexoFila($tabla, ['Anexo D.', 'Inventario de armas y objetos', $objetos > 0, $objetos], ['No se entregan anexos', '', $sinAnexos, null]);

        $this->iphDocumentacionComplementaria($section, $fotos);
    }

    private function iphDocumentacionComplementaria($section, int $fotos): void
    {
        $tabla = $section->addTable([
            'borderSize' => 0,
            'borderColor' => '000000',
            'cellMargin' => 0,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'unit' => TblWidth::TWIP,
        ]);

        $rowStyle = [
            'borderTopSize' => 6,
            'borderTopColor' => '000000',
            'borderBottomSize' => 6,
            'borderBottomColor' => '000000',
            'valign' => 'center',
        ];

        $tabla->addRow(500);
        $tabla->addCell(2100, array_merge($rowStyle, ['borderLeftSize' => 6, 'borderLeftColor' => '000000']))
            ->addText("¿Anexa documentación\ncomplementaria?", ['size' => 7], ['alignment' => Jc::CENTER, 'spaceAfter' => 0, 'lineHeight' => 1]);
        $tabla->addCell(1250, $rowStyle)
            ->addText('Sí ' . ($fotos > 0 ? 'X' : '') . '   No ' . ($fotos > 0 ? '' : 'X'), ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $tabla->addCell(550, $rowStyle)
            ->addText('=>', ['bold' => true, 'size' => 13], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $tabla->addCell(2350, $rowStyle)
            ->addText('Fotografías ' . ($fotos > 0 ? 'X' : '') . '   Videos   Otra', ['bold' => true, 'size' => 7], ['spaceAfter' => 0]);
        $tabla->addCell(2650, $rowStyle)
            ->addText('Audio   Certificados médicos   ¿Cuál?', ['bold' => true, 'size' => 7], ['spaceAfter' => 0]);
        $tabla->addCell(2206, array_merge($rowStyle, ['borderRightSize' => 6, 'borderRightColor' => '000000']))
            ->addText("(1) Inventario de\nResguardo de vehículos", ['bold' => true, 'size' => 8], ['alignment' => Jc::CENTER, 'spaceAfter' => 0, 'lineHeight' => 1]);
    }

    private function iphAnexoFila($tabla, array $left, array $right): void
    {
        $tabla->addRow(335);
        $this->iphAnexoCeldas($tabla, $left, 3300, true);
        $tabla->addCell(260, [
            'borderLeftSize' => 6,
            'borderLeftColor' => '000000',
        ])->addText('', [], $this->p0());
        $this->iphAnexoCeldas($tabla, $right, 5786, false);
    }

    private function iphAnexoCeldas($tabla, array $data, int $labelWidth, bool $leftSide): void
    {
        [$prefix, $label, $checked, $count] = $data + ['', '', false, 0];
        $texto = trim($prefix . ' ' . $label);
        $labelStyle = ['valign' => 'center'];

        if ($leftSide) {
            $labelStyle['borderLeftSize'] = 6;
            $labelStyle['borderLeftColor'] = '000000';
        }

        $tabla->addCell($labelWidth, $labelStyle)
            ->addText($texto, ['bold' => $prefix !== 'No se entregan anexos', 'size' => 7], ['spaceAfter' => 0]);
        $tabla->addCell(320, ['valign' => 'center'])
            ->addText($checked ? 'X' : '', ['bold' => true, 'size' => 9], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);

        if ($count === null) {
            $tabla->addCell(280, ['valign' => 'center'])->addText('', [], $this->p0());
            $style = ['valign' => 'center'];

            if (!$leftSide) {
                $style['borderRightSize'] = 6;
                $style['borderRightColor'] = '000000';
            }

            $tabla->addCell(280, $style)->addText('', [], $this->p0());

            return;
        }

        foreach ($this->charsForBoxes(str_pad((string) max(0, (int) $count), 2, '0', STR_PAD_LEFT), 2) as $index => $char) {
            $style = ['borderSize' => 6, 'borderColor' => '000000', 'valign' => 'center'];

            if (!$leftSide && $index === 1) {
                $style['borderRightSize'] = 6;
                $style['borderRightColor'] = '000000';
            }

            $tabla->addCell(280, $style)
                ->addText($char, ['bold' => true, 'size' => 7], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
    }

    private function iphPersonaLineas($section, string $titulo, array $nombre, array $extra): void
    {
        $tabla = $section->addTable([
            'borderSize' => 6,
            'borderColor' => '000000',
            'cellMargin' => 30,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'unit' => TblWidth::TWIP,
        ]);

        $tabla->addRow(280);
        $tabla->addCell(self::CONTENT_W, ['gridSpan' => 2, 'bgColor' => self::CREAM])
            ->addText($titulo, ['bold' => true, 'size' => 8], ['spaceAfter' => 0]);

        foreach ([
            'Primer apellido:' => $nombre['primer_apellido'] ?? '',
            'Segundo apellido:' => $nombre['segundo_apellido'] ?? '',
            'Nombre (s):' => $nombre['nombres'] ?? '',
        ] + $extra as $label => $value) {
            $tabla->addRow(300);
            $tabla->addCell(1700, ['valign' => 'center'])
                ->addText($label, ['bold' => true, 'size' => 7], ['spaceAfter' => 0]);
            $tabla->addCell(self::CONTENT_W - 1700, ['valign' => 'center'])
                ->addText((string) $value, ['bold' => true, 'size' => 8], ['spaceAfter' => 0]);
        }
    }

    private function partesNombreIph(string $nombre): array
    {
        $tokens = preg_split('/\s+/', trim($nombre), -1, PREG_SPLIT_NO_EMPTY) ?: [];

        if (count($tokens) >= 3) {
            $primerTokenEsNombre = $this->tokenNombreComunIph($tokens[0]);
            $tercerTokenEsNombre = $this->tokenNombreComunIph($tokens[2]);

            if ($primerTokenEsNombre && !$tercerTokenEsNombre) {
                return [
                    'primer_apellido' => $tokens[count($tokens) - 2],
                    'segundo_apellido' => $tokens[count($tokens) - 1],
                    'nombres' => implode(' ', array_slice($tokens, 0, -2)),
                ];
            }

            return [
                'primer_apellido' => $tokens[0],
                'segundo_apellido' => $tokens[1],
                'nombres' => implode(' ', array_slice($tokens, 2)),
            ];
        }

        if (count($tokens) === 2) {
            if ($this->tokenNombreComunIph($tokens[0]) && !$this->tokenNombreComunIph($tokens[1])) {
                return [
                    'primer_apellido' => $tokens[1],
                    'segundo_apellido' => '',
                    'nombres' => $tokens[0],
                ];
            }

            if (!$this->tokenNombreComunIph($tokens[0]) && $this->tokenNombreComunIph($tokens[1])) {
                return [
                    'primer_apellido' => $tokens[0],
                    'segundo_apellido' => '',
                    'nombres' => $tokens[1],
                ];
            }

            return [
                'primer_apellido' => '',
                'segundo_apellido' => '',
                'nombres' => implode(' ', $tokens),
            ];
        }

        return [
            'primer_apellido' => '',
            'segundo_apellido' => '',
            'nombres' => $tokens[0] ?? '',
        ];
    }

    private function partesPoliciaIph(array $data): array
    {
        $nombres = trim((string) ($data['agente_nombres'] ?? ''));
        $apellidoPaterno = trim((string) ($data['agente_apellido_paterno'] ?? ''));
        $apellidoMaterno = trim((string) ($data['agente_apellido_materno'] ?? ''));

        if ($nombres !== '' || $apellidoPaterno !== '' || $apellidoMaterno !== '') {
            return [
                'primer_apellido' => $apellidoPaterno,
                'segundo_apellido' => $apellidoMaterno,
                'nombres' => $nombres,
            ];
        }

        return $this->partesNombreIph((string) ($data['nombre_policia_mayus'] ?? ''));
    }

    private function tokenNombreComunIph(string $token): bool
    {
        $normalizado = Str::ascii(mb_strtoupper(trim($token), 'UTF-8'));

        return in_array($normalizado, [
            'JOSE', 'JOSEFINA', 'MARIA', 'MA', 'JESUS', 'JUAN', 'LUIS', 'CARLOS', 'MIGUEL',
            'ANGEL', 'MANUEL', 'FRANCISCO', 'JAVIER', 'ANTONIO', 'ROBERTO', 'RAUL', 'RUBEN',
            'ALBERTO', 'ALEJANDRO', 'FERNANDO', 'RICARDO', 'EDUARDO', 'SERGIO', 'JORGE',
            'DANIEL', 'DAVID', 'OSCAR', 'ARTURO', 'ENRIQUE', 'MARIO', 'MARTIN', 'PEDRO',
            'GUADALUPE', 'ANA', 'LAURA', 'KARLA', 'KARINA', 'CLAUDIA', 'SANDRA', 'PATRICIA',
            'ELIZABETH', 'ERIKA', 'VERONICA', 'ROSA', 'LETICIA', 'YOLANDA', 'TERESA',
            'KATALINA', 'ROCIO', 'NOE', 'BRYAN',
        ], true);
    }

    private function iphFechaHoraPuesta($section, array $d): void
    {
        $fecha = $this->fechaPartesIph($d['fecha_puesta'] ?? null);
        $hora = substr((string) ($d['hora_puesta'] ?? ''), 0, 5);
        $horaPartes = preg_match('/^(\d{2}):(\d{2})$/', $hora, $matches)
            ? ['hora' => $matches[1], 'minuto' => $matches[2]]
            : ['hora' => '', 'minuto' => ''];

        $tabla = $section->addTable([
            'borderSize' => 0,
            'borderColor' => '000000',
            'cellMargin' => 0,
            'alignment' => JcTable::CENTER,
            'layout' => Table::LAYOUT_FIXED,
            'unit' => TblWidth::TWIP,
        ]);

        $fieldStyle = [
            'borderTopSize' => 6,
            'borderTopColor' => '000000',
            'borderBottomSize' => 6,
            'borderBottomColor' => '000000',
            'valign' => 'center',
        ];
        $boxStyle = ['borderSize' => 7, 'borderColor' => '000000', 'valign' => 'center'];

        $tabla->addRow(430);
        $tabla->addCell(850, array_merge($fieldStyle, ['borderLeftSize' => 6, 'borderLeftColor' => '000000']))
            ->addText('Fecha:', ['size' => 7], ['alignment' => Jc::RIGHT, 'spaceAfter' => 0]);
        foreach ($this->charsForBoxes($fecha['dia'] . $fecha['mes'] . $fecha['anio'], 8) as $char) {
            $tabla->addCell(230, $boxStyle)
                ->addText($char, ['bold' => true, 'size' => 9], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
        $tabla->addCell(910, array_merge($fieldStyle, ['borderRightSize' => 6, 'borderRightColor' => '000000']))
            ->addText('', [], $this->p0());

        $tabla->addCell(730, $fieldStyle)
            ->addText('Hora:', ['size' => 7], ['alignment' => Jc::RIGHT, 'spaceAfter' => 0]);
        foreach ($this->charsForBoxes($horaPartes['hora'], 2) as $char) {
            $tabla->addCell(230, $boxStyle)
                ->addText($char, ['bold' => true, 'size' => 9], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
        $tabla->addCell(100, $fieldStyle)
            ->addText(':', ['bold' => true, 'size' => 10], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        foreach ($this->charsForBoxes($horaPartes['minuto'], 2) as $char) {
            $tabla->addCell(230, $boxStyle)
                ->addText($char, ['bold' => true, 'size' => 9], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
        $tabla->addCell(850, array_merge($fieldStyle, ['borderRightSize' => 6, 'borderRightColor' => '000000']))
            ->addText('', [], $this->p0());

        $tabla->addCell(1200, $fieldStyle)
            ->addText('No. de expediente:', ['bold' => true, 'size' => 7], ['alignment' => Jc::RIGHT, 'spaceAfter' => 0]);
        foreach ($this->charsForBoxes($d['expediente'] ?? '', 18) as $char) {
            $tabla->addCell(185, $boxStyle)
                ->addText($char, ['bold' => true, 'size' => 7], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
        $tabla->addCell(376, array_merge($fieldStyle, ['borderRightSize' => 6, 'borderRightColor' => '000000']))
            ->addText('', [], $this->p0());
    }

    private function charsForBoxes($value, int $length): array
    {
        $text = preg_replace('/\s+/', '', (string) $value) ?? '';
        $chars = preg_split('//u', $text, -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $result = [];

        for ($i = 0; $i < $length; $i++) {
            $result[] = $chars[$i] ?? '';
        }

        return $result;
    }

    private function seccion(PhpWord $phpWord, string $size)
    {
        $isLegal = $size === 'legal';

        return $phpWord->addSection([
            'pageSizeW' => $isLegal ? self::LEGAL_W : self::LETTER_W,
            'pageSizeH' => $isLegal ? self::LEGAL_H : self::LETTER_H,
            'marginTop' => self::MARGIN,
            'marginRight' => self::MARGIN,
            'marginBottom' => self::MARGIN,
            'marginLeft' => self::MARGIN,
        ]);
    }

    private function barra($section, string $text, string $bgColor, string $fontColor = '000000', bool $left = false): void
    {
        $tabla = $section->addTable('FormTable');
        $tabla->addRow(380);
        $tabla->addCell(self::CONTENT_W, ['bgColor' => $bgColor, 'valign' => 'center'])->addText($text, ['bold' => true, 'color' => $fontColor, 'size' => 9], ['alignment' => $left ? Jc::LEFT : Jc::CENTER, 'spaceAfter' => 0]);
    }

    private function tituloReporte($section, string $text): void
    {
        $this->texto($section, $text, ['bold' => true, 'size' => 11], ['spaceBefore' => 180, 'spaceAfter' => 50]);
    }

    private function logoPaginaParte($section): void
    {
        $logo = public_path('img/SSP_horizontal.png');

        if (is_file($logo)) {
            $this->addImageFit($section, $logo, 175, 85, Jc::LEFT);
            $section->addTextBreak(1);
        }
    }

    private function encabezadoParte($section, string $roman, string $title): void
    {
        $this->texto($section, self::PARTE_TAB_PREFIX . $roman . '      ' . $title, ['bold' => true, 'size' => 14], [
            'alignment' => Jc::BOTH,
            'lineHeight' => 1.1,
            'spaceBefore' => 300,
            'spaceAfter' => 0,
        ]);
    }

    private function parrafoParte($section, string $text, int $spaceBefore = 360): void
    {
        $this->texto($section, self::PARTE_TAB_PREFIX . $text, ['size' => 11], [
            'alignment' => Jc::BOTH,
            'lineHeight' => 1.08,
            'spaceBefore' => $spaceBefore,
            'spaceAfter' => 0,
        ]);
    }

    private function vinetaParte($section, string $text, int $spaceBefore = 260): void
    {
        $this->texto($section, '•    ' . $text, ['size' => 11], [
            'alignment' => Jc::BOTH,
            'indentation' => ['left' => self::PARTE_BULLET_LEFT, 'hanging' => self::PARTE_BULLET_HANGING],
            'lineHeight' => 1.08,
            'spaceBefore' => $spaceBefore,
            'spaceAfter' => 0,
        ]);
    }

    private function parrafoParteConNombre($section, array $d): void
    {
        $run = $section->addTextRun([
            'alignment' => Jc::BOTH,
            'lineHeight' => 1.08,
            'spaceBefore' => 0,
            'spaceAfter' => 0,
        ]);
        $run->addText(self::PARTE_TAB_PREFIX . 'El suscrito Perito en Hechos de Tránsito ', ['size' => 11]);
        $run->addText($d['nombre_policia_mayus'], ['bold' => true, 'size' => 11]);
        $run->addText(', adscrito a la Coordinación del Agrupamiento de Seguridad Vial, de la Secretaría de Seguridad Pública del Estado, tengo a bien emitir el siguiente:', ['size' => 11]);
    }

    private function parrafoProblemaParte($section, array $d): void
    {
        $run = $section->addTextRun([
            'alignment' => Jc::BOTH,
            'lineHeight' => 1.08,
            'spaceBefore' => 360,
            'spaceAfter' => 0,
        ]);
        $run->addText(self::PARTE_TAB_PREFIX . 'Establecer las causas que originaron el hecho de tránsito terrestre en su modalidad de ', ['size' => 11]);
        $run->addText('(' . $d['modalidad_parte'] . ')', ['bold' => true, 'size' => 11]);
        $run->addText(', ocurrido el día ' . $d['fecha_hecho'] . ', a las ' . substr($d['hora_hecho'], 0, 5) . ' horas en ' . $d['calle_parte'] . ', de la colonia ', ['size' => 11]);
        $run->addText($d['colonia_parte'], ['bold' => true, 'size' => 11]);
        $run->addText(', en esta ciudad.', ['size' => 11]);
    }

    private function parrafoVehiculoParte($section, array $vehiculo, int $i): void
    {
        $run = $section->addTextRun([
            'alignment' => Jc::BOTH,
            'lineHeight' => 1.08,
            'spaceBefore' => 360,
            'spaceAfter' => 0,
        ]);

        $run->addText(self::PARTE_TAB_PREFIX . 'VEHÍCULO (' . $this->plain($this->letraIndice($i)) . ').- ', ['bold' => true, 'size' => 11]);
        $tieneDetalle = false;
        $separador = function () use ($run, &$tieneDetalle): void {
            $run->addText($tieneDetalle ? ', ' : ' ', ['size' => 11]);
            $tieneDetalle = true;
        };

        foreach ([
            'Marca' => $this->clean($vehiculo['marca'] ?? null),
            'Modelo' => $this->clean($vehiculo['modelo'] ?? null),
            'Tipo' => $this->clean($vehiculo['tipo'] ?? null),
            'Línea' => $this->clean($vehiculo['linea'] ?? null),
            'Color' => $this->clean($vehiculo['color'] ?? null),
        ] as $etiqueta => $valor) {
            if (!$valor) {
                continue;
            }

            $separador();
            $run->addText($etiqueta . ' ' . $this->plain($valor), ['size' => 11]);
        }

        if ($capacidad = $this->clean($vehiculo['capacidad_personas'] ?? null)) {
            $separador();
            $run->addText('Capacidad para ' . $this->plain($capacidad) . ' Personas', ['size' => 11]);
        }

        if ($placas = $this->clean($vehiculo['placas'] ?? null)) {
            $separador();
            $run->addText('Placas para circular ', ['size' => 11]);
            $run->addText($this->plain($placas), ['bold' => true, 'size' => 11]);

            if ($servicio = $this->clean($vehiculo['tipo_servicio'] ?? null)) {
                $run->addText(' del servicio ' . mb_strtolower($this->plain($servicio), 'UTF-8'), ['size' => 11]);
            }

            if ($estadoPlacas = $this->clean($vehiculo['estado_placas'] ?? null)) {
                $run->addText(' de ' . $this->plain($estadoPlacas), ['size' => 11]);
            }
        }

        if ($serie = $this->clean($vehiculo['serie'] ?? null)) {
            $separador();
            $run->addText('Serie ', ['size' => 11]);
            $run->addText($this->plain($serie), ['bold' => true, 'size' => 11]);
        }

        if ($tarjeta = $this->clean($vehiculo['tarjeta_circulacion_nombre'] ?? null)) {
            $separador();
            $run->addText('tarjeta de circulación a nombre de ' . $this->plain($tarjeta), ['size' => 11]);
        }

        $conductores = $vehiculo['conductores'] ?? [];

        foreach ($conductores as $conductor) {
            $nombreConductor = $this->clean($conductor['nombre'] ?? null);

            if (!$nombreConductor || mb_strtoupper($nombreConductor, 'UTF-8') === 'SIN CONDUCTOR') {
                continue;
            }

            $sexo = mb_strtoupper($this->clean($conductor['sexo'] ?? null), 'UTF-8');
            $tratamiento = in_array($sexo, ['F', 'FEMENINO', 'MUJER'], true) || strpos($sexo, 'FEM') === 0
                ? 'la C. '
                : 'el C. ';
            $separador();
            $run->addText($tratamiento, ['size' => 11]);
            $run->addText(mb_strtoupper($this->plain($nombreConductor), 'UTF-8'), ['bold' => true, 'size' => 11]);

            if ($edad = $this->clean($conductor['edad'] ?? null)) {
                $run->addText(' de ' . $this->plain($edad) . ' años de edad', ['size' => 11]);
            }

            if ($domicilio = $this->clean($conductor['domicilio'] ?? null)) {
                $run->addText(', con domicilio en ' . $this->plain($domicilio) . ', en esta ciudad', ['size' => 11]);
            }

            $run->addText(', me manifestó ir a bordo del vehículo', ['size' => 11]);

            $licenciaPartes = array_values(array_filter([
                $this->clean($conductor['tipo_licencia'] ?? null),
                $this->clean($conductor['numero_licencia'] ?? null),
            ]));
            $estadoLicencia = $this->clean($conductor['estado_licencia'] ?? null);
            $estadoLicenciaNormalizado = mb_strtoupper($estadoLicencia, 'UTF-8');
            $presentoLicencia = !empty($licenciaPartes)
                || ($estadoLicencia !== '' && !in_array($estadoLicenciaNormalizado, ['NO', 'NO PRESENTO', 'NO PRESENTÓ', 'SIN LICENCIA'], true));

            if ($presentoLicencia) {
                $run->addText(', presentó licencia', ['size' => 11]);

                if (!empty($licenciaPartes)) {
                    $run->addText(' ' . $this->plain(implode(' ', $licenciaPartes)), ['size' => 11]);
                }
            }
        }

        $run->addText('.', ['size' => 11]);
    }

    private function texto($container, string $text, array $font = [], array $paragraph = []): void
    {
        $container->addText($this->plain($text), array_merge(['size' => 10], $font), array_merge(['spaceAfter' => 80], $paragraph));
    }

    private function p0(): array
    {
        return ['spaceAfter' => 0, 'spaceBefore' => 0];
    }

    private function sinBorde(array $style = []): array
    {
        return array_merge([
            'borderTopSize' => 1,
            'borderTopColor' => 'FFFFFF',
            'borderRightSize' => 1,
            'borderRightColor' => 'FFFFFF',
            'borderBottomSize' => 1,
            'borderBottomColor' => 'FFFFFF',
            'borderLeftSize' => 1,
            'borderLeftColor' => 'FFFFFF',
        ], $style);
    }

    private function imagenEnMarco($section, ?string $path, int $maxW, int $maxH, string $empty): void
    {
        if ($path && is_file($path)) {
            $this->addImageFit($section, $path, $maxW, $maxH, Jc::CENTER);
            $section->addTextBreak(1);

            return;
        }

        $tabla = $section->addTable('FormTable');
        $tabla->addRow((int) round(Converter::pointToTwip($maxH + 20)));
        $cell = $tabla->addCell(self::CONTENT_W, ['valign' => 'center']);

        if ($empty !== '') {
            $cell->addText($empty, ['italic' => true], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        }
    }

    private function addImageFit($container, string $path, int $maxW, int $maxH, string $alignment = Jc::CENTER): bool
    {
        if (!is_file($path)) {
            return false;
        }

        $maxW = min($maxW, 535);
        $size = @getimagesize($path);
        $width = $maxW;
        $height = null;

        if ($size && $size[0] > 0 && $size[1] > 0) {
            $ratio = min($maxW / $size[0], $maxH / $size[1], 1);
            $width = max(1, (int) floor($size[0] * $ratio));
            $height = max(1, (int) floor($size[1] * $ratio));
        }

        $style = ['width' => $width, 'alignment' => $alignment];

        if ($height) {
            $style['height'] = $height;
        }

        $container->addImage($path, $style);

        return true;
    }

    private function normalizarImagenesDocx(string $path): void
    {
        $zip = new \ZipArchive();

        if ($zip->open($path) !== true) {
            return;
        }

        $xml = $zip->getFromName('word/document.xml');

        if (!is_string($xml) || strpos($xml, '<w:pict>') === false) {
            $zip->close();

            return;
        }

        if (strpos($xml, 'xmlns:a=') === false) {
            $xml = preg_replace('/<w:document\b/', '<w:document xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"', $xml, 1);
        }

        if (strpos($xml, 'xmlns:pic=') === false) {
            $xml = preg_replace('/<w:document\b/', '<w:document xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"', $xml, 1);
        }

        $contador = 1;
        $xml = preg_replace_callback(
            '/<w:pict>\s*<v:shape\b[^>]*style="([^"]+)"[^>]*>\s*(?:<w10:wrap\b[^>]*\/>\s*)?<v:imagedata\b[^>]*r:id="([^"]+)"[^>]*\/>\s*<\/v:shape>\s*<\/w:pict>/s',
            function (array $matches) use (&$contador): string {
                $width = $this->puntosAEmu($this->medidaPuntos($matches[1], 'width', 120));
                $height = $this->puntosAEmu($this->medidaPuntos($matches[1], 'height', 90));
                $id = $contador++;
                $rId = htmlspecialchars($matches[2], ENT_QUOTES | ENT_XML1, 'UTF-8');

                return '<w:drawing>'
                    . '<wp:inline distT="0" distB="0" distL="0" distR="0">'
                    . '<wp:extent cx="' . $width . '" cy="' . $height . '"/>'
                    . '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
                    . '<wp:docPr id="' . $id . '" name="Imagen ' . $id . '"/>'
                    . '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
                    . '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
                    . '<pic:pic>'
                    . '<pic:nvPicPr><pic:cNvPr id="' . $id . '" name="Imagen ' . $id . '"/><pic:cNvPicPr/></pic:nvPicPr>'
                    . '<pic:blipFill><a:blip r:embed="' . $rId . '"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
                    . '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="' . $width . '" cy="' . $height . '"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
                    . '</pic:pic>'
                    . '</a:graphicData></a:graphic>'
                    . '</wp:inline>'
                    . '</w:drawing>';
            },
            $xml
        );

        $zip->deleteName('word/document.xml');
        $zip->addFromString('word/document.xml', $xml);
        $zip->close();
    }

    private function medidaPuntos(string $style, string $nombre, float $default): float
    {
        if (preg_match('/\b' . preg_quote($nombre, '/') . '\s*:\s*([0-9.]+)pt/i', $style, $matches)) {
            return (float) $matches[1];
        }

        return $default;
    }

    private function puntosAEmu(float $points): int
    {
        return max(1, (int) round($points * 12700));
    }

    private function pieCadena($section, string $left): void
    {
        $section->addTextBreak(1);
        $table = $section->addTable('Clean');
        $table->addRow();
        $table->addCell(6500)->addText($left, ['size' => 8], $this->p0());
        $table->addCell(4600)->addText('Página ___ de ___', ['bold' => true, 'size' => 8], ['alignment' => Jc::RIGHT, 'spaceAfter' => 0]);
    }

    private function resolverImagen($valor): ?string
    {
        if (is_array($valor)) {
            $valor = reset($valor);
        }

        $src = trim((string) $valor);

        if ($src === '') {
            return null;
        }

        if (preg_match('/^data:image\/([a-z0-9+.-]+);base64,(.+)$/i', $src, $matches)) {
            $ext = str_contains($matches[1], 'jpeg') ? 'jpg' : (str_contains($matches[1], 'png') ? 'png' : 'img');
            $path = storage_path('app/temp/' . uniqid('iph_img_', true) . '.' . $ext);
            File::ensureDirectoryExists(dirname($path));
            file_put_contents($path, base64_decode($matches[2]));
            $this->tempFiles[] = $path;

            return $path;
        }

        if (is_file($src)) {
            return $src;
        }

        if (preg_match('#(^|/)previews/|croquis#i', $src)) {
            $croquisPath = app(CroquisArchivoStorage::class)->temporaryLocalPath($src);

            if ($croquisPath && is_file($croquisPath)) {
                if (Str::startsWith(str_replace('\\', '/', $croquisPath), str_replace('\\', '/', storage_path('app/temp/')))) {
                    $this->tempFiles[] = $croquisPath;
                }

                return $croquisPath;
            }
        }

        if (preg_match('#(^|/)(hechos|vehiculos)/#i', $src)) {
            $fotoPath = app(HechoFotoStorage::class)->temporaryLocalPath($src);

            if ($fotoPath && is_file($fotoPath)) {
                if (Str::startsWith(str_replace('\\', '/', $fotoPath), str_replace('\\', '/', storage_path('app/temp/')))) {
                    $this->tempFiles[] = $fotoPath;
                }

                return $fotoPath;
            }
        }

        $path = parse_url($src, PHP_URL_PATH) ?: $src;
        $path = urldecode(str_replace('\\', '/', ltrim($path, '/')));
        $candidatos = [public_path($path), public_path('storage/' . $path)];

        foreach (['storage/', 'img/'] as $marca) {
            $pos = strpos($path, $marca);

            if ($pos !== false) {
                $candidatos[] = public_path(substr($path, $pos));
            }
        }

        foreach ($candidatos as $candidato) {
            if (is_file($candidato)) {
                return $candidato;
            }
        }

        return null;
    }

    private function limpiarTemporales(): void
    {
        foreach ($this->tempFiles as $path) {
            if (is_file($path)) {
                @unlink($path);
            }
        }

        $this->tempFiles = [];
    }

    private function carbon(string $fecha, string $hora): ?Carbon
    {
        if ($fecha === '' || $hora === '') {
            return null;
        }

        try {
            return Carbon::createFromFormat('Y-m-d H:i', $fecha . ' ' . substr($hora, 0, 5), 'America/Mexico_City');
        } catch (\Throwable $e) {
            return null;
        }
    }

    private function fechaTexto(?string $fecha): string
    {
        if (!$fecha) {
            return 'fecha no especificada';
        }

        try {
            return Carbon::parse($fecha, 'America/Mexico_City')->translatedFormat('d \\d\\e F \\d\\e Y');
        } catch (\Throwable $e) {
            return (string) $fecha;
        }
    }

    private function fechaCorta(?string $fecha): string
    {
        if (!$fecha) {
            return '';
        }

        try {
            return Carbon::parse($fecha, 'America/Mexico_City')->format('d-m-Y');
        } catch (\Throwable $e) {
            return (string) $fecha;
        }
    }

    private function narrativaIphParrafos(array $d): array
    {
        $conocimiento = $d['conocimiento'] ?? null;
        $arribo = $d['arribo'] ?? null;
        $fechaConocimiento = $conocimiento ? $this->fechaTexto($conocimiento->format('Y-m-d')) : ($d['fecha_texto'] ?? 'fecha no especificada');
        $horaConocimiento = $conocimiento ? $conocimiento->format('H:i') : substr((string) ($d['hora_hecho'] ?? ''), 0, 5);
        $horaArribo = $arribo ? $arribo->format('H:i') : substr((string) ($d['hora_hecho'] ?? ''), 0, 5);
        $folio = trim((string) ($d['folio'] ?? ''));
        $lugar = $this->valor($d['lugar'] ?? null, 'el lugar de intervención');
        $tipoHecho = $this->valor($d['tipo_hecho'] ?? null, 'HECHO PROBABLEMENTE DELICTIVO');
        $unidadArribo = trim((string) ($d['unidad_arribo'] ?? ''));

        $primerParrafo = 'Siendo aproximadamente las ' . ($horaConocimiento !== '' ? $horaConocimiento : 'hora no especificada')
            . ' horas del día ' . $fechaConocimiento . ', quien suscribe ' . $this->valor($d['nombre_policia'] ?? null, 'el primer respondiente')
            . ', adscrito a ' . $this->valor($d['adscripcion'] ?? null, 'la unidad correspondiente')
            . ', tuvo conocimiento ' . ($folio !== '' ? 'por medio del folio C5i ' . $folio : 'por reporte registrado en el sistema')
            . ' de un hecho registrado como ' . $tipoHecho . ', en ' . $lugar
            . '. Por tal motivo se trasladó al lugar de intervención'
            . ($unidadArribo !== '' ? ' a bordo de la unidad ' . $unidadArribo : '')
            . ', arribando aproximadamente a las ' . ($horaArribo !== '' ? $horaArribo : 'hora no especificada') . ' horas.';

        $parrafos = [$primerParrafo];

        if (!empty($d['condiciones_climatologicas']) || !empty($d['condiciones_iluminacion'])) {
            $parrafos[] = trim(collect([
                $d['condiciones_climatologicas'] ?? null,
                $d['condiciones_iluminacion'] ?? null,
            ])->filter()->implode(' '));
        }

        if (!empty($d['narrativa_operativa'])) {
            $parrafos[] = $d['narrativa_operativa'];
        }

        $vehiculos = $d['vehiculos'] ?? [];

        if (!empty($vehiculos)) {
            $parrafos[] = 'Al arribar al lugar de intervención se ' . (count($vehiculos) === 1 ? 'localizó un vehículo' : 'localizaron ' . count($vehiculos) . ' vehículos') . ' con las características registradas en el sistema.';

            foreach ($vehiculos as $i => $vehiculo) {
                $parrafos[] = $this->descripcionVehiculo($vehiculo, $i);
            }
        } else {
            $parrafos[] = 'Al arribar al lugar de intervención no se cuenta con vehículos capturados en el sistema para describir dentro de esta narrativa.';
        }

        foreach ($d['lesionados'] ?? [] as $lesionado) {
            $parrafos[] = $this->descripcionVictimaParte($lesionado);
        }

        if (!empty($vehiculos)) {
            $danios = collect($vehiculos)
                ->map(fn ($vehiculo, $i) => $this->daniosVehiculo($vehiculo, $i))
                ->implode(' ');

            if ($danios !== '') {
                $parrafos[] = 'Respecto de los daños observados, se asentó lo siguiente: ' . $danios;
            }

            $parrafos[] = $this->observacionesGruas($vehiculos);
        }

        $parrafos[] = 'Queda pendiente que el elemento actuante complemente de manera cronológica y detallada las circunstancias específicas de cómo recibió el reporte, el traslado, las acciones realizadas en el lugar, entrevistas, aseguramientos y demás datos operativos que no obren capturados en el sistema.';

        return array_values(array_filter($parrafos, fn ($parrafo) => trim((string) $parrafo) !== ''));
    }

    private function descripcionVehiculo(array $vehiculo, int $i): string
    {
        $partes = collect([
            $this->clean($vehiculo['marca'] ?? null) ? 'Marca ' . $this->clean($vehiculo['marca'] ?? null) : null,
            $this->clean($vehiculo['linea'] ?? null) ? 'Línea ' . $this->clean($vehiculo['linea'] ?? null) : null,
            $this->clean($vehiculo['modelo'] ?? null) ? 'Modelo ' . $this->clean($vehiculo['modelo'] ?? null) : null,
            $this->clean($vehiculo['tipo'] ?? null) ? 'Tipo ' . $this->clean($vehiculo['tipo'] ?? null) : null,
            $this->clean($vehiculo['color'] ?? null) ? 'Color ' . $this->clean($vehiculo['color'] ?? null) : null,
            $this->clean($vehiculo['capacidad_personas'] ?? null) ? 'Capacidad para ' . $this->clean($vehiculo['capacidad_personas'] ?? null) . ' personas' : null,
        ])->filter()->values();

        if ($placas = $this->clean($vehiculo['placas'] ?? null)) {
            $placasTexto = 'Placas ' . $placas;

            if ($servicio = $this->clean($vehiculo['tipo_servicio'] ?? null)) {
                $placasTexto .= ' del servicio ' . mb_strtolower($servicio, 'UTF-8');
            }

            if ($estadoPlacas = $this->clean($vehiculo['estado_placas'] ?? null)) {
                $placasTexto .= ' de ' . $estadoPlacas;
            }

            $partes->push($placasTexto);
        }

        if ($serie = $this->clean($vehiculo['serie'] ?? null)) {
            $partes->push('NIV/Serie ' . $serie);
        }

        if ($tarjeta = $this->clean($vehiculo['tarjeta_circulacion_nombre'] ?? null)) {
            $partes->push('tarjeta de circulación a nombre de ' . $tarjeta);
        }

        $texto = 'VEHÍCULO (' . $this->letraIndice($i) . ').- ' . ($partes->isNotEmpty()
            ? $partes->implode(', ')
            : 'Sin características vehiculares completas capturadas en el sistema') . '.';

        $conductores = collect($vehiculo['conductores'] ?? [])
            ->map(function (array $conductor) {
                $nombre = $this->clean($conductor['nombre'] ?? null);

                if (!$nombre || mb_strtoupper($nombre, 'UTF-8') === 'SIN CONDUCTOR') {
                    return null;
                }

                $frase = 'Conductor registrado: ' . mb_strtoupper($nombre, 'UTF-8');

                if ($edad = $this->clean($conductor['edad'] ?? null)) {
                    $frase .= ', de ' . $edad . ' años de edad';
                }

                if ($domicilio = $this->clean($conductor['domicilio'] ?? null)) {
                    $frase .= ', con domicilio en ' . $domicilio;
                }

                $licencia = collect([
                    $this->clean($conductor['tipo_licencia'] ?? null),
                    $this->clean($conductor['numero_licencia'] ?? null),
                    $this->clean($conductor['estado_licencia'] ?? null),
                ])->filter()->implode(' ');

                if ($licencia !== '') {
                    $frase .= ', licencia ' . $licencia;
                }

                return $frase . '.';
            })
            ->filter()
            ->values();

        if ($conductores->isNotEmpty()) {
            $texto .= ' ' . $conductores->implode(' ');
        }

        return $texto;
    }

    private function daniosVehiculo(array $vehiculo, int $i): string
    {
        $partes = $this->clean($vehiculo['partes_danadas'] ?? null);
        $monto = $vehiculo['monto_danos'] ?? null;
        $textoDanios = 'No se cuenta con partes dañadas registradas';

        if ($partes) {
            $partesNormalizadas = $this->normalizarClaveIph($partes);
            $textoDanios = str_starts_with($partesNormalizadas, 'DANO') || str_starts_with($partesNormalizadas, 'DANOS')
                ? 'Presenta ' . mb_strtolower($partes, 'UTF-8')
                : 'Presenta daños en su ' . $this->title($partes);
        }

        $texto = 'VEHÍCULO (' . $this->letraIndice($i) . ').- ' . $textoDanios;

        if (is_numeric($monto) && (float) $monto > 0) {
            $montoNumero = (float) $monto;
            $texto .= ', se estiman en la cantidad aproximada para su reparación de $ '
                . number_format($montoNumero, 2)
                . ' (' . $this->pesosEnLetra($montoNumero) . ')';
        }

        return $texto . '.';
    }

    private function daniosInspeccion(array $vehiculo, int $i): string
    {
        return 'DAÑOS DEL VEHÍCULO (' . $this->title($this->numeroALetras($i + 1)) . '): A simple vista ' . mb_strtolower($this->daniosVehiculo($vehiculo, $i), 'UTF-8');
    }

    private function destinoVehiculo(array $vehiculo): string
    {
        $nombre = $this->valorGrua($vehiculo['grua_nombre'] ?? null) ?: $this->valorGrua($vehiculo['grua'] ?? null);
        $destino = $this->valorGrua($vehiculo['grua_direccion'] ?? null)
            ?: $this->valorGrua($vehiculo['grua_ubicacion_corralon'] ?? null)
            ?: $this->valorGrua($vehiculo['corralon'] ?? null);

        if (!$nombre && !$destino) {
            return 'Destino que se le dio: pendiente de precisar en el presente anexo.';
        }

        return 'Destino que se le dio: El vehículo fue remitido' . ($nombre ? ' al corralón de ' . $nombre : '') . ($destino ? ' ubicado en ' . $destino : '') . '.';
    }

    private function descripcionCadenaVehiculo(array $vehiculo, int $i): string
    {
        return 'VEHÍCULO ' . $this->letraIndice($i) . ' EL CUAL ES DE LA ' . mb_strtoupper(trim(collect([
            $this->clean($vehiculo['marca'] ?? null) ? 'Marca ' . $this->clean($vehiculo['marca'] ?? null) : null,
            $this->clean($vehiculo['tipo'] ?? null) ? 'Tipo ' . $this->clean($vehiculo['tipo'] ?? null) : null,
            $this->clean($vehiculo['linea'] ?? null) ? 'Línea ' . $this->clean($vehiculo['linea'] ?? null) : null,
            $this->clean($vehiculo['modelo'] ?? null) ? 'Modelo ' . $this->clean($vehiculo['modelo'] ?? null) : null,
            $this->clean($vehiculo['color'] ?? null) ? 'Color ' . $this->clean($vehiculo['color'] ?? null) : null,
            $this->clean($vehiculo['placas'] ?? null) ? 'con número de placas de circulación ' . $this->clean($vehiculo['placas'] ?? null) : null,
            $this->clean($vehiculo['serie'] ?? null) ? 'con número de serie ' . $this->clean($vehiculo['serie'] ?? null) : null,
        ])->filter()->implode(', ')), 'UTF-8') . '.';
    }

    private function observacionesGruas(array $vehiculos): string
    {
        $totalVehiculos = count($vehiculos);
        $sujeto = $this->textoVehiculosParte($totalVehiculos);
        $gruas = $this->gruasParte($vehiculos);

        if ($gruas->isEmpty()) {
            return $sujeto . ($totalVehiculos === 1 ? ' no cuenta' : ' no cuentan') . ' con registro de traslado o resguardo por grúa en el sistema.';
        }

        $verbo = $totalVehiculos === 1 ? 'fue' : 'fueron';
        $resguardado = $totalVehiculos === 1 ? 'resguardado' : 'resguardados';
        $nombres = $gruas->pluck('nombre')->filter()->unique()->implode(' y ');
        $direcciones = $gruas->pluck('direccion')->filter()->unique()->implode(' y ');
        $frase = $sujeto . ' ' . $verbo . ' ' . $resguardado . ' por su propia tracción';

        if ($nombres !== '') {
            $frase .= ' en las instalaciones de ' . $nombres;
        }

        if ($direcciones !== '' && $nombres !== '') {
            $frase .= ', garaje de apoyo a esta dependencia, ubicado en ' . $direcciones;
        } elseif ($direcciones !== '') {
            $frase .= ' en ' . $direcciones;
        }

        return $frase . '.';
    }

    private function descripcionVictimaParte(array $lesionado): string
    {
        $nombre = $this->clean($lesionado['nombre'] ?? null);
        $edad = $this->clean($lesionado['edad'] ?? null);
        $tipoLesion = mb_strtoupper($this->clean($lesionado['tipo_lesion'] ?? null), 'UTF-8');
        $hospital = $this->clean($lesionado['hospital'] ?? null);
        $ambulancia = $this->clean($lesionado['ambulancia'] ?? null);
        $paramedico = $this->clean($lesionado['paramedico'] ?? null);
        $observaciones = $this->clean($lesionado['observaciones'] ?? null);
        $esFallecido = $tipoLesion === 'FALLECIDO';
        $sexo = mb_strtoupper($this->clean($lesionado['sexo'] ?? null), 'UTF-8');
        $tratamiento = in_array($sexo, ['F', 'FEMENINO', 'MUJER'], true) || strpos($sexo, 'FEM') === 0 ? 'la C. ' : 'el C. ';

        if ($esFallecido) {
            $frase = $nombre
                ? 'De este hecho de tránsito resultó fallecido ' . $tratamiento . mb_strtoupper($nombre, 'UTF-8')
                : 'De este hecho de tránsito resultó fallecida una persona';
        } else {
            $frase = $nombre
                ? 'De este hecho de tránsito resultó lesionado ' . $tratamiento . mb_strtoupper($nombre, 'UTF-8')
                : 'De este hecho de tránsito resultó lesionada una persona';
        }

        if ($edad) {
            $frase .= ' de ' . $edad . ' años de edad';
        }

        if ($esFallecido) {
            $frase .= $observaciones ? ', ' . mb_strtolower($observaciones, 'UTF-8') : ', quedando registrado su fallecimiento en el lugar';

            return $frase . '.';
        }

        $atenciones = [];
        $atendido = 'atendido';
        $trasladado = 'trasladado';
        $valorado = 'valorado';

        if ($paramedico) {
            $atenciones[] = $atendido . ' por el paramédico ' . $paramedico;
        } elseif (!empty($lesionado['atencion_en_sitio'])) {
            $atenciones[] = $atendido . ' en el lugar';
        }

        if (!empty($lesionado['hospitalizado']) || $hospital) {
            $traslado = $trasladado;
            $traslado .= $hospital ? ' al nosocomio ' . $hospital : ' a nosocomio para su atención médica';

            if ($ambulancia) {
                $traslado .= ' a bordo de la ambulancia ' . $ambulancia;
            }

            $atenciones[] = $traslado;
        } elseif ($ambulancia) {
            $atenciones[] = $valorado . ' por la ambulancia ' . $ambulancia;
        }

        if (!empty($atenciones)) {
            $frase .= ', quien fue ' . implode(' y ', $atenciones);
        }

        if ($observaciones) {
            $frase .= ', observándose ' . mb_strtolower($observaciones, 'UTF-8');
        }

        return $frase . '.';
    }

    private function conclusionCausaParte(array $d): string
    {
        if (!empty($d['conclusion_causa'])) {
            return $d['conclusion_causa'];
        }

        $causa = $this->clean($d['causas'] ?? null);
        $causaTexto = $causa !== '' ? mb_strtolower($causa, 'UTF-8') : 'la falta de precaución y cuidado';

        return 'ÚNICA.- La causa que da origen al hecho de tránsito que nos ocupa se refiere a '
            . $causaTexto
            . ' por parte del conductor del vehículo (A), en consecuencia ocasionar '
            . $this->resultadoLegalParte($d)
            . ', violando por tal motivo el artículo 432 Fracción V, del Reglamento de la Ley de Movilidad y Seguridad Vial vigente en el Estado.';
    }

    private function conclusionDisposicionParte(array $d): string
    {
        if (!empty($d['conclusion_disposicion'])) {
            return $d['conclusion_disposicion'];
        }

        $vehiculos = $d['vehiculos'] ?? [];
        $vehiculosTexto = mb_strtolower($this->textoVehiculosParte(count($vehiculos)), 'UTF-8');
        $frase = 'Con base en lo dispuesto en el artículo 59 de la Ley de Tránsito y Vialidad vigente en el Estado, Pongo a su disposición ' . $vehiculosTexto;
        $nombres = $this->gruasParte($vehiculos)->pluck('nombre')->filter()->unique()->implode(' y ');

        if ($nombres !== '') {
            $frase .= ', en las instalaciones de ' . mb_strtoupper($nombres, 'UTF-8') . ', garaje de apoyo a esta dependencia';
        }

        return $frase . ', lo anterior para los fines legales a los que haya lugar.';
    }

    private function resultadoLegalParte(array $d): string
    {
        $lesionados = (int) ($d['hecho']['lesionados_count'] ?? 0);
        $fallecidos = (int) ($d['hecho']['fallecidos_count'] ?? 0);

        if ($lesionados === 0 && $fallecidos === 0 && !empty($d['lesionados'])) {
            foreach ($d['lesionados'] as $lesionado) {
                $tipo = mb_strtoupper($this->clean($lesionado['tipo_lesion'] ?? null), 'UTF-8');

                if ($tipo === 'FALLECIDO') {
                    $fallecidos++;
                } else {
                    $lesionados++;
                }
            }
        }

        $resultados = [];

        if ($lesionados > 0) {
            $resultados[] = 'lesiones';
        }

        if ($fallecidos > 0) {
            $resultados[] = 'fallecimiento';
        }

        $resultados[] = 'daños materiales';

        if (count($resultados) === 1) {
            return $resultados[0];
        }

        $ultimo = array_pop($resultados);

        return implode(', ', $resultados) . ' y ' . $ultimo;
    }

    private function textoVehiculosParte(int $total): string
    {
        if ($total === 1) {
            return 'El vehículo';
        }

        if ($total === 2) {
            return 'Ambos vehículos';
        }

        return 'Los vehículos';
    }

    private function gruasParte(array $vehiculos)
    {
        return collect($vehiculos)
            ->map(function (array $vehiculo) {
                $nombre = $this->valorGrua($vehiculo['grua_nombre'] ?? null) ?: $this->valorGrua($vehiculo['grua'] ?? null);
                $direccion = $this->valorGrua($vehiculo['grua_direccion'] ?? null)
                    ?: $this->valorGrua($vehiculo['grua_ubicacion_corralon'] ?? null)
                    ?: $this->valorGrua($vehiculo['corralon'] ?? null);

                return (!$nombre && !$direccion) ? null : ['nombre' => $nombre, 'direccion' => $direccion];
            })
            ->filter()
            ->unique(fn ($grua) => mb_strtoupper(($grua['nombre'] ?? '') . '|' . ($grua['direccion'] ?? ''), 'UTF-8'))
            ->values();
    }

    private function firmaParte($section, array $d): void
    {
        $section->addTextBreak(2);
        $this->texto($section, 'ATENTAMENTE.', ['bold' => true, 'size' => 11], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $this->texto($section, 'PERITO DE TRÁNSITO.', ['bold' => true, 'size' => 11], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
        $section->addTextBreak(3);
        $this->texto($section, $d['nombre_policia_mayus'], ['bold' => true, 'size' => 11], ['alignment' => Jc::CENTER, 'spaceAfter' => 0]);
    }

    private function pesosEnLetra($monto): string
    {
        $monto = is_numeric($monto) ? (float) $monto : 0.0;
        $entero = (int) floor($monto);
        $centavos = (int) round(($monto - $entero) * 100);

        if ($centavos === 100) {
            $entero++;
            $centavos = 0;
        }

        return $this->numeroALetras($entero) . ' PESOS ' . str_pad((string) $centavos, 2, '0', STR_PAD_LEFT) . '/100 M.N.';
    }

    private function valorGrua($valor): ?string
    {
        $texto = $this->clean($valor);

        if (!$texto) {
            return null;
        }

        return in_array(mb_strtoupper($texto, 'UTF-8'), ['0', 'NO', 'SIN GRUA', 'SIN GRÚA', 'SIN CORRALON', 'SIN CORRALÓN'], true) ? null : $texto;
    }

    private function normalizarClaveIph($valor): string
    {
        $texto = mb_strtoupper(trim((string) $valor), 'UTF-8');
        $ascii = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $texto);

        if ($ascii !== false) {
            $texto = $ascii;
        }

        return preg_replace('/[^A-Z0-9]+/', '', $texto) ?: '';
    }

    private function letraIndice(int $i): string
    {
        return chr(65 + ($i % 26));
    }

    private function numeroALetras(int $n): string
    {
        $unidades = [
            0 => 'CERO',
            1 => 'UNO',
            2 => 'DOS',
            3 => 'TRES',
            4 => 'CUATRO',
            5 => 'CINCO',
            6 => 'SEIS',
            7 => 'SIETE',
            8 => 'OCHO',
            9 => 'NUEVE',
            10 => 'DIEZ',
            11 => 'ONCE',
            12 => 'DOCE',
            13 => 'TRECE',
            14 => 'CATORCE',
            15 => 'QUINCE',
            16 => 'DIECISÉIS',
            17 => 'DIECISIETE',
            18 => 'DIECIOCHO',
            19 => 'DIECINUEVE',
            20 => 'VEINTE',
            21 => 'VEINTIUNO',
            22 => 'VEINTIDÓS',
            23 => 'VEINTITRÉS',
            24 => 'VEINTICUATRO',
            25 => 'VEINTICINCO',
            26 => 'VEINTISÉIS',
            27 => 'VEINTISIETE',
            28 => 'VEINTIOCHO',
            29 => 'VEINTINUEVE',
        ];
        $decenas = [30 => 'TREINTA', 40 => 'CUARENTA', 50 => 'CINCUENTA', 60 => 'SESENTA', 70 => 'SETENTA', 80 => 'OCHENTA', 90 => 'NOVENTA'];
        $centenas = [100 => 'CIEN', 200 => 'DOSCIENTOS', 300 => 'TRESCIENTOS', 400 => 'CUATROCIENTOS', 500 => 'QUINIENTOS', 600 => 'SEISCIENTOS', 700 => 'SETECIENTOS', 800 => 'OCHOCIENTOS', 900 => 'NOVECIENTOS'];

        $convertir = function (int $numero) use (&$convertir, $unidades, $decenas, $centenas): string {
            if ($numero < 30) {
                return $unidades[$numero];
            }

            if ($numero < 100) {
                $decena = (int) (floor($numero / 10) * 10);
                $resto = $numero % 10;

                return $resto ? $decenas[$decena] . ' Y ' . $unidades[$resto] : $decenas[$decena];
            }

            if ($numero < 1000) {
                if ($numero === 100) {
                    return 'CIEN';
                }

                $centena = (int) (floor($numero / 100) * 100);
                $resto = $numero % 100;
                $prefijo = $centena === 100 ? 'CIENTO' : $centenas[$centena];

                return $resto ? $prefijo . ' ' . $convertir($resto) : $prefijo;
            }

            if ($numero < 2000) {
                $resto = $numero - 1000;

                return $resto ? 'MIL ' . $convertir($resto) : 'MIL';
            }

            if ($numero < 1000000) {
                $miles = (int) floor($numero / 1000);
                $resto = $numero % 1000;
                $texto = $convertir($miles) . ' MIL';

                return $resto ? $texto . ' ' . $convertir($resto) : $texto;
            }

            if ($numero < 2000000) {
                $resto = $numero - 1000000;

                return $resto ? 'UN MILLÓN ' . $convertir($resto) : 'UN MILLÓN';
            }

            $millones = (int) floor($numero / 1000000);
            $resto = $numero % 1000000;
            $texto = $convertir($millones) . ' MILLONES';

            return $resto ? $texto . ' ' . $convertir($resto) : $texto;
        };

        return $convertir(max(0, $n));
    }

    private function valor($valor, string $default = 'No especificado'): string
    {
        $texto = trim((string) $valor);

        return $texto === '' ? $default : $texto;
    }

    private function clean($valor): string
    {
        $texto = trim((string) $valor);
        $normalizado = mb_strtoupper($texto, 'UTF-8');

        return in_array($normalizado, ['', '-', 'N/A', 'NA', 'NO APLICA', 'NO ESPECIFICADO'], true) ? '' : $texto;
    }

    private function plain(string $text): string
    {
        return html_entity_decode(strip_tags($text), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    private function title($value): string
    {
        return mb_convert_case(mb_strtolower(trim((string) $value), 'UTF-8'), MB_CASE_TITLE, 'UTF-8');
    }
}
