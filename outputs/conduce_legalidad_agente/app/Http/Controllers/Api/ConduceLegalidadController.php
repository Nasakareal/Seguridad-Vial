<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ConduceLegalidadCaptura;
use App\Models\ConduceLegalidadCapturaFundamento;
use App\Models\ConduceLegalidadFoto;
use App\Models\ConduceLegalidadOperativo;
use App\Models\ConduceLegalidadPersona;
use App\Models\ConduceLegalidadVehiculo;
use App\Models\Delegacion;
use App\Models\Grua;
use App\Models\Hechos;
use App\Models\LicenciaPuntoInfraccion;
use App\Models\Unidad;
use App\Models\User;
use App\Services\CodigoPostalGeoService;
use App\Services\ImageThumbnailService;
use App\Services\IphPuestaDisposicionDocxService;
use App\Services\WhatsAppCloudService;
use App\Support\TelefonoMexico;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ConduceLegalidadController extends Controller
{
    private const UNIDAD_SINIESTROS = 1;
    private const UNIDAD_DELEGACIONES = 2;
    private const UNIDAD_SEGURIDAD_VIAL = 3;
    private const UNIDAD_VIALIDADES_URBANAS = 5;
    private const NOMBRE_OPERATIVO = 'Operativo conduce con legalidad';
    private const NOMBRE_OPERATIVO_ALCOHOLIMETRIA = 'Operativo de Alcoholimetría';
    private const ALCOHOLIMETRIA_HORAS_ALIMENTACION = 8;
    private const TIPOS_OPERATIVO = ['conduce_legalidad', 'alcoholimetria'];
    private const ESTADOS = ['activo', 'cerrado', 'cancelado'];
    private const ESTADOS_CIVILES = ['SOLTERO(A)', 'CASADO(A)', 'VIUDO(A)', 'DIVORCIADO(A)'];
    private const FORMATO_IPH_BARANDILLAS = 'barandillas';
    private const FORMATO_IPH_ANTERIOR = 'anterior';
    private const TICKET_SUPERVISOR_NOMBRE = 'Luis Eduardo Lugo Ordorica';
    private const TICKET_SUPERVISOR_CARGO = 'Subdirector de la Unidad de Protección en Vialidades Urbanas';
    private const TICKET_COORDINADOR_NOMBRE = 'Lic. Luis Roberto Rosiles Soberanis';
    private const TICKET_COORDINADOR_CARGO = 'Coordinador del Agrupamiento de Seguridad Vial';
    private const AGENTE_ADSCRIPCION_DEFAULT = 'Unidad de Protección en Vialidades Urbanas';
    private const FUNDAMENTO_SIN_LICENCIA_CODIGO = 'OP_CL_SIN_LICENCIA_SIN_HABILITADO';
    private const NARRATIVA_SIN_LICENCIA = 'Se hace constar que la persona conductora no exhibe licencia vigente expedida por autoridad competente, por lo que, conforme al articulo 402, carece de habilitacion juridica para continuar conduciendo el vehiculo. Se le informa que la marcha no puede continuar bajo su mando. Al no encontrarse en el lugar persona legalmente habilitada que pueda hacerse cargo inmediato y seguro del vehiculo, la autoridad adopta la medida necesaria para retirar el vehiculo de la via y evitar la continuacion de la conducta. Se deja constancia de que la medida no se funda en una causal automatica de "sin licencia = deposito", sino en la imposibilidad de permitir que el vehiculo continue bajo el mando de persona no habilitada y en la falta de alternativa inmediata legalmente viable, tomando en cuenta el marco de retiro y remision previsto para supuestos expresos en los articulos 700 y 702.';
    private const FUNDAMENTOS_EXCLUIDOS_OPERATIVO = [
        'ART420_FIV_IA_B_TRANSPORTE_PUBLICO_ESCOLAR',
        'ART465_FXI_POLARIZADO_MAYOR_20',
        'ART519_FIV_IA_NO_MOVER_SINIESTRO_DANOS',
    ];
    private const TEXTOS_EXCLUIDOS_OPERATIVO = [
        'POLARIZADO',
        'TRANSPORTE PUBLICO',
        'SERVICIO PUBLICO',
        'SINIESTRO',
        'COMPETENCIAS DE VELOCIDAD',
        'PLACAS DE DEMOSTRACION',
        'SIN REGISTRO PREVIO EN REV',
        'PLACAS FORANEAS SIN REGISTRO PREVIO',
        'REGISTRO DE VISITA VENCIDO',
        'ESTACIONAR',
        'CERRAR U OBSTRUIR CIRCULACION',
        'OBSTRUIR CIRCULACION',
        'REPARACIONES A VEHICULOS',
        'REPARAR VEHICULO',
        'RESERVAR ESTACIONAMIENTO',
        'REQUERIMIENTO DE RETIRO',
        'ESPACIOS ESPECIALES DE ASCENSO',
        'ASCENSO DESCENSO TIEMPO EXCEDIDO',
    ];

    public function meta(Request $request)
    {
        $user = $request->user();
        $canAssignScope = $this->canAssignOperativoScope($user);

        return response()->json([
            'ok' => true,
            'data' => [
                'operativo_nombre' => self::NOMBRE_OPERATIVO,
                'estados' => [
                    'activo' => 'Activo',
                    'cerrado' => 'Cerrado',
                    'cancelado' => 'Cancelado',
                ],
                'abilities' => $this->abilitiesPayload($user),
                'fundamentos_corralon' => $this->fundamentosCorralonPayload(),
                'fundamentos_conduce_legalidad' => $this->fundamentosConduceLegalidadPayload(),
                'fundamentos_actividad_corralon' => $this->fundamentosActividadCorralonPayload(),
                'fundamentos_persona' => $this->fundamentosPersonaPayload(),
                'formatos_impresion' => $this->formatosImpresionPayload(),
                'unidades' => $canAssignScope
                    ? Unidad::query()
                        ->where('activa', true)
                        ->orderBy('nombre')
                        ->get(['id', 'nombre'])
                    : [],
                'delegaciones' => $canAssignScope
                    ? Delegacion::query()
                        ->where('activa', true)
                        ->orderBy('nombre')
                        ->get(['id', 'nombre'])
                    : [],
            ],
        ]);
    }

    public function gruasSiniestros(Request $request)
    {
        abort_unless($request->user(), 403);

        $gruas = Grua::query()
            ->select(['id', 'nombre', 'direccion', 'ubicacion_corralon', 'telefono', 'email', 'created_at'])
            ->whereHas('unidades', function ($query) {
                $query->where('unidades.id', self::UNIDAD_SINIESTROS);
            })
            ->with('unidades:id,nombre,slug')
            ->with('delegaciones:id,clave,nombre,municipio')
            ->orderBy('nombre')
            ->get();

        return response()->json([
            'data' => $gruas,
        ]);
    }

    public function index(Request $request)
    {
        $user = $request->user();
        abort_unless($user, 403);

        $dateFilters = $request->validate([
            'fecha' => ['nullable', 'date_format:Y-m-d'],
            'fecha_desde' => ['nullable', 'date_format:Y-m-d'],
            'fecha_hasta' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:fecha_desde'],
        ]);

        $query = ConduceLegalidadOperativo::query()
            ->with(['creador', 'delegacion'])
            ->withCount([
                'capturas',
                'capturas as mis_capturas_count' => function ($capturas) use ($user) {
                    $capturas->where('created_by', $user->id);
                },
            ])
            ->orderByDesc('fecha')
            ->orderByDesc('id');

        $this->scopeOperativos($query, $user);

        if ($request->filled('tipo_operativo')) {
            $tipoOperativo = trim((string) $request->query('tipo_operativo'));
            if (!in_array($tipoOperativo, self::TIPOS_OPERATIVO, true)) {
                throw ValidationException::withMessages([
                    'tipo_operativo' => 'El tipo de operativo no es válido.',
                ]);
            }
            $query->where('tipo_operativo', $tipoOperativo);
        }

        if ($request->filled('mes')) {
            $mes = trim((string) $request->query('mes'));
            if (!preg_match('/^(\d{4})-(0[1-9]|1[0-2])$/', $mes, $matches)) {
                throw ValidationException::withMessages([
                    'mes' => 'El mes debe tener el formato AAAA-MM.',
                ]);
            }
            $query->whereYear('fecha', (int) $matches[1])
                ->whereMonth('fecha', (int) $matches[2]);
        }

        if (!$this->canCreateOperativo($user)) {
            $query->where('estado', 'activo');
        } elseif ($request->filled('estado') && in_array($request->query('estado'), self::ESTADOS, true)) {
            $query->where('estado', $request->query('estado'));
        } elseif (!$request->boolean('incluir_cerrados')) {
            $query->where('estado', 'activo');
        }

        if (!empty($dateFilters['fecha'])) {
            $query->whereDate('fecha', $dateFilters['fecha']);
        } else {
            if (!empty($dateFilters['fecha_desde'])) {
                $query->whereDate('fecha', '>=', $dateFilters['fecha_desde']);
            }

            if (!empty($dateFilters['fecha_hasta'])) {
                $query->whereDate('fecha', '<=', $dateFilters['fecha_hasta']);
            }
        }

        if ($request->filled('buscar')) {
            $buscar = trim((string) $request->query('buscar'));
            $query->where(function ($sub) use ($buscar) {
                $sub->where('nombre', 'like', "%{$buscar}%")
                    ->orWhere('municipio', 'like', "%{$buscar}%")
                    ->orWhere('lugar', 'like', "%{$buscar}%")
                    ->orWhere('numero', 'like', "%{$buscar}%")
                    ->orWhere('colonia', 'like', "%{$buscar}%")
                    ->orWhere('codigo_postal', 'like', "%{$buscar}%");
            });
        }

        $perPage = max(1, min((int) $request->query('per_page', 30), 100));
        $page = $query->paginate($perPage);

        return response()->json([
            'ok' => true,
            'abilities' => $this->abilitiesPayload($user),
            'data' => $page->getCollection()
                ->map(fn (ConduceLegalidadOperativo $operativo) => $this->operativoPayload($operativo, $user))
                ->values(),
            'pagination' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function buscar(Request $request)
    {
        $user = $request->user();
        abort_unless($user, 403);

        $q = trim((string) $request->query('q', ''));
        $perPage = max(1, min((int) $request->query('per_page', 20), 50));

        if ($q === '' || mb_strlen($q) < 2) {
            return response()->json([
                'data' => [],
                'meta' => [
                    'current_page' => 1,
                    'per_page' => $perPage,
                    'total' => 0,
                    'last_page' => 1,
                ],
            ]);
        }

        $like = '%' . addcslashes($q, "%_\\") . '%';
        $folio = $this->parseFolioBusqueda($q);

        $query = ConduceLegalidadCaptura::query()
            ->with([
                'operativo',
                'creador',
                'personas',
                'vehiculos',
            ]);

        $this->scopeCapturas($query, $user);

        $query->where(function ($capturas) use ($q, $like, $folio) {
            if (ctype_digit($q)) {
                $capturas->orWhere('conduce_legalidad_capturas.id', (int) $q)
                    ->orWhere('conduce_legalidad_capturas.operativo_id', (int) $q);
            }

            if ($folio !== null) {
                $capturas->orWhere(function ($porFolio) use ($folio) {
                    $porFolio->where('conduce_legalidad_capturas.operativo_id', $folio['operativo_id'])
                        ->where('conduce_legalidad_capturas.id', $folio['captura_id'])
                        ->whereHas('operativo', function ($operativos) use ($folio) {
                            $operativos->where('tipo_operativo', $folio['tipo_operativo']);
                        });
                });
            }

            $capturas
                ->orWhere('conduce_legalidad_capturas.municipio', 'like', $like)
                ->orWhere('conduce_legalidad_capturas.lugar', 'like', $like)
                ->orWhere('conduce_legalidad_capturas.narrativa', 'like', $like)
                ->orWhere('conduce_legalidad_capturas.observaciones', 'like', $like)
                ->orWhereHas('operativo', function ($operativos) use ($like) {
                    $operativos->where('nombre', 'like', $like)
                        ->orWhere('municipio', 'like', $like)
                        ->orWhere('lugar', 'like', $like)
                        ->orWhere('numero', 'like', $like)
                        ->orWhere('colonia', 'like', $like)
                        ->orWhere('codigo_postal', 'like', $like);
                })
                ->orWhereHas('personas', function ($personas) use ($like) {
                    $personas->where('nombre', 'like', $like)
                        ->orWhere('nombres', 'like', $like)
                        ->orWhere('apellido_paterno', 'like', $like)
                        ->orWhere('apellido_materno', 'like', $like)
                        ->orWhere('telefono', 'like', $like)
                        ->orWhere('domicilio', 'like', $like)
                        ->orWhere('numero_licencia', 'like', $like)
                        ->orWhereRaw(
                            "CONCAT_WS(' ', nombres, apellido_paterno, apellido_materno) LIKE ?",
                            [$like]
                        );
                })
                ->orWhereHas('vehiculos', function ($vehiculos) use ($like) {
                    $vehiculos->where('placas', 'like', $like)
                        ->orWhere('serie', 'like', $like)
                        ->orWhere('marca', 'like', $like)
                        ->orWhere('modelo', 'like', $like)
                        ->orWhere('linea', 'like', $like);
                });
        })
            ->orderByDesc('fecha')
            ->orderByDesc('id');

        $results = $query->paginate($perPage);

        return response()->json([
            'data' => $results->getCollection()
                ->map(fn (ConduceLegalidadCaptura $captura) => $this->capturaBusquedaPayload($captura))
                ->values(),
            'meta' => [
                'current_page' => $results->currentPage(),
                'per_page' => $results->perPage(),
                'total' => $results->total(),
                'last_page' => $results->lastPage(),
            ],
        ]);
    }

    public function storeOperativo(Request $request)
    {
        $user = $request->user();
        abort_unless($this->canCreateOperativo($user), 403);

        $validated = $request->validate($this->operativoRulesForUser($user));
        $now = now();
        $schedule = $this->resolveOperativoSchedule($user, $validated, $now);
        $scope = $this->resolveOperativoScope($user, $validated);
        $codigoPostal = $this->resolverCodigoPostalOperativo($validated['lat'] ?? null, $validated['lng'] ?? null);
        $tipoOperativo = $this->tipoOperativo(
            $validated['tipo_operativo'] ?? null,
            $validated['nombre'] ?? null,
            $validated['objetivo'] ?? null
        );

        $operativo = ConduceLegalidadOperativo::create([
            'client_uuid' => $this->nullableString($validated['client_uuid'] ?? null),
            'nombre' => $this->nombreOperativo($tipoOperativo),
            'tipo_operativo' => $tipoOperativo,
            'fecha' => $schedule['fecha'],
            'hora_inicio' => $schedule['hora_inicio'],
            'municipio' => $this->nullableString($validated['municipio'] ?? null),
            'lugar' => $this->nullableString($validated['lugar'] ?? null),
            'numero' => $this->nullableString($validated['numero'] ?? null),
            'colonia' => $this->nullableString($validated['colonia'] ?? null),
            'codigo_postal' => $codigoPostal,
            'lat' => $validated['lat'] ?? null,
            'lng' => $validated['lng'] ?? null,
            'coordenadas_texto' => $this->nullableString($validated['coordenadas_texto'] ?? null),
            'objetivo' => $this->nullableString($validated['objetivo'] ?? null),
            'estado' => $validated['estado'] ?? 'activo',
            'unidad_id' => $scope['unidad_id'],
            'delegacion_id' => $scope['delegacion_id'],
            'created_by' => $user->id,
            'updated_by' => $user->id,
        ]);

        $operativo->load('creador');

        return response()->json([
            'ok' => true,
            'message' => 'Operativo creado correctamente.',
            'data' => $this->operativoPayload($operativo, $user, collect()),
        ], 201);
    }

    public function show(Request $request, ConduceLegalidadOperativo $operativo)
    {
        $user = $request->user();
        abort_unless($user, 403);
        $this->assertPuedeVerOperativo($operativo, $user);

        $operativo->loadMissing(['creador', 'actualizador', 'cerrador']);

        $capturasQuery = $operativo->capturas()
            ->with(['creador', 'unidad', 'delegacion', 'infraccion', 'fundamentos.infraccion', 'vehiculos.infraccion', 'personas.infraccion', 'fotos'])
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        $this->scopeCapturas($capturasQuery, $user);
        $capturas = $capturasQuery->get();

        return response()->json([
            'ok' => true,
            'abilities' => $this->abilitiesPayload($user),
            'data' => $this->operativoPayload($operativo, $user, $capturas),
        ]);
    }

    public function updateOperativo(Request $request, ConduceLegalidadOperativo $operativo)
    {
        $user = $request->user();
        abort_unless($this->canManage($user), 403);
        $this->assertPuedeVerOperativo($operativo, $user);

        $validated = $request->validate($this->operativoRulesForUser($user, $operativo));
        $oldEstado = $operativo->estado;
        $requestedEstado = $validated['estado'] ?? $oldEstado;
        if ($oldEstado !== 'activo' && $requestedEstado === 'activo') {
            abort_unless($this->canReactivateOperativo($user), 403);
        }

        $scope = $this->resolveOperativoScope($user, $validated, $operativo);
        $tipoOperativo = array_key_exists('tipo_operativo', $validated)
            ? $this->tipoOperativo(
                $validated['tipo_operativo'],
                $validated['nombre'] ?? $operativo->nombre,
                $validated['objetivo'] ?? $operativo->objetivo
            )
            : ($operativo->tipo_operativo ?: $this->tipoOperativo(null, $operativo->nombre, $operativo->objetivo));
        $latCodigoPostal = array_key_exists('lat', $validated) ? $validated['lat'] : $operativo->lat;
        $lngCodigoPostal = array_key_exists('lng', $validated) ? $validated['lng'] : $operativo->lng;
        $actualizarCodigoPostal = array_key_exists('lat', $validated)
            || array_key_exists('lng', $validated)
            || empty($operativo->codigo_postal);
        $codigoPostal = $actualizarCodigoPostal
            ? $this->resolverCodigoPostalOperativo($latCodigoPostal, $lngCodigoPostal)
            : $operativo->codigo_postal;

        $operativo->fill([
            'nombre' => $this->nombreOperativo($tipoOperativo),
            'tipo_operativo' => $tipoOperativo,
            'fecha' => $this->canSetOperativoSchedule($user)
                ? ($validated['fecha'] ?? $operativo->fecha)
                : $operativo->fecha,
            'hora_inicio' => $this->canSetOperativoSchedule($user) && array_key_exists('hora_inicio', $validated)
                ? $validated['hora_inicio']
                : $operativo->hora_inicio,
            'hora_cierre' => array_key_exists('hora_cierre', $validated) ? $validated['hora_cierre'] : $operativo->hora_cierre,
            'municipio' => array_key_exists('municipio', $validated) ? $this->nullableString($validated['municipio']) : $operativo->municipio,
            'lugar' => array_key_exists('lugar', $validated) ? $this->nullableString($validated['lugar']) : $operativo->lugar,
            'numero' => array_key_exists('numero', $validated) ? $this->nullableString($validated['numero']) : $operativo->numero,
            'colonia' => array_key_exists('colonia', $validated) ? $this->nullableString($validated['colonia']) : $operativo->colonia,
            'codigo_postal' => $codigoPostal,
            'lat' => array_key_exists('lat', $validated) ? $validated['lat'] : $operativo->lat,
            'lng' => array_key_exists('lng', $validated) ? $validated['lng'] : $operativo->lng,
            'coordenadas_texto' => array_key_exists('coordenadas_texto', $validated) ? $this->nullableString($validated['coordenadas_texto']) : $operativo->coordenadas_texto,
            'objetivo' => array_key_exists('objetivo', $validated) ? $this->nullableString($validated['objetivo']) : $operativo->objetivo,
            'estado' => $validated['estado'] ?? $operativo->estado,
            'unidad_id' => $scope['unidad_id'],
            'delegacion_id' => $scope['delegacion_id'],
            'updated_by' => $user->id,
        ]);

        if ($oldEstado === 'activo' && in_array($operativo->estado, ['cerrado', 'cancelado'], true)) {
            $operativo->closed_by = $user->id;
            $operativo->hora_cierre = $operativo->hora_cierre ?: now()->format('H:i:s');
        }

        if ($oldEstado !== 'activo' && $operativo->estado === 'activo') {
            $operativo->closed_by = null;
            $operativo->hora_cierre = null;
        }

        $operativo->save();
        $operativo->load(['creador', 'actualizador', 'cerrador']);

        return response()->json([
            'ok' => true,
            'message' => 'Operativo actualizado correctamente.',
            'data' => $this->operativoPayload($operativo, $user),
        ]);
    }

    public function destroyOperativo(Request $request, ConduceLegalidadOperativo $operativo)
    {
        $user = $request->user();
        abort_unless($this->canDeleteOperativo($user), 403);
        $this->assertPuedeVerOperativo($operativo, $user);

        $operativo->delete();

        return response()->json([
            'ok' => true,
            'message' => 'Operativo eliminado correctamente.',
        ]);
    }

    public function storeCaptura(
        Request $request,
        ConduceLegalidadOperativo $operativo,
        WhatsAppCloudService $whatsApp
    )
    {
        $user = $request->user();
        abort_unless($user, 403);
        $this->assertPuedeVerOperativo($operativo, $user);

        $validated = $request->validate(
            $this->capturaRules($operativo),
            $this->capturaValidationMessages()
        );
        $clientUuid = $this->nullableString($validated['client_uuid'] ?? null);
        if ($clientUuid !== null) {
            $existing = $operativo->capturas()
                ->where('client_uuid', $clientUuid)
                ->with(['creador', 'unidad', 'delegacion', 'infraccion', 'fundamentos.infraccion', 'vehiculos.infraccion', 'personas.infraccion', 'fotos'])
                ->first();

            if ($existing) {
                return response()->json([
                    'ok' => true,
                    'message' => 'Captura guardada correctamente.',
                    'data' => $this->capturaPayload($existing, $user),
                ]);
            }
        }

        $this->assertPuedeAlimentarOperativo($operativo, $user);

        $this->assertCapturaHasFundamento($validated, $operativo);
        $this->assertCapturaHasContent($validated, $request);
        $this->assertVehiculosCorrespondenOperativo($validated, $operativo);

        $captura = DB::transaction(function () use ($operativo, $user, $validated, $clientUuid, $request) {
            $operativo->refresh();
            $this->assertPuedeAlimentarOperativo($operativo, $user);
            $usaFundamentoUnificado = array_key_exists('fundamentos', $validated)
                || array_key_exists('fundamento_ids', $validated)
                || array_key_exists('licencia_punto_infraccion_id', $validated);
            $fundamentos = $usaFundamentoUnificado
                ? $this->capturaInfracciones($validated, $operativo)
                : [];
            $infraccion = $fundamentos[0] ?? null;
            $infraccionSnapshot = $this->capturaInfraccionSnapshot($validated, $infraccion);
            $agente = $this->agenteCapturaData($validated, $user);
            $now = now();
            $captura = $operativo->capturas()->create([
                'client_uuid' => $clientUuid,
                'licencia_punto_infraccion_id' => $infraccion ? $infraccion->id : null,
                'infraccion_codigo' => $infraccionSnapshot['codigo'],
                'fundamento_legal' => $infraccionSnapshot['fundamento_legal'],
                'created_by' => $user->id,
                'agente_nombre' => $agente['nombre'],
                'agente_nombres' => $agente['nombres'],
                'agente_apellido_paterno' => $agente['apellido_paterno'],
                'agente_apellido_materno' => $agente['apellido_materno'],
                'agente_numero_placa' => $agente['numero_placa'],
                'agente_adscripcion' => $agente['adscripcion'],
                'unidad_id' => $user->unidad_id,
                'delegacion_id' => $user->delegacion_id,
                'fecha' => $validated['fecha'] ?? $operativo->fecha ?? $now->toDateString(),
                'hora' => $validated['hora'] ?? $now->format('H:i:s'),
                'municipio' => $this->nullableString($validated['municipio'] ?? $operativo->municipio),
                'lugar' => $this->nullableString($validated['lugar'] ?? $operativo->lugar),
                'lat' => $validated['lat'] ?? null,
                'lng' => $validated['lng'] ?? null,
                'coordenadas_texto' => $this->nullableString($validated['coordenadas_texto'] ?? null),
                'narrativa' => $this->nullableString($validated['narrativa'] ?? null),
                'observaciones' => $this->nullableString($validated['observaciones'] ?? null),
                'rnd_data' => $this->canUseRnd($user) ? $this->normalizeRndData($validated['rnd_data'] ?? null) : null,
            ]);

            $this->replaceFundamentosCaptura($captura, $fundamentos, $validated);
            $this->replaceVehiculos(
                $captura,
                $validated['vehiculos'] ?? [],
                $fundamentos,
                $usaFundamentoUnificado
            );
            $this->replacePersonas(
                $captura,
                $validated['personas'] ?? [],
                $this->esOperativoAlcoholimetria($operativo),
                $usaFundamentoUnificado
            );
            $this->storeFotos($captura, $request, $user);

            return $captura;
        });

        $captura->load(['creador', 'unidad', 'delegacion', 'infraccion', 'fundamentos.infraccion', 'vehiculos.infraccion', 'personas.infraccion', 'fotos']);

        $whatsappPayload = null;
        if (!$this->esOperativoAlcoholimetria($operativo)) {
            try {
                $whatsappResponse = $this->enviarBoletaWhatsApp(
                    $request,
                    $operativo,
                    $captura,
                    $whatsApp
                );
                $whatsappPayload = $whatsappResponse->getData(true);
            } catch (ValidationException $e) {
                $firstError = collect($e->errors())->flatten()->first();
                $whatsappPayload = [
                    'ok' => false,
                    'message' => $firstError ?: 'La captura no tiene un teléfono válido para enviar la boleta.',
                ];
            } catch (\Symfony\Component\HttpKernel\Exception\HttpExceptionInterface $e) {
                $whatsappPayload = [
                    'ok' => false,
                    'message' => trim($e->getMessage())
                        ?: 'La captura no tiene un teléfono válido para enviar la boleta.',
                ];
            } catch (\Throwable $e) {
                report($e);
                $whatsappPayload = [
                    'ok' => false,
                    'message' => trim($e->getMessage())
                        ?: 'No se pudo enviar la boleta por WhatsApp.',
                ];
            }
        }

        $message = 'Captura guardada correctamente.';
        if ($whatsappPayload !== null) {
            $message .= ($whatsappPayload['ok'] ?? false)
                ? ' La boleta se envió automáticamente por WhatsApp.'
                : ' La captura quedó guardada, pero la boleta no se envió por WhatsApp: '
                    . ($whatsappPayload['message'] ?? 'revisa el teléfono o la configuración de Meta.');
        }

        return response()->json([
            'ok' => true,
            'message' => $message,
            'data' => $this->capturaPayload($captura, $user),
            'whatsapp_boleta' => $whatsappPayload,
        ], 201);
    }

    public function updateCaptura(Request $request, ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura)
    {
        $user = $request->user();
        $this->assertPuedeVerOperativo($operativo, $user);
        abort_unless($captura->operativo_id === $operativo->id, 404);
        abort_unless($this->canEditCaptura($user, $captura), 403);
        $this->assertPuedeAlimentarOperativo($operativo, $user);

        $validated = $request->validate(
            $this->capturaRules($operativo),
            $this->capturaValidationMessages()
        );
        $this->assertCapturaHasFundamento($validated, $operativo, $captura);
        $this->assertCapturaHasContent($validated, $request, $captura);
        $this->assertVehiculosCorrespondenOperativo($validated, $operativo);

        DB::transaction(function () use ($captura, $operativo, $validated, $request, $user) {
            $operativo->refresh();
            $this->assertPuedeAlimentarOperativo($operativo, $user);
            $campoFundamentoPresente = array_key_exists('fundamentos', $validated)
                || array_key_exists('fundamento_ids', $validated)
                || array_key_exists('licencia_punto_infraccion_id', $validated);
            $captura->loadMissing(['fundamentos.infraccion', 'infraccion']);
            $fundamentos = $campoFundamentoPresente
                ? $this->capturaInfracciones($validated, $operativo)
                : $this->fundamentosCapturaActuales($captura);
            $infraccion = $fundamentos[0] ?? null;
            $infraccionSnapshot = $campoFundamentoPresente
                ? $this->capturaInfraccionSnapshot($validated, $infraccion)
                : [
                    'codigo' => $captura->infraccion_codigo,
                    'fundamento_legal' => $captura->fundamento_legal,
                ];
            $usaFundamentoUnificado = $campoFundamentoPresente || count($fundamentos) > 0;
            $agente = $this->agenteCapturaData($validated, $user, $captura);
            $captura->fill([
                'licencia_punto_infraccion_id' => $campoFundamentoPresente
                    ? ($infraccion ? $infraccion->id : null)
                    : $captura->licencia_punto_infraccion_id,
                'infraccion_codigo' => $campoFundamentoPresente
                    ? $infraccionSnapshot['codigo']
                    : $captura->infraccion_codigo,
                'fundamento_legal' => $campoFundamentoPresente
                    ? $infraccionSnapshot['fundamento_legal']
                    : $captura->fundamento_legal,
                'agente_nombre' => $agente['nombre'],
                'agente_nombres' => $agente['nombres'],
                'agente_apellido_paterno' => $agente['apellido_paterno'],
                'agente_apellido_materno' => $agente['apellido_materno'],
                'agente_numero_placa' => $agente['numero_placa'],
                'agente_adscripcion' => $agente['adscripcion'],
                'fecha' => $validated['fecha'] ?? $captura->fecha,
                'hora' => $validated['hora'] ?? $captura->hora,
                'municipio' => array_key_exists('municipio', $validated) ? $this->nullableString($validated['municipio']) : $captura->municipio,
                'lugar' => array_key_exists('lugar', $validated) ? $this->nullableString($validated['lugar']) : $captura->lugar,
                'lat' => array_key_exists('lat', $validated) ? $validated['lat'] : $captura->lat,
                'lng' => array_key_exists('lng', $validated) ? $validated['lng'] : $captura->lng,
                'coordenadas_texto' => array_key_exists('coordenadas_texto', $validated) ? $this->nullableString($validated['coordenadas_texto']) : $captura->coordenadas_texto,
                'narrativa' => array_key_exists('narrativa', $validated) ? $this->nullableString($validated['narrativa']) : $captura->narrativa,
                'observaciones' => array_key_exists('observaciones', $validated) ? $this->nullableString($validated['observaciones']) : $captura->observaciones,
                'rnd_data' => ($this->canUseRnd($user) && array_key_exists('rnd_data', $validated))
                    ? $this->normalizeRndData($validated['rnd_data'])
                    : $captura->rnd_data,
            ]);
            $captura->save();

            if ($campoFundamentoPresente) {
                $this->replaceFundamentosCaptura($captura, $fundamentos, $validated);
            }

            $this->replaceVehiculos(
                $captura,
                $validated['vehiculos'] ?? [],
                $fundamentos,
                $usaFundamentoUnificado
            );
            $this->replacePersonas(
                $captura,
                $validated['personas'] ?? [],
                $this->esOperativoAlcoholimetria($operativo),
                $usaFundamentoUnificado
            );
            $this->storeFotos($captura, $request, $user);
        });

        $captura->load(['creador', 'unidad', 'delegacion', 'infraccion', 'fundamentos.infraccion', 'vehiculos.infraccion', 'personas.infraccion', 'fotos']);

        return response()->json([
            'ok' => true,
            'message' => 'Captura actualizada correctamente.',
            'data' => $this->capturaPayload($captura, $user),
        ]);
    }

    public function destroyCaptura(Request $request, ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura)
    {
        $user = $request->user();
        $this->assertPuedeVerOperativo($operativo, $user);
        abort_unless($captura->operativo_id === $operativo->id, 404);
        abort_unless($this->canDeleteCaptura($user), 403);
        $this->assertPuedeAlimentarOperativo($operativo, $user);

        $captura->delete();

        return response()->json([
            'ok' => true,
            'message' => 'Captura eliminada correctamente.',
        ]);
    }

    public function sendRndChatbot(Request $request, ConduceLegalidadOperativo $operativo, WhatsAppCloudService $whatsApp)
    {
        $user = $request->user();
        abort_unless($this->canUseRnd($user), 403);
        $this->assertPuedeVerOperativo($operativo, $user);

        $validated = $request->validate([
            'captura_id' => ['nullable', 'integer'],
            'rnd_data' => ['required', 'array'],
            'rnd_data.*' => ['nullable', 'string', 'max:2000'],
            'message' => ['nullable', 'string', 'max:12000'],
            'solicitante_nombre' => ['nullable', 'string', 'max:255'],
            'solicitante_telefono' => ['nullable', 'string', 'max:30'],
        ]);

        $rndData = $this->normalizeRndData($validated['rnd_data'] ?? []);
        if ($rndData === null) {
            throw ValidationException::withMessages([
                'rnd_data' => 'Captura al menos un dato RND.',
            ]);
        }

        $captura = null;
        $capturaId = (int) ($validated['captura_id'] ?? 0);
        if ($capturaId > 0) {
            $captura = $operativo->capturas()->whereKey($capturaId)->first();
            abort_unless($captura, 404);
            abort_unless($this->canEditCaptura($user, $captura), 403);
            $this->assertPuedeAlimentarOperativo($operativo, $user);

            $captura->rnd_data = $rndData;
            $captura->save();
        }

        $usuario = $this->nullableString($validated['solicitante_nombre'] ?? null)
            ?: $this->nombreUsuario($user);
        $telefono = $this->nullableString($validated['solicitante_telefono'] ?? null)
            ?: $this->nullableString(data_get($user, 'telefono'))
            ?: $this->nullableString(data_get($user, 'personal.telefono'))
            ?: 'SIN DATO';
        $referencia = 'Operativo ' . $operativo->id . ($captura ? ' / Captura ' . $captura->id : '');
        $message = $this->nullableString($validated['message'] ?? null)
            ?: $this->rndMessage($rndData, $usuario, $telefono, $referencia);

        $to = (string) config('services.whatsapp.conduce_legalidad.rnd_chatbot_to', '5214433163728');
        $template = (string) config('services.whatsapp.conduce_legalidad.rnd_chatbot_template', 'solicitud_rnd_faltas_administrativas');
        $language = (string) config('services.whatsapp.conduce_legalidad.rnd_chatbot_template_language', 'es_MX');

        $response = $whatsApp->sendTemplate($to, $template, [
            $usuario,
            $telefono,
            $referencia,
            $message,
        ], $language);

        if (!($response['ok'] ?? false)) {
            return response()->json([
                'ok' => false,
                'message' => 'Meta no acepto la solicitud RND. Revisa la plantilla/configuracion de WhatsApp.',
                'meta' => $response['body'] ?? null,
            ], 502);
        }

        return response()->json([
            'ok' => true,
            'message' => 'Solicitud RND enviada al chatbot.',
            'data' => [
                'to' => preg_replace('/\D+/', '', $to) ?: $to,
                'template' => $template,
                'language' => $language,
                'referencia' => $referencia,
            ],
        ]);
    }
    public function nativeShareOperativo(Request $request, ConduceLegalidadOperativo $operativo)
    {
        $user = $request->user();
        abort_unless($this->canManage($user), 403);
        $this->assertPuedeVerOperativo($operativo, $user);

        $operativo->loadMissing(['creador']);

        $capturas = $operativo->capturas()
            ->with(['creador', 'unidad', 'delegacion', 'infraccion', 'fundamentos.infraccion', 'vehiculos.infraccion', 'personas.infraccion', 'fotos'])
            ->orderBy('fecha')
            ->orderBy('hora')
            ->orderBy('id')
            ->get();

        $texto = $this->tarjetaTotalesOperativo($operativo, $capturas, $user);

        return response()->json([
            'ok' => true,
            'data' => [
                'title' => 'Resumen ' . $this->nombreTicketOperativo($operativo),
                'texto' => trim($texto),
                'message' => trim($texto),
                'media' => [],
                'fotos' => [],
                'operativo_id' => $operativo->id,
                'tipo' => 'operativo_totales',
            ],
        ]);
    }

    public function nativeShareCaptura(Request $request, ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura)
    {
        $user = $request->user();
        abort_unless($user, 403);
        $this->assertPuedeVerOperativo($operativo, $user);
        abort_unless($captura->operativo_id === $operativo->id, 404);

        $query = $operativo->capturas()->whereKey($captura->id);
        $this->scopeCapturas($query, $user);
        abort_unless($query->exists(), 404);

        $operativo->loadMissing(['creador']);
        $captura->loadMissing(['creador', 'unidad', 'delegacion', 'infraccion', 'fundamentos.infraccion', 'vehiculos.infraccion', 'personas.infraccion', 'fotos']);

        $texto = $this->tarjetaCapturaOperativo($operativo, $captura, $user);
        $fotos = $captura->fotos
            ->map(fn (ConduceLegalidadFoto $foto) => $this->storageUrl($foto->foto_path))
            ->filter()
            ->unique()
            ->values()
            ->all();

        return response()->json([
            'ok' => true,
            'data' => [
                'title' => 'Captura Operativo Conduce con Legalidad',
                'texto' => trim($texto),
                'message' => trim($texto),
                'foto' => $fotos[0] ?? null,
                'fotos' => $fotos,
                'media' => $fotos,
                'operativo_id' => $operativo->id,
                'captura_id' => $captura->id,
                'tipo' => 'captura_individual',
            ],
        ]);
    }

    public function enviarBoletaWhatsApp(
        Request $request,
        ConduceLegalidadOperativo $operativo,
        ConduceLegalidadCaptura $captura,
        WhatsAppCloudService $whatsApp
    ) {
        $user = $request->user();
        abort_unless($user, 403);
        $this->assertPuedeVerOperativo($operativo, $user);
        abort_unless($captura->operativo_id === $operativo->id, 404);
        abort_unless(!$this->esOperativoAlcoholimetria($operativo), 422, 'La boleta por WhatsApp sólo está disponible para Conduce con Legalidad.');

        $query = $operativo->capturas()->whereKey($captura->id);
        $this->scopeCapturas($query, $user);
        abort_unless($query->exists(), 404);

        $validated = $request->validate([
            'persona_id' => ['nullable', 'integer'],
        ]);

        $operativo->loadMissing(['creador']);
        $captura->loadMissing([
            'creador.personal.unidad',
            'creador.unidad',
            'unidad',
            'delegacion',
            'infraccion',
            'fundamentos.infraccion',
            'vehiculos.infraccion',
            'personas.infraccion',
        ]);

        $personaId = (int) ($validated['persona_id'] ?? 0);
        $persona = $personaId > 0
            ? $captura->personas->firstWhere('id', $personaId)
            : $captura->personas->first(function (ConduceLegalidadPersona $item) {
                $telefono = TelefonoMexico::normalize($item->telefono);
                return $telefono !== null && preg_match('/^\d{10}$/', $telefono);
            });

        abort_unless($persona, 422, 'La captura no tiene una persona con teléfono para enviar la boleta.');

        $telefono = TelefonoMexico::normalize($persona->telefono);
        if (!$telefono || !preg_match('/^\d{10}$/', $telefono)) {
            throw ValidationException::withMessages([
                'telefono' => 'El teléfono capturado debe tener 10 dígitos para enviar la boleta por WhatsApp.',
            ]);
        }

        $prefix = preg_replace('/\D+/', '', (string) config(
            'services.whatsapp.conduce_legalidad.boleta_country_prefix',
            '521'
        )) ?: '521';
        $to = $prefix . $telefono;
        $template = trim((string) config(
            'services.whatsapp.conduce_legalidad.boleta_template',
            'boleta_conduce_legalidad_v1'
        ));
        $language = trim((string) config(
            'services.whatsapp.conduce_legalidad.boleta_template_language',
            'es_MX'
        )) ?: 'es_MX';
        $boleta = $this->boletaWhatsAppData($operativo, $captura, $persona, $user);
        $filename = 'boleta_' . Str::slug($boleta['folio'], '_') . '.pdf';
        $tempPath = sys_get_temp_dir() . DIRECTORY_SEPARATOR
            . 'boleta_conduce_' . Str::uuid() . '.pdf';

        try {
            $pdf = Pdf::loadView('pdf.conduce_legalidad_boleta', [
                'boleta' => $boleta,
            ])->setPaper('letter');
            file_put_contents($tempPath, $pdf->output());

            $upload = $whatsApp->uploadMedia($tempPath, 'application/pdf');
            $mediaId = data_get($upload, 'body.id');
            if (!($upload['ok'] ?? false) || !$mediaId) {
                return response()->json([
                    'ok' => false,
                    'message' => 'No se pudo preparar el PDF de la boleta para WhatsApp. Intenta nuevamente.',
                ], 502);
            }

            $response = $whatsApp->sendDocumentTemplate(
                $to,
                $template,
                (string) $mediaId,
                $filename,
                [
                    $boleta['folio'],
                    $boleta['persona_nombre'],
                    $boleta['fecha_hora'],
                    $boleta['vehiculo_resumen'],
                ],
                $language
            );

            if (!($response['ok'] ?? false)) {
                return response()->json([
                    'ok' => false,
                    'message' => 'WhatsApp no aceptó el envío. Verifica que la plantilla esté aprobada en Meta y vuelve a intentar.',
                ], 502);
            }
        } catch (\Throwable $e) {
            report($e);

            return response()->json([
                'ok' => false,
                'message' => 'No fue posible comunicarse con WhatsApp en este momento. Intenta nuevamente.',
            ], 502);
        } finally {
            if (is_file($tempPath)) {
                @unlink($tempPath);
            }
        }

        return response()->json([
            'ok' => true,
            'message' => 'Boleta enviada por WhatsApp al teléfono terminado en ' . substr($telefono, -4) . '.',
            'data' => [
                'folio' => $boleta['folio'],
                'telefono_terminacion' => substr($telefono, -4),
                'template' => $template,
                'language' => $language,
            ],
        ]);
    }

    private function boletaWhatsAppData(
        ConduceLegalidadOperativo $operativo,
        ConduceLegalidadCaptura $captura,
        ConduceLegalidadPersona $persona,
        $user
    ): array {
        $vehiculo = $captura->vehiculos->first();
        $adscripcion = $this->adscripcionTicket($operativo, $user, $captura);
        $supervisor = $this->supervisorTicket(
            $adscripcion['unidad_id'],
            $adscripcion['delegacion_id']
        );
        $creador = $captura->creador;
        $creadorPayload = $this->userPayload($creador);

        $personaNombre = $this->joinText([
            $persona->nombre,
            $this->joinText([
                $persona->nombres,
                $persona->apellido_paterno,
                $persona->apellido_materno,
            ], ' '),
        ], ' ');

        $sanciones = $captura->fundamentos
            ->map(fn (ConduceLegalidadCapturaFundamento $fundamento) => $fundamento->infraccion
                ? $this->nullableString($fundamento->infraccion->resumen_sanciones)
                : null)
            ->filter()
            ->values();
        if ($captura->infraccion && $this->nullableString($captura->infraccion->resumen_sanciones)) {
            $sanciones->push($captura->infraccion->resumen_sanciones);
        }
        if ($vehiculo && $vehiculo->infraccion && $this->nullableString($vehiculo->infraccion->resumen_sanciones)) {
            $sanciones->push($vehiculo->infraccion->resumen_sanciones);
        }

        $conducta = $this->nullableString($captura->narrativa)
            ?: ($captura->infraccion ? $this->textoOperativoInfraccion($captura->infraccion) : null)
            ?: ($vehiculo && $vehiculo->infraccion ? $this->textoOperativoInfraccion($vehiculo->infraccion) : null)
            ?: ($vehiculo ? $this->nullableString($vehiculo->motivo_retencion) : null)
            ?: 'Conducta asentada en la intervención del operativo.';

        $vigenciaLicencia = $persona->permanente
            ? 'Permanente'
            : (optional($persona->vigencia_licencia)->format('d/m/Y') ?: 'No capturada');
        $licencia = $this->joinText([
            $persona->tipo_licencia ? 'Tipo: ' . $persona->tipo_licencia : null,
            $persona->numero_licencia ? 'Número: ' . $persona->numero_licencia : null,
            $persona->estado_licencia ? 'Estado: ' . $persona->estado_licencia : null,
            'Vigencia: ' . $vigenciaLicencia,
        ], ' · ');

        $placaAgente = $this->nullableString($captura->agente_numero_placa)
            ?: $this->nullableString(data_get($creadorPayload, 'numero_placa'));
        $unidadAgente = $this->nullableString($captura->agente_adscripcion)
            ?: $this->nullableString(data_get($creadorPayload, 'adscripcion'))
            ?: $this->unidadOperativaTexto($adscripcion['unidad_id']);
        $delegacion = $this->delegacionTexto($adscripcion['delegacion_id']);
        $lugar = $this->lugarConNumero(
            $this->nullableString($captura->lugar) ?: $this->nullableString($operativo->lugar),
            $operativo->numero
        );

        return [
            'folio' => 'CL-' . $operativo->id . '-' . $captura->id,
            'municipio' => $captura->municipio ?: $operativo->municipio ?: 'No capturado',
            'fecha' => optional($captura->fecha)->format('d/m/Y') ?: 'No capturada',
            'hora' => $this->horaCorta($captura->hora) ?: 'No capturada',
            'fecha_hora' => $this->fechaHoraCaptura($captura),
            'lugar' => $lugar ?: 'No capturado',
            'fundamento' => $this->fundamentosIphCaptura($captura),
            'sancion' => $sanciones->unique()->implode('; ') ?: 'La asentada en la boleta de notificación.',
            'conducta' => $conducta,
            'persona_nombre' => $personaNombre ?: 'No proporcionado',
            'persona_domicilio' => $persona->domicilio ?: 'No proporcionado',
            'vehiculo_resumen' => $vehiculo ? $this->vehiculoResumen($vehiculo) : 'No capturado',
            'placas' => $vehiculo && $vehiculo->placas ? $vehiculo->placas : 'No capturadas',
            'estado_placas' => $vehiculo && $vehiculo->estado_placas ? $vehiculo->estado_placas : 'No capturado',
            'numero_inventario' => $vehiculo && $vehiculo->numero_inventario ? $vehiculo->numero_inventario : 'No capturado',
            'corralon' => $vehiculo ? ($this->valorCorralon($vehiculo) ?: 'No capturado') : 'No capturado',
            'grua' => $vehiculo ? ($this->valorGrua($vehiculo) ?: 'No capturada') : 'No capturada',
            'licencia' => $licencia ?: 'No capturada',
            'requiere_liberacion' => $vehiculo ? $this->vehiculoResguardado($vehiculo) : false,
            'liberacion' => 'La liberación del vehículo deberá tramitarse ante la autoridad competente, presentando la documentación aplicable y esta boleta.',
            'agente_nombre' => $this->nullableString($captura->agente_nombre)
                ?: ($creador ? $this->nombreUsuario($creador) : 'No capturado'),
            'agente_placa' => $placaAgente ?: 'No capturada',
            'adscripcion' => $this->joinText([$unidadAgente, $delegacion], ' · '),
            'coordinador_nombre' => self::TICKET_COORDINADOR_NOMBRE,
            'coordinador_cargo' => self::TICKET_COORDINADOR_CARGO,
            'supervisor_nombre' => $supervisor['nombre'],
            'supervisor_cargo' => $supervisor['cargo'],
        ];
    }

    public function descargarIphCaptura(
        Request $request,
        ConduceLegalidadOperativo $operativo,
        ConduceLegalidadCaptura $captura,
        IphPuestaDisposicionDocxService $docxService
    ) {
        $user = $request->user();
        abort_unless($user, 403);
        $this->assertPuedeVerOperativo($operativo, $user);
        abort_unless($captura->operativo_id === $operativo->id, 404);

        $query = $operativo->capturas()->whereKey($captura->id);
        $this->scopeCapturas($query, $user);
        abort_unless($query->exists(), 404);

        $operativo->loadMissing(['creador']);
        $captura->loadMissing([
            'creador.personal.unidad',
            'creador.unidad',
            'unidad',
            'delegacion',
            'infraccion',
            'vehiculos.infraccion',
            'vehiculos.gruaRelacion',
            'vehiculos.corralonRelacion',
            'personas.infraccion',
            'fotos',
        ]);

        $formato = $this->formatoIphCaptura($request);
        $hecho = $this->hechoTemporalIph($operativo, $captura);
        $mapeo = $this->mapearIphDesdeCaptura($operativo, $captura, $user);

        [$path, $filename] = $formato === self::FORMATO_IPH_ANTERIOR
            ? $docxService->generar($hecho, $mapeo)
            : $docxService->generarConduceLegalidadBarandillas($hecho, $mapeo);

        return response()->download($path, $filename, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ])->deleteFileAfterSend(true);
    }

    private function formatoIphCaptura(Request $request): string
    {
        $value = $request->query('formato', $request->query('formato_impresion', $request->query('tipo_formato')));
        $formato = $this->normalizarFormatoIph($value);

        if ($formato === '') {
            return self::FORMATO_IPH_BARANDILLAS;
        }

        $aliases = [
            'barandillas' => self::FORMATO_IPH_BARANDILLAS,
            'actual' => self::FORMATO_IPH_BARANDILLAS,
            'nuevo' => self::FORMATO_IPH_BARANDILLAS,
            'formato_nuevo' => self::FORMATO_IPH_BARANDILLAS,
            'formato_actual' => self::FORMATO_IPH_BARANDILLAS,
            'nuevo_barandillas' => self::FORMATO_IPH_BARANDILLAS,
            'plantilla' => self::FORMATO_IPH_BARANDILLAS,
            'plantilla_barandillas' => self::FORMATO_IPH_BARANDILLAS,
            'iph_barandillas' => self::FORMATO_IPH_BARANDILLAS,
            'anterior' => self::FORMATO_IPH_ANTERIOR,
            'clasico' => self::FORMATO_IPH_ANTERIOR,
            'compacto' => self::FORMATO_IPH_ANTERIOR,
            'formato_anterior' => self::FORMATO_IPH_ANTERIOR,
            'legacy' => self::FORMATO_IPH_ANTERIOR,
            'viejo' => self::FORMATO_IPH_ANTERIOR,
            'iph' => self::FORMATO_IPH_ANTERIOR,
            'iph_completo' => self::FORMATO_IPH_ANTERIOR,
            'oficial' => self::FORMATO_IPH_ANTERIOR,
            'ticket' => self::FORMATO_IPH_ANTERIOR,
            'termico' => self::FORMATO_IPH_ANTERIOR,
            'termica' => self::FORMATO_IPH_ANTERIOR,
            '48' => self::FORMATO_IPH_ANTERIOR,
            '48mm' => self::FORMATO_IPH_ANTERIOR,
            '48_mm' => self::FORMATO_IPH_ANTERIOR,
            '50' => self::FORMATO_IPH_ANTERIOR,
            '50mm' => self::FORMATO_IPH_ANTERIOR,
            '50_mm' => self::FORMATO_IPH_ANTERIOR,
            '58' => self::FORMATO_IPH_ANTERIOR,
            '58mm' => self::FORMATO_IPH_ANTERIOR,
            '58_mm' => self::FORMATO_IPH_ANTERIOR,
        ];

        if (!isset($aliases[$formato])) {
            throw ValidationException::withMessages([
                'formato' => 'Selecciona un formato de impresion valido.',
            ]);
        }

        return $aliases[$formato];
    }

    private function normalizarFormatoIph($value): string
    {
        $text = trim((string) ($value ?? ''));
        if ($text === '') {
            return '';
        }

        $text = Str::lower(Str::ascii($text));
        $text = str_replace([' ', '-'], '_', $text);

        return preg_replace('/[^a-z0-9_]+/', '', $text) ?? '';
    }

    private function hechoTemporalIph(ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura): Hechos
    {
        $folio = $this->folioCaptura($operativo, $captura);
        $lugar = $this->lugarConNumero(
            $this->nullableString($captura->lugar) ?: $this->nullableString($operativo->lugar),
            $operativo->numero
        );
        $codigoPostal = $this->codigoPostalOperativo($operativo);
        $hecho = new Hechos();
        $hecho->forceFill([
            'id' => $captura->id,
            'folio_c5i' => $folio,
            'fecha' => $captura->fecha ?: $operativo->fecha,
            'hora' => $captura->hora ?: $operativo->hora_inicio,
            'tipo_hecho' => 'RETIRO DE VEHICULO DERIVADO DE OPERATIVO CONDUCE CON LEGALIDAD',
            'municipio' => $captura->municipio ?: $operativo->municipio,
            'calle' => $lugar,
            'colonia' => $operativo->colonia,
            'codigo_postal' => $codigoPostal,
            'ubicacion_formateada' => $lugar,
            'lat' => $captura->lat ?: $operativo->lat,
            'lng' => $captura->lng ?: $operativo->lng,
        ]);

        return $hecho;
    }

    private function mapearIphDesdeCaptura(ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura, $user): array
    {
        $folio = $this->folioCaptura($operativo, $captura);
        $fecha = optional($captura->fecha ?: $operativo->fecha)->toDateString();
        $hora = $this->horaCorta($captura->hora ?: $operativo->hora_inicio);
        $lugar = $this->lugarConNumero(
            $this->nullableString($captura->lugar) ?: $this->nullableString($operativo->lugar),
            $operativo->numero
        );
        $municipio = $this->nullableString($captura->municipio) ?: $this->nullableString($operativo->municipio) ?: 'Morelia';
        $colonia = $this->nullableString($operativo->colonia);
        $codigoPostal = $this->codigoPostalOperativo($operativo);
        $ubicacionFormateada = implode(', ', array_filter([
            $lugar,
            $colonia ? 'Col. ' . $colonia : null,
            $codigoPostal ? 'CP ' . $codigoPostal : null,
        ]));
        $unidadNombre = $this->nullableString($captura->agente_adscripcion)
            ?: $this->nullableString(optional($captura->unidad)->nombre)
            ?: $this->nullableString(optional($captura->creador)->unidad->nombre ?? null)
            ?: 'Coordinación del Agrupamiento de Seguridad Vial';
        $agenteNombre = $this->nullableString($captura->agente_nombre)
            ?: $this->nullableString(optional($captura->creador)->name)
            ?: $this->nullableString($user->name ?? null)
            ?: 'Elemento actuante';
        $agentePartes = $this->partesAgenteCaptura($agenteNombre, $captura);
        $narrativaOperativa = $this->narrativaIphConduceLegalidad($operativo, $captura);
        $dinamica = $this->dinamicaIphConduceLegalidad($operativo, $captura, $narrativaOperativa);
        $fundamento = $this->fundamentosIphCaptura($captura);
        $primerFoto = $captura->fotos->first();

        return [
            'opciones' => [
                'incluir_parte_informativo' => false,
            ],
            'hecho' => [
                'id' => $captura->id,
                'folio_c5i' => $folio,
                'fecha' => $fecha,
                'hora' => $hora,
                'situacion' => 'Atendido',
                'perito' => $agenteNombre,
                'creador_nombre' => $agenteNombre,
                'unidad_numero_economico' => '',
                'unidad_org_id' => (int) ($captura->unidad_id ?: self::UNIDAD_SEGURIDAD_VIAL),
                'unidad_org_nombre' => $unidadNombre,
                'delegacion_id' => $captura->delegacion_id,
                'delegacion_nombre' => optional($captura->delegacion)->nombre,
                'oficio_mp' => $folio,
                'vehiculos_mp' => $captura->vehiculos->count(),
                'personas_mp' => $captura->personas->count(),
                'lesionados_count' => 0,
                'fallecidos_count' => 0,
                'tipo_hecho' => 'RETIRO DE VEHICULO DERIVADO DE OPERATIVO CONDUCE CON LEGALIDAD',
                'tiempo' => '',
                'clima' => '',
                'condiciones' => '',
                'causas' => $this->causaIphCaptura($captura),
                'colision_camino' => '',
                'dinamica_hecho' => $dinamica,
                'narrativa_operativa' => $narrativaOperativa,
                'conclusion_causa' => $this->conclusionCausaIphCaptura($captura, $fundamento),
                'conclusion_disposicion' => $this->conclusionDisposicionIphCaptura($captura, $fundamento),
                'ubicacion' => [
                    'calle' => $lugar,
                    'colonia' => $colonia ?: '',
                    'entre_calles' => '',
                    'municipio' => $municipio,
                    'codigo_postal' => $codigoPostal ?: '',
                    'lat' => $captura->lat ?: $operativo->lat,
                    'lng' => $captura->lng ?: $operativo->lng,
                    'ubicacion_formateada' => $ubicacionFormateada,
                    'place_id' => null,
                ],
            ],
            'puesta_disposicion' => [
                'id' => null,
                'folio' => $folio,
                'numero_puesta' => $folio,
                'anio' => now('America/Mexico_City')->format('Y'),
                'tipo_puesta' => 'RETIRO Y RESGUARDO DE VEHICULO',
                'motivo' => $fundamento,
                'estatus' => 'Generado desde operativo',
                'nombre_policia' => $agenteNombre,
                'agente_nombres' => $agentePartes['nombres'],
                'agente_apellido_paterno' => $agentePartes['apellido_paterno'],
                'agente_apellido_materno' => $agentePartes['apellido_materno'],
                'agente_numero_placa' => $this->nullableString($captura->agente_numero_placa),
                'nombre_mp' => '',
                'autoridad_receptora' => 'AUTORIDAD COMPETENTE PARA LOS FINES LEGALES PROCEDENTES',
                'area' => $unidadNombre,
                'carpeta_investigacion' => '',
                'oficio' => $folio,
                'fecha_puesta' => $fecha,
                'hora_puesta' => $hora,
                'lugar_puesta' => $lugar,
                'narrativa' => $dinamica,
                'narrativa_operativa' => $narrativaOperativa,
                'conclusion_causa' => $this->conclusionCausaIphCaptura($captura, $fundamento),
                'conclusion_disposicion' => $this->conclusionDisposicionIphCaptura($captura, $fundamento),
                'observaciones' => $captura->observaciones,
                'unidad_id' => (int) ($captura->unidad_id ?: self::UNIDAD_SEGURIDAD_VIAL),
                'unidad_nombre' => $unidadNombre,
                'delegacion_id' => $captura->delegacion_id,
                'delegacion_nombre' => optional($captura->delegacion)->nombre,
                'destacamento_id' => null,
                'destacamento_nombre' => null,
            ],
            'vehiculos_hecho' => $this->vehiculosIphCaptura($captura),
            'conductores_hecho' => $this->conductoresIphCaptura($captura),
            'lesionados_hecho' => [],
            'personas' => $this->personasIphCaptura($captura),
            'vehiculos' => $this->vehiculosPuestaIphCaptura($captura),
            'objetos' => [],
            'anexos' => [
                'foto_lugar' => $primerFoto ? $primerFoto->foto_path : null,
                'foto_situacion' => null,
                'iph_delegaciones_path' => null,
                'archivo_puesta' => null,
                'croquis_preview' => null,
            ],
        ];
    }

    private function folioCaptura(ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura): string
    {
        return $this->prefijoFolioOperativo($operativo) . '-' . $operativo->id . '-' . $captura->id;
    }

    private function parseFolioBusqueda(string $value): ?array
    {
        $folio = Str::upper(trim($value));
        if (!preg_match('/^(CL|PA)-(\d+)-(\d+)(?:-(\d+))?$/', $folio, $matches)) {
            return null;
        }

        return [
            'tipo_operativo' => $matches[1] === 'PA' ? 'alcoholimetria' : 'conduce_legalidad',
            'operativo_id' => (int) $matches[2],
            'captura_id' => (int) $matches[3],
            'ticket_index' => isset($matches[4]) ? (int) $matches[4] : null,
        ];
    }

    private function prefijoFolioOperativo(ConduceLegalidadOperativo $operativo): string
    {
        return $this->esOperativoAlcoholimetria($operativo) ? 'PA' : 'CL';
    }

    private function capturaBusquedaPayload(ConduceLegalidadCaptura $captura): array
    {
        $operativo = $captura->operativo;
        $tipoOperativo = $this->esOperativoAlcoholimetria($operativo)
            ? 'alcoholimetria'
            : 'conduce_legalidad';
        $folioBase = $this->folioCaptura($operativo, $captura);
        $numeroTickets = max(1, $captura->vehiculos->count());
        $folios = $numeroTickets === 1
            ? [$folioBase]
            : collect(range(1, $numeroTickets))
                ->map(fn (int $index) => $folioBase . '-' . $index)
                ->values()
                ->all();

        return [
            'result_type' => 'operativo',
            'module' => $tipoOperativo,
            'module_label' => $tipoOperativo === 'alcoholimetria'
                ? 'Alcoholimetría'
                : 'Conduce con Legalidad',
            'operativo_id' => (int) $operativo->id,
            'captura_id' => (int) $captura->id,
            'folio' => $folioBase,
            'folios' => $folios,
            'fecha' => optional($captura->fecha ?: $operativo->fecha)->toDateString(),
            'hora' => $this->horaCorta($captura->hora ?: $operativo->hora_inicio),
            'municipio' => $this->nullableString($captura->municipio)
                ?: $this->nullableString($operativo->municipio),
            'lugar' => $this->nullableString($captura->lugar)
                ?: $this->lugarConNumero($operativo->lugar, $operativo->numero),
            'colonia' => $operativo->colonia,
            'creador' => $this->nullableString(optional($captura->creador)->name),
            'personas' => $captura->personas->map(function (ConduceLegalidadPersona $persona) {
                $nombre = collect([
                    $persona->nombres,
                    $persona->apellido_paterno,
                    $persona->apellido_materno,
                ])->filter(fn ($value) => $this->nullableString($value) !== null)->implode(' ');

                return [
                    'nombre' => $this->nullableString($nombre) ?: $this->nullableString($persona->nombre),
                    'telefono' => $persona->telefono,
                    'numero_licencia' => $persona->numero_licencia,
                ];
            })->values(),
            'vehiculos' => $captura->vehiculos->map(fn (ConduceLegalidadVehiculo $vehiculo) => [
                'marca' => $vehiculo->marca,
                'modelo' => $vehiculo->modelo,
                'linea' => $vehiculo->linea,
                'placas' => $vehiculo->placas,
                'serie' => $vehiculo->serie,
                'numero_inventario' => $vehiculo->numero_inventario,
            ])->values(),
        ];
    }

    private function vehiculosIphCaptura(ConduceLegalidadCaptura $captura): array
    {
        return $captura->vehiculos->values()->map(function (ConduceLegalidadVehiculo $vehiculo, int $index) use ($captura) {
            $persona = $this->personaPorIndice($captura, $index);
            $grua = $vehiculo->gruaRelacion;
            $corralon = $vehiculo->corralonRelacion;

            return [
                'id' => $vehiculo->id,
                'tipo' => $vehiculo->tipo ?: ($vehiculo->tipo_general ?: 'Vehiculo'),
                'marca' => $vehiculo->marca,
                'linea' => $vehiculo->linea,
                'modelo' => $vehiculo->modelo,
                'color' => $vehiculo->color,
                'placas' => $vehiculo->placas,
                'estado_placas' => $vehiculo->estado_placas,
                'serie' => $vehiculo->serie,
                'numero_inventario' => $vehiculo->numero_inventario,
                'capacidad_personas' => $vehiculo->capacidad_personas,
                'tipo_servicio' => $vehiculo->tipo_servicio,
                'tarjeta_circulacion_nombre' => $vehiculo->tarjeta_circulacion_nombre,
                'foto' => null,
                'grua' => $vehiculo->grua ?: optional($grua)->nombre,
                'grua_id' => $vehiculo->grua_id,
                'grua_nombre' => optional($grua)->nombre ?: $vehiculo->grua,
                'grua_direccion' => optional($grua)->direccion ?: optional($corralon)->direccion,
                'grua_ubicacion_corralon' => optional($grua)->ubicacion_corralon ?: optional($corralon)->ubicacion_corralon,
                'corralon' => $vehiculo->corralon ?: optional($corralon)->nombre,
                'monto_danos' => $vehiculo->monto_danos,
                'partes_danadas' => $vehiculo->partes_danadas,
                'aseguradora' => $vehiculo->aseguradora,
                'antecedente_vehiculo' => (bool) $vehiculo->antecedente_vehiculo,
                'conductores' => $persona ? [$this->conductorIph($persona)] : [],
            ];
        })->values()->all();
    }

    private function conductoresIphCaptura(ConduceLegalidadCaptura $captura): array
    {
        return $captura->personas->values()->map(function (ConduceLegalidadPersona $persona, int $index) use ($captura) {
            $vehiculo = $captura->vehiculos->get($index) ?: $captura->vehiculos->first();
            $data = $this->conductorIph($persona);
            $data['vehiculo_id'] = optional($vehiculo)->id;
            $data['vehiculo_label'] = $vehiculo ? $this->vehiculoLabel($vehiculo) : '';

            return $data;
        })->values()->all();
    }

    private function personasIphCaptura(ConduceLegalidadCaptura $captura): array
    {
        return $captura->personas->values()->map(function (ConduceLegalidadPersona $persona, int $index) use ($captura) {
            $vehiculo = $captura->vehiculos->get($index) ?: $captura->vehiculos->first();

            return [
                'nombre_completo' => $persona->nombre,
                'alias' => null,
                'edad' => $persona->edad,
                'sexo' => $persona->sexo,
                'nacionalidad' => $persona->nacionalidad,
                'fecha_nacimiento' => null,
                'curp' => null,
                'rfc' => null,
                'domicilio' => $persona->domicilio,
                'calidad' => 'Persona conductora o interviniente',
                'delito_o_motivo' => $vehiculo ? $this->motivoIphVehiculo($vehiculo) : 'Operativo Conduce con Legalidad',
                'orden_aprehension' => false,
                'mandamiento_judicial' => null,
                'observaciones' => $persona->observaciones,
            ] + $this->camposDescripcionFisicaIph($persona);
        })->values()->all();
    }

    private function vehiculosPuestaIphCaptura(ConduceLegalidadCaptura $captura): array
    {
        return $captura->vehiculos->values()->map(fn (ConduceLegalidadVehiculo $vehiculo) => [
            'vehiculo_id' => $vehiculo->id,
            'tipo' => $vehiculo->tipo ?: ($vehiculo->tipo_general ?: 'Vehiculo'),
            'marca' => $vehiculo->marca,
            'submarca' => $vehiculo->linea,
            'modelo' => $vehiculo->modelo,
            'color' => $vehiculo->color,
            'placas' => $vehiculo->placas,
            'serie' => $vehiculo->serie,
            'calidad' => 'Vehiculo retirado o resguardado',
            'motivo_relacion' => $this->motivoIphVehiculo($vehiculo),
            'con_reporte_robo' => false,
            'numero_reporte_robo' => null,
            'observaciones' => $vehiculo->observaciones,
        ])->values()->all();
    }

    private function conductorIph(ConduceLegalidadPersona $persona): array
    {
        return [
            'nombre' => $persona->nombre,
            'nombre_completo' => $persona->nombre,
            'alias' => null,
            'edad' => $persona->edad,
            'sexo' => $persona->sexo,
            'nacionalidad' => $persona->nacionalidad,
            'domicilio' => $persona->domicilio,
            'ocupacion' => $persona->ocupacion,
            'numero_licencia' => $persona->numero_licencia,
            'tipo_licencia' => $persona->tipo_licencia,
            'estado_licencia' => $persona->estado_licencia,
            'vigencia_licencia' => optional($persona->vigencia_licencia)->toDateString(),
            'antecedentes' => false,
            'certificado_lesiones' => null,
            'certificado_alcoholemia' => null,
            'aliento_etilico' => null,
        ] + $this->camposDescripcionFisicaIph($persona);
    }

    private function camposDescripcionFisicaIph(ConduceLegalidadPersona $persona): array
    {
        return [
            'edad_aproximada' => $persona->edad_aproximada,
            'complexion' => $persona->complexion,
            'estatura' => $persona->estatura,
            'tez' => $persona->tez,
            'cabello' => $persona->cabello,
            'prenda_superior' => $persona->prenda_superior,
            'color_superior' => $persona->color_superior,
            'prenda_inferior' => $persona->prenda_inferior,
            'color_inferior' => $persona->color_inferior,
            'calzado' => $persona->calzado,
            'color_calzado' => $persona->color_calzado,
            'rasgos_visibles' => $persona->rasgos_visibles ?: [],
        ];
    }

    private function narrativaIphConduceLegalidad(ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura): string
    {
        $fundamento = $this->fundamentosIphCaptura($captura);
        $vehiculos = $captura->vehiculos->values()
            ->map(fn (ConduceLegalidadVehiculo $vehiculo) => $this->vehiculoLabel($vehiculo))
            ->filter()
            ->implode('; ');
        $personas = $captura->personas->pluck('nombre')->filter()->implode(', ');
        $lugar = $this->lugarConNumero(
            $this->nullableString($captura->lugar) ?: $this->nullableString($operativo->lugar),
            $operativo->numero
        ) ?: 'el punto del operativo';
        $capturada = $this->nullableString($captura->narrativa);

        $lineas = [
            'Durante el Operativo Conduce con Legalidad, en ' . $lugar . ', el personal actuante detecto el vehiculo o vehiculos registrados en el sistema' . ($vehiculos ? ': ' . $vehiculos : '') . '.',
            $personas ? 'Se relaciono como persona conductora o interviniente a: ' . $personas . '.' : null,
            $capturada ? 'Narrativa asentada por el elemento actuante: ' . $capturada : null,
            'La intervencion se documenta con base en el fundamento especifico capturado para la conducta observada: ' . $fundamento . '.',
            'La medida de retiro o resguardo se registra para impedir la continuacion de la conducta y preservar la seguridad vial. Cuando el supuesto operativo derive de falta de licencia o permiso vigente, se deja constancia de que no se asienta como causal automatica de deposito; se documenta la falta de habilitacion juridica para continuar conduciendo y la ausencia de alternativa inmediata legalmente viable para que una persona habilitada se haga cargo del vehiculo en condiciones seguras.',
            'El traslado, entrega, inventario y resguardo del vehiculo deberan quedar soportados con los datos de grua, corralon, fotografias, boleta de infraccion y demas constancias operativas disponibles.',
        ];

        return collect($lineas)->filter()->implode(' ');
    }

    private function dinamicaIphConduceLegalidad(ConduceLegalidadOperativo $operativo, ConduceLegalidadCaptura $captura, string $narrativaOperativa): string
    {
        $fecha = optional($captura->fecha ?: $operativo->fecha)->format('d-m-Y');
        $hora = $this->horaCorta($captura->hora ?: $operativo->hora_inicio);

        return 'El dia ' . ($fecha ?: 'no especificado') . ', aproximadamente a las ' . ($hora ?: 'hora no especificada') . ' horas, en el marco del Operativo Conduce con Legalidad, se realizo la intervencion preventiva y administrativa descrita. ' . $narrativaOperativa;
    }

    private function conclusionCausaIphCaptura(ConduceLegalidadCaptura $captura, string $fundamento): string
    {
        return 'UNICA.- La intervencion documentada corresponde a la deteccion de una conducta en materia de transito y seguridad vial dentro del Operativo Conduce con Legalidad, sustentada en el fundamento asentado en la captura: ' . $fundamento . '. La medida descrita se registra para hacer cesar la continuacion de la conducta y preservar la seguridad vial, sin prejuzgar responsabilidades diversas a las que determine la autoridad competente.';
    }

    private function conclusionDisposicionIphCaptura(ConduceLegalidadCaptura $captura, string $fundamento): string
    {
        $vehiculosTexto = $captura->vehiculos->count() === 1 ? 'el vehiculo registrado' : 'los vehiculos registrados';
        $destinos = $captura->vehiculos->map(function (ConduceLegalidadVehiculo $vehiculo) {
            return $this->nullableString($vehiculo->corralon)
                ?: $this->nullableString($vehiculo->grua)
                ?: $this->nullableString(optional($vehiculo->corralonRelacion)->nombre)
                ?: $this->nullableString(optional($vehiculo->gruaRelacion)->nombre);
        })->filter()->unique()->implode(' y ');

        $texto = 'Con base en el fundamento capturado para la intervencion (' . $fundamento . '), se deja constancia de la puesta a resguardo de ' . $vehiculosTexto;

        if ($destinos !== '') {
            $texto .= ' en ' . mb_strtoupper($destinos, 'UTF-8');
        }

        return $texto . ', para los fines administrativos y legales procedentes, quedando sujeto a la documentacion complementaria, inventario, boleta y cadena de resguardo que correspondan.';
    }

    private function causaIphCaptura(ConduceLegalidadCaptura $captura): string
    {
        $causa = $captura->vehiculos
            ->map(fn (ConduceLegalidadVehiculo $vehiculo) => $this->motivoIphVehiculo($vehiculo))
            ->filter()
            ->unique()
            ->implode('; ');

        return $causa ?: 'OPERATIVO CONDUCE CON LEGALIDAD';
    }

    private function fundamentosIphCaptura(ConduceLegalidadCaptura $captura): string
    {
        $captura->loadMissing('fundamentos.infraccion');
        $fundamentosMultiples = $captura->fundamentos
            ->map(function (ConduceLegalidadCapturaFundamento $fundamento) {
                return $this->joinText([
                    $fundamento->infraccion
                        ? $this->nullableString($fundamento->infraccion->referencia_legal_corta)
                        : null,
                    $this->nullableString($fundamento->fundamento_legal),
                    $fundamento->infraccion
                        ? $this->nullableString($fundamento->infraccion->fundamento_legal)
                        : null,
                ], ' - ');
            })
            ->filter()
            ->unique()
            ->implode('; ');
        if ($fundamentosMultiples !== '') {
            return $fundamentosMultiples;
        }

        $fundamentoCaptura = $this->joinText([
            $captura->infraccion ? $this->nullableString($captura->infraccion->referencia_legal_corta) : null,
            $this->nullableString($captura->fundamento_legal),
            $captura->infraccion ? $this->nullableString($captura->infraccion->fundamento_legal) : null,
        ], ' - ');
        if ($fundamentoCaptura !== '') {
            return $fundamentoCaptura;
        }

        $fundamentos = $captura->vehiculos
            ->map(fn (ConduceLegalidadVehiculo $vehiculo) => $this->motivoIphVehiculo($vehiculo))
            ->filter()
            ->unique()
            ->values();

        if ($fundamentos->isNotEmpty()) {
            return $fundamentos->implode('; ');
        }

        return 'Ley y Reglamento de Transito y Seguridad Vial aplicables al Operativo Conduce con Legalidad';
    }

    private function motivoIphVehiculo(ConduceLegalidadVehiculo $vehiculo): string
    {
        $infraccion = $vehiculo->infraccion;

        return $this->joinText([
            $infraccion ? $this->nullableString($infraccion->referencia_legal_corta) : null,
            $this->nullableString($vehiculo->fundamento_legal),
            $infraccion ? $this->nullableString($infraccion->fundamento_legal) : null,
            $infraccion ? $this->nullableString($infraccion->resumen_sanciones) : null,
            $this->nullableString($vehiculo->motivo_retencion),
            $infraccion ? $this->textoOperativoInfraccion($infraccion) : null,
        ], ' - ') ?: 'Fundamento operativo capturado para retiro o resguardo del vehiculo';
    }

    private function personaPorIndice(ConduceLegalidadCaptura $captura, int $index): ?ConduceLegalidadPersona
    {
        if ($captura->personas->isEmpty()) {
            return null;
        }

        return $captura->personas->get($index) ?: $captura->personas->first();
    }

    private function vehiculoLabel(ConduceLegalidadVehiculo $vehiculo): string
    {
        return $this->joinText([
            $vehiculo->marca,
            $vehiculo->linea,
            $vehiculo->modelo,
            $vehiculo->tipo_general ?: $vehiculo->tipo,
            $vehiculo->color,
            $vehiculo->placas ? 'placas ' . $vehiculo->placas : null,
            $vehiculo->serie ? 'serie ' . $vehiculo->serie : null,
        ], ' ');
    }

    private function joinText(array $values, string $separator): string
    {
        return collect($values)
            ->map(fn ($value) => trim((string) ($value ?? '')))
            ->filter()
            ->unique(fn ($value) => mb_strtoupper($value, 'UTF-8'))
            ->implode($separator);
    }

    private function tarjetaTotalesOperativo(ConduceLegalidadOperativo $operativo, $capturas, $user): string
    {
        $puntoOperativo = $this->lugarConNumero($operativo->lugar, $operativo->numero);
        $codigoPostal = $this->codigoPostalOperativo($operativo);
        $pairs = [];
        foreach ($capturas as $captura) {
            foreach ($captura->vehiculos as $vehiculo) {
                $pairs[] = [$captura, $vehiculo];
            }
        }

        $resguardados = array_values(array_filter(
            $pairs,
            fn (array $pair) => $this->vehiculoResguardado($pair[1])
        ));

        $adscripcion = $this->adscripcionTicket($operativo, $user);
        $unidadId = $adscripcion['unidad_id'];
        $delegacionId = $adscripcion['delegacion_id'];
        $lines = $this->tarjetaHeaderLines($unidadId, $delegacionId);
        $lines[] = 'TEMA: RESUMEN DE VEHICULOS RESGUARDADOS';
        $lines[] = $this->nombreTicketOperativo($operativo);
        $lines[] = '';
        $lines[] = 'OPERATIVO ID: ' . $operativo->id;
        $lines[] = 'PUNTO: ' . $this->upper($puntoOperativo ?: 'SIN DATO');
        $lines[] = 'COLONIA: ' . $this->upper($operativo->colonia ?: 'SIN DATO');
        if ($codigoPostal !== null) {
            $lines[] = 'CODIGO POSTAL: ' . $codigoPostal;
        }
        $lines[] = 'MUNICIPIO: ' . $this->upper($operativo->municipio ?: 'SIN DATO');
        $lines[] = 'FECHA: ' . $this->fechaHoraOperativo($operativo) . ' Hrs.';
        $lines[] = 'ESTADO: ' . $this->upper($operativo->estado ?: 'SIN DATO');
        $this->appendCoordenadas($lines, $operativo->lat, $operativo->lng, $operativo->coordenadas_texto);
        $lines[] = '';
        $lines[] = 'TOTAL GENERAL:';
        $lines[] = 'Capturas registradas: ' . $capturas->count();
        $lines[] = 'Vehiculos capturados: ' . count($pairs);
        $lines[] = 'Vehiculos resguardados: ' . count($resguardados);
        $lines[] = 'Personas registradas: ' . $capturas->sum(fn (ConduceLegalidadCaptura $captura) => $captura->personas->count());

        $this->appendDesglose($lines, $resguardados, 'CORRALON', fn (ConduceLegalidadVehiculo $vehiculo) => $this->valorCorralon($vehiculo));
        $this->appendDesglose($lines, $resguardados, 'GRUA', fn (ConduceLegalidadVehiculo $vehiculo) => $this->valorGrua($vehiculo));

        $lines[] = '';
        $lines[] = 'VEHICULOS RESGUARDADOS:';
        if (count($resguardados) === 0) {
            $lines[] = 'SIN VEHICULOS RESGUARDADOS REGISTRADOS.';
        } else {
            foreach ($resguardados as $index => [$captura, $vehiculo]) {
                $lines[] = '';
                $lines[] = 'VEHICULO ' . $this->letraVehiculo($index) . ') ' . $this->vehiculoResumen($vehiculo);
                $lines[] = 'Captura #' . $captura->id . ' - ' . $this->nombreUsuario($captura->creador);
                $this->appendVehiculoRetencion($lines, $vehiculo);
            }
        }

        $lines[] = '';
        $lines[] = 'INFORMA ' . $this->upper($this->unidadOperativaTexto($unidadId));
        $this->appendSupervisorTicket($lines, $unidadId, $delegacionId);

        return implode("\n", $lines);
    }

    private function tarjetaCapturaOperativo(
        ConduceLegalidadOperativo $operativo,
        ConduceLegalidadCaptura $captura,
        $user
    ): string
    {
        $adscripcion = $this->adscripcionTicket($operativo, $user, $captura);
        $unidadId = $adscripcion['unidad_id'];
        $delegacionId = $adscripcion['delegacion_id'];
        $puntoOperativo = $this->lugarConNumero($operativo->lugar, $operativo->numero);
        $lugarCaptura = $this->lugarConNumero(
            $this->nullableString($captura->lugar) ?: $this->nullableString($operativo->lugar),
            $operativo->numero
        );
        $codigoPostal = $this->codigoPostalOperativo($operativo);

        $lines = $this->tarjetaHeaderLines($unidadId, $delegacionId);
        $lines[] = 'TEMA: CAPTURA INDIVIDUAL';
        $lines[] = $this->nombreTicketOperativo($operativo);
        $lines[] = '';
        $lines[] = 'OPERATIVO ID: ' . $operativo->id;
        $lines[] = 'CAPTURA ID: ' . $captura->id;
        $lines[] = 'PUNTO OPERATIVO: ' . $this->upper($puntoOperativo ?: 'SIN DATO');
        $lines[] = 'LUGAR CAPTURA: ' . $this->upper($lugarCaptura ?: 'SIN DATO');
        $lines[] = 'COLONIA: ' . $this->upper($operativo->colonia ?: 'SIN DATO');
        if ($codigoPostal !== null) {
            $lines[] = 'CODIGO POSTAL: ' . $codigoPostal;
        }
        $lines[] = 'MUNICIPIO: ' . $this->upper($captura->municipio ?: $operativo->municipio ?: 'SIN DATO');
        $lines[] = 'FECHA: ' . $this->fechaHoraCaptura($captura) . ' Hrs.';
        $lines[] = 'USUARIO: ' . $this->upper($this->nombreUsuario($captura->creador));
        $this->appendCoordenadas($lines, $captura->lat, $captura->lng, $captura->coordenadas_texto);

        if ($this->nullableString($captura->narrativa) !== null) {
            $lines[] = '';
            $lines[] = 'NARRATIVA:';
            $lines[] = trim((string) $captura->narrativa);
        }

        $lines[] = '';
        $lines[] = 'VEHICULOS:';
        if ($captura->vehiculos->count() === 0) {
            $lines[] = 'SIN VEHICULOS CAPTURADOS.';
        } else {
            foreach ($captura->vehiculos as $index => $vehiculo) {
                $lines[] = '';
                $lines[] = 'VEHICULO ' . $this->letraVehiculo($index) . ')';
                $lines[] = $this->vehiculoResumen($vehiculo);
                $this->appendVehiculoRetencion($lines, $vehiculo);
            }
        }

        $lines[] = '';
        $lines[] = 'PERSONAS:';
        if ($captura->personas->count() === 0) {
            $lines[] = 'SIN PERSONAS CAPTURADAS.';
        } else {
            foreach ($captura->personas as $persona) {
                $lines[] = '- ' . $this->personaResumen($persona);
            }
        }

        if ($captura->fotos->count() > 0) {
            $lines[] = '';
            $lines[] = 'FOTOS ADJUNTAS: ' . $captura->fotos->count();
        }

        $lines[] = '';
        $lines[] = 'INFORMA ' . $this->upper($this->unidadOperativaTexto($unidadId));
        $this->appendSupervisorTicket($lines, $unidadId, $delegacionId);

        return implode("\n", $lines);
    }

    private function adscripcionTicket(
        ConduceLegalidadOperativo $operativo,
        $user,
        ?ConduceLegalidadCaptura $captura = null
    ): array {
        $unidadId = (int) (
            $operativo->unidad_id
            ?: ($captura ? $captura->unidad_id : null)
            ?: ($user->unidad_id ?? 0)
        );
        $delegacionId = $unidadId === self::UNIDAD_DELEGACIONES
            ? ((int) (
                $operativo->delegacion_id
                ?: ($captura ? $captura->delegacion_id : null)
                ?: ($user->delegacion_id ?? 0)
            ) ?: null)
            : null;

        return [
            'unidad_id' => $unidadId,
            'delegacion_id' => $delegacionId,
        ];
    }

    private function appendSupervisorTicket(
        array &$lines,
        int $unidadId,
        $delegacionId = null
    ): void {
        $supervisor = $this->supervisorTicket($unidadId, $delegacionId);

        $lines[] = '';
        $lines[] = 'RESPONSABLES DEL OPERATIVO:';
        $lines[] = self::TICKET_COORDINADOR_CARGO;
        $lines[] = self::TICKET_COORDINADOR_NOMBRE;
        $lines[] = '';
        $lines[] = 'Supervisión operativa: ' . $supervisor['nombre'];
        $lines[] = $supervisor['cargo'];
    }

    private function supervisorTicket(int $unidadId, $delegacionId = null): array
    {
        if ($unidadId !== self::UNIDAD_DELEGACIONES) {
            return [
                'nombre' => self::TICKET_SUPERVISOR_NOMBRE,
                'cargo' => self::TICKET_SUPERVISOR_CARGO,
            ];
        }

        $delegacionId = (int) $delegacionId;
        $delegado = $this->delegadoSupervisor($delegacionId);
        $delegacionNombre = $this->nombreDelegacionTicket($delegacionId);

        return [
            'nombre' => $delegado
                ? $this->nombreUsuario($delegado)
                : 'Delegado no asignado',
            'cargo' => $delegacionNombre
                ? 'Delegado de la Delegación de ' . $delegacionNombre
                : 'Delegado',
        ];
    }

    protected function delegadoSupervisor(int $delegacionId): ?User
    {
        if ($delegacionId <= 0) {
            return null;
        }

        return User::query()
            ->where(function ($query) use ($delegacionId) {
                $query->where('delegacion_id', $delegacionId)
                    ->orWhereIn('id', function ($subQuery) use ($delegacionId) {
                        $subQuery->select('user_id')
                            ->from('delegacion_user')
                            ->where('delegacion_id', $delegacionId);
                    });
            })
            ->whereHas('roles', function ($query) {
                $query->where('name', 'Delegado');
            })
            ->where(function ($query) {
                $query->whereNull('estado')
                    ->orWhereRaw('UPPER(TRIM(estado)) <> ?', ['INACTIVO']);
            })
            ->orderByRaw('CASE WHEN delegacion_id = ? THEN 0 ELSE 1 END', [$delegacionId])
            ->orderByDesc('id')
            ->first();
    }

    protected function nombreDelegacionTicket(int $delegacionId): ?string
    {
        if ($delegacionId <= 0) {
            return null;
        }

        return $this->nullableString(
            Delegacion::query()->whereKey($delegacionId)->value('nombre')
        );
    }

    private function tarjetaHeaderLines(int $unidadId, $delegacionId = null): array
    {
        $lines = [
            'GUARDIA CIVIL',
            '',
            'COORDINACION DEL AGRUPAMIENTO DE SEGURIDAD VIAL',
            '',
            $this->upper($this->unidadOperativaTexto($unidadId)),
        ];

        $delegacion = $this->delegacionTexto($delegacionId);
        if ($delegacion !== null) {
            $lines[] = $delegacion;
        }

        $lines[] = '';

        return $lines;
    }

    private function unidadOperativaTexto(int $unidadId): string
    {
        switch ($unidadId) {
            case self::UNIDAD_SINIESTROS:
                return 'UNIDAD DE ATENCION A SINIESTROS';
            case 2:
                return 'UNIDAD DE DELEGACIONES';
            case self::UNIDAD_SEGURIDAD_VIAL:
                return 'UNIDAD DE SEGURIDAD VIAL';
            case 4:
                return 'UNIDAD DE PROTECCION A CARRETERAS';
            case self::UNIDAD_VIALIDADES_URBANAS:
                return 'UNIDAD DE VIALIDADES URBANAS';
            default:
                return DB::table('unidades')->where('id', $unidadId)->value('nombre') ?: 'SIN DATO';
        }
    }

    private function delegacionTexto($delegacionId): ?string
    {
        $id = (int) ($delegacionId ?? 0);
        if ($id <= 0) {
            return null;
        }

        $nombre = DB::table('delegaciones')->where('id', $id)->value('nombre');
        return $nombre ? 'DELEGACION ' . $this->upper($nombre) : null;
    }

    private function appendDesglose(array &$lines, array $pairs, string $label, callable $resolver): void
    {
        $totales = [];
        foreach ($pairs as [, $vehiculo]) {
            $key = $this->upper($resolver($vehiculo) ?: 'SIN ' . $label . ' REGISTRADA');
            $totales[$key] = ($totales[$key] ?? 0) + 1;
        }

        $lines[] = '';
        $lines[] = 'DESGLOSE POR ' . $label . ':';
        if (count($totales) === 0) {
            $lines[] = '- SIN DATOS.';
            return;
        }

        ksort($totales);
        foreach ($totales as $nombre => $total) {
            $lines[] = '- ' . $nombre . ': ' . $total;
        }
    }

    private function appendVehiculoRetencion(array &$lines, ConduceLegalidadVehiculo $vehiculo): void
    {
        $motivo = $this->nullableString($vehiculo->motivo_retencion);
        if ($motivo !== null) {
            $lines[] = 'Motivo de retencion: ' . $motivo . '.';
        }

        $referencia = $vehiculo->infraccion ? $vehiculo->infraccion->referencia_legal_corta : null;
        if ($this->nullableString($referencia) !== null) {
            $lines[] = 'Fundamento: ' . $referencia . '.';
        }

        $grua = $this->valorGrua($vehiculo);
        if ($grua !== null) {
            $lines[] = 'Grua: ' . $this->upper($grua) . '.';
        }

        $corralon = $this->valorCorralon($vehiculo);
        if ($corralon !== null) {
            $lines[] = 'Corralon: ' . $this->upper($corralon) . '.';
        }
    }

    private function appendCoordenadas(array &$lines, $lat, $lng, ?string $coordenadasTexto): void
    {
        if ($lat !== null && $lng !== null) {
            $lines[] = 'COORDENADAS: ' . $lat . ', ' . $lng;
            $lines[] = 'GOOGLE MAPS: https://www.google.com/maps?q=' . $lat . ',' . $lng;
            return;
        }

        $coordenadas = $this->nullableString($coordenadasTexto);
        if ($coordenadas !== null) {
            $lines[] = 'COORDENADAS: ' . $coordenadas;
        }
    }

    private function vehiculoResumen(ConduceLegalidadVehiculo $vehiculo): string
    {
        return 'Marca ' . $this->valorTexto($vehiculo->marca)
            . ', tipo ' . $this->valorTexto($vehiculo->tipo ?: $vehiculo->tipo_general)
            . ', linea ' . $this->valorTexto($vehiculo->linea)
            . ', color ' . $this->valorTexto($vehiculo->color)
            . ', placas ' . $this->valorTexto($vehiculo->placas ?: 'SIN PLACAS')
            . ', NIV ' . $this->valorTexto($vehiculo->serie) . '.';
    }

    private function personaResumen(ConduceLegalidadPersona $persona): string
    {
        $parts = [$this->valorTexto($persona->nombre)];

        if ($persona->edad !== null) {
            $parts[] = $persona->edad . ' anos';
        }

        if ($this->nullableString($persona->numero_licencia) !== null) {
            $parts[] = 'licencia ' . $persona->numero_licencia;
        }

        if ($this->nullableString($persona->estado_licencia) !== null) {
            $parts[] = 'estado licencia ' . $persona->estado_licencia;
        }

        return implode(', ', $parts) . '.';
    }

    private function vehiculoResguardado(ConduceLegalidadVehiculo $vehiculo): bool
    {
        return (bool) $vehiculo->retencion_vehiculo
            || $this->valorGrua($vehiculo) !== null
            || $this->valorCorralon($vehiculo) !== null;
    }

    private function valorGrua(ConduceLegalidadVehiculo $vehiculo): ?string
    {
        return $this->nullableString($vehiculo->grua)
            ?: ($vehiculo->grua_id ? 'GRUA #' . $vehiculo->grua_id : null);
    }

    private function valorCorralon(ConduceLegalidadVehiculo $vehiculo): ?string
    {
        return $this->nullableString($vehiculo->corralon)
            ?: ($vehiculo->corralon_id ? 'CORRALON #' . $vehiculo->corralon_id : null);
    }

    private function fechaHoraOperativo(ConduceLegalidadOperativo $operativo): string
    {
        return trim(implode(' ', array_filter([
            optional($operativo->fecha)->toDateString(),
            $this->horaCorta($operativo->hora_inicio),
        ]))) ?: 'SIN DATO';
    }

    private function fechaHoraCaptura(ConduceLegalidadCaptura $captura): string
    {
        return trim(implode(' ', array_filter([
            optional($captura->fecha)->toDateString(),
            $this->horaCorta($captura->hora),
        ]))) ?: 'SIN DATO';
    }

    private function horaCorta($hora): ?string
    {
        $text = $this->nullableString($hora);
        return $text === null ? null : substr($text, 0, 5);
    }

    private function letraVehiculo(int $index): string
    {
        $letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        return $index >= 0 && $index < strlen($letters)
            ? $letters[$index]
            : (string) ($index + 1);
    }

    private function nombreUsuario($user): string
    {
        return trim((string) ($user->name ?? $user->nombre ?? 'Usuario'));
    }

    private function valorTexto($value): string
    {
        return $this->upper($this->nullableString($value) ?: 'SIN DATO');
    }

    private function upper($value): string
    {
        $text = trim((string) ($value ?? ''));
        return $text === '' ? 'SIN DATO' : Str::upper($text);
    }

    private function nombreOperativo(string $tipoOperativo): string
    {
        return $tipoOperativo === 'alcoholimetria'
            ? self::NOMBRE_OPERATIVO_ALCOHOLIMETRIA
            : self::NOMBRE_OPERATIVO;
    }

    private function nombreTicketOperativo(ConduceLegalidadOperativo $operativo): string
    {
        return $this->esOperativoAlcoholimetria($operativo)
            ? self::NOMBRE_OPERATIVO_ALCOHOLIMETRIA
            : self::NOMBRE_OPERATIVO;
    }

    private function tipoOperativo($value, ...$fallbackValues): string
    {
        $tipo = $this->nullableString($value);
        if ($tipo !== null && in_array($tipo, self::TIPOS_OPERATIVO, true)) {
            return $tipo;
        }

        $text = Str::upper(Str::ascii(implode(' ', array_filter($fallbackValues))));
        return Str::contains($text, ['ALCOHOL', 'PREVENCION DE ACCIDENTES'])
            ? 'alcoholimetria'
            : 'conduce_legalidad';
    }

    private function operativoRules(?ConduceLegalidadOperativo $operativo = null): array
    {
        $ignoreId = $operativo ? $operativo->id : null;
        $locationRequired = $operativo ? ['sometimes', 'required'] : ['required'];

        return [
            'client_uuid' => ['nullable', 'string', 'max:80', Rule::unique('conduce_legalidad_operativos', 'client_uuid')->ignore($ignoreId)],
            'nombre' => ['nullable', 'string', 'max:120'],
            'tipo_operativo' => ['nullable', Rule::in(self::TIPOS_OPERATIVO)],
            'objetivo' => ['nullable', 'string'],
            'fecha' => ['nullable', 'date'],
            'hora_inicio' => ['nullable', 'date_format:H:i'],
            'hora_cierre' => ['nullable', 'date_format:H:i'],
            'municipio' => ['nullable', 'string', 'max:120'],
            'lugar' => array_merge($locationRequired, ['string', 'max:255']),
            'numero' => ['nullable', 'string', 'max:40'],
            'colonia' => array_merge($locationRequired, ['string', 'max:120']),
            'lat' => array_merge($locationRequired, ['numeric', 'between:-90,90']),
            'lng' => array_merge($locationRequired, ['numeric', 'between:-180,180']),
            'coordenadas_texto' => array_merge($locationRequired, ['string', 'max:255']),
            'estado' => ['nullable', Rule::in(self::ESTADOS)],
        ];
    }

    private function agenteCapturaData(
        array $validated,
        $user,
        ?ConduceLegalidadCaptura $captura = null
    ): array {
        $partesExplicitas = array_key_exists('agente_nombres', $validated)
            || array_key_exists('agente_apellido_paterno', $validated)
            || array_key_exists('agente_apellido_materno', $validated);

        if ($partesExplicitas) {
            $partes = [
                'nombres' => $this->nullableString($validated['agente_nombres'] ?? null),
                'apellido_paterno' => $this->nullableString($validated['agente_apellido_paterno'] ?? null),
                'apellido_materno' => $this->nullableString($validated['agente_apellido_materno'] ?? null),
            ];
            $nombre = $this->joinText([
                $partes['nombres'],
                $partes['apellido_paterno'],
                $partes['apellido_materno'],
            ], ' ');
        } else {
            $nombre = array_key_exists('agente_nombre', $validated)
                ? $this->nullableString($validated['agente_nombre'])
                : $this->nullableString(optional($captura)->agente_nombre);
            $nombre = $nombre
                ?: $this->nullableString($user->name ?? null)
                ?: 'Elemento actuante';
            $partes = $this->partesAgenteCaptura($nombre, $captura);
        }

        $nombre = $this->nullableString($nombre)
            ?: $this->nullableString($validated['agente_nombre'] ?? null)
            ?: 'Elemento actuante';

        $numeroPlaca = array_key_exists('agente_numero_placa', $validated)
            ? $this->nullableString($validated['agente_numero_placa'])
            : $this->nullableString(optional($captura)->agente_numero_placa);
        $numeroPlaca = $numeroPlaca
            ?: $this->nullableString(data_get($user, 'numero_placa'))
            ?: $this->nullableString(data_get($user, 'personal.numero_placa'));

        return [
            'nombre' => $nombre,
            'nombres' => $partes['nombres'],
            'apellido_paterno' => $partes['apellido_paterno'],
            'apellido_materno' => $partes['apellido_materno'],
            'numero_placa' => $numeroPlaca,
            'adscripcion' => self::AGENTE_ADSCRIPCION_DEFAULT,
        ];
    }

    private function partesAgenteCaptura(
        string $nombre,
        ?ConduceLegalidadCaptura $captura = null
    ): array {
        $nombresGuardados = $this->nullableString(optional($captura)->agente_nombres);
        $paternoGuardado = $this->nullableString(optional($captura)->agente_apellido_paterno);
        $maternoGuardado = $this->nullableString(optional($captura)->agente_apellido_materno);

        if ($nombresGuardados !== null || $paternoGuardado !== null || $maternoGuardado !== null) {
            return [
                'nombres' => $nombresGuardados,
                'apellido_paterno' => $paternoGuardado,
                'apellido_materno' => $maternoGuardado,
            ];
        }

        $tokens = preg_split('/\s+/u', trim($nombre), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        if (count($tokens) >= 3) {
            $apellidoMaterno = array_pop($tokens);
            $apellidoPaterno = array_pop($tokens);

            return [
                'nombres' => implode(' ', $tokens),
                'apellido_paterno' => $apellidoPaterno,
                'apellido_materno' => $apellidoMaterno,
            ];
        }

        if (count($tokens) === 2) {
            return [
                'nombres' => $tokens[0],
                'apellido_paterno' => $tokens[1],
                'apellido_materno' => null,
            ];
        }

        return [
            'nombres' => $tokens[0] ?? $nombre,
            'apellido_paterno' => null,
            'apellido_materno' => null,
        ];
    }

    private function capturaRules(?ConduceLegalidadOperativo $operativo = null): array
    {
        $requiereVehiculo = $operativo === null || !$this->esOperativoAlcoholimetria($operativo);

        return [
            'client_uuid' => ['nullable', 'string', 'max:80'],
            'agente_nombre' => ['nullable', 'string', 'max:255'],
            'agente_nombres' => ['nullable', 'string', 'max:120'],
            'agente_apellido_paterno' => ['nullable', 'string', 'max:100'],
            'agente_apellido_materno' => ['nullable', 'string', 'max:100'],
            'agente_numero_placa' => ['nullable', 'string', 'max:80'],
            'agente_adscripcion' => ['nullable', 'string', 'max:180'],
            'fecha' => ['nullable', 'date'],
            'hora' => ['nullable', 'date_format:H:i'],
            'municipio' => ['nullable', 'string', 'max:120'],
            'lugar' => ['nullable', 'string', 'max:255'],
            'lat' => ['nullable', 'numeric', 'between:-90,90'],
            'lng' => ['nullable', 'numeric', 'between:-180,180'],
            'coordenadas_texto' => ['nullable', 'string', 'max:255'],
            'narrativa' => ['nullable', 'string'],
            'observaciones' => ['nullable', 'string'],
            'fundamentos' => ['sometimes', 'array', 'max:20'],
            'fundamentos.*' => ['required', 'array'],
            'fundamentos.*.licencia_punto_infraccion_id' => ['nullable', 'integer', 'exists:licencia_punto_infracciones,id'],
            'fundamentos.*.infraccion_codigo' => ['nullable', 'string', 'max:80'],
            'fundamentos.*.fundamento_legal' => ['nullable', 'string', 'max:2000'],
            'fundamento_ids' => ['sometimes', 'array', 'max:20'],
            'fundamento_ids.*' => ['required', 'integer', 'distinct', 'exists:licencia_punto_infracciones,id'],
            'licencia_punto_infraccion_id' => ['nullable', 'integer', 'exists:licencia_punto_infracciones,id'],
            'infraccion_codigo' => ['nullable', 'string', 'max:80'],
            'fundamento_legal' => ['nullable', 'string', 'max:2000'],
            'rnd_data' => ['nullable', 'array'],
            'rnd_data.*' => ['nullable', 'string', 'max:2000'],
            'fotos' => ['nullable', 'array', 'max:25'],
            'fotos.*' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
            'vehiculos' => $requiereVehiculo
                ? ['required', 'array', 'size:1']
                : ['nullable', 'array', 'max:1'],
            'vehiculos.*' => [$requiereVehiculo ? 'required' : 'sometimes', 'array'],
            'vehiculos.*.marca' => ['nullable', 'string', 'max:80'],
            'vehiculos.*.modelo' => ['nullable', 'string', 'max:20'],
            'vehiculos.*.tipo_general' => ['nullable', 'string', 'max:80'],
            'vehiculos.*.tipo' => ['nullable', 'string', 'max:80'],
            'vehiculos.*.linea' => ['nullable', 'string', 'max:100'],
            'vehiculos.*.color' => ['nullable', 'string', 'max:50'],
            'vehiculos.*.placas' => ['nullable', 'string', 'max:20'],
            'vehiculos.*.estado_placas' => ['nullable', 'string', 'max:80'],
            'vehiculos.*.serie' => ['nullable', 'string', 'max:30'],
            'vehiculos.*.numero_inventario' => [$requiereVehiculo ? 'required' : 'nullable', 'string', 'max:100'],
            'vehiculos.*.capacidad_personas' => ['nullable', 'integer', 'min:0', 'max:999'],
            'vehiculos.*.tipo_servicio' => ['nullable', 'string', 'max:80'],
            'vehiculos.*.tarjeta_circulacion_nombre' => ['nullable', 'string', 'max:255'],
            'vehiculos.*.grua_id' => ['nullable', 'integer', 'exists:gruas,id'],
            'vehiculos.*.corralon_id' => [$requiereVehiculo ? 'required' : 'nullable', 'integer', 'exists:gruas,id'],
            'vehiculos.*.grua' => ['nullable', 'string', 'max:255'],
            'vehiculos.*.corralon' => ['nullable', 'string', 'max:255'],
            'vehiculos.*.aseguradora' => ['nullable', 'string', 'max:255'],
            'vehiculos.*.monto_danos' => ['nullable', 'numeric', 'min:0'],
            'vehiculos.*.partes_danadas' => ['nullable', 'string'],
            'vehiculos.*.antecedente_vehiculo' => ['nullable', 'boolean'],
            'vehiculos.*.raw_tarjeta_qr' => ['nullable', 'string'],
            'vehiculos.*.licencia_punto_infraccion_id' => ['nullable', 'integer', 'exists:licencia_punto_infracciones,id'],
            'vehiculos.*.motivo_retencion' => ['nullable', 'string'],
            'vehiculos.*.persona_habilitada_resguardo' => ['nullable', 'boolean'],
            'vehiculos.*.responsable_habilitado_presente' => ['nullable', 'boolean'],
            'vehiculos.*.observaciones' => ['nullable', 'string'],
            'personas' => ['nullable', 'array', 'max:100'],
            'personas.*' => ['array'],
            'personas.*.nombre' => ['nullable', 'string', 'max:255'],
            'personas.*.nombres' => ['nullable', 'string', 'max:120'],
            'personas.*.apellido_paterno' => ['nullable', 'string', 'max:100'],
            'personas.*.apellido_materno' => ['nullable', 'string', 'max:100'],
            'personas.*.telefono' => ['nullable', 'string', 'max:30'],
            'personas.*.domicilio' => ['nullable', 'string', 'max:255'],
            'personas.*.sexo' => ['nullable', 'string', 'max:30'],
            'personas.*.nacionalidad' => ['nullable', 'string', 'max:80'],
            'personas.*.ocupacion' => ['nullable', 'string', 'max:255'],
            'personas.*.edad' => ['nullable', 'integer', 'min:0', 'max:120'],
            'personas.*.edad_texto' => ['nullable', 'string', 'max:40'],
            'personas.*.estado_civil' => ['nullable', 'string', Rule::in(self::ESTADOS_CIVILES)],
            'personas.*.edad_aproximada' => ['nullable', 'string', 'max:40'],
            'personas.*.complexion' => ['nullable', 'string', 'max:80'],
            'personas.*.estatura' => ['nullable', 'string', 'max:80'],
            'personas.*.tez' => ['nullable', 'string', 'max:80'],
            'personas.*.cabello' => ['nullable', 'string', 'max:80'],
            'personas.*.prenda_superior' => ['nullable', 'string', 'max:80'],
            'personas.*.color_superior' => ['nullable', 'string', 'max:80'],
            'personas.*.prenda_inferior' => ['nullable', 'string', 'max:80'],
            'personas.*.color_inferior' => ['nullable', 'string', 'max:80'],
            'personas.*.calzado' => ['nullable', 'string', 'max:80'],
            'personas.*.color_calzado' => ['nullable', 'string', 'max:80'],
            'personas.*.rasgos_visibles' => ['nullable', 'array'],
            'personas.*.rasgos_visibles.*' => ['string', 'max:80'],
            'personas.*.tipo_licencia' => ['nullable', 'string', 'max:80'],
            'personas.*.estado_licencia' => ['nullable', 'string', 'max:120'],
            'personas.*.numero_licencia' => ['nullable', 'string', 'max:80'],
            'personas.*.vigencia_licencia' => ['nullable', 'date'],
            'personas.*.permanente' => ['nullable', 'boolean'],
            'personas.*.raw_licencia_qr' => ['nullable', 'string'],
            'personas.*.licencia_punto_infraccion_id' => ['nullable', 'integer', 'exists:licencia_punto_infracciones,id'],
            'personas.*.observaciones' => ['nullable', 'string'],
        ];
    }

    private function capturaValidationMessages(): array
    {
        return [
            'vehiculos.required' => 'Agrega el vehículo antes de guardar la captura.',
            'vehiculos.size' => 'La captura debe contener exactamente un vehículo.',
            'vehiculos.*.numero_inventario.required' => 'Captura el número de inventario del vehículo.',
            'vehiculos.*.corralon_id.required' => 'Selecciona el corralón al que se trasladará el vehículo.',
            'vehiculos.*.corralon_id.exists' => 'El corralón seleccionado ya no está disponible. Selecciona otro.',
        ];
    }

    private function assertCapturaHasContent(
        array $validated,
        Request $request,
        ?ConduceLegalidadCaptura $captura = null
    ): void
    {
        $narrativa = $this->nullableString($validated['narrativa'] ?? null);
        $vehiculos = $validated['vehiculos'] ?? [];
        $personas = $validated['personas'] ?? [];
        $hasFotos = $request->hasFile('fotos')
            || ($captura !== null && $captura->fotos()->exists());

        if ($narrativa === null && count($vehiculos) === 0 && count($personas) === 0 && !$hasFotos) {
            throw ValidationException::withMessages([
                'narrativa' => 'Captura una narrativa o agrega al menos un vehiculo/persona/foto.',
            ]);
        }
    }

    private function assertCapturaHasFundamento(
        array $validated,
        ConduceLegalidadOperativo $operativo,
        ?ConduceLegalidadCaptura $captura = null
    ): void
    {
        $campoFundamentoPresente = array_key_exists('fundamentos', $validated)
            || array_key_exists('fundamento_ids', $validated)
            || array_key_exists('licencia_punto_infraccion_id', $validated);

        if ($campoFundamentoPresente) {
            $fundamentos = $this->capturaInfracciones($validated, $operativo);
        } elseif ($captura !== null) {
            $captura->loadMissing(['fundamentos.infraccion', 'infraccion']);
            $fundamentos = $this->fundamentosCapturaActuales($captura);
        } else {
            $fundamentos = [];
        }

        if (count($fundamentos) === 0) {
            throw ValidationException::withMessages([
                'fundamentos' => 'Selecciona al menos un fundamento legal antes de guardar la alimentación.',
            ]);
        }
    }

    private function storeFotos(ConduceLegalidadCaptura $captura, Request $request, $user): void
    {
        if (!$request->hasFile('fotos')) {
            return;
        }

        $files = $request->file('fotos', []);
        if (!is_array($files)) {
            $files = [$files];
        }

        $orden = (int) $captura->fotos()->max('orden');

        foreach ($files as $file) {
            if (!$file || !$file->isValid()) {
                continue;
            }

            $orden++;
            $extension = strtolower($file->getClientOriginalExtension() ?: 'jpg');
            $filename = 'captura_' . $captura->id . '_' . Str::uuid() . '.' . $extension;
            $fotoPath = $file->storeAs('conduce_legalidad', $filename, 'public');
            $fotoHash = hash_file('sha256', $file->getRealPath());
            $thumbnailPath = $this->crearThumbnailSeguro(
                $fotoPath,
                'conduce_legalidad_thumbnails/operativo_' . $captura->operativo_id,
                'captura_' . $captura->id . '_foto_' . $orden
            );

            $captura->fotos()->create([
                'foto_path' => $fotoPath,
                'foto_thumbnail_path' => $thumbnailPath,
                'foto_nombre_original' => $file->getClientOriginalName(),
                'foto_hash' => $fotoHash,
                'orden' => $orden,
                'created_by' => $user->id ?? null,
                'updated_by' => $user->id ?? null,
            ]);
        }
    }

    private function crearThumbnailSeguro(string $fotoPath, string $directorio, string $prefijo): ?string
    {
        try {
            return app(ImageThumbnailService::class)->createPublicThumbnail($fotoPath, $directorio, $prefijo);
        } catch (\Throwable $e) {
            report($e);
            return null;
        }
    }

    private function replaceVehiculos(
        ConduceLegalidadCaptura $captura,
        array $vehiculos,
        array $fundamentosCaptura = [],
        bool $usaFundamentoUnificado = false
    ): void
    {
        $captura->vehiculos()->delete();

        foreach ($vehiculos as $row) {
            $infracciones = $usaFundamentoUnificado
                ? $fundamentosCaptura
                : array_filter([
                    $this->retencionInfraccion($row['licencia_punto_infraccion_id'] ?? null),
                ]);
            $infraccion = $infracciones[0] ?? null;
            $personaHabilitadaResguardo = $this->booleanRow($row, 'persona_habilitada_resguardo', 'responsable_habilitado_presente');
            $retenciones = [];
            foreach ($infracciones as $fundamento) {
                $retencionCondicional = (bool) $fundamento->deposito_si_sin_persona_habilitada
                    && !$personaHabilitadaResguardo;
                if ((bool) $fundamento->retencion_vehiculo || $retencionCondicional) {
                    $retenciones[] = [
                        'fundamento' => $fundamento,
                        'condicional' => $retencionCondicional,
                    ];
                }
            }
            $retencionVehiculo = count($retenciones) > 0;
            $motivoSugerido = collect($retenciones)
                ->map(fn (array $retencion) => $this->motivoRetencionPorInfraccion(
                    $retencion['fundamento'],
                    $retencion['condicional']
                ))
                ->filter()
                ->unique()
                ->implode('; ');
            $motivoRetencion = $usaFundamentoUnificado
                ? ($retencionVehiculo
                    ? (
                        $this->nullableString($row['motivo_retencion'] ?? null)
                        ?: ($motivoSugerido !== '' ? $motivoSugerido : null)
                    )
                    : null)
                : (
                    $this->nullableString($row['motivo_retencion'] ?? null)
                    ?: ($retencionVehiculo && $motivoSugerido !== '' ? $motivoSugerido : null)
                );
            $tieneServicioGrua = $this->tieneServicioGrua($row);
            $corralonId = $row['corralon_id'] ?? null;
            $corralonNombre = $this->nullableString($row['corralon'] ?? null);

            if ($corralonId) {
                $corralonNombre = Grua::query()->whereKey($corralonId)->value('nombre')
                    ?: $corralonNombre;
            }

            $captura->vehiculos()->create([
                'marca' => $this->nullableString($row['marca'] ?? null),
                'modelo' => $this->nullableString($row['modelo'] ?? null),
                'tipo_general' => $this->nullableString($row['tipo_general'] ?? null),
                'tipo' => $this->nullableString($row['tipo'] ?? null),
                'linea' => $this->nullableString($row['linea'] ?? null),
                'color' => $this->nullableString($row['color'] ?? null),
                'placas' => $this->nullableString($row['placas'] ?? null),
                'estado_placas' => $this->nullableString($row['estado_placas'] ?? null),
                'serie' => $this->nullableString($row['serie'] ?? null),
                'numero_inventario' => $this->nullableString($row['numero_inventario'] ?? null),
                'capacidad_personas' => (int) ($row['capacidad_personas'] ?? 0),
                'tipo_servicio' => $this->nullableString($row['tipo_servicio'] ?? null),
                'tarjeta_circulacion_nombre' => $this->nullableString($row['tarjeta_circulacion_nombre'] ?? null),
                'grua_id' => $row['grua_id'] ?? null,
                'corralon_id' => $corralonId,
                'grua' => $this->nullableString($row['grua'] ?? null),
                'corralon' => $corralonNombre,
                'servicio_unidad_id' => $tieneServicioGrua ? $captura->unidad_id : null,
                'servicio_delegacion_id' => $tieneServicioGrua ? $captura->delegacion_id : null,
                'servicio_created_by' => $tieneServicioGrua ? $captura->created_by : null,
                'aseguradora' => $this->nullableString($row['aseguradora'] ?? null),
                'monto_danos' => $row['monto_danos'] ?? null,
                'partes_danadas' => $this->nullableString($row['partes_danadas'] ?? null),
                'antecedente_vehiculo' => (bool) ($row['antecedente_vehiculo'] ?? false),
                'raw_tarjeta_qr' => $this->nullableString($row['raw_tarjeta_qr'] ?? null),
                'licencia_punto_infraccion_id' => !$usaFundamentoUnificado && $infraccion ? $infraccion->id : null,
                'infraccion_codigo' => !$usaFundamentoUnificado && $infraccion ? $infraccion->codigo : null,
                'fundamento_legal' => !$usaFundamentoUnificado && $infraccion ? $infraccion->fundamento_legal : null,
                'retencion_vehiculo' => $retencionVehiculo,
                'motivo_retencion' => $motivoRetencion,
                'persona_habilitada_resguardo' => $personaHabilitadaResguardo,
                'observaciones' => $this->nullableString($row['observaciones'] ?? null),
            ]);
        }
    }

    private function tieneServicioGrua(array $row): bool
    {
        return !empty($row['grua_id'])
            || !empty($row['corralon_id'])
            || $this->nullableString($row['grua'] ?? null) !== null
            || $this->nullableString($row['corralon'] ?? null) !== null;
    }

    private function booleanRow(array $row, string $field, ?string $alias = null): bool
    {
        $value = $row[$field] ?? ($alias !== null ? ($row[$alias] ?? false) : false);

        return filter_var($value, FILTER_VALIDATE_BOOLEAN);
    }

    private function replacePersonas(
        ConduceLegalidadCaptura $captura,
        array $personas,
        bool $esAlcoholimetria,
        bool $usaFundamentoUnificado = false
    ): void
    {
        $captura->personas()->delete();

        foreach ($personas as $row) {
            $infraccion = $usaFundamentoUnificado
                ? null
                : $this->personaInfraccion($row['licencia_punto_infraccion_id'] ?? null);

            $captura->personas()->create([
                'nombre' => $this->nullableString($row['nombre'] ?? null),
                'nombres' => $esAlcoholimetria ? $this->nullableString($row['nombres'] ?? null) : null,
                'apellido_paterno' => $esAlcoholimetria ? $this->nullableString($row['apellido_paterno'] ?? null) : null,
                'apellido_materno' => $esAlcoholimetria ? $this->nullableString($row['apellido_materno'] ?? null) : null,
                'telefono' => $this->nullableString($row['telefono'] ?? null),
                'domicilio' => $this->nullableString($row['domicilio'] ?? null),
                'sexo' => $this->nullableString($row['sexo'] ?? null),
                'nacionalidad' => $this->nullableString($row['nacionalidad'] ?? null),
                'ocupacion' => $this->nullableString($row['ocupacion'] ?? null),
                'edad' => $row['edad'] ?? null,
                'edad_texto' => $esAlcoholimetria ? $this->nullableString($row['edad_texto'] ?? null) : null,
                'estado_civil' => $esAlcoholimetria ? $this->nullableString($row['estado_civil'] ?? null) : null,
                'edad_aproximada' => $this->nullableString($row['edad_aproximada'] ?? null),
                'complexion' => $this->nullableString($row['complexion'] ?? null),
                'estatura' => $this->nullableString($row['estatura'] ?? null),
                'tez' => $this->nullableString($row['tez'] ?? null),
                'cabello' => $this->nullableString($row['cabello'] ?? null),
                'prenda_superior' => $this->nullableString($row['prenda_superior'] ?? null),
                'color_superior' => $this->nullableString($row['color_superior'] ?? null),
                'prenda_inferior' => $this->nullableString($row['prenda_inferior'] ?? null),
                'color_inferior' => $this->nullableString($row['color_inferior'] ?? null),
                'calzado' => $this->nullableString($row['calzado'] ?? null),
                'color_calzado' => $this->nullableString($row['color_calzado'] ?? null),
                'rasgos_visibles' => $this->nullableStringArray($row['rasgos_visibles'] ?? null),
                'tipo_licencia' => $this->nullableString($row['tipo_licencia'] ?? null),
                'estado_licencia' => $this->nullableString($row['estado_licencia'] ?? null),
                'numero_licencia' => $this->nullableString($row['numero_licencia'] ?? null),
                'vigencia_licencia' => $row['vigencia_licencia'] ?? null,
                'permanente' => (bool) ($row['permanente'] ?? false),
                'raw_licencia_qr' => $this->nullableString($row['raw_licencia_qr'] ?? null),
                'licencia_punto_infraccion_id' => $infraccion ? $infraccion->id : null,
                'infraccion_codigo' => $infraccion ? $infraccion->codigo : null,
                'fundamento_legal' => $infraccion ? $infraccion->fundamento_legal : null,
                'observaciones' => $this->nullableString($row['observaciones'] ?? null),
            ]);
        }
    }

    private function esOperativoAlcoholimetria(ConduceLegalidadOperativo $operativo): bool
    {
        if (in_array($operativo->tipo_operativo, self::TIPOS_OPERATIVO, true)) {
            return $operativo->tipo_operativo === 'alcoholimetria';
        }

        $texto = Str::upper(Str::ascii(implode(' ', array_filter([
            $operativo->nombre,
            $operativo->objetivo,
            $operativo->narrativa,
            $operativo->observaciones,
        ]))));

        return Str::contains($texto, ['ALCOHOL', 'PREVENCION DE ACCIDENTES']);
    }

    private function alimentacionAlcoholimetriaCierraEn(ConduceLegalidadOperativo $operativo)
    {
        if (!$this->esOperativoAlcoholimetria($operativo) || !$operativo->created_at) {
            return null;
        }

        return $operativo->created_at->copy()->addHours(self::ALCOHOLIMETRIA_HORAS_ALIMENTACION);
    }

    private function alimentacionAlcoholimetriaCerrada(ConduceLegalidadOperativo $operativo, $instant = null): bool
    {
        $cierraEn = $this->alimentacionAlcoholimetriaCierraEn($operativo);
        if ($cierraEn === null) {
            return false;
        }

        return ($instant ?: now())->greaterThanOrEqualTo($cierraEn);
    }

    private function puedeAlimentarOperativo(ConduceLegalidadOperativo $operativo, $user): bool
    {
        if (!$user || $operativo->estado !== 'activo') {
            return false;
        }

        if ($user->hasRole('Superadmin')) {
            return true;
        }

        return !$this->alimentacionAlcoholimetriaCerrada($operativo);
    }

    private function assertPuedeAlimentarOperativo(ConduceLegalidadOperativo $operativo, $user): void
    {
        if ($operativo->estado !== 'activo') {
            throw ValidationException::withMessages([
                'operativo' => 'El operativo no esta activo.',
            ]);
        }

        if (!$this->puedeAlimentarOperativo($operativo, $user)) {
            throw ValidationException::withMessages([
                'operativo' => 'El operativo de alcoholimetria cumplio 8 horas y quedo cerrado para captura. Solo Superadmin puede continuar alimentandolo.',
            ]);
        }
    }

    private function retencionInfraccion($id): ?LicenciaPuntoInfraccion
    {
        $id = (int) ($id ?? 0);
        if ($id <= 0) {
            return null;
        }

        $infraccion = LicenciaPuntoInfraccion::activas()->find($id);
        if (
            !$infraccion ||
            !$this->infraccionAplicaRetencionOperativo($infraccion) ||
            $this->esFundamentoExcluidoDelOperativo($infraccion)
        ) {
            throw ValidationException::withMessages([
                'licencia_punto_infraccion_id' => 'El fundamento seleccionado no aplica para este operativo o no amerita retiro de vehiculo.',
            ]);
        }

        return $infraccion;
    }

    private function personaInfraccion($id): ?LicenciaPuntoInfraccion
    {
        $id = (int) ($id ?? 0);
        if ($id <= 0) {
            return null;
        }

        $infraccion = LicenciaPuntoInfraccion::activas()->find($id);
        if (!$infraccion || !$this->infraccionAplicaSancionPersonaOperativo($infraccion)) {
            throw ValidationException::withMessages([
                'licencia_punto_infraccion_id' => 'El fundamento seleccionado no aplica como sancion de persona en este operativo.',
            ]);
        }

        return $infraccion;
    }

    /**
     * @return array<int, LicenciaPuntoInfraccion>
     */
    private function capturaInfracciones(
        array $validated,
        ConduceLegalidadOperativo $operativo
    ): array
    {
        $seleccionesEntrada = array_key_exists('fundamentos', $validated)
            ? ($validated['fundamentos'] ?? [])
            : (array_key_exists('fundamento_ids', $validated)
                ? array_map(
                    fn ($id) => ['licencia_punto_infraccion_id' => $id],
                    $validated['fundamento_ids'] ?? []
                )
                : [[
                    'licencia_punto_infraccion_id' => $validated['licencia_punto_infraccion_id'] ?? null,
                    'infraccion_codigo' => $validated['infraccion_codigo'] ?? null,
                    'fundamento_legal' => $validated['fundamento_legal'] ?? null,
                ]]);

        $fundamentos = [];
        $selecciones = [];
        foreach ($seleccionesEntrada as $orden => $seleccion) {
            $seleccion = is_array($seleccion) ? $seleccion : [];
            $infraccion = $this->capturaInfraccion(
                $seleccion['licencia_punto_infraccion_id'] ?? null,
                $operativo,
                $seleccion['infraccion_codigo'] ?? null
            );
            if ($infraccion) {
                $snapshot = $this->capturaInfraccionSnapshot(
                    $seleccion,
                    $infraccion
                );
                $key = $infraccion->id . '|' . ($snapshot['codigo'] ?? '');
                if (isset($selecciones[$key])) {
                    throw ValidationException::withMessages([
                        'fundamentos' => 'No puedes seleccionar dos veces el mismo fundamento.',
                    ]);
                }

                $selecciones[$key] = true;
                $fundamentos[] = $infraccion;
            }
        }

        return $fundamentos;
    }

    /**
     * @return array<int, LicenciaPuntoInfraccion>
     */
    private function fundamentosCapturaActuales(
        ConduceLegalidadCaptura $captura
    ): array
    {
        $fundamentos = $captura->fundamentos
            ->map(fn (ConduceLegalidadCapturaFundamento $item) => $item->infraccion)
            ->filter()
            ->values()
            ->all();

        if (count($fundamentos) === 0 && $captura->infraccion) {
            $fundamentos[] = $captura->infraccion;
        }

        return $fundamentos;
    }

    private function replaceFundamentosCaptura(
        ConduceLegalidadCaptura $captura,
        array $fundamentos,
        array $validated
    ): void
    {
        $captura->fundamentos()->delete();

        foreach (array_values($fundamentos) as $orden => $infraccion) {
            $seleccion = $validated['fundamentos'][$orden] ?? null;
            $snapshot = $this->capturaInfraccionSnapshot(
                is_array($seleccion) ? $seleccion : ($orden === 0 ? $validated : []),
                $infraccion
            );
            $captura->fundamentos()->create([
                'licencia_punto_infraccion_id' => $infraccion->id,
                'orden' => $orden,
                'infraccion_codigo' => $snapshot['codigo'],
                'fundamento_legal' => $snapshot['fundamento_legal'],
            ]);
        }
    }

    private function capturaInfraccion(
        $id,
        ConduceLegalidadOperativo $operativo,
        $codigo = null
    ): ?LicenciaPuntoInfraccion
    {
        $id = (int) ($id ?? 0);
        $codigo = $this->nullableString($codigo);
        if ($id <= 0 && $codigo === null) {
            return null;
        }

        $infraccion = $id > 0
            ? LicenciaPuntoInfraccion::activas()->find($id)
            : LicenciaPuntoInfraccion::activas()->where('codigo', $codigo)->first();
        $esAlcoholimetria = $this->esOperativoAlcoholimetria($operativo);
        $aplica = $infraccion && (
            $esAlcoholimetria
                ? $this->esFundamentoAlcoholimetria($infraccion)
                : (
                    $this->infraccionAplicaRetencionOperativo($infraccion)
                    && $this->ambitoFundamentoAplicaConduceLegalidad($infraccion->ambito_vehiculo)
                    && !$this->esFundamentoExcluidoDelOperativo($infraccion)
                )
        );

        if (!$aplica) {
            throw ValidationException::withMessages([
                'licencia_punto_infraccion_id' => $esAlcoholimetria
                    ? 'El fundamento seleccionado no corresponde a Alcoholimetria.'
                    : 'El fundamento seleccionado no corresponde al operativo de motocicletas.',
            ]);
        }

        return $infraccion;
    }

    private function esFundamentoAlcoholimetria(LicenciaPuntoInfraccion $infraccion): bool
    {
        $articulo = trim((string) $infraccion->articulo);
        if (in_array($articulo, ['345', '508'], true)) {
            return true;
        }

        $texto = Str::upper(Str::ascii(implode(' ', array_filter([
            $infraccion->codigo,
            $infraccion->nombre,
            $infraccion->etiqueta_operativa,
            $infraccion->texto_operativo,
            $infraccion->descripcion,
            $infraccion->fundamento_legal,
            $infraccion->referencia_legal_corta,
        ]))));

        return Str::contains($texto, [
            'ALCOHOL',
            'ALCOHOLEMIA',
            'EBRIEDAD',
            'EBRIO',
            'INTOXICACION',
            'ALIENTO ALCOHOLICO',
        ]);
    }

    private function capturaInfraccionSnapshot(
        array $validated,
        ?LicenciaPuntoInfraccion $infraccion
    ): array
    {
        if (!$infraccion) {
            return [
                'codigo' => null,
                'fundamento_legal' => null,
            ];
        }

        $codigoBase = $this->nullableString($infraccion->codigo);
        $codigoSolicitado = $this->nullableString($validated['infraccion_codigo'] ?? null);
        $codigo = $codigoSolicitado !== null
            && $codigoBase !== null
            && Str::startsWith($codigoSolicitado, $codigoBase)
                ? $codigoSolicitado
                : $codigoBase;

        $fundamentoLegal = $codigoSolicitado !== null && $codigo === $codigoSolicitado
            ? $this->nullableString($validated['fundamento_legal'] ?? null)
            : null;

        return [
            'codigo' => $codigo,
            'fundamento_legal' => $fundamentoLegal ?: $this->nullableString($infraccion->fundamento_legal),
        ];
    }

    private function infraccionAplicaRetencionOperativo(LicenciaPuntoInfraccion $infraccion): bool
    {
        return (bool) $infraccion->retencion_vehiculo
            || (bool) $infraccion->deposito_si_sin_persona_habilitada;
    }

    private function assertVehiculosCorrespondenOperativo(
        array $validated,
        ConduceLegalidadOperativo $operativo
    ): void
    {
        if ($this->esOperativoAlcoholimetria($operativo)) {
            return;
        }

        foreach ($validated['vehiculos'] ?? [] as $index => $vehiculo) {
            if (strtolower(trim((string) ($vehiculo['tipo_general'] ?? ''))) !== 'motocicleta') {
                throw ValidationException::withMessages([
                    "vehiculos.$index.tipo_general" => 'Conduce con Legalidad es exclusivo para motocicletas.',
                ]);
            }
        }
    }

    private function ambitoFundamentoAplicaConduceLegalidad(?string $ambito): bool
    {
        return in_array(strtolower(trim((string) $ambito)), [
            '',
            'general',
            'motocicleta',
        ], true);
    }

    private function infraccionAplicaSancionPersonaOperativo(LicenciaPuntoInfraccion $infraccion): bool
    {
        return (bool) $infraccion->amonestacion
            || (bool) $infraccion->arresto_persona
            || (bool) $infraccion->suspension_licencia
            || (bool) $infraccion->cancelacion_licencia
            || (int) $infraccion->puntos > 0;
    }

    private function formatosImpresionPayload(): array
    {
        return [
            [
                'key' => self::FORMATO_IPH_BARANDILLAS,
                'label' => 'Formato nuevo Barandillas',
                'query_param' => 'formato',
                'query_value' => self::FORMATO_IPH_BARANDILLAS,
                'default' => true,
            ],
            [
                'key' => self::FORMATO_IPH_ANTERIOR,
                'label' => 'Formato anterior',
                'query_param' => 'formato',
                'query_value' => self::FORMATO_IPH_ANTERIOR,
                'default' => false,
            ],
        ];
    }

    private function fundamentosCorralonPayload()
    {
        return LicenciaPuntoInfraccion::activas()
            ->where(function ($query) {
                $query->where('retencion_vehiculo', true)
                    ->orWhere('deposito_si_sin_persona_habilitada', true);
            })
            ->get()
            ->reject(fn (LicenciaPuntoInfraccion $infraccion) => $this->esFundamentoExcluidoDelOperativo($infraccion))
            ->sortBy(function (LicenciaPuntoInfraccion $infraccion) {
                return implode('|', [
                    $infraccion->articulo ? str_pad((string) $infraccion->articulo, 8, '0', STR_PAD_LEFT) : 'ZZZZZZZZ',
                    $infraccion->fraccion ?: 'ZZZZ',
                    $infraccion->inciso ?: 'ZZZZ',
                    $infraccion->nombre,
                ]);
            })
            ->values()
            ->map(fn (LicenciaPuntoInfraccion $infraccion) => $this->fundamentoInfraccionPayload($infraccion));
    }

    private function fundamentosActividadCorralonPayload()
    {
        return LicenciaPuntoInfraccion::activas()
            ->where(function ($query) {
                $query->where('retencion_vehiculo', true)
                    ->orWhere('deposito_si_sin_persona_habilitada', true);
            })
            ->get()
            ->sortBy(function (LicenciaPuntoInfraccion $infraccion) {
                return implode('|', [
                    $infraccion->ambito_vehiculo ?: 'general',
                    $infraccion->articulo ? str_pad((string) $infraccion->articulo, 8, '0', STR_PAD_LEFT) : 'ZZZZZZZZ',
                    $infraccion->fraccion ?: 'ZZZZ',
                    $infraccion->inciso ?: 'ZZZZ',
                    $infraccion->nombre,
                ]);
            })
            ->values()
            ->map(fn (LicenciaPuntoInfraccion $infraccion) => $this->fundamentoInfraccionPayload($infraccion));
    }

    private function fundamentosConduceLegalidadPayload()
    {
        return $this->fundamentosCorralonPayload()
            ->filter(fn (array $fundamento) => $this->ambitoFundamentoAplicaConduceLegalidad(
                $fundamento['ambito_vehiculo'] ?? null
            ))
            ->values();
    }

    private function fundamentosPersonaPayload()
    {
        return LicenciaPuntoInfraccion::activas()
            ->where(function ($query) {
                $query->where('amonestacion', true)
                    ->orWhere('arresto_persona', true)
                    ->orWhere('suspension_licencia', true)
                    ->orWhere('cancelacion_licencia', true)
                    ->orWhere('puntos', '>', 0);
            })
            ->get()
            ->filter(fn (LicenciaPuntoInfraccion $infraccion) => $this->infraccionAplicaSancionPersonaOperativo($infraccion))
            ->sortBy(function (LicenciaPuntoInfraccion $infraccion) {
                return implode('|', [
                    $infraccion->arresto_persona ? '0' : '1',
                    $infraccion->articulo ? str_pad((string) $infraccion->articulo, 8, '0', STR_PAD_LEFT) : 'ZZZZZZZZ',
                    $infraccion->fraccion ?: 'ZZZZ',
                    $infraccion->inciso ?: 'ZZZZ',
                    $infraccion->nombre,
                ]);
            })
            ->values()
            ->map(fn (LicenciaPuntoInfraccion $infraccion) => $this->fundamentoInfraccionPayload($infraccion));
    }

    private function fundamentoInfraccionPayload(LicenciaPuntoInfraccion $infraccion): array
    {
        return [
            'id' => $infraccion->id,
            'codigo' => $infraccion->codigo,
            'nombre' => $infraccion->nombre,
            'articulo' => $infraccion->articulo,
            'fraccion' => $infraccion->fraccion,
            'inciso' => $infraccion->inciso,
            'ambito_vehiculo' => $infraccion->ambito_vehiculo,
            'ambito_vehiculo_texto' => $infraccion->ambito_vehiculo_texto,
            'referencia_legal_corta' => $infraccion->referencia_legal_corta,
            'puntos' => (int) $infraccion->puntos,
            'multa_uma_min' => $infraccion->multa_uma_min,
            'multa_uma_max' => $infraccion->multa_uma_max,
            'multa_uma_texto' => $infraccion->multa_uma_texto,
            'amonestacion' => (bool) $infraccion->amonestacion,
            'arresto_persona' => (bool) $infraccion->arresto_persona,
            'suspension_licencia' => (bool) $infraccion->suspension_licencia,
            'cancelacion_licencia' => (bool) $infraccion->cancelacion_licencia,
            'deposito_si_sin_persona_habilitada' => (bool) $infraccion->deposito_si_sin_persona_habilitada,
            'sancion_persona_texto' => $infraccion->sancion_persona_texto,
            'retencion_vehiculo' => (bool) $infraccion->retencion_vehiculo,
            'resumen_sanciones' => $infraccion->resumen_sanciones,
            'etiqueta_operativa' => $this->textoOperativoInfraccion($infraccion),
            'texto_operativo' => $this->textoOperativoInfraccion($infraccion),
            'descripcion' => $infraccion->descripcion,
            'fundamento_legal' => $infraccion->fundamento_legal,
            'narrativa_sugerida' => $this->narrativaSugeridaInfraccion($infraccion),
        ];
    }

    private function operativoPayload(ConduceLegalidadOperativo $operativo, $user, $capturas = null): array
    {
        $operativo->loadMissing(['delegacion', 'creador']);

        $adscripcion = $this->adscripcionTicket(
            $operativo,
            $operativo->creador ?: $user
        );
        $delegacion = $operativo->delegacion;
        if (!$delegacion && $adscripcion['delegacion_id']) {
            $delegacion = Delegacion::query()->find($adscripcion['delegacion_id']);
        }

        $isManager = $this->canManage($user);
        $alimentacionCierraEn = $this->alimentacionAlcoholimetriaCierraEn($operativo);
        $misCapturas = $operativo->mis_capturas_count;
        if ($misCapturas === null && $user) {
            $misCapturas = $operativo->capturas()->where('created_by', $user->id)->count();
        }
        $totalCapturas = $isManager
            ? (int) ($operativo->capturas_count ?? $operativo->capturas()->count())
            : (int) $misCapturas;

        $payload = [
            'id' => $operativo->id,
            'client_uuid' => $operativo->client_uuid,
            'nombre' => $operativo->nombre,
            'tipo_operativo' => $operativo->tipo_operativo,
            'fecha' => optional($operativo->fecha)->toDateString(),
            'unidad_id' => $adscripcion['unidad_id'] ?: null,
            'delegacion_id' => $adscripcion['delegacion_id'],
            'delegacion' => $this->refPayload($delegacion),
            'supervisor' => $this->supervisorTicket(
                $adscripcion['unidad_id'],
                $adscripcion['delegacion_id']
            ),
            'hora_inicio' => $operativo->hora_inicio,
            'hora_cierre' => $operativo->hora_cierre,
            'municipio' => $operativo->municipio,
            'lugar' => $operativo->lugar,
            'numero' => $operativo->numero,
            'colonia' => $operativo->colonia,
            'codigo_postal' => $operativo->codigo_postal,
            'lat' => $operativo->lat === null ? null : (float) $operativo->lat,
            'lng' => $operativo->lng === null ? null : (float) $operativo->lng,
            'coordenadas_texto' => $operativo->coordenadas_texto,
            'objetivo' => $operativo->objetivo,
            'narrativa' => $operativo->narrativa,
            'observaciones' => $operativo->observaciones,
            'estado' => $operativo->estado,
            'can_feed' => $this->puedeAlimentarOperativo($operativo, $user),
            'alimentacion_cierra_en' => optional($alimentacionCierraEn)->toISOString(),
            'alimentacion_cerrada' => $this->alimentacionAlcoholimetriaCerrada($operativo),
            'can_edit' => $this->canManage($user),
            'can_delete' => $this->canDeleteOperativo($user),
            'created_by' => $operativo->created_by,
            'creador' => $this->userPayload($operativo->creador),
            'total_capturas' => $totalCapturas,
            'mis_capturas' => (int) $misCapturas,
            'created_at' => optional($operativo->created_at)->toISOString(),
            'updated_at' => optional($operativo->updated_at)->toISOString(),
        ];

        if ($capturas !== null) {
            $payload['capturas'] = $capturas
                ->map(fn (ConduceLegalidadCaptura $captura) => $this->capturaPayload($captura, $user))
                ->values();
        }

        return $payload;
    }

    private function capturaPayload(ConduceLegalidadCaptura $captura, $user): array
    {
        $captura->loadMissing(['creador', 'unidad', 'delegacion', 'infraccion', 'fundamentos.infraccion', 'vehiculos.infraccion', 'personas.infraccion', 'fotos']);

        return [
            'id' => $captura->id,
            'client_uuid' => $captura->client_uuid,
            'operativo_id' => $captura->operativo_id,
            'licencia_punto_infraccion_id' => $captura->licencia_punto_infraccion_id,
            'infraccion_codigo' => $captura->infraccion_codigo,
            'fundamento_legal' => $captura->fundamento_legal,
            'infraccion' => $captura->infraccion
                ? $this->fundamentoInfraccionPayload($captura->infraccion)
                : null,
            'fundamentos' => $captura->fundamentos
                ->map(fn (ConduceLegalidadCapturaFundamento $fundamento) => $this->capturaFundamentoPayload($fundamento))
                ->values(),
            'created_by' => $captura->created_by,
            'creador' => $this->userPayload($captura->creador),
            'agente_nombre' => $captura->agente_nombre,
            'agente_nombres' => $captura->agente_nombres,
            'agente_apellido_paterno' => $captura->agente_apellido_paterno,
            'agente_apellido_materno' => $captura->agente_apellido_materno,
            'agente_numero_placa' => $captura->agente_numero_placa,
            'agente_adscripcion' => $captura->agente_adscripcion,
            'unidad' => $this->refPayload($captura->unidad),
            'delegacion' => $this->refPayload($captura->delegacion),
            'fecha' => optional($captura->fecha)->toDateString(),
            'hora' => $captura->hora,
            'municipio' => $captura->municipio,
            'lugar' => $captura->lugar,
            'lat' => $captura->lat === null ? null : (float) $captura->lat,
            'lng' => $captura->lng === null ? null : (float) $captura->lng,
            'coordenadas_texto' => $captura->coordenadas_texto,
            'narrativa' => $captura->narrativa,
            'observaciones' => $captura->observaciones,
            'rnd_data' => $captura->rnd_data,
            'can_edit' => $this->canEditCaptura($user, $captura),
            'can_delete' => $this->canDeleteCaptura($user),
            'vehiculos' => $captura->vehiculos->map(fn (ConduceLegalidadVehiculo $vehiculo) => $this->vehiculoPayload($vehiculo))->values(),
            'personas' => $captura->personas->map(fn (ConduceLegalidadPersona $persona) => $this->personaPayload($persona))->values(),
            'fotos' => $captura->fotos->map(fn (ConduceLegalidadFoto $foto) => $this->fotoPayload($foto))->values(),
            'created_at' => optional($captura->created_at)->toISOString(),
            'updated_at' => optional($captura->updated_at)->toISOString(),
        ];
    }

    private function capturaFundamentoPayload(
        ConduceLegalidadCapturaFundamento $fundamento
    ): array
    {
        $payload = $fundamento->infraccion
            ? $this->fundamentoInfraccionPayload($fundamento->infraccion)
            : [
                'id' => $fundamento->licencia_punto_infraccion_id ?: 0,
                'codigo' => $fundamento->infraccion_codigo,
                'nombre' => $fundamento->infraccion_codigo,
            ];

        $payload['infraccion_codigo'] = $fundamento->infraccion_codigo
            ?: ($payload['codigo'] ?? null);
        $payload['fundamento_legal_guardado'] = $fundamento->fundamento_legal
            ?: ($payload['fundamento_legal'] ?? null);

        return $payload;
    }

    private function fotoPayload(ConduceLegalidadFoto $foto): array
    {
        return [
            'id' => $foto->id,
            'foto_path' => $foto->foto_path,
            'foto_thumbnail_path' => $foto->foto_thumbnail_path,
            'foto_nombre_original' => $foto->foto_nombre_original,
            'foto_url' => $this->storageUrl($foto->foto_path),
            'foto_thumbnail_url' => $this->storageUrl($foto->foto_thumbnail_path ?: $foto->foto_path),
            'foto_preview_url' => $this->storageUrl($foto->foto_thumbnail_path ?: $foto->foto_path),
            'orden' => (int) $foto->orden,
        ];
    }

    private function vehiculoPayload(ConduceLegalidadVehiculo $vehiculo): array
    {
        return [
            'id' => $vehiculo->id,
            'marca' => $vehiculo->marca,
            'modelo' => $vehiculo->modelo,
            'tipo_general' => $vehiculo->tipo_general,
            'tipo' => $vehiculo->tipo,
            'linea' => $vehiculo->linea,
            'color' => $vehiculo->color,
            'placas' => $vehiculo->placas,
            'estado_placas' => $vehiculo->estado_placas,
            'serie' => $vehiculo->serie,
            'numero_inventario' => $vehiculo->numero_inventario,
            'capacidad_personas' => (int) $vehiculo->capacidad_personas,
            'tipo_servicio' => $vehiculo->tipo_servicio,
            'tarjeta_circulacion_nombre' => $vehiculo->tarjeta_circulacion_nombre,
            'grua_id' => $vehiculo->grua_id,
            'corralon_id' => $vehiculo->corralon_id,
            'grua' => $vehiculo->grua,
            'corralon' => $vehiculo->corralon ?: optional($vehiculo->corralonRelacion)->nombre,
            'servicio_unidad_id' => $vehiculo->servicio_unidad_id,
            'servicio_delegacion_id' => $vehiculo->servicio_delegacion_id,
            'servicio_created_by' => $vehiculo->servicio_created_by,
            'aseguradora' => $vehiculo->aseguradora,
            'monto_danos' => $vehiculo->monto_danos === null ? null : (float) $vehiculo->monto_danos,
            'partes_danadas' => $vehiculo->partes_danadas,
            'antecedente_vehiculo' => (bool) $vehiculo->antecedente_vehiculo,
            'raw_tarjeta_qr' => $vehiculo->raw_tarjeta_qr,
            'licencia_punto_infraccion_id' => $vehiculo->licencia_punto_infraccion_id,
            'infraccion_codigo' => $vehiculo->infraccion_codigo,
            'fundamento_legal' => $vehiculo->fundamento_legal,
            'retencion_vehiculo' => (bool) $vehiculo->retencion_vehiculo,
            'motivo_retencion' => $vehiculo->motivo_retencion,
            'persona_habilitada_resguardo' => (bool) $vehiculo->persona_habilitada_resguardo,
            'observaciones' => $vehiculo->observaciones,
            'infraccion' => $vehiculo->infraccion ? [
                'id' => $vehiculo->infraccion->id,
                'codigo' => $vehiculo->infraccion->codigo,
                'nombre' => $vehiculo->infraccion->nombre,
                'articulo' => $vehiculo->infraccion->articulo,
                'fraccion' => $vehiculo->infraccion->fraccion,
                'inciso' => $vehiculo->infraccion->inciso,
                'referencia_legal_corta' => $vehiculo->infraccion->referencia_legal_corta,
                'ambito_vehiculo' => $vehiculo->infraccion->ambito_vehiculo,
                'ambito_vehiculo_texto' => $vehiculo->infraccion->ambito_vehiculo_texto,
                'puntos' => (int) $vehiculo->infraccion->puntos,
                'multa_uma_min' => $vehiculo->infraccion->multa_uma_min,
                'multa_uma_max' => $vehiculo->infraccion->multa_uma_max,
                'multa_uma_texto' => $vehiculo->infraccion->multa_uma_texto,
                'etiqueta_operativa' => $this->textoOperativoInfraccion($vehiculo->infraccion),
                'texto_operativo' => $this->textoOperativoInfraccion($vehiculo->infraccion),
                'descripcion' => $vehiculo->infraccion->descripcion,
                'fundamento_legal' => $vehiculo->infraccion->fundamento_legal,
                'amonestacion' => (bool) $vehiculo->infraccion->amonestacion,
                'arresto_persona' => (bool) $vehiculo->infraccion->arresto_persona,
                'suspension_licencia' => (bool) $vehiculo->infraccion->suspension_licencia,
                'cancelacion_licencia' => (bool) $vehiculo->infraccion->cancelacion_licencia,
                'deposito_si_sin_persona_habilitada' => (bool) $vehiculo->infraccion->deposito_si_sin_persona_habilitada,
                'sancion_persona_texto' => $vehiculo->infraccion->sancion_persona_texto,
                'retencion_vehiculo' => (bool) $vehiculo->infraccion->retencion_vehiculo,
                'resumen_sanciones' => $vehiculo->infraccion->resumen_sanciones,
                'narrativa_sugerida' => $this->narrativaSugeridaInfraccion($vehiculo->infraccion),
            ] : null,
        ];
    }

    private function personaPayload(ConduceLegalidadPersona $persona): array
    {
        return [
            'id' => $persona->id,
            'nombre' => $persona->nombre,
            'nombres' => $persona->nombres,
            'apellido_paterno' => $persona->apellido_paterno,
            'apellido_materno' => $persona->apellido_materno,
            'telefono' => $persona->telefono,
            'domicilio' => $persona->domicilio,
            'sexo' => $persona->sexo,
            'nacionalidad' => $persona->nacionalidad,
            'ocupacion' => $persona->ocupacion,
            'edad' => $persona->edad,
            'edad_texto' => $persona->edad_texto,
            'estado_civil' => $persona->estado_civil,
            'edad_aproximada' => $persona->edad_aproximada,
            'complexion' => $persona->complexion,
            'estatura' => $persona->estatura,
            'tez' => $persona->tez,
            'cabello' => $persona->cabello,
            'prenda_superior' => $persona->prenda_superior,
            'color_superior' => $persona->color_superior,
            'prenda_inferior' => $persona->prenda_inferior,
            'color_inferior' => $persona->color_inferior,
            'calzado' => $persona->calzado,
            'color_calzado' => $persona->color_calzado,
            'rasgos_visibles' => $persona->rasgos_visibles ?: [],
            'tipo_licencia' => $persona->tipo_licencia,
            'estado_licencia' => $persona->estado_licencia,
            'numero_licencia' => $persona->numero_licencia,
            'vigencia_licencia' => optional($persona->vigencia_licencia)->toDateString(),
            'permanente' => (bool) $persona->permanente,
            'raw_licencia_qr' => $persona->raw_licencia_qr,
            'licencia_punto_infraccion_id' => $persona->licencia_punto_infraccion_id,
            'infraccion_codigo' => $persona->infraccion_codigo,
            'fundamento_legal' => $persona->fundamento_legal,
            'infraccion' => $persona->infraccion
                ? $this->fundamentoInfraccionPayload($persona->infraccion)
                : null,
            'observaciones' => $persona->observaciones,
        ];
    }

    private function userPayload($user): ?array
    {
        if (!$user) {
            return null;
        }

        $user->loadMissing(['personal.unidad', 'unidad']);
        $personal = $user->personal;
        $unidad = ($personal && $personal->unidad) ? $personal->unidad : $user->unidad;
        $unidadNombre = $unidad ? $unidad->nombre : null;
        $numeroPlaca = $this->nullableString($personal ? $personal->numero_placa : null);

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'numero_placa' => $numeroPlaca,
            'placa' => $numeroPlaca,
            'adscripcion' => $unidadNombre,
            'unidad_nombre' => $unidadNombre,
            'unidad_id' => $user->unidad_id,
            'delegacion_id' => $user->delegacion_id,
        ];
    }

    private function refPayload($model): ?array
    {
        if (!$model) {
            return null;
        }

        return [
            'id' => $model->id,
            'nombre' => $model->nombre ?? $model->name ?? null,
            'direccion_completa' => $model->direccion_completa ?? null,
        ];
    }

    private function storageUrl(?string $path): ?string
    {
        $clean = $this->nullableString($path);
        return $clean ? asset('storage/' . $clean) : null;
    }

    private function textoOperativoInfraccion(LicenciaPuntoInfraccion $infraccion): string
    {
        return $this->nullableString($infraccion->nombre)
            ?: $this->nullableString($infraccion->descripcion)
            ?: $this->nullableString($infraccion->codigo)
            ?: 'Fundamento #' . $infraccion->id;
    }

    private function narrativaSugeridaInfraccion(LicenciaPuntoInfraccion $infraccion): ?string
    {
        return strtoupper(trim((string) $infraccion->codigo)) === self::FUNDAMENTO_SIN_LICENCIA_CODIGO
            ? self::NARRATIVA_SIN_LICENCIA
            : null;
    }

    private function esFundamentoExcluidoDelOperativo(LicenciaPuntoInfraccion $infraccion): bool
    {
        $codigo = strtoupper(trim((string) $infraccion->codigo));
        if (in_array($codigo, self::FUNDAMENTOS_EXCLUIDOS_OPERATIVO, true)) {
            return true;
        }

        $texto = $this->normalizarTextoFiltro(implode(' ', [
            $infraccion->codigo,
            $infraccion->nombre,
            $infraccion->descripcion,
            $infraccion->fundamento_legal,
        ]));

        foreach (self::TEXTOS_EXCLUIDOS_OPERATIVO as $excluido) {
            if (str_contains($texto, $excluido)) {
                return true;
            }
        }

        return false;
    }

    private function normalizarTextoFiltro(string $texto): string
    {
        $texto = strtoupper(strtr($texto, [
            'Á' => 'A',
            'É' => 'E',
            'Í' => 'I',
            'Ó' => 'O',
            'Ú' => 'U',
            'Ü' => 'U',
            'Ñ' => 'N',
            'á' => 'A',
            'é' => 'E',
            'í' => 'I',
            'ó' => 'O',
            'ú' => 'U',
            'ü' => 'U',
            'ñ' => 'N',
        ]));
        $texto = preg_replace('/[^A-Z0-9]+/', ' ', $texto) ?? $texto;
        $texto = preg_replace('/\s+/', ' ', trim($texto)) ?? $texto;

        return $texto;
    }

    private function motivoRetencionPorInfraccion(LicenciaPuntoInfraccion $infraccion, bool $retencionCondicional = false): string
    {
        $referencia = $this->nullableString($infraccion->referencia_legal_corta);
        $motivo = $this->textoOperativoInfraccion($infraccion);

        if ($retencionCondicional) {
            $motivo = trim($motivo . ' - sin persona habilitada para resguardar el vehiculo');
        }

        if ($referencia && $motivo) {
            return $referencia . ' - ' . $motivo;
        }

        return $referencia ?: $motivo;
    }

    private function abilitiesPayload($user): array
    {
        return [
            'can_feed' => (bool) $user,
            'can_create_operativo' => $this->canCreateOperativo($user),
            'can_set_schedule' => $this->canSetOperativoSchedule($user),
            'can_assign_scope' => $this->canAssignOperativoScope($user),
            'can_manage_operativos' => $this->canManage($user),
            'can_view_all_capturas' => $this->canManage($user),
            'can_use_rnd' => $this->canUseRnd($user),
            'scope' => $this->canManage($user) ? 'all' : 'own',
        ];
    }

    private function scopeOperativos($query, $user): void
    {
        if (!$user) {
            $query->whereRaw('1=0');
            return;
        }

        if ($user->hasRole('Superadmin')) {
            return;
        }

        $unidadId = (int) ($user->unidad_id ?? 0);
        if ($unidadId <= 0) {
            $query->whereRaw('1=0');
            return;
        }

        $query->where(function ($unidades) use ($unidadId) {
            $unidades->where('unidad_id', $unidadId)
                ->orWhere(function ($legacy) use ($unidadId) {
                    $legacy->whereNull('unidad_id')
                        ->whereHas('creador', function ($creador) use ($unidadId) {
                            $creador->where('unidad_id', $unidadId);
                        });
                });
        });

        if ($unidadId !== self::UNIDAD_DELEGACIONES) {
            return;
        }

        $delegacionId = (int) ($user->delegacion_id ?? 0);
        if ($delegacionId <= 0) {
            $query->whereRaw('1=0');
            return;
        }

        $query->where(function ($delegaciones) use ($delegacionId) {
            $delegaciones->where('delegacion_id', $delegacionId)
                ->orWhere(function ($legacy) use ($delegacionId) {
                    $legacy->whereNull('delegacion_id')
                        ->whereHas('creador', function ($creador) use ($delegacionId) {
                            $creador->where('delegacion_id', $delegacionId);
                        });
                });
        });
    }

    private function canViewOperativo($user, ConduceLegalidadOperativo $operativo): bool
    {
        if (!$user) {
            return false;
        }

        if ($user->hasRole('Superadmin')) {
            return true;
        }

        $operativo->loadMissing('creador');
        $unidadId = (int) ($user->unidad_id ?? 0);
        $unidadOperativo = (int) ($operativo->unidad_id ?? optional($operativo->creador)->unidad_id ?? 0);
        if ($unidadId <= 0 || $unidadOperativo !== $unidadId) {
            return false;
        }

        if ($unidadId !== self::UNIDAD_DELEGACIONES) {
            return true;
        }

        $delegacionId = (int) ($user->delegacion_id ?? 0);
        $delegacionOperativo = (int) ($operativo->delegacion_id ?? optional($operativo->creador)->delegacion_id ?? 0);

        return $delegacionId > 0 && $delegacionOperativo === $delegacionId;
    }

    private function assertPuedeVerOperativo(ConduceLegalidadOperativo $operativo, $user): void
    {
        abort_unless($this->canViewOperativo($user, $operativo), 404);
    }

    private function scopeCapturas($query, $user): void
    {
        $query->whereHas('operativo', function ($operativos) use ($user) {
            $this->scopeOperativos($operativos, $user);
        });

        if ($this->canManage($user)) {
            return;
        }

        $query->where('created_by', $user ? $user->id : null);
    }

    private function canUseRnd($user): bool
    {
        if (!$user) {
            return false;
        }

        return (int) ($user->unidad_id ?? 0) !== self::UNIDAD_DELEGACIONES
            && optional($user->unidad)->slug !== 'delegaciones';
    }

    private function normalizeRndData($raw): ?array
    {
        if (!is_array($raw)) {
            return null;
        }

        $out = [];
        foreach ($this->rndDataKeys() as $key) {
            if (!array_key_exists($key, $raw)) {
                continue;
            }

            $value = $this->nullableString($raw[$key]);
            if ($value !== null) {
                $out[$key] = Str::limit($value, 2000, '');
            }
        }

        return $out === [] ? null : $out;
    }

    private function rndDataKeys(): array
    {
        return [
            'elementos_nombre',
            'elementos_cargo',
            'elementos_adscripcion',
            'falta_administrativa',
            'detencion_fecha_hora',
            'detencion_tiempo_forma',
            'detencion_motivo',
            'lugar_municipio',
            'lugar_localidad',
            'lugar_calle_numero',
            'lugar_referencia',
            'detenido_nombre',
            'detenido_alias',
            'detenido_nacionalidad',
            'detenido_edad',
            'detenido_lesiones_visibles',
            'detenido_delincuencia_organizada',
            'detenido_complexion',
            'traslado_ruta',
            'traslado_unidad',
            'solicitante_nombre',
            'solicitante_telefono',
        ];
    }

    private function rndMessage(array $data, string $usuario, string $telefono, string $referencia): string
    {
        $v = fn (string $key) => $this->rndValue($data[$key] ?? null);

        return implode("\n", [
            'DATOS PARA RND DE FALTAS ADMINISTRATIVAS',
            '',
            'REFERENCIA',
            'Usuario: ' . $usuario,
            'Telefono: ' . $telefono,
            'Registro: ' . $referencia,
            '',
            'ELEMENTOS',
            'Nombre: ' . $v('elementos_nombre'),
            'Cargo: ' . $v('elementos_cargo'),
            'Adscripcion: ' . $v('elementos_adscripcion'),
            '',
            'DETENCION',
            'Falta: ' . $v('falta_administrativa'),
            'Fecha/hora: ' . $v('detencion_fecha_hora'),
            'Tiempo y forma: ' . $v('detencion_tiempo_forma'),
            'Motivo: ' . $v('detencion_motivo'),
            '',
            'LUGAR',
            'Municipio: ' . $v('lugar_municipio'),
            'Localidad: ' . $v('lugar_localidad'),
            'Calle/numero: ' . $v('lugar_calle_numero'),
            'Referencia: ' . $v('lugar_referencia'),
            '',
            'DETENIDO',
            'Nombre: ' . $v('detenido_nombre'),
            'Alias: ' . $v('detenido_alias'),
            'Nacionalidad: ' . $v('detenido_nacionalidad'),
            'Edad: ' . $v('detenido_edad'),
            'Lesiones visibles: ' . $v('detenido_lesiones_visibles'),
            'Delincuencia organizada: ' . $v('detenido_delincuencia_organizada'),
            'Complexion: ' . $v('detenido_complexion'),
            '',
            'TRASLADO',
            'Ruta: ' . $v('traslado_ruta'),
            'Unidad: ' . $v('traslado_unidad'),
        ]);
    }

    private function rndValue($value): string
    {
        return $this->nullableString($value) ?: 'SIN DATO';
    }
    private function canCreateOperativo($user): bool
    {
        if (!$user) {
            return false;
        }

        if ($user->hasRole('Superadmin')) {
            return true;
        }

        if ($this->isDelegacionesUser($user) && $user->hasRole('Delegado')) {
            return true;
        }

        if (!$this->isVialidadesUser($user)) {
            return false;
        }

        if ($user->hasAnyRole(['Agente Vial', 'Fenix', 'Fénix', 'Motociclista'])) {
            return false;
        }

        return $user->hasAnyRole([
            'Responsable de Turno',
            'RT',
            'Subdirector',
            'Administrador',
            'Administrativo',
        ]);
    }

    private function operativoRulesForUser($user, ?ConduceLegalidadOperativo $operativo = null): array
    {
        $rules = $this->operativoRules($operativo);
        if (!$this->canSetOperativoSchedule($user)) {
            unset($rules['fecha'], $rules['hora_inicio']);
        }

        if ($this->canAssignOperativoScope($user)) {
            $rules['unidad_id'] = [
                $operativo ? 'sometimes' : 'required',
                'integer',
                Rule::exists('unidades', 'id')->where(
                    fn ($query) => $query->where('activa', true)
                ),
            ];
            $rules['delegacion_id'] = [
                'nullable',
                'integer',
                'required_if:unidad_id,' . self::UNIDAD_DELEGACIONES,
                'prohibited_unless:unidad_id,' . self::UNIDAD_DELEGACIONES,
                Rule::exists('delegaciones', 'id')->where(
                    fn ($query) => $query->where('activa', true)
                ),
            ];
        }

        return $rules;
    }

    private function canSetOperativoSchedule($user): bool
    {
        return $user && (
            (int) ($user->unidad_id ?? 0) === self::UNIDAD_VIALIDADES_URBANAS
            || $user->hasAnyRole(['Superadmin', 'Administrador', 'Subdirector'])
        );
    }

    private function canAssignOperativoScope($user): bool
    {
        return $user
            && $user->hasRole('Superadmin');
    }

    private function resolveOperativoSchedule($user, array $validated, $now): array
    {
        if (!$this->canSetOperativoSchedule($user)) {
            return [
                'fecha' => $now->toDateString(),
                'hora_inicio' => $now->format('H:i:s'),
            ];
        }

        return [
            'fecha' => $validated['fecha'] ?? $now->toDateString(),
            'hora_inicio' => $validated['hora_inicio'] ?? $now->format('H:i:s'),
        ];
    }

    private function resolveOperativoScope(
        $user,
        array $validated,
        ?ConduceLegalidadOperativo $operativo = null
    ): array {
        if (!$this->canAssignOperativoScope($user)) {
            if ($operativo) {
                return [
                    'unidad_id' => (int) ($operativo->unidad_id ?? 0) ?: null,
                    'delegacion_id' => (int) ($operativo->delegacion_id ?? 0) ?: null,
                ];
            }

            $unidadId = (int) ($user->unidad_id ?? 0);
            if ($unidadId <= 0) {
                throw ValidationException::withMessages([
                    'unidad_id' => ['Tu usuario no tiene una unidad asignada.'],
                ]);
            }

            $delegacionId = (int) ($user->delegacion_id ?? 0);
            if ($unidadId === self::UNIDAD_DELEGACIONES && $delegacionId <= 0) {
                throw ValidationException::withMessages([
                    'delegacion_id' => ['Tu usuario no tiene una delegación asignada.'],
                ]);
            }

            return [
                'unidad_id' => $unidadId,
                'delegacion_id' => $unidadId === self::UNIDAD_DELEGACIONES
                    ? $delegacionId
                    : null,
            ];
        }

        if ($operativo && !array_key_exists('unidad_id', $validated)) {
            return [
                'unidad_id' => (int) ($operativo->unidad_id ?? 0) ?: null,
                'delegacion_id' => (int) ($operativo->delegacion_id ?? 0) ?: null,
            ];
        }

        $unidadId = (int) ($validated['unidad_id'] ?? 0);

        return [
            'unidad_id' => $unidadId ?: null,
            'delegacion_id' => $unidadId === self::UNIDAD_DELEGACIONES
                ? ((int) ($validated['delegacion_id'] ?? 0) ?: null)
                : null,
        ];
    }

    private function canReactivateOperativo($user): bool
    {
        return $user && $user->hasRole('Superadmin');
    }

    private function canManage($user): bool
    {
        if (!$user) {
            return false;
        }

        if ($user->hasAnyRole(['Superadmin', 'Administrador', 'Subdirector'])) {
            return true;
        }

        if ($this->isRtVialidades($user) || $this->isSubdirectorVialidades($user)) {
            return true;
        }

        if ($this->isVialidadesUser($user)
            && $user->hasAnyRole(['Agente Vial', 'Fenix', 'Fénix', 'Motociclista'])) {
            return false;
        }

        return $this->isVialidadesUser($user) && $user->can('editar conduce legalidad');
    }

    private function canEditCaptura($user, ConduceLegalidadCaptura $captura): bool
    {
        if (!$user) {
            return false;
        }

        if ($this->canManage($user)) {
            return true;
        }

        return (int) $captura->created_by === (int) $user->id;
    }

    private function canDeleteOperativo($user): bool
    {
        return $this->canDeleteAdministrativo($user);
    }

    private function canDeleteCaptura($user): bool
    {
        return $this->canDeleteAdministrativo($user);
    }

    private function canDeleteAdministrativo($user): bool
    {
        if (!$user) {
            return false;
        }

        return $user->hasAnyRole(['Superadmin', 'Administrador']);
    }

    private function isRtVialidades($user): bool
    {
        return $this->isVialidadesUser($user)
            && $user->hasAnyRole(['Responsable de Turno', 'RT']);
    }

    private function isSubdirectorVialidades($user): bool
    {
        return $this->isVialidadesUser($user)
            && $user->hasRole('Subdirector');
    }

    private function isDelegacionesUser($user): bool
    {
        return (int) ($user->unidad_id ?? 0) === self::UNIDAD_DELEGACIONES
            || optional($user->unidad)->slug === 'delegaciones';
    }

    private function isVialidadesUser($user): bool
    {
        return (int) ($user->unidad_id ?? 0) === self::UNIDAD_VIALIDADES_URBANAS
            || optional($user->unidad)->slug === 'vialidades-urbanas';
    }

    private function lugarConNumero($lugar, $numero): ?string
    {
        $lugar = $this->nullableString($lugar);
        $numero = $this->nullableString($numero);

        if ($lugar === null) {
            return $numero;
        }

        if ($numero === null) {
            return $lugar;
        }

        return $lugar . ' ' . $numero;
    }

    private function resolverCodigoPostalOperativo($lat, $lng): ?string
    {
        return $this->nullableString(
            app(CodigoPostalGeoService::class)->resolver($lat, $lng)
        );
    }

    private function codigoPostalOperativo(ConduceLegalidadOperativo $operativo): ?string
    {
        $codigoPostal = $this->nullableString($operativo->codigo_postal ?? null);

        if ($codigoPostal !== null) {
            return $codigoPostal;
        }

        $codigoPostal = $this->resolverCodigoPostalOperativo($operativo->lat, $operativo->lng);

        if ($codigoPostal === null) {
            return null;
        }

        if ($operativo->exists) {
            $timestamps = $operativo->timestamps;
            $operativo->timestamps = false;

            try {
                $operativo->forceFill(['codigo_postal' => $codigoPostal])->save();
            } finally {
                $operativo->timestamps = $timestamps;
            }
        }

        return $codigoPostal;
    }

    private function nullableStringArray($value): ?array
    {
        if (!is_array($value)) {
            return null;
        }

        $items = [];
        foreach ($value as $item) {
            $text = $this->nullableString($item);
            if ($text !== null && !in_array($text, $items, true)) {
                $items[] = $text;
            }
        }

        return empty($items) ? null : $items;
    }

    private function nullableString($value): ?string
    {
        $text = trim((string) ($value ?? ''));
        return $text === '' ? null : $text;
    }
}

