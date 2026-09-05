<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Helpers\StreetNormalizer;
use App\Models\Hechos;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

use App\Services\WhatsApp\WhatsAppLink;
use App\Services\Croquis\CroquisArchivoStorage;
use App\Services\CodigoPostalGeoService;
use App\Services\DelegacionesWhatsAppAlertService;
use App\Services\Fotos\HechoFotoStorage;
use App\Services\HechoRevisionNotificationService;
use App\Models\Dictamen;
use App\Support\HechoAccess;
use App\Support\HechoLocationGuard;
use App\Support\GruaEditGuard;
use Illuminate\Support\Facades\DB;

class HechoController extends Controller
{
    private const SECTORES = ['REVOLUCION','NUEVA ESPANA','INDEPENDENCIA','REPUBLICA','CENTRO'];
    private const TIEMPOS  = ['DIA','NOCHE','AMANECER','ATARDECER'];
    private const CLIMAS   = ['BUENO','MALO','NUBLADO','LLUVIOSO'];
    private const COND     = ['BUENO','REGULAR','MALO'];
    private const SITUAS   = ['RESUELTO','PENDIENTE','TURNADO','REPORTE'];

    public function index(Request $request)
    {
        $perPage = (int)($request->query('per_page', 20));
        $perPage = $perPage > 0 ? min($perPage, 100) : 20;

        $user = $request->user();

        $query = Hechos::with(['vehiculos.conductores', 'lesionados']);

        if ($request->filled('fecha')) {
            $query->whereDate('fecha', $request->query('fecha'));
        }

        $this->applyHechosVisibilityScope($query, $user);

        $hechos = $query->orderByDesc('id')->paginate($perPage);
        $hechos->setCollection(
            $hechos->getCollection()->transform(fn (Hechos $hecho) => $this->withFotoUrls($hecho))
        );

        return response()->json($hechos);
    }

    public function buscar(Request $request)
    {
        $user = $request->user();

        $q = trim((string)$request->query('q', ''));
        $perPage = (int)($request->query('per_page', 20));
        $perPage = $perPage > 0 ? min($perPage, 50) : 20;

        if ($q === '' || mb_strlen($q) < 2) {
            return response()->json([
                'data' => [],
                'meta' => [
                    'current_page' => 1,
                    'per_page'     => $perPage,
                    'total'        => 0,
                    'last_page'    => 1,
                ],
            ], 200);
        }

        $qNorm = strtoupper($this->removeAccents($q));
        $like  = '%' . addcslashes($qNorm, "%_\\") . '%';

        $query = Hechos::query()
            ->select([
                'hechos.id',
                'hechos.perito',
                'hechos.folio_c5i',
                'hechos.fecha',
                'hechos.calle',
                'hechos.colonia',
                'hechos.municipio',
                'hechos.codigo_postal',
                'hechos.situacion',
                'hechos.foto_lugar',
                'hechos.foto_lugar_2',
                'hechos.foto_situacion',
                'hechos.danos_patrimoniales',
                'hechos.propiedades_afectadas',
                'hechos.monto_danos_patrimoniales',
            ])
            ->with([
                'vehiculos' => function ($v) {
                    $v->select(['vehiculos.id', 'vehiculos.placas', 'vehiculos.serie'])
                      ->with([
                          'conductores' => function ($c) {
                              $c->select(['conductores.id', 'conductores.nombre']);
                          }
                      ]);
                },
                'lesionados' => function ($l) {
                    $l->select(['lesionados.id', 'lesionados.hecho_id', 'lesionados.nombre']);
                },
            ]);

        $this->applyHechosVisibilityScope($query, $user);

        $query->where(function ($w) use ($q, $like) {
                if (ctype_digit($q)) {
                    $w->orWhere('hechos.id', (int)$q);
                }

                $w->orWhere('hechos.folio_c5i', 'like', $like)
                  ->orWhere('hechos.calle', 'like', $like)
                  ->orWhere('hechos.colonia', 'like', $like);

                $w->orWhereHas('vehiculos', function ($v) use ($like) {
                    $v->where(function ($vv) use ($like) {
                        $vv->where('vehiculos.placas', 'like', $like)
                           ->orWhere('vehiculos.serie', 'like', $like);
                    });
                });

                $w->orWhereHas('vehiculos.conductores', function ($c) use ($like) {
                    $c->where('conductores.nombre', 'like', $like);
                });

                $w->orWhereHas('lesionados', function ($l) use ($like) {
                    $l->where('lesionados.nombre', 'like', $like);
                });
            })
            ->orderByDesc('hechos.id');

        $results = $query->paginate($perPage);

        $data = array_map(function ($row) {
            $row['foto_lugar_url']     = $this->hechoFotoUrl($row['foto_lugar'] ?? null);
            $row['foto_lugar_2_url']   = $this->hechoFotoUrl($row['foto_lugar_2'] ?? null);
            $row['foto_situacion_url'] = $this->hechoFotoUrl($row['foto_situacion'] ?? null);
            return $row;
        }, $results->items());

        return response()->json([
            'data' => $data,
            'meta' => [
                'current_page' => $results->currentPage(),
                'per_page'     => $results->perPage(),
                'total'        => $results->total(),
                'last_page'    => $results->lastPage(),
            ],
        ], 200);
    }

    public function seguimiento(Request $request)
    {
        $usuario = $request->user();

        $esUsuarioDelegaciones = $usuario && (int) ($usuario->unidad_id ?? 0) === 2;
        $periodoDefault = $esUsuarioDelegaciones ? 'ANIO' : 'SEMANA';
        $situacionDefault = $esUsuarioDelegaciones ? 'TODOS' : 'PENDIENTE';
        $puedeMostrarTodasSituaciones = $esUsuarioDelegaciones;

        $periodo = strtoupper((string) $request->query('periodo', $periodoDefault));
        $situacion = strtoupper((string) $request->query('situacion', $situacionDefault));
        $unidadFiltro = (string) $request->query('unidad_filtro', '');
        $perPage = (int) $request->query('per_page', 20);
        $perPage = $perPage > 0 ? min($perPage, 100) : 20;

        $puedeFiltrarUnidad = $usuario
            && ($usuario->hasRole('Superadmin') || (int) ($usuario->unidad_id ?? 0) === 3);

        $unidadesFiltro = [
            '1' => 'Siniestros',
            '2' => 'Delegaciones',
            '4' => 'Carreteras',
        ];

        $situacionesValidas = ['PENDIENTE', 'TURNADO', 'RESUELTO', 'FALTA_COMPLETAR'];
        if ($puedeMostrarTodasSituaciones) {
            $situacionesValidas[] = 'TODOS';
        }

        $periodosValidos = ['SEMANA', 'MES', 'ANIO'];

        if (!in_array($situacion, $situacionesValidas, true)) {
            $situacion = $situacionDefault;
        }

        if (!in_array($periodo, $periodosValidos, true)) {
            $periodo = $periodoDefault;
        }

        if (!$puedeFiltrarUnidad || !array_key_exists($unidadFiltro, $unidadesFiltro)) {
            $unidadFiltro = '';
        }

        $hoy = now('America/Mexico_City');
        $rangos = [
            'semana' => [
                $hoy->copy()->startOfWeek(),
                $hoy->copy()->endOfWeek(),
            ],
            'mes' => [
                $hoy->copy()->startOfMonth(),
                $hoy->copy()->endOfMonth(),
            ],
            'anio' => [
                $hoy->copy()->startOfYear(),
                $hoy->copy()->endOfYear(),
            ],
        ];

        $crearQueryConteo = function ($inicio, $fin, string $situacionConteo) use ($usuario, $puedeFiltrarUnidad, $unidadFiltro) {
            $query = Hechos::query()
                ->whereBetween('fecha', [$inicio->toDateString(), $fin->toDateString()])
                ->where('situacion', $situacionConteo);

            $this->applyHechosVisibilityScope($query, $usuario);
            $this->aplicarFiltroUnidadSeguimiento($query, $puedeFiltrarUnidad, $unidadFiltro);

            return $query;
        };

        $crearQueryTodos = function ($inicio, $fin) use ($usuario, $puedeFiltrarUnidad, $unidadFiltro) {
            $query = Hechos::query()
                ->whereBetween('fecha', [$inicio->toDateString(), $fin->toDateString()]);

            $this->applyHechosVisibilityScope($query, $usuario);
            $this->aplicarFiltroUnidadSeguimiento($query, $puedeFiltrarUnidad, $unidadFiltro);

            return $query;
        };

        $crearQueryFaltaCompletar = function ($inicio, $fin) use ($usuario, $puedeFiltrarUnidad, $unidadFiltro) {
            $query = Hechos::query()
                ->whereBetween('fecha', [$inicio->toDateString(), $fin->toDateString()]);

            $this->applyHechosVisibilityScope($query, $usuario);
            $this->aplicarFiltroFaltaCompletarSeguimiento($query, $puedeFiltrarUnidad, $unidadFiltro);

            return $query;
        };

        $conteos = [];
        foreach ($rangos as $key => [$inicio, $fin]) {
            $conteos[$key] = [
                'TODOS' => $crearQueryTodos($inicio, $fin)->count(),
                'PENDIENTE' => $crearQueryConteo($inicio, $fin, 'PENDIENTE')->count(),
                'TURNADO' => $crearQueryConteo($inicio, $fin, 'TURNADO')->count(),
                'RESUELTO' => $crearQueryConteo($inicio, $fin, 'RESUELTO')->count(),
                'FALTA_COMPLETAR' => $crearQueryFaltaCompletar($inicio, $fin)->count(),
            ];
        }

        $periodoKey = strtolower($periodo);
        [$inicioSeleccionado, $finSeleccionado] = $rangos[$periodoKey];

        $query = Hechos::query()->with(['creator', 'unidadOrganizacional', 'delegacion'])
            ->whereBetween('fecha', [
                $inicioSeleccionado->toDateString(),
                $finSeleccionado->toDateString(),
            ]);

        $this->applyHechosVisibilityScope($query, $usuario);

        if ($situacion === 'FALTA_COMPLETAR') {
            $this->aplicarFiltroFaltaCompletarSeguimiento($query, $puedeFiltrarUnidad, $unidadFiltro);
        } elseif ($situacion === 'TODOS') {
            $this->aplicarFiltroUnidadSeguimiento($query, $puedeFiltrarUnidad, $unidadFiltro);
        } else {
            $query->where('situacion', $situacion);
            $this->aplicarFiltroUnidadSeguimiento($query, $puedeFiltrarUnidad, $unidadFiltro);
        }

        $hechos = $query
            ->orderByDesc('fecha')
            ->orderByDesc('hora')
            ->paginate($perPage);

        $hechos->setCollection(
            $hechos->getCollection()->transform(function (Hechos $hecho) {
                return $this->seguimientoHechoPayload($hecho);
            })
        );

        return response()->json([
            'data' => $hechos->getCollection()->values()->all(),
            'conteos' => $conteos,
            'filters' => [
                'periodo' => $periodo,
                'situacion' => $situacion,
                'unidad_filtro' => $unidadFiltro,
                'puede_filtrar_unidad' => $puedeFiltrarUnidad,
                'puede_mostrar_todas_situaciones' => $puedeMostrarTodasSituaciones,
                'unidades_filtro' => $unidadesFiltro,
            ],
            'meta' => [
                'current_page' => $hechos->currentPage(),
                'per_page' => $hechos->perPage(),
                'total' => $hechos->total(),
                'last_page' => $hechos->lastPage(),
            ],
        ], 200);
    }

    public function store(Request $request)
    {
        $user = $request->user();

        $this->normalizarLongitudRequest($request);

        if ($this->userCannotCreateHecho($user)) {
            return response()->json([
                'message' => 'No tienes permiso para crear hechos.',
            ], 403);
        }

        $this->normalizeCatalogFields($request);
        $photoHashes = app(\App\Services\ActividadDuplicateGuard::class)->hashUploadedFiles([
            $request->file('foto_lugar'), $request->file('foto_lugar_2'), $request->file('foto_situacion'),
        ]);
        $fingerprint = app(\App\Services\HechoDuplicateGuard::class)->fingerprint(
            (int) $user->id, $request->all(), $photoHashes
        );
        $clientUuid = trim((string) $request->input('client_uuid', ''));
        $hechoExistente = Hechos::query()->where('submission_fingerprint', $fingerprint)->first();
        if ($clientUuid !== '') {
            $byUuid = Hechos::query()->where('client_uuid', $clientUuid)->first();
            if ($byUuid) {
                $matches = $byUuid->submission_fingerprint
                    ? $byUuid->submission_fingerprint === $fingerprint
                    : app(\App\Services\HechoDuplicateGuard::class)->legacyMatches($request->all(), $byUuid->getAttributes());
                if (!$matches) {
                    return response()->json([
                        'message' => 'Esta captura ya fue enviada con otros datos. No se modificó el hecho anterior. Abre el hecho guardado para continuar, o elige Nuevo hecho para otro evento.',
                        'code' => 'capture_already_submitted',
                    ], 409);
                }
                $hechoExistente = $byUuid;
            }
        }
        if ($hechoExistente) {
            return $this->existingCreateResponse($user, $hechoExistente);
        }
        $usaReglasFlexibles = $this->usaReglasFlexiblesHechos($user);
        $puedeCapturarFechaHora = $this->userCanCaptureFechaHora($user);
        $puedeUsarDictamenes = $this->userCanUseDictamenes($user);
        $puedeGestionarTotalesEsperados = HechoAccess::canManageTotalesEsperados($user);

        $reglaFolio = ['nullable', 'string', 'max:20', Rule::unique('hechos', 'folio_c5i')];

        $reglaSector = $usaReglasFlexibles
            ? 'nullable|string|max:100'
            : ['required', 'string', Rule::in(self::SECTORES)];

        $rules = [
            'client_uuid' => ['sometimes', 'nullable', 'string', 'max:36'],
            'folio_c5i' => $reglaFolio,
            'perito' => 'required|string|max:255',
            'autorizacion_practico' => 'nullable|string|max:255',
            'unidad' => 'required|string|max:50',
            'hora' => $puedeCapturarFechaHora ? 'required|date_format:H:i' : 'nullable',
            'fecha' => $puedeCapturarFechaHora ? 'required|date' : 'nullable',
            'sector' => $reglaSector,
            'calle' => 'required|string|max:255',
            'colonia' => 'required|string|max:255',
            'entre_calles' => 'nullable|string|max:255',
            'municipio' => 'required|string|max:100',
            'tipo_hecho' => 'required|string|max:255',
            'superficie_via' => 'required|string|max:50',
            'tiempo' => ['required', 'string', Rule::in(self::TIEMPOS)],
            'clima' => ['required', 'string', Rule::in(self::CLIMAS)],
            'condiciones' => ['required', 'string', Rule::in(self::COND)],
            'control_transito' => 'required|string|max:50',
            'checaron_antecedentes' => 'nullable|boolean',
            'causas' => 'required|string|max:255',
            'responsable' => 'nullable|string|max:255',
            'colision_camino' => 'required|string|max:255',
            'situacion' => ['required', 'string', Rule::in(self::SITUAS)],
            'oficio_mp' => $puedeUsarDictamenes ? 'nullable|string|max:255|required_if:situacion,TURNADO' : 'nullable',
            'vehiculos_mp' => 'required|integer|min:0',
            'personas_mp' => 'required|integer|min:0',
            'dictamen_id' => $puedeUsarDictamenes ? 'nullable|required_if:situacion,TURNADO|exists:dictamens,id' : 'nullable',
            'danos_patrimoniales' => 'nullable|boolean',
            'propiedades_afectadas' => 'nullable|string|max:2000',
            'monto_danos_patrimoniales' => 'nullable|numeric|min:0',
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
            'km_recorridos' => 'nullable|numeric|min:0',
            'calidad_geo' => 'nullable|string|max:20',
            'nota_geo' => 'nullable|string|max:1000',
            'fuente_ubicacion' => 'nullable|string|max:20',
            'ubicacion_formateada' => 'nullable|string|max:2000',
            'place_id' => 'nullable|string|max:128',
            'foto_lugar' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
            'foto_lugar_2' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
            'foto_situacion' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
        ];

        if ($puedeGestionarTotalesEsperados) {
            $rules['vehiculos_esperados'] = 'required|integer|min:0';
            $rules['conductores_esperados'] = 'required|integer|min:0';
            $rules['lesionados_esperados'] = 'required|integer|min:0';
        }

        $validator = Validator::make($request->all(), $rules, $this->messages());

        $validator->after(function ($v) use ($request, $usaReglasFlexibles, $puedeUsarDictamenes, $puedeGestionarTotalesEsperados) {
            $situacion = strtoupper($this->removeAccents((string) $request->input('situacion')));

            if (!$usaReglasFlexibles && in_array($situacion, ['RESUELTO', 'TURNADO'], true) && !$request->hasFile('foto_situacion')) {
                $v->errors()->add('foto_situacion', 'Para marcar el hecho como RESUELTO o TURNADO debes subir la foto de situación.');
            }

            if (HechoLocationGuard::isBlockedOfficeLocation($request->input('lat'), $request->input('lng'))) {
                $v->errors()->add('lat', HechoLocationGuard::OFFICE_MESSAGE);
                $v->errors()->add('lng', HechoLocationGuard::OFFICE_MESSAGE);
            }

            if ($situacion === 'TURNADO') {
                $vehiculosMp = (int) $request->input('vehiculos_mp', 0);
                $personasMp = (int) $request->input('personas_mp', 0);

                if ($vehiculosMp === 0 && $personasMp === 0) {
                    $v->errors()->add('vehiculos_mp', 'Si la situacion es TURNADO, captura al menos una persona o un vehiculo presentado al MP.');
                    $v->errors()->add('personas_mp', 'Si la situacion es TURNADO, captura al menos una persona o un vehiculo presentado al MP.');
                }
            }

            if ($puedeGestionarTotalesEsperados) {
                $vehiculosEsperados = (int) $request->input('vehiculos_esperados', 0);
                $conductoresEsperados = (int) $request->input('conductores_esperados', 0);

                if ($conductoresEsperados > $vehiculosEsperados) {
                    $v->errors()->add('conductores_esperados', 'Los conductores no pueden ser mayores que los vehículos.');
                }

                if ($vehiculosEsperados === 0 && $conductoresEsperados > 0) {
                    $v->errors()->add('vehiculos_esperados', 'No puede haber conductores si no hay vehículos.');
                }
            }
        });

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors()->toArray());
        }

        $validated = $validator->validated();

        if (array_key_exists('folio_c5i', $validated) && empty($validated['folio_c5i'])) {
            $validated['folio_c5i'] = null;
        }

        if ($usaReglasFlexibles && empty($validated['sector'])) {
            $validated['sector'] = $this->sectorPredeterminadoHechos($user);
        }

        $dictamenId = $puedeUsarDictamenes ? ($validated['dictamen_id'] ?? null) : null;
        unset($validated['dictamen_id'], $validated['foto_lugar'], $validated['foto_lugar_2'], $validated['foto_situacion']);

        $validated['checaron_antecedentes'] = $request->boolean('checaron_antecedentes');
        $validated['danos_patrimoniales'] = $request->boolean('danos_patrimoniales');

        if (!$validated['danos_patrimoniales']) {
            $validated['propiedades_afectadas'] = null;
            $validated['monto_danos_patrimoniales'] = null;
        }

        if ($request->has('monto_danos_patrimoniales') && !$request->filled('monto_danos_patrimoniales')) {
            $validated['monto_danos_patrimoniales'] = null;
        }

        if ($request->has('propiedades_afectadas') && trim((string) $request->input('propiedades_afectadas')) === '') {
            $validated['propiedades_afectadas'] = null;
        }

        if (!$puedeCapturarFechaHora) {
            $now = now('America/Mexico_City');
            $validated['fecha'] = $now->toDateString();
            $validated['hora'] = $now->format('H:i');
        }

        if ($request->filled('lat') && $request->filled('lng') && empty($validated['fuente_ubicacion'])) {
            $validated['fuente_ubicacion'] = 'GPS_APP';
        }

        foreach ($validated as $key => $value) {
            if (is_string($value) && !in_array($key, ['client_uuid', 'place_id'], true)) {
                $validated[$key] = strtoupper($this->removeAccents($value));
            }
        }

        if (!$puedeGestionarTotalesEsperados) {
            $validated['vehiculos_esperados'] = 0;
            $validated['conductores_esperados'] = 0;
            $validated['lesionados_esperados'] = 0;
        }

        $validated['vehiculos_capturados'] = 0;
        $validated['conductores_capturados'] = 0;
        $validated['lesionados_capturados'] = 0;
        $validated['captura_completa'] = !$puedeGestionarTotalesEsperados;
        $validated['captura_completa_at'] = !$puedeGestionarTotalesEsperados ? now() : null;

        if (!$puedeUsarDictamenes) {
            $validated['oficio_mp'] = null;
        }

        if (($validated['situacion'] ?? null) === 'TURNADO') {
            $validated['vehiculos_mp'] = (int) ($validated['vehiculos_mp'] ?? 0);
            $validated['personas_mp'] = (int) ($validated['personas_mp'] ?? 0);
        } else {
            $validated['vehiculos_mp'] = 0;
            $validated['personas_mp'] = 0;
        }

        $validated['submission_fingerprint'] = $fingerprint;
        $validated['calle_norm'] = StreetNormalizer::normalize($validated['calle'] ?? null);
        $validated['codigo_postal'] = app(CodigoPostalGeoService::class)
            ->resolver($validated['lat'] ?? null, $validated['lng'] ?? null);
        $validated['delegacion_id'] = $user->delegacion_id ?? null;
        $validated['created_by'] = $user->id;
        $validated['unidad_org_id'] = HechoAccess::effectiveUnidadId($user);
        $validated['estado_revision'] = 'pendiente';
        $validated['revisado_por'] = null;
        $validated['revisado_at'] = null;
        $validated['observacion_revision'] = null;

        $hecho = null;
        $newFotoLugarPath = null;
        $newFotoLugar2Path = null;
        $newFotoSituacionPath = null;
        $fotoStorage = app(HechoFotoStorage::class);

        try {
            DB::transaction(function () use (
                $request,
                $validated,
                $dictamenId,
                $puedeUsarDictamenes,
                $fotoStorage,
                &$hecho,
                &$newFotoLugarPath,
                &$newFotoLugar2Path,
                &$newFotoSituacionPath
            ) {
                $hecho = Hechos::create($validated);

                $updates = [];

                if ($request->hasFile('foto_lugar')) {
                    $newFotoLugarPath = $fotoStorage->putUploadedFile($request->file('foto_lugar'), $hecho, 'lugar');
                    $updates['foto_lugar'] = $newFotoLugarPath;
                }

                if ($request->hasFile('foto_lugar_2')) {
                    $newFotoLugar2Path = $fotoStorage->putUploadedFile($request->file('foto_lugar_2'), $hecho, 'lugar_2');
                    $updates['foto_lugar_2'] = $newFotoLugar2Path;
                }

                if ($request->hasFile('foto_situacion')) {
                    $newFotoSituacionPath = $fotoStorage->putUploadedFile($request->file('foto_situacion'), $hecho, 'situacion');
                    $updates['foto_situacion'] = $newFotoSituacionPath;
                }

                if (!empty($updates)) {
                    $hecho->update($updates);
                }

                $hecho->actualizarEstadoCaptura();

                if ($puedeUsarDictamenes && ($validated['situacion'] ?? null) === 'TURNADO' && $dictamenId) {
                    $dictamen = Dictamen::query()->lockForUpdate()->findOrFail($dictamenId);

                    if (!empty($dictamen->hecho_id) && (int) $dictamen->hecho_id !== (int) $hecho->id) {
                        throw new \RuntimeException('Ese dictamen ya está ligado a otro hecho.');
                    }

                    $dictamen->hecho_id = $hecho->id;
                    $dictamen->save();
                }
            });
        } catch (\Throwable $e) {
            $fotoStorage->delete($newFotoLugarPath);
            $fotoStorage->delete($newFotoLugar2Path);
            $fotoStorage->delete($newFotoSituacionPath);

            if ($e instanceof \Illuminate\Database\QueryException) {
                $existing = Hechos::query()->where('submission_fingerprint', $fingerprint)->first();
                if (!$existing && $clientUuid !== '') {
                    $existing = Hechos::query()->where('client_uuid', $clientUuid)->first();
                }
                if ($existing) {
                    return $this->existingCreateResponse($user, $existing);
                }
            }
            return response()->json([
                'message' => $e->getMessage(),
                'errors' => [
                    'hecho' => [$e->getMessage()],
                ],
            ], 422);
        }

        app(HechoRevisionNotificationService::class)->notificarJefesDeGrupoPorHechoPendiente($hecho);

        app(DelegacionesWhatsAppAlertService::class)->notificarHechoTurnado($hecho);

        $hecho = $hecho->fresh()->load(['vehiculos.conductores', 'lesionados']);

        return response()->json([
            'message' => 'Hecho creado exitosamente',
            'created' => true,
            'data' => $this->withFotoUrls($hecho),
            'meta' => [
                'id' => $hecho->id,
                'client_uuid' => $hecho->client_uuid,
            ],
        ], 201);
    }

    private function existingCreateResponse($user, Hechos $hecho)
    {
        if (!HechoAccess::canView($user, $hecho)) {
            return response()->json(['message' => 'No tienes permiso para consultar este hecho.'], 403);
        }
        $hecho->load(['vehiculos.conductores', 'lesionados']);
        return response()->json([
            'message' => 'Este hecho ya estaba guardado. No se creó otro ni se modificó el anterior.',
            'created' => false,
            'duplicate' => true,
            'data' => $this->withFotoUrls($hecho),
            'meta' => ['id' => $hecho->id, 'client_uuid' => $hecho->client_uuid],
        ], 200);
    }
    public function update(Request $request, Hechos $hecho)
    {
        $user = $request->user();

        $this->normalizarLongitudRequest($request);

        if (!HechoAccess::canEdit($user, $hecho)) {
            return response()->json([
                'message' => 'No tienes permiso para editar este hecho.',
            ], 403);
        }

        $hechoAntes = clone $hecho;

        $this->normalizeCatalogFields($request);

        $usaReglasFlexibles = $this->usaReglasFlexiblesHechos($user, $hecho);
        $puedeCapturarFechaHora = $this->userCanCaptureFechaHora($user);
        $puedeUsarDictamenes = $this->userCanUseDictamenes($user, $hecho);
        $puedeGestionarTotalesEsperados = HechoAccess::canManageTotalesEsperados($user, $hecho);

        $anioParaDictamen = (int) (optional($hecho->fecha)->year ?: optional($hecho->created_at)->year ?: now()->year);
        $fechaSolicitada = (string) $request->input('fecha', '');

        if ($puedeCapturarFechaHora && preg_match('/^(\d{4})-\d{2}-\d{2}$/', $fechaSolicitada, $coincidencias)) {
            $anioParaDictamen = (int) $coincidencias[1];
        }

        $reglaFolio = [
            'sometimes',
            'nullable',
            'string',
            'max:20',
            Rule::unique('hechos', 'folio_c5i')->ignore($hecho->id),
        ];

        $reglaSector = $usaReglasFlexibles
            ? 'sometimes|nullable|string|max:100'
            : ['sometimes', 'required', 'string', Rule::in(self::SECTORES)];

        $rules = [
            'folio_c5i' => $reglaFolio,
            'perito' => 'sometimes|required|string|max:255',
            'autorizacion_practico' => 'sometimes|nullable|string|max:255',
            'unidad' => 'sometimes|required|string|max:50',
            'hora' => $puedeCapturarFechaHora ? 'sometimes|required|date_format:H:i' : 'sometimes|nullable',
            'fecha' => $puedeCapturarFechaHora ? 'sometimes|required|date' : 'sometimes|nullable',
            'sector' => $reglaSector,
            'calle' => 'sometimes|required|string|max:255',
            'colonia' => 'sometimes|required|string|max:255',
            'entre_calles' => 'sometimes|nullable|string|max:255',
            'municipio' => 'sometimes|required|string|max:100',
            'tipo_hecho' => 'sometimes|required|string|max:255',
            'superficie_via' => 'sometimes|required|string|max:50',
            'tiempo' => ['sometimes', 'required', 'string', Rule::in(self::TIEMPOS)],
            'clima' => ['sometimes', 'required', 'string', Rule::in(self::CLIMAS)],
            'condiciones' => ['sometimes', 'required', 'string', Rule::in(self::COND)],
            'control_transito' => 'sometimes|required|string|max:50',
            'checaron_antecedentes' => 'sometimes|nullable|boolean',
            'causas' => 'sometimes|required|string|max:255',
            'responsable' => 'sometimes|nullable|string|max:255',
            'colision_camino' => 'sometimes|required|string|max:255',
            'situacion' => ['sometimes', 'required', 'string', Rule::in(self::SITUAS)],
            'oficio_mp' => $puedeUsarDictamenes ? 'sometimes|nullable|string|max:255|required_if:situacion,TURNADO' : 'sometimes|nullable',
            'vehiculos_mp' => 'sometimes|nullable|integer|min:0',
            'personas_mp' => 'sometimes|nullable|integer|min:0',
            'dictamen_id' => $puedeUsarDictamenes
                ? [
                    'sometimes',
                    'nullable',
                    'required_if:situacion,TURNADO',
                    Rule::exists('dictamens', 'id')->where(fn ($query) => $query->where('anio', $anioParaDictamen)),
                ]
                : 'sometimes|nullable',
            'danos_patrimoniales' => 'sometimes|nullable|boolean',
            'propiedades_afectadas' => 'sometimes|nullable|string|max:2000',
            'monto_danos_patrimoniales' => 'sometimes|nullable|numeric|min:0',
            'lat' => 'sometimes|nullable|numeric|between:-90,90',
            'lng' => 'sometimes|nullable|numeric|between:-180,180',
            'km_recorridos' => 'sometimes|nullable|numeric|min:0',
            'calidad_geo' => 'sometimes|nullable|string|max:20',
            'nota_geo' => 'sometimes|nullable|string|max:1000',
            'fuente_ubicacion' => 'sometimes|nullable|string|max:20',
            'ubicacion_formateada' => 'sometimes|nullable|string|max:2000',
            'place_id' => 'sometimes|nullable|string|max:128',
            'foto_lugar' => 'sometimes|nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
            'foto_lugar_2' => 'sometimes|nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
            'foto_situacion' => 'sometimes|nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
        ];

        if ($puedeGestionarTotalesEsperados) {
            $rules['vehiculos_esperados'] = 'sometimes|required|integer|min:0';
            $rules['conductores_esperados'] = 'sometimes|required|integer|min:0';
            $rules['lesionados_esperados'] = 'sometimes|required|integer|min:0';
        }

        $messages = $this->messages();

        $validator = Validator::make($request->all(), $rules, $messages);

        $validator->after(function ($v) use ($request, $hecho, $usaReglasFlexibles, $puedeUsarDictamenes, $puedeGestionarTotalesEsperados) {
            $situacionNueva = $request->has('situacion')
                ? strtoupper($this->removeAccents((string) $request->input('situacion')))
                : null;

            $situacionEfectiva = $situacionNueva ?? strtoupper((string) ($hecho->situacion ?? ''));

            if (!$usaReglasFlexibles && in_array($situacionEfectiva, ['RESUELTO', 'TURNADO'], true)) {
                $yaTieneFoto = !empty($hecho->foto_situacion);
                $vieneArchivo = $request->hasFile('foto_situacion');

                if (!$yaTieneFoto && !$vieneArchivo) {
                    $v->errors()->add('foto_situacion', 'Para marcar el hecho como RESUELTO o TURNADO debes subir la foto de situación.');
                }
            }

            $hasLat = $request->filled('lat');
            $hasLng = $request->filled('lng');

            if ($hasLat xor $hasLng) {
                $v->errors()->add('lat', 'Si envías ubicación, debes enviar lat y lng.');
                $v->errors()->add('lng', 'Si envías ubicación, debes enviar lat y lng.');
            }

            if ($hasLat && $hasLng && HechoLocationGuard::isBlockedOfficeLocation($request->input('lat'), $request->input('lng'))) {
                $v->errors()->add('lat', HechoLocationGuard::OFFICE_MESSAGE);
                $v->errors()->add('lng', HechoLocationGuard::OFFICE_MESSAGE);
            }

            if ($situacionEfectiva === 'TURNADO') {
                $vehiculosMp = $request->has('vehiculos_mp')
                    ? (int) $request->input('vehiculos_mp', 0)
                    : (int) ($hecho->vehiculos_mp ?? 0);
                $personasMp = $request->has('personas_mp')
                    ? (int) $request->input('personas_mp', 0)
                    : (int) ($hecho->personas_mp ?? 0);

                if ($vehiculosMp === 0 && $personasMp === 0) {
                    $v->errors()->add('vehiculos_mp', 'Si la situacion es TURNADO, captura al menos una persona o un vehiculo presentado al MP.');
                    $v->errors()->add('personas_mp', 'Si la situacion es TURNADO, captura al menos una persona o un vehiculo presentado al MP.');
                }
            }

            if ($puedeGestionarTotalesEsperados) {
                $vehiculosEsperados = $request->has('vehiculos_esperados') ? (int) $request->input('vehiculos_esperados') : (int) $hecho->vehiculos_esperados;
                $conductoresEsperados = $request->has('conductores_esperados') ? (int) $request->input('conductores_esperados') : (int) $hecho->conductores_esperados;

                if ($conductoresEsperados > $vehiculosEsperados) {
                    $v->errors()->add('conductores_esperados', 'Los conductores no pueden ser mayores que los vehículos.');
                }

                if ($vehiculosEsperados === 0 && $conductoresEsperados > 0) {
                    $v->errors()->add('vehiculos_esperados', 'No puede haber conductores si no hay vehículos.');
                }
            }
        });

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors()->toArray());
        }

        $validated = $validator->validated();

        if (array_key_exists('folio_c5i', $validated) && empty($validated['folio_c5i'])) {
            $validated['folio_c5i'] = null;
        }

        if (!$puedeGestionarTotalesEsperados) {
            unset(
                $validated['vehiculos_esperados'],
                $validated['conductores_esperados'],
                $validated['lesionados_esperados']
            );
        }

        if ($usaReglasFlexibles && array_key_exists('sector', $validated) && empty($validated['sector'])) {
            $validated['sector'] = $this->sectorPredeterminadoHechos($user, $hecho);
        }

        $dictamenId = $puedeUsarDictamenes ? ($validated['dictamen_id'] ?? null) : null;
        $dictamenIdProvided = $puedeUsarDictamenes && array_key_exists('dictamen_id', $validated);
        unset($validated['dictamen_id']);

        if ($request->has('checaron_antecedentes')) {
            $validated['checaron_antecedentes'] = $request->boolean('checaron_antecedentes');
        }

        if ($request->has('danos_patrimoniales')) {
            $validated['danos_patrimoniales'] = $request->boolean('danos_patrimoniales');
        }

        foreach ($validated as $key => $value) {
            if (is_string($value)) {
                $validated[$key] = strtoupper($this->removeAccents($value));
            }
        }

        if (array_key_exists('calle', $validated)) {
            $validated['calle_norm'] = StreetNormalizer::normalize($validated['calle'] ?? null);
        }

        if (!$puedeCapturarFechaHora) {
            unset($validated['hora'], $validated['fecha']);
        }

        $hasCoords = $request->filled('lat') && $request->filled('lng');
        if ($hasCoords && empty($validated['fuente_ubicacion'])) {
            $validated['fuente_ubicacion'] = 'GPS_APP';
        }

        if ($request->has('lat') && !$request->filled('lat')) {
            $validated['lat'] = null;
        }

        if ($request->has('lng') && !$request->filled('lng')) {
            $validated['lng'] = null;
        }

        if ($request->has('lat') || $request->has('lng')) {
            $latCodigoPostal = array_key_exists('lat', $validated) ? $validated['lat'] : $hecho->lat;
            $lngCodigoPostal = array_key_exists('lng', $validated) ? $validated['lng'] : $hecho->lng;

            $validated['codigo_postal'] = app(CodigoPostalGeoService::class)
                ->resolver($latCodigoPostal, $lngCodigoPostal);
        }

        if ($request->has('monto_danos_patrimoniales') && !$request->filled('monto_danos_patrimoniales')) {
            $validated['monto_danos_patrimoniales'] = null;
        }

        if ($request->has('propiedades_afectadas') && trim((string) $request->input('propiedades_afectadas')) === '') {
            $validated['propiedades_afectadas'] = null;
        }

        if (array_key_exists('danos_patrimoniales', $validated) && !$validated['danos_patrimoniales']) {
            $validated['propiedades_afectadas'] = null;
            $validated['monto_danos_patrimoniales'] = null;
        }

        if (!$puedeUsarDictamenes) {
            $validated['oficio_mp'] = null;
        }

        $situacionDespues = array_key_exists('situacion', $validated)
            ? (string) $validated['situacion']
            : (string) ($hecho->situacion ?? '');

        if ($situacionDespues === 'TURNADO') {
            if (array_key_exists('vehiculos_mp', $validated)) {
                $validated['vehiculos_mp'] = (int) ($validated['vehiculos_mp'] ?? 0);
            }

            if (array_key_exists('personas_mp', $validated)) {
                $validated['personas_mp'] = (int) ($validated['personas_mp'] ?? 0);
            }
        } elseif (array_key_exists('situacion', $validated)) {
            $validated['oficio_mp'] = null;
            $validated['vehiculos_mp'] = 0;
            $validated['personas_mp'] = 0;
        }

        $validated['updated_by'] = $user->id;

        unset($validated['unidad_org_id']);

        $newFotoLugarPath = null;
        $newFotoLugar2Path = null;
        $newFotoSituacionPath = null;
        $oldFotoLugar = $hecho->foto_lugar;
        $oldFotoLugar2 = $hecho->foto_lugar_2;
        $oldFotoSituacion = $hecho->foto_situacion;
        $fotoStorage = app(HechoFotoStorage::class);

        try {
            DB::transaction(function () use (
                $request,
                $hecho,
                $validated,
                $dictamenId,
                $dictamenIdProvided,
                $puedeUsarDictamenes,
                $fotoStorage,
                &$newFotoLugarPath,
                &$newFotoLugar2Path,
                &$newFotoSituacionPath
            ) {
                if ($request->hasFile('foto_lugar')) {
                    $newFotoLugarPath = $fotoStorage->putUploadedFile($request->file('foto_lugar'), $hecho, 'lugar');
                    $validated['foto_lugar'] = $newFotoLugarPath;
                }

                if ($request->hasFile('foto_lugar_2')) {
                    $newFotoLugar2Path = $fotoStorage->putUploadedFile($request->file('foto_lugar_2'), $hecho, 'lugar_2');
                    $validated['foto_lugar_2'] = $newFotoLugar2Path;
                }

                if ($request->hasFile('foto_situacion')) {
                    $newFotoSituacionPath = $fotoStorage->putUploadedFile($request->file('foto_situacion'), $hecho, 'situacion');
                    $validated['foto_situacion'] = $newFotoSituacionPath;
                }

                $hecho->update($validated);

                $situacion = $request->has('situacion')
                    ? strtoupper($this->removeAccents((string) $request->input('situacion')))
                    : strtoupper((string) ($hecho->situacion ?? ''));

                $dictamenActual = $hecho->dictamen;

                if ($puedeUsarDictamenes && $situacion === 'TURNADO') {
                    if ($dictamenIdProvided) {
                        if ($dictamenActual && (string) $dictamenActual->id !== (string) $dictamenId) {
                            $dictamenActual = Dictamen::query()->lockForUpdate()->find($dictamenActual->id);

                            if ($dictamenActual) {
                                $dictamenActual->hecho_id = null;
                                $dictamenActual->save();
                            }
                        }

                        if ($dictamenId) {
                            $nuevo = Dictamen::query()->lockForUpdate()->findOrFail($dictamenId);

                            if (!empty($nuevo->hecho_id) && (int) $nuevo->hecho_id !== (int) $hecho->id) {
                                throw new \RuntimeException('Ese dictamen ya está ligado a otro hecho.');
                            }

                            $nuevo->hecho_id = $hecho->id;
                            $nuevo->save();
                        }
                    }
                } else {
                    if ($dictamenActual) {
                        $dictamenActual = Dictamen::query()->lockForUpdate()->find($dictamenActual->id);

                        if ($dictamenActual) {
                            $dictamenActual->hecho_id = null;
                            $dictamenActual->save();
                        }
                    }
                }
            });
        } catch (\Throwable $e) {
            $fotoStorage->delete($newFotoLugarPath);
            $fotoStorage->delete($newFotoLugar2Path);
            $fotoStorage->delete($newFotoSituacionPath);

            return response()->json([
                'message' => $e->getMessage(),
                'errors' => [
                    'dictamen_id' => [$e->getMessage()],
                ],
            ], 422);
        }

        $hecho->actualizarEstadoCaptura();

        if ($newFotoLugarPath && !empty($oldFotoLugar)) {
            $fotoStorage->delete($oldFotoLugar);
        }

        if ($newFotoLugar2Path && !empty($oldFotoLugar2)) {
            $fotoStorage->delete($oldFotoLugar2);
        }

        if ($newFotoSituacionPath && !empty($oldFotoSituacion)) {
            $fotoStorage->delete($oldFotoSituacion);
        }

        $hecho = $hecho->fresh()->load(['vehiculos.conductores', 'lesionados']);

        $alertService = app(DelegacionesWhatsAppAlertService::class);

        if ($alertService->debeNotificarNuevaPuestaHecho($hechoAntes, $hecho)) {
            $alertService->notificarHechoTurnado($hecho);
        }

        return response()->json([
            'message' => 'Hecho actualizado exitosamente',
            'data' => $this->withFotoUrls($hecho),
        ], 200);
    }

    public function show(Hechos $hecho)
    {
        $user = request()->user();

        $q = Hechos::query()->whereKey($hecho->id);
        $this->applyHechosVisibilityScope($q, $user);

        if (!$q->exists()) {
            return response()->json([
                'message' => 'No encontrado.',
            ], 404);
        }

        $this->resolverCodigoPostalFaltante($hecho);

        $hecho->load(['vehiculos.conductores', 'lesionados']);

        return response()->json([
            'data' => $this->withFotoUrls($hecho),
        ], 200);
    }

    public function destroy(Request $request, Hechos $hecho)
    {
        $user = $request->user();

        $q = Hechos::query()->whereKey($hecho->id);
        $this->applyHechosVisibilityScope($q, $user);

        if (!$q->exists()) {
            return response()->json([
                'message' => 'No encontrado.',
            ], 404);
        }

        if (!$this->userCanDeleteHecho($user)) {
            return response()->json([
                'message' => 'No tienes permiso para eliminar este hecho.',
            ], 403);
        }

        $hecho->loadMissing('vehiculos');

        if (
            GruaEditGuard::locksHecho($user, $hecho)
            && $hecho->vehiculos->contains(fn ($vehiculo) => GruaEditGuard::vehicleHasGruaData($vehiculo))
        ) {
            return response()->json([
                'message' => 'Este hecho tiene grúa o corralón bloqueado. Solicita autorización de un Administrador.',
            ], 403);
        }

        try {
            DB::transaction(function () use ($hecho) {
                $fotoStorage = app(HechoFotoStorage::class);
                $fotoStorage->delete($hecho->foto_lugar);
                $fotoStorage->delete($hecho->foto_lugar_2);
                $fotoStorage->delete($hecho->foto_situacion);

                if (!empty($hecho->descargo_path) && Storage::disk('public')->exists($hecho->descargo_path)) {
                    Storage::disk('public')->delete($hecho->descargo_path);
                }

                $dictamenActual = $hecho->dictamen;
                if ($dictamenActual) {
                    $dictamenActual->hecho_id = null;
                    $dictamenActual->save();
                }

                $hecho->vehiculos()->detach();
                $hecho->lesionados()->delete();

                if ($hecho->croquis) {
                    app(CroquisArchivoStorage::class)->delete($hecho->croquis->imagen_preview);
                    app(CroquisArchivoStorage::class)->delete($hecho->croquis->pdf_path);
                    $hecho->croquis->delete();
                }

                $hecho->delete();
            });
        } catch (\Throwable $e) {
            return response()->json([
                'message' => 'No se pudo eliminar el hecho. Revisa relaciones o llaves foráneas relacionadas.',
                'errors' => [
                    'hecho' => [$e->getMessage()],
                ],
            ], 422);
        }

        return response()->json([
            'message' => 'Hecho eliminado exitosamente',
        ], 200);
    }

    public function subirDescargo(Request $request, Hechos $hecho)
    {
        if (!HechoAccess::canEdit($request->user(), $hecho)) {
            return response()->json([
                'message' => 'No tienes permiso para editar este hecho.',
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'descargo' => 'required|file|mimes:pdf,jpeg,png|max:5120',
        ], $this->messages());

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors()->toArray());
        }

        $path = $request->file('descargo')->store('descargos', 'public');

        $hecho->descargo_path = $path;
        $hecho->save();

        return response()->json([
            'message' => 'Descargo subido correctamente',
            'path'    => Storage::url($path),
        ], 200);
    }

    public function subirIphDelegacion(Request $request, Hechos $hecho)
    {
        $user = $request->user();

        if (!$this->userCanUploadDelegacionesIph($user, $hecho)) {
            return response()->json([
                'message' => 'No tienes permiso para subir IPH a este hecho.',
            ], 403);
        }

        $situacion = strtoupper($this->removeAccents((string) ($hecho->situacion ?? '')));
        if ($situacion !== 'TURNADO') {
            return response()->json([
                'message' => 'Solo puedes subir IPH cuando el hecho está TURNADO.',
                'errors' => [
                    'situacion' => ['El hecho debe estar TURNADO.'],
                ],
            ], 422);
        }

        $archivoField = $request->hasFile('archivo_iph') ? 'archivo_iph' : 'archivo_dictamen';

        $validator = Validator::make($request->all(), [
            $archivoField => 'required|file|mimes:pdf|max:20480',
            'nombre_policia' => 'sometimes|nullable|string|max:100',
            'nombre_mp' => 'sometimes|nullable|string|max:100',
        ], $this->messages());

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors()->toArray());
        }

        $path = $request->file($archivoField)->store("iph_delegaciones/{$hecho->id}", 'public');
        $oldPath = null;

        try {
            DB::transaction(function () use ($hecho, $user, $path, &$oldPath) {
                $locked = Hechos::query()
                    ->whereKey($hecho->id)
                    ->lockForUpdate()
                    ->firstOrFail();

                $oldPath = $locked->iph_delegaciones_path;
                $locked->iph_delegaciones_path = $path;
                $locked->updated_by = $user->id;
                $locked->save();
            });
        } catch (\Throwable $e) {
            if (Storage::disk('public')->exists($path)) {
                Storage::disk('public')->delete($path);
            }

            return response()->json([
                'message' => $e->getMessage(),
                'errors' => [
                    $archivoField => [$e->getMessage()],
                ],
            ], 422);
        }

        if ($oldPath && $oldPath !== $path && Storage::disk('public')->exists($oldPath)) {
            Storage::disk('public')->delete($oldPath);
        }

        $hecho = $hecho->fresh()->load(['vehiculos.conductores', 'lesionados']);

        return response()->json([
            'message' => 'IPH de Delegaciones subido correctamente.',
            'data' => $this->withFotoUrls($hecho),
        ], 200);
    }

    private function resolverCodigoPostalFaltante(Hechos $hecho): void
    {
        if (!empty($hecho->codigo_postal) || !is_numeric($hecho->lat) || !is_numeric($hecho->lng)) {
            return;
        }

        $codigoPostal = app(CodigoPostalGeoService::class)->resolver($hecho->lat, $hecho->lng);

        if (empty($codigoPostal)) {
            return;
        }

        $timestamps = $hecho->timestamps;
        $hecho->timestamps = false;

        try {
            $hecho->forceFill(['codigo_postal' => $codigoPostal])->save();
        } finally {
            $hecho->timestamps = $timestamps;
        }
    }

    private function withFotoUrls(Hechos $hecho): array
    {
        $hecho->loadMissing(['dictamen', 'puestaDisposicion']);

        $data = $hecho->toArray();

        $data['foto_lugar_url']     = $this->hechoFotoUrl($hecho->foto_lugar);
        $data['foto_lugar_2_url']   = $this->hechoFotoUrl($hecho->foto_lugar_2);
        $data['foto_situacion_url'] = $this->hechoFotoUrl($hecho->foto_situacion);
        $data['iph_delegaciones_path'] = $hecho->iph_delegaciones_path ?? null;
        $data['iph_delegaciones_url'] = $this->publicStoragePath($data['iph_delegaciones_path']);
        $data['descargo_path'] = $data['descargo_path'] ?? $data['iph_delegaciones_path'];
        $data['descargo_url'] = $data['descargo_url'] ?? $data['iph_delegaciones_url'];
        $data['dictamen_id'] = $hecho->dictamen ? $hecho->dictamen->id : null;
        $data['dictamen_archivo'] = $hecho->dictamen ? $hecho->dictamen->archivo_dictamen : null;
        $data['dictamen_archivo_url'] = $hecho->dictamen
            ? route('api.dictamenes.archivo', $hecho->dictamen->id)
            : null;

        $puesta = $hecho->puestaDisposicion;
        $data['puesta_disposicion_id'] = $puesta ? $puesta->id : null;
        $data['puesta_disposicion'] = $puesta ? [
            'id' => $puesta->id,
            'numero_puesta' => $puesta->numero_puesta,
            'anio' => $puesta->anio,
            'tipo_puesta' => $puesta->tipo_puesta,
            'motivo' => $puesta->motivo,
            'estatus' => $puesta->estatus,
            'fecha_puesta' => $puesta->fecha_puesta
                ? $puesta->fecha_puesta->format('Y-m-d')
                : null,
            'hora_puesta' => $puesta->hora_puesta
                ? $puesta->hora_puesta->format('H:i')
                : null,
            'archivo_puesta' => $puesta->archivo_puesta,
            'archivo_puesta_url' => $puesta->archivo_puesta
                ? route('api.puestas_disposicion.archivo', $puesta->id)
                : null,
        ] : null;
        $data['puestas_disposicion'] = $data['puesta_disposicion']
            ? [$data['puesta_disposicion']]
            : [];

        $data['puede_editar'] = HechoAccess::canEdit(request()->user(), $hecho);
        $data['puede_gestionar_totales_esperados'] = HechoAccess::canManageTotalesEsperados(request()->user(), $hecho);

        if (!$data['puede_gestionar_totales_esperados']) {
            unset(
                $data['vehiculos_esperados'],
                $data['conductores_esperados'],
                $data['lesionados_esperados'],
                $data['faltantes_captura']
            );
        }

        return $data;
    }

    private function aplicarFiltroUnidadSeguimiento($query, bool $puedeFiltrarUnidad, string $unidadFiltro): void
    {
        if (!$puedeFiltrarUnidad || $unidadFiltro === '') {
            return;
        }

        $this->scopeHechosUnidadSeguimiento($query, (int) $unidadFiltro);
    }

    private function aplicarFiltroFaltaCompletarSeguimiento($query, bool $puedeFiltrarUnidad, string $unidadFiltro): void
    {
        if ($puedeFiltrarUnidad && $unidadFiltro !== '' && $unidadFiltro !== '2') {
            $query->whereRaw('1=0');
            return;
        }

        $this->scopeHechosUnidadSeguimiento($query, 2);
        $this->aplicarFiltroCapturaIncompletaDelegacionesSeguimiento($query);
    }

    private function scopeHechosUnidadSeguimiento($query, int $unidadId): void
    {
        HechoAccess::applyUnidadScope($query, $unidadId);
    }

    private function aplicarFiltroCapturaIncompletaDelegacionesSeguimiento($query): void
    {
        $query->where(function ($q) {
            $q->where('captura_completa', false)
                ->orWhereNull('captura_completa')
                ->orWhereRaw('COALESCE(vehiculos_capturados, 0) < COALESCE(vehiculos_esperados, 0)')
                ->orWhereRaw('COALESCE(conductores_capturados, 0) < COALESCE(conductores_esperados, 0)')
                ->orWhereRaw('COALESCE(lesionados_capturados, 0) < COALESCE(lesionados_esperados, 0)');
        });
    }

    private function seguimientoHechoPayload(Hechos $hecho): array
    {
        $hecho->loadMissing(['creator', 'unidadOrganizacional', 'delegacion']);

        $unidadReal = HechoAccess::effectiveUnidadIdForHecho($hecho);
        $capturaCompleta = $unidadReal === 2
            ? $hecho->capturaCompletaCalculada()
            : (bool) $hecho->captura_completa;

        $hecho->mostrar_captura = $unidadReal === 2;
        $hecho->captura_completa = $capturaCompleta;
        $hecho->faltantes_captura = $unidadReal === 2 ? $hecho->faltantesCapturaTexto() : [];
        $hecho->estado_captura = $unidadReal === 2
            ? ($capturaCompleta ? 'COMPLETO' : 'INCOMPLETO')
            : null;

        $data = $this->withFotoUrls($hecho);
        $unidad = $hecho->unidadOrganizacional;
        $delegacion = $hecho->delegacion;
        $creator = $hecho->creator;

        $data['unidad_real_id'] = $unidadReal;
        $data['unidad_nombre'] = $unidad ? $unidad->nombre : ($hecho->unidad ?? null);
        $data['delegacion_nombre'] = $delegacion ? $delegacion->nombre : null;
        $data['creator_name'] = $creator ? $creator->name : null;
        $data['puede_eliminar'] = $this->userCanDeleteHecho(request()->user());

        return $data;
    }

    private function validationErrorResponse(array $errors)
    {
        $first = null;
        foreach ($errors as $field => $msgs) {
            if (!empty($msgs[0])) {
                $first = $msgs[0];
                break;
            }
        }

        return response()->json([
            'message' => $first ?: 'Revisa los campos marcados e inténtalo de nuevo.',
            'errors'  => $errors,
        ], 422);
    }

    private function usaReglasFlexiblesHechos($user, ?Hechos $hecho = null): bool
    {
        $unidadId = $hecho
            ? HechoAccess::effectiveUnidadIdForHecho($hecho)
            : HechoAccess::effectiveUnidadId($user);

        return in_array($unidadId, [2, 4], true);
    }

    private function sectorPredeterminadoHechos($user, ?Hechos $hecho = null): string
    {
        $unidadId = $hecho
            ? HechoAccess::effectiveUnidadIdForHecho($hecho)
            : HechoAccess::effectiveUnidadId($user);

        return $unidadId === 4
            ? 'PROTECCION A CARRETERAS'
            : 'DELEGACIONES';
    }

    private function normalizarLongitudRequest(Request $request): void
    {
        if ($request->has('lng') && is_numeric($request->input('lng'))) {
            $request->merge([
                'lng' => Hechos::normalizarLongitud($request->input('lng')),
            ]);
        }
    }

    private function messages(): array
    {
        return [
            'required' => 'Este campo es obligatorio.',
            'string'   => 'Escribe un texto válido.',
            'max'      => 'Máximo :max caracteres.',
            'min'      => 'El valor mínimo es :min.',
            'date'     => 'Escribe una fecha válida.',
            'date_format' => 'La hora debe tener formato HH:MM (ej. 08:30).',
            'integer'  => 'Solo se permiten números (sin letras).',
            'numeric'  => 'Solo se permiten números.',
            'boolean'  => 'Valor inválido.',
            'unique'   => 'Ese valor ya existe, usa uno diferente.',
            'image'    => 'El archivo debe ser una imagen.',
            'mimes'    => 'Formato no permitido. Usa: :values.',
            'file'     => 'Archivo inválido.',
            'between'  => 'El valor está fuera de rango.',

            'folio_c5i.unique'   => 'Ese folio C5i ya está registrado.',
            'perito.required'    => 'Falta el nombre del perito.',
            'unidad.required'    => 'Falta la unidad.',
            'sector.in'          => 'Selecciona un sector válido.',
            'tiempo.in'          => 'Selecciona un tiempo válido (DÍA, NOCHE, AMANECER o ATARDECER).',
            'clima.in'           => 'Selecciona un clima válido.',
            'condiciones.in'     => 'Selecciona condiciones válidas.',
            'situacion.in'       => 'Selecciona una situación válida.',

            'vehiculos_mp.required' => 'Indica cuántos vehículos se turnaron (puede ser 0).',
            'vehiculos_mp.integer'  => 'En “Vehículos MP” solo se permiten números.',
            'personas_mp.required'  => 'Indica cuántas personas se turnaron (puede ser 0).',
            'personas_mp.integer'   => 'En “Personas MP” solo se permiten números.',

            'oficio_mp.required_if' => 'Si la situación es TURNADO, debes capturar el oficio del MP.',

            'lat.between'   => 'Latitud inválida.',
            'lng.between'   => 'Longitud inválida.',

            'monto_danos_patrimoniales.numeric' => 'En “Monto daños patrimoniales” solo se permiten números.',
            'monto_danos_patrimoniales.min'     => 'El monto no puede ser negativo.',
            'propiedades_afectadas.max'         => 'Máximo 2000 caracteres en “Propiedades afectadas”.',

            'foto_lugar.max'        => 'La foto del lugar es muy pesada (máximo 5 MB).',
            'foto_lugar_2.max'      => 'La foto 2 del lugar es muy pesada (máximo 5 MB).',
            'foto_situacion.max'    => 'La foto de situación es muy pesada (máximo 5 MB).',

            'vehiculos_esperados.required' => 'Indica cuántos vehículos participaron.',
            'vehiculos_esperados.integer' => 'En “Vehículos” solo se permiten números.',
            'conductores_esperados.required' => 'Indica cuántos conductores participaron.',
            'conductores_esperados.integer' => 'En “Conductores” solo se permiten números.',
            'lesionados_esperados.required' => 'Indica cuántos lesionados hubo.',
            'lesionados_esperados.integer' => 'En “Lesionados” solo se permiten números.',
        ];
    }

    private function normalizeCatalogFields(Request $request): void
    {
        $map = [];

        if ($request->has('sector')) {
            $map['sector'] = strtoupper($this->removeAccents((string)$request->input('sector')));
        }
        if ($request->has('tiempo')) {
            $map['tiempo'] = strtoupper($this->removeAccents((string)$request->input('tiempo')));
            if ($map['tiempo'] === 'ATARDECER' || $map['tiempo'] === 'ATARDECER ') {
                $map['tiempo'] = 'ATARDECER';
            }
        }
        if ($request->has('clima')) {
            $map['clima'] = strtoupper($this->removeAccents((string)$request->input('clima')));
        }
        if ($request->has('condiciones')) {
            $map['condiciones'] = strtoupper($this->removeAccents((string)$request->input('condiciones')));
        }
        if ($request->has('situacion')) {
            $map['situacion'] = strtoupper($this->removeAccents((string)$request->input('situacion')));
        }

        if (!empty($map)) {
            $request->merge($map);
        }
    }

    private function removeAccents(string $string): string
    {
        $unwanted_array = [
            'Á'=>'A','É'=>'E','Í'=>'I','Ó'=>'O','Ú'=>'U',
            'À'=>'A','È'=>'E','Ì'=>'I','Ò'=>'O','Ù'=>'U',
            'Â'=>'A','Ê'=>'E','Î'=>'I','Ô'=>'O','Û'=>'U',
            'Ä'=>'A','Ë'=>'E','Ï'=>'I','Ö'=>'O','Ü'=>'U',
            'á'=>'A','é'=>'E','í'=>'I','ó'=>'O','ú'=>'U',
            'à'=>'A','è'=>'E','ì'=>'I','ò'=>'O','ù'=>'U',
            'â'=>'A','ê'=>'E','î'=>'I','ô'=>'O','û'=>'U',
            'ä'=>'A','ë'=>'A','ï'=>'I','ö'=>'O','ü'=>'U',
            'Ñ'=>'N','ñ'=>'N','Ç'=>'C','ç'=>'C'
        ];

        return strtr($string, $unwanted_array);
    }

    private function publicStoragePath(?string $storedPath): ?string
    {
        if (empty($storedPath)) {
            return null;
        }

        return asset('storage/' . ltrim($storedPath, '/'));
    }

    private function hechoFotoUrl(?string $storedPath): ?string
    {
        return app(HechoFotoStorage::class)->url($storedPath);
    }

    private function applyHechosVisibilityScope($query, $usuario): void
    {
        HechoAccess::applyVisibilityScope($query, $usuario);
    }

    private function userCanEditHecho($usuario, \App\Models\Hechos $hecho): bool
    {
        return HechoAccess::canEdit($usuario, $hecho);
    }

    private function userCanDeleteHecho($usuario): bool
    {
        if (!$usuario) {
            return false;
        }

        if ($usuario->hasRole('Superadmin')) {
            return true;
        }

        $unidadId = (int) ($usuario->unidad_id ?? 0);

        if ($unidadId === 3) {
            return false;
        }

        return $usuario->hasRole('Administrador')
            && in_array($unidadId, [1, 2, 4], true);
    }

    public function whatsappLink(Request $request, Hechos $hecho)
    {
        $user = $request->user();

        if (!$user || !$user->can('ver hechos')) {
            return response()->json([
                'ok' => false,
                'message' => 'No autorizado.',
            ], 403);
        }

        $q = Hechos::query()->whereKey($hecho->id);
        $this->applyHechosVisibilityScope($q, $user);

        if (!$q->exists()) {
            return response()->json([
                'ok' => false,
                'message' => 'No encontrado.',
            ], 404);
        }

        $hecho->load(['vehiculos.conductores', 'lesionados', 'puestaDisposicion.personas']);

        $message = WhatsAppLink::textForHecho($hecho);

        $fechaMostrar = !empty($hecho->fecha)
            ? \Carbon\Carbon::parse($hecho->fecha)->format('Y-m-d')
            : '';

        $horaMostrar = !empty($hecho->hora)
            ? substr((string) $hecho->hora, 0, 5)
            : '';

        $ubicacionCorta = trim((string) ($hecho->calle ?? ''));
        if (!empty($hecho->colonia)) {
            $ubicacionCorta .= ', col. ' . trim((string) $hecho->colonia);
        }

        $message = preg_replace(
            '/\b\d{4}-\d{2}-\d{2}\s+00:00:00\s+\d{2}:\d{2}:\d{2}\s+Hrs\./u',
            $fechaMostrar . ' ' . $horaMostrar . ' Hrs.',
            $message,
            1
        );

        if (!empty($ubicacionCorta)) {
            $message = preg_replace(
                '/Guardia Civil toma conocimiento en .*?\./u',
                'Guardia Civil toma conocimiento en ' . $ubicacionCorta . '.',
                $message,
                1
            );
        }

        return response()->json([
            'ok' => true,
            'wa_url' => 'https://wa.me/?text=' . urlencode($message),
        ], 200);
    }

    public function nativeShare(Request $request, Hechos $hecho)
    {
        $user = $request->user();

        if (!$user || !$user->can('ver hechos')) {
            return response()->json([
                'ok' => false,
                'message' => 'No autorizado.',
            ], 403);
        }

        $q = Hechos::query()->whereKey($hecho->id);
        $this->applyHechosVisibilityScope($q, $user);

        if (!$q->exists()) {
            return response()->json([
                'ok' => false,
                'message' => 'No encontrado.',
            ], 404);
        }

        $hecho->load(['vehiculos.conductores', 'lesionados', 'puestaDisposicion.personas']);

        $message = WhatsAppLink::textForHecho($hecho);

        $fechaMostrar = !empty($hecho->fecha)
            ? \Carbon\Carbon::parse($hecho->fecha)->format('Y-m-d')
            : '';

        $horaMostrar = !empty($hecho->hora)
            ? substr((string) $hecho->hora, 0, 5)
            : '';

        $ubicacionCorta = trim((string) ($hecho->calle ?? ''));
        if (!empty($hecho->colonia)) {
            $ubicacionCorta .= ', col. ' . trim((string) $hecho->colonia);
        }

        $message = preg_replace(
            '/\b\d{4}-\d{2}-\d{2}\s+00:00:00\s+\d{2}:\d{2}:\d{2}\s+Hrs\./u',
            trim($fechaMostrar . ' ' . $horaMostrar) . ' Hrs.',
            $message,
            1
        );

        if (!empty($ubicacionCorta)) {
            $message = preg_replace(
                '/Guardia Civil toma conocimiento en .*?\./u',
                'Guardia Civil toma conocimiento en ' . $ubicacionCorta . '.',
                $message,
                1
            );
        }

        $fotos = [];

        if (!empty($hecho->foto_lugar)) {
            $fotos[] = $this->hechoFotoUrl($hecho->foto_lugar);
        }

        if (!empty($hecho->foto_lugar_2)) {
            $fotos[] = $this->hechoFotoUrl($hecho->foto_lugar_2);
        }

        if (!empty($hecho->foto_situacion)) {
            $fotos[] = $this->hechoFotoUrl($hecho->foto_situacion);
        }

        foreach ($hecho->vehiculos as $v) {
            if (!empty($v->fotos)) {
                $fotos[] = $this->hechoFotoUrl($v->fotos);
            }
        }

        $fotos = array_values(array_unique(array_filter($fotos)));

        return response()->json([
            'ok' => true,
            'data' => [
                'texto' => trim($message),
                'foto'  => $fotos[0] ?? null,
                'fotos' => $fotos,
            ],
        ], 200);
    }

    private function userCannotCreateHecho($user): bool
    {
        if (!$user) {
            return true;
        }

        return false;
    }

    private function userCanCaptureFechaHora($user): bool
    {
        if (!$user) {
            return false;
        }

        return $user->hasRole('Superadmin')
            || $user->hasRole('Administrador')
            || $user->hasRole('Subdirector');
    }

    private function userCanUseDictamenes($user, ?Hechos $hecho = null): bool
    {
        if (!$user) {
            return false;
        }

        $unidadId = $hecho
            ? HechoAccess::effectiveUnidadIdForHecho($hecho)
            : HechoAccess::effectiveUnidadId($user);

        return $unidadId === 1;
    }

    private function userCanUploadDelegacionesIph($user, Hechos $hecho): bool
    {
        if (!$user || !HechoAccess::canEdit($user, $hecho)) {
            return false;
        }

        return HechoAccess::effectiveUnidadIdForHecho($hecho) === 2;
    }

}
