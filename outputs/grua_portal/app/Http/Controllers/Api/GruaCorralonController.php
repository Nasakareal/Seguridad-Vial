<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Actividad;
use App\Models\ActividadFoto;
use App\Models\ConduceLegalidadFoto;
use App\Models\GruaUsuario;
use App\Models\LiberacionCorralon;
use App\Models\Servicio;
use App\Models\Vehiculo;
use App\Services\Fotos\ActividadFotoBlobStorage;
use App\Services\Fotos\HechoFotoStorage;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class GruaCorralonController extends Controller
{
    public function index(Request $request)
    {
        $user = $this->gruaUser($request);
        $estado = mb_strtolower(trim((string) $request->input('estado', 'pendientes')));
        $busqueda = trim((string) $request->input('q', ''));
        $origen = mb_strtoupper(trim((string) $request->input('origen', 'TODOS')));
        $dias = max(0, min(365, (int) $request->input('dias', 0)));
        $perPage = max(20, min(100, (int) $request->input('per_page', 50)));

        if ($estado === 'entregados') {
            $query = LiberacionCorralon::query()
                ->where('grua_id', $user->grua_id)
                ->where('estado', 'ENTREGADO')
                ->with($this->vehiculoRelations('vehiculo.'))
                ->when($busqueda !== '', function ($query) use ($busqueda) {
                    $query->whereHas('vehiculo', function ($vehiculo) use ($busqueda) {
                        $this->buscarVehiculo($vehiculo, $busqueda);
                    });
                })
                ->when($dias > 0, fn ($query) => $query->where(
                    'fecha_entrega', '>=', now('America/Mexico_City')->subDays($dias - 1)->startOfDay()
                ))
                ->when($origen !== 'TODOS', function ($query) use ($origen) {
                    $query->whereHas('vehiculo', fn ($vehiculo) => $this->filtrarOrigen($vehiculo, $origen));
                })
                ->orderByDesc('fecha_entrega')
                ->orderByDesc('id');

            $page = $query->paginate($perPage);
            $items = collect($page->items())
                ->map(fn (LiberacionCorralon $liberacion) => $this->serializeVehiculo(
                    $liberacion->vehiculo,
                    $liberacion
                ))
                ->values();
        } else {
            $query = $this->vehiculosPendientesQuery((int) $user->grua_id)
                ->with($this->vehiculoRelations())
                ->when($busqueda !== '', function ($query) use ($busqueda) {
                    $query->where(function ($vehiculo) use ($busqueda) {
                        $this->buscarVehiculo($vehiculo, $busqueda);
                    });
                })
                ->when($dias > 0, function ($query) use ($dias) {
                    $desde = now('America/Mexico_City')->subDays($dias - 1)->startOfDay();
                    $query->whereRaw(
                        'COALESCE((SELECT servicios_filtro.created_at FROM servicios AS servicios_filtro '
                        . 'WHERE servicios_filtro.vehiculo_id = vehiculos.id '
                        . 'ORDER BY servicios_filtro.created_at DESC, servicios_filtro.id DESC LIMIT 1), '
                        . 'vehiculos.fecha_inventario_grua, vehiculos.created_at) >= ?',
                        [$desde]
                    );
                })
                ->when($origen !== 'TODOS', fn ($query) => $this->filtrarOrigen($query, $origen))
                ->orderByDesc('ultimo_servicio_at')
                ->orderByDesc('fecha_inventario_grua')
                ->orderByDesc('updated_at');

            $page = $query->paginate($perPage);
            $items = collect($page->items())
                ->map(fn (Vehiculo $vehiculo) => $this->serializeVehiculo($vehiculo))
                ->values();
        }

        return response()->json([
            'items' => $items,
            'summary' => $this->resumen((int) $user->grua_id),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'total' => $page->total(),
            ],
            'grua' => [
                'id' => $user->grua_id,
                'nombre' => optional($user->grua)->nombre,
            ],
        ]);
    }

    public function exportar(Request $request, string $formato)
    {
        $user = $this->gruaUser($request);
        $estado = mb_strtolower(trim((string) $request->input('estado', 'pendientes')));
        $busqueda = trim((string) $request->input('q', ''));
        $origen = mb_strtoupper(trim((string) $request->input('origen', 'TODOS')));
        $dias = max(0, min(365, (int) $request->input('dias', 0)));
        abort_unless(in_array($formato, ['csv', 'pdf'], true), 404);

        $items = $this->reporteItems((int) $user->grua_id, $estado, $busqueda, $origen, $dias);
        $fecha = now('America/Mexico_City')->format('Y-m-d_H-i');
        $nombre = 'servicios_corralon_' . $estado . '_' . $fecha;

        if ($formato === 'pdf') {
            return Pdf::loadView('pdf.grua_corralon_reporte', [
                'items' => $items,
                'estado' => $estado,
                'grua' => $user->grua,
                'generado' => now('America/Mexico_City'),
                'summary' => $this->resumen((int) $user->grua_id),
            ])->setPaper('letter', 'landscape')->download($nombre . '.pdf');
        }

        return response()->streamDownload(function () use ($items) {
            $out = fopen('php://output', 'wb');
            fwrite($out, "\xEF\xBB\xBF");
            fputcsv($out, [
                'Estado',
                'Origen',
                'Placas',
                'NIV',
                'Marca',
                'Línea',
                'Modelo',
                'Color',
                'Inventario',
                'Corralón',
                'Fecha servicio',
                'Realizó maniobras',
                'Descripción de maniobras',
                'Observaciones de la grúa',
                'Fecha entrega',
                'Persona que recibió',
                'Folio SIERSE',
                'Condición',
                'Observaciones',
            ]);

            foreach ($items as $item) {
                fputcsv($out, array_map([$this, 'csvSeguro'], [
                    $item['estado'],
                    data_get($item, 'origen.etiqueta'),
                    $item['placas'],
                    $item['serie'],
                    $item['marca'],
                    $item['linea'],
                    $item['modelo'],
                    $item['color'],
                    $item['numero_inventario_grua'],
                    $item['corralon'],
                    $item['fecha_servicio'],
                    data_get($item, 'servicio.realizo_maniobras') === null
                        ? 'SIN CAPTURAR'
                        : (data_get($item, 'servicio.realizo_maniobras') ? 'SI' : 'NO'),
                    data_get($item, 'servicio.maniobras_descripcion'),
                    data_get($item, 'servicio.observaciones_grua'),
                    data_get($item, 'liberacion.fecha_entrega'),
                    data_get($item, 'liberacion.persona_recibe'),
                    data_get($item, 'liberacion.sierse_folio'),
                    data_get($item, 'liberacion.condicion_entrega'),
                    data_get($item, 'liberacion.observaciones'),
                ]));
            }

            fclose($out);
        }, $nombre . '.csv', [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    public function show(Request $request, Vehiculo $vehiculo)
    {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);

        $vehiculo->load($this->vehiculoRelations());

        return response()->json($this->serializeVehiculo(
            $vehiculo,
            $vehiculo->liberacionCorralon
        ));
    }

    public function crearServicio(Request $request)
    {
        $user = $this->gruaUser($request);
        $validated = $request->validate(array_merge($this->vehiculoRules(true), $this->servicioRules(true)));

        if (empty(trim((string) ($validated['placas'] ?? '')))
            && empty(trim((string) ($validated['serie'] ?? '')))) {
            return response()->json([
                'message' => 'Captura por lo menos placas o NIV/serie.',
                'errors' => ['placas' => ['Captura por lo menos placas o NIV/serie.']],
            ], 422);
        }

        $duplicado = $this->buscarDuplicadoActivo(
            (int) $user->grua_id,
            $validated['placas'] ?? null,
            $validated['serie'] ?? null
        );
        if ($duplicado) {
            return response()->json([
                'message' => 'Este vehículo ya tiene un servicio activo en tu corralón.',
                'errors' => ['placas' => ['Ya existe el vehículo #' . $duplicado->id . ' en corralón.']],
            ], 422);
        }

        [$vehiculo, $servicio] = DB::transaction(function () use ($request, $user, $validated) {
            $vehiculo = Vehiculo::create([
                'client_uuid' => (string) Str::uuid(),
                'marca' => trim($validated['marca']),
                'linea' => trim($validated['linea']),
                'modelo' => $this->nullableTrim($validated['modelo'] ?? null),
                'tipo' => trim($validated['tipo']),
                'color' => trim($validated['color']),
                'placas' => $this->nullableTrim($validated['placas'] ?? null),
                'estado_placas' => $this->nullableTrim($validated['estado_placas'] ?? null),
                'serie' => $this->nullableTrim($validated['serie'] ?? null),
                'capacidad_personas' => (int) ($validated['capacidad_personas'] ?? 0),
                'tipo_servicio' => $this->nullableTrim($validated['tipo_servicio'] ?? null) ?: 'PARTICULAR',
                'tarjeta_circulacion_nombre' => $this->nullableTrim($validated['tarjeta_circulacion_nombre'] ?? null),
                'grua' => optional($user->grua)->nombre,
                'grua_id' => $user->grua_id,
                'numero_inventario_grua' => $this->nullableTrim($validated['numero_inventario_grua'] ?? null),
                'fecha_inventario_grua' => $validated['fecha_solicitud'],
                'corralon' => $this->nullableTrim($validated['corralon'] ?? null)
                    ?: optional($user->grua)->nombre,
            ]);

            $servicio = Servicio::create(array_merge(
                $this->servicioPayload($validated, $user),
                [
                    'client_uuid' => (string) Str::uuid(),
                    'grua_id' => $user->grua_id,
                    'vehiculo_id' => $vehiculo->id,
                    'tipo_vehiculo' => $vehiculo->tipo,
                    'tipo_general_vehiculo' => $validated['tipo_general_vehiculo'] ?? null,
                    'created_at' => $validated['fecha_solicitud'],
                ]
            ));

            $this->guardarMemoria($request, $servicio, $user);
            return [$vehiculo, $servicio];
        });

        $vehiculo->load($this->vehiculoRelations());
        return response()->json([
            'message' => 'Servicio agregado al expediente SIERSE.',
            'item' => $this->serializeVehiculo($vehiculo),
        ], 201);
    }

    public function actualizarExpediente(Request $request, Vehiculo $vehiculo)
    {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        $servicio = $this->servicioActual($vehiculo);
        abort_unless($servicio, 404, 'No se encontró el servicio de grúa.');
        $validated = $request->validate(array_merge($this->vehiculoRules(false), $this->servicioRules(false)));

        DB::transaction(function () use ($request, $vehiculo, $servicio, $user, $validated) {
            $vehiculoCampos = collect([
                'marca', 'linea', 'modelo', 'tipo', 'color', 'placas', 'estado_placas',
                'serie', 'capacidad_personas', 'tipo_servicio', 'tarjeta_circulacion_nombre',
                'numero_inventario_grua', 'corralon',
            ])->filter(fn ($campo) => array_key_exists($campo, $validated))
                ->mapWithKeys(fn ($campo) => [$campo => is_string($validated[$campo] ?? null)
                    ? $this->nullableTrim($validated[$campo]) : $validated[$campo]])->all();
            if ($vehiculoCampos) {
                $vehiculo->update($vehiculoCampos);
            }

            $servicio->update($this->servicioPayload($validated, $user, false));
            $this->guardarMemoria($request, $servicio, $user);
        });

        $vehiculo->refresh()->load($this->vehiculoRelations());
        return response()->json([
            'message' => 'Expediente y memoria actualizados.',
            'item' => $this->serializeVehiculo($vehiculo, $vehiculo->liberacionCorralon),
        ]);
    }

    public function archivoMemoriaDescriptiva(Request $request, Vehiculo $vehiculo)
    {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        $servicio = $this->servicioActual($vehiculo);
        abort_unless($servicio && $servicio->memoria_descriptiva_path, 404);
        abort_unless(Storage::disk('local')->exists($servicio->memoria_descriptiva_path), 404);

        return Storage::disk('local')->response(
            $servicio->memoria_descriptiva_path,
            $servicio->memoria_descriptiva_nombre ?: basename($servicio->memoria_descriptiva_path),
            ['Content-Type' => $servicio->memoria_descriptiva_mime ?: 'application/octet-stream']
        );
    }

    public function entregar(Request $request, Vehiculo $vehiculo)
    {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);

        abort_if(
            $vehiculo->liberacionCorralon()
                ->where('estado', 'ENTREGADO')
                ->exists(),
            422,
            'Este vehículo ya fue marcado como entregado.'
        );

        $validated = $request->validate([
            'persona_recibe' => ['required', 'string', 'max:255'],
            'identificacion_recibe' => ['required', 'string', 'max:255'],
            'telefono_recibe' => ['nullable', 'string', 'max:30'],
            'sierse_folio' => ['required', 'string', 'max:120'],
            'condicion_entrega' => ['required', 'in:CONFORME_INVENTARIO,CON_OBSERVACIONES'],
            'observaciones' => ['nullable', 'string', 'max:2000'],
            'foto_entrega' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'foto_identificacion' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'documento_liberacion' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png,webp', 'max:10240'],
            'memoria_descriptiva' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png,webp', 'max:15360'],
            'comprobante_pago' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png,webp', 'max:10240'],
            'firma_recibe' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'conformidad_memoria' => ['accepted'],
            'confirmar_entrega' => ['accepted'],
        ]);

        unset($validated['confirmar_entrega']);
        $validated['conformidad_memoria'] = true;
        $validated['telefono_recibe'] = $this->normalizarTelefonoMx(
            $validated['telefono_recibe'] ?? null
        );

        foreach ([
            'foto_entrega',
            'foto_identificacion',
            'documento_liberacion',
            'memoria_descriptiva',
            'comprobante_pago',
            'firma_recibe',
        ] as $campo) {
            if ($request->hasFile($campo)) {
                $validated[$campo] = $request->file($campo)
                    ->store('liberaciones_corralon', 'local');
            }
        }

        $liberacion = DB::transaction(function () use ($request, $vehiculo, $user, $validated) {
            $liberacion = LiberacionCorralon::updateOrCreate(
                ['vehiculo_id' => $vehiculo->id],
                array_merge($validated, [
                    'grua_id' => $user->grua_id,
                    'grua_usuario_id' => $user->id,
                    'estado' => 'ENTREGADO',
                    'fecha_entrega' => now(),
                    'fecha_conformidad' => now(),
                    'ip_entrega' => $request->ip(),
                    'user_agent_entrega' => mb_substr((string) $request->userAgent(), 0, 500),
                ])
            );

            $vehiculo->update(['corralon' => null]);

            return $liberacion;
        });

        $vehiculo->refresh()->load($this->vehiculoRelations());

        return response()->json([
            'message' => 'Vehículo marcado como entregado.',
            'item' => $this->serializeVehiculo($vehiculo, $liberacion),
        ]);
    }

    public function evidencia(Request $request, LiberacionCorralon $liberacionCorralon, string $campo)
    {
        $user = $this->gruaUser($request);
        abort_unless((int) $liberacionCorralon->grua_id === (int) $user->grua_id, 403);

        abort_unless(in_array($campo, [
            'foto_identificacion',
            'foto_entrega',
            'documento_liberacion',
            'memoria_descriptiva',
            'comprobante_pago',
            'firma_recibe',
        ], true), 404);

        $ruta = $liberacionCorralon->{$campo};
        abort_unless(is_string($ruta) && $ruta !== '', 404);

        $disco = Storage::disk('local')->exists($ruta)
            ? 'local'
            : (Storage::disk('public')->exists($ruta) ? 'public' : null);
        abort_unless($disco, 404);

        return Storage::disk($disco)->response($ruta, basename($ruta));
    }

    public function fotoInventario(
        Request $request,
        Vehiculo $vehiculo,
        HechoFotoStorage $storage
    ) {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        abort_unless($vehiculo->foto_inventario_grua, 404);

        return $storage->response(
            $vehiculo->foto_inventario_grua,
            'inventario_vehiculo_' . $vehiculo->id . '.'
            . (pathinfo($vehiculo->foto_inventario_grua, PATHINFO_EXTENSION) ?: 'jpg')
        );
    }

    public function fotoVehiculo(
        Request $request,
        Vehiculo $vehiculo,
        HechoFotoStorage $storage
    ) {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        abort_unless($vehiculo->getRawOriginal('fotos'), 404);

        return $storage->response(
            $vehiculo->getRawOriginal('fotos'),
            'vehiculo_' . $vehiculo->id . '.'
            . (pathinfo($vehiculo->getRawOriginal('fotos'), PATHINFO_EXTENSION) ?: 'jpg')
        );
    }

    public function fotoServicio(
        Request $request,
        Vehiculo $vehiculo,
        HechoFotoStorage $storage
    ) {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        $servicio = $this->servicioActual($vehiculo);
        abort_unless($servicio && $servicio->foto_vehiculo, 404);

        return $storage->response(
            $servicio->foto_vehiculo,
            'servicio_' . $servicio->id . '.'
            . (pathinfo($servicio->foto_vehiculo, PATHINFO_EXTENSION) ?: 'jpg')
        );
    }

    public function fotoActividad(
        Request $request,
        Vehiculo $vehiculo,
        ActividadFoto $foto,
        ActividadFotoBlobStorage $storage
    ) {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        abort_unless(
            $vehiculo->actividades()->whereKey($foto->actividad_id)->exists(),
            404
        );

        return $storage->response(
            $foto->foto_blob_path ?: $foto->foto_thumbnail_blob_path,
            $foto->foto_path ?: $foto->foto_thumbnail_path,
            $foto->foto_nombre_original ?: 'actividad_' . $foto->id . '.jpg'
        );
    }

    public function fotoActividadPrincipal(
        Request $request,
        Vehiculo $vehiculo,
        Actividad $actividad,
        ActividadFotoBlobStorage $storage
    ) {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        abort_unless($vehiculo->actividades()->whereKey($actividad->id)->exists(), 404);

        return $storage->response(
            $actividad->foto_blob_path ?: $actividad->foto_thumbnail_blob_path,
            $actividad->foto_path ?: $actividad->foto_thumbnail_path,
            $actividad->foto_nombre_original ?: 'actividad_' . $actividad->id . '.jpg'
        );
    }

    public function fotoConduce(
        Request $request,
        Vehiculo $vehiculo,
        ConduceLegalidadFoto $foto,
        HechoFotoStorage $storage
    ) {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        abort_unless(
            $vehiculo->actividades()
                ->whereHas('conduceLegalidadCaptura.fotos', function ($query) use ($foto) {
                    $query->whereKey($foto->id);
                })
                ->exists(),
            404
        );

        return $storage->response(
            $foto->foto_path,
            $foto->foto_nombre_original ?: 'conduce_legalidad_' . $foto->id . '.jpg'
        );
    }

    public function actualizarServicio(Request $request, Vehiculo $vehiculo)
    {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        $servicio = $this->servicioActual($vehiculo);
        abort_unless($servicio, 404, 'No se encontró el servicio de grúa.');

        $validated = $request->validate([
            'realizo_maniobras' => ['required', 'boolean'],
            'maniobras_descripcion' => ['nullable', 'string', 'max:2000'],
            'observaciones_grua' => ['nullable', 'string', 'max:2000'],
        ]);

        if ($validated['realizo_maniobras']
            && trim((string) ($validated['maniobras_descripcion'] ?? '')) === '') {
            return response()->json([
                'message' => 'Describe las maniobras realizadas.',
                'errors' => [
                    'maniobras_descripcion' => ['Describe las maniobras realizadas.'],
                ],
            ], 422);
        }

        $servicio->update([
            'realizo_maniobras' => (bool) $validated['realizo_maniobras'],
            'maniobras_descripcion' => trim((string) ($validated['maniobras_descripcion'] ?? '')) ?: null,
            'observaciones_grua' => trim((string) ($validated['observaciones_grua'] ?? '')) ?: null,
            'actualizado_por_grua_usuario_id' => $user->id,
            'actualizado_por_grua_at' => now(),
        ]);

        $vehiculo->load($this->vehiculoRelations());

        return response()->json([
            'message' => 'Datos del servicio actualizados.',
            'item' => $this->serializeVehiculo($vehiculo, $vehiculo->liberacionCorralon),
        ]);
    }

    public function memoriaDescriptiva(Request $request, Vehiculo $vehiculo)
    {
        $user = $this->gruaUser($request);
        $this->autorizarVehiculo($vehiculo, $user);
        $vehiculo->load($this->vehiculoRelations());
        $item = $this->serializeVehiculo($vehiculo, $vehiculo->liberacionCorralon);

        return Pdf::loadView('pdf.grua_memoria_descriptiva', [
            'item' => $item,
            'grua' => $user->grua,
            'generado' => now('America/Mexico_City'),
        ])->setPaper('letter')->download(
            'memoria_servicio_' . $vehiculo->id . '.pdf'
        );
    }

    private function gruaUser(Request $request): GruaUsuario
    {
        $user = $request->user();
        abort_unless($user instanceof GruaUsuario && $user->activo, 403);
        $user->loadMissing('grua');

        return $user;
    }

    private function vehiculosPendientesQuery(int $gruaId)
    {
        return Vehiculo::query()
            ->select('vehiculos.*')
            ->selectSub(function ($query) {
                $query->from('servicios')
                    ->select('created_at')
                    ->whereColumn('servicios.vehiculo_id', 'vehiculos.id')
                    ->orderByDesc('created_at')
                    ->orderByDesc('id')
                    ->limit(1);
            }, 'ultimo_servicio_at')
            ->whereRaw(
                'COALESCE((SELECT servicios_actuales.grua_id FROM servicios AS servicios_actuales '
                . 'WHERE servicios_actuales.vehiculo_id = vehiculos.id '
                . 'ORDER BY servicios_actuales.created_at DESC, servicios_actuales.id DESC LIMIT 1), '
                . 'vehiculos.grua_id) = ?',
                [$gruaId]
            )
            ->whereNotNull('vehiculos.corralon')
            ->whereRaw("TRIM(vehiculos.corralon) <> ''")
            ->whereRaw(
                "UPPER(TRIM(vehiculos.corralon)) NOT IN ("
                . implode(',', array_fill(0, count(Vehiculo::corralonValoresInvalidos()), '?'))
                . ')',
                Vehiculo::corralonValoresInvalidos()
            )
            ->whereDoesntHave('liberacionCorralon', function ($liberacion) {
                $liberacion->where('estado', 'ENTREGADO');
            });
    }

    private function autorizarVehiculo(Vehiculo $vehiculo, GruaUsuario $user): void
    {
        $gruaServicioActual = $vehiculo->servicios()
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->value('grua_id');
        $gruaAsignada = $gruaServicioActual ?: $vehiculo->grua_id;

        abort_unless((int) $gruaAsignada === (int) $user->grua_id, 403);
    }

    private function buscarVehiculo($query, string $busqueda): void
    {
        $query->where('placas', 'like', '%' . $busqueda . '%')
            ->orWhere('serie', 'like', '%' . $busqueda . '%')
            ->orWhere('marca', 'like', '%' . $busqueda . '%')
            ->orWhere('linea', 'like', '%' . $busqueda . '%')
            ->orWhere('numero_inventario_grua', 'like', '%' . $busqueda . '%');
    }

    private function filtrarOrigen($query, string $origen): void
    {
        if ($origen === 'SINIESTRO') {
            $query->whereHas('hechos');
            return;
        }
        if ($origen === 'CONDUCE_LEGALIDAD') {
            $query->whereHas('actividades.conduceLegalidadCaptura');
            return;
        }
        if ($origen === 'ACTIVIDAD') {
            $query->whereHas('actividades')
                ->whereDoesntHave('actividades.conduceLegalidadCaptura')
                ->whereDoesntHave('hechos');
            return;
        }
        if ($origen === 'MANUAL') {
            $query->whereDoesntHave('hechos')->whereDoesntHave('actividades');
        }
    }

    private function serializeVehiculo(Vehiculo $vehiculo, ?LiberacionCorralon $liberacion = null): array
    {
        $hecho = $vehiculo->relationLoaded('hechos') ? $vehiculo->hechos->first() : null;
        $servicio = $vehiculo->relationLoaded('servicio') ? $vehiculo->servicio : null;
        $origen = $this->origenVehiculo($vehiculo);
        $galeria = $this->galeriaVehiculo($vehiculo, $servicio, $liberacion);

        return [
            'id' => $vehiculo->id,
            'marca' => $vehiculo->marca,
            'linea' => $vehiculo->linea,
            'modelo' => $vehiculo->modelo,
            'color' => $vehiculo->color,
            'placas' => $vehiculo->placas,
            'estado_placas' => $vehiculo->estado_placas,
            'serie' => $vehiculo->serie,
            'tipo' => $vehiculo->tipo,
            'tipo_servicio' => $vehiculo->tipo_servicio,
            'tarjeta_circulacion_nombre' => $vehiculo->tarjeta_circulacion_nombre,
            'numero_inventario_grua' => $vehiculo->numero_inventario_grua,
            'corralon' => $vehiculo->nombreCorralonValido(),
            'fecha_servicio' => $vehiculo->ultimo_servicio_at
                ?? optional($servicio)->created_at
                ?? $vehiculo->fecha_inventario_grua,
            'servicio_descripcion' => optional($servicio)->descripcion,
            'servicio' => $servicio ? [
                'id' => $servicio->id,
                'realizo_maniobras' => $servicio->realizo_maniobras,
                'maniobras_descripcion' => $servicio->maniobras_descripcion,
                'observaciones_grua' => $servicio->observaciones_grua,
                'tipo_general_vehiculo' => $servicio->tipo_general_vehiculo,
                'inventario_recepcion' => $servicio->inventario_recepcion ?: [],
                'actualizado_por_grua_at' => $servicio->actualizado_por_grua_at,
                'modalidad_servicio' => $servicio->modalidad_servicio,
                'folio_sierse' => $servicio->folio_sierse,
                'fecha_solicitud' => $servicio->fecha_solicitud,
                'fecha_arribo' => $servicio->fecha_arribo,
                'fecha_inicio' => $servicio->fecha_inicio,
                'fecha_fin' => $servicio->fecha_fin,
                'lugar_origen' => $servicio->lugar_origen,
                'lugar_destino' => $servicio->lugar_destino,
                'autoridad_solicitante' => $servicio->autoridad_solicitante,
                'agente_solicitante' => $servicio->agente_solicitante,
                'persona_solicitante' => $servicio->persona_solicitante,
                'operador_nombre' => $servicio->operador_nombre,
                'unidad_grua' => $servicio->unidad_grua,
                'kilometros_recorridos' => $servicio->kilometros_recorridos,
                'importe_total' => $servicio->importe_total,
                'forma_pago' => $servicio->forma_pago,
                'memoria' => $servicio->memoria_descriptiva_path ? [
                    'nombre' => $servicio->memoria_descriptiva_nombre,
                    'mime' => $servicio->memoria_descriptiva_mime,
                    'sha256' => $servicio->memoria_descriptiva_sha256,
                    'subida_at' => $servicio->memoria_subida_at,
                    'url' => '/grua/corralon/' . $vehiculo->id . '/memoria-descriptiva/archivo',
                ] : null,
            ] : null,
            'origen' => $origen,
            'hecho' => $hecho ? [
                'id' => $hecho->id,
                'fecha' => $hecho->fecha,
                'calle' => $hecho->calle,
                'colonia' => $hecho->colonia,
            ] : null,
            'estado' => $liberacion && $liberacion->estado === 'ENTREGADO'
                ? 'ENTREGADO'
                : 'EN_CORRALON',
            'liberacion' => $liberacion ? [
                'id' => $liberacion->id,
                'persona_recibe' => $liberacion->persona_recibe,
                'identificacion_recibe' => $liberacion->identificacion_recibe,
                'sierse_folio' => $liberacion->sierse_folio,
                'condicion_entrega' => $liberacion->condicion_entrega,
                'observaciones' => $liberacion->observaciones,
                'fecha_entrega' => $liberacion->fecha_entrega,
            ] : null,
            'fotos' => [
                'inventario' => $vehiculo->foto_inventario_grua
                    ? '/grua/corralon/' . $vehiculo->id . '/foto-inventario'
                    : null,
                'entrega' => $liberacion && $liberacion->foto_entrega
                    ? '/grua/corralon/liberacion/' . $liberacion->id
                        . '/evidencia/foto_entrega'
                    : null,
            ],
            'galeria' => $galeria,
            'expediente' => $this->estadoExpediente($vehiculo, $servicio),
        ];
    }

    private function vehiculoRules(bool $required): array
    {
        $r = $required ? 'required' : 'sometimes';
        return [
            'marca' => [$r, 'string', 'max:50'],
            'linea' => [$r, 'string', 'max:50'],
            'modelo' => ['nullable', 'string', 'max:10'],
            'tipo' => [$r, 'string', 'max:50'],
            'color' => [$r, 'string', 'max:30'],
            'placas' => ['nullable', 'string', 'max:20'],
            'estado_placas' => ['nullable', 'string', 'max:30'],
            'serie' => ['nullable', 'string', 'max:40'],
            'capacidad_personas' => ['nullable', 'integer', 'min:0', 'max:200'],
            'tipo_servicio' => ['nullable', 'string', 'max:50'],
            'tarjeta_circulacion_nombre' => ['nullable', 'string', 'max:100'],
            'numero_inventario_grua' => ['nullable', 'string', 'max:120'],
            'corralon' => ['nullable', 'string', 'max:255'],
        ];
    }

    private function servicioRules(bool $required): array
    {
        $r = $required ? 'required' : 'sometimes';
        return [
            'modalidad_servicio' => [$r, 'in:GRUA,ARRASTRE,ARRASTRE_SALVAMENTO,REMOLQUE,DEPOSITO'],
            'folio_sierse' => ['nullable', 'string', 'max:120'],
            'fecha_solicitud' => [$r, 'date'],
            'fecha_arribo' => ['nullable', 'date'],
            'fecha_inicio' => ['nullable', 'date'],
            'fecha_fin' => ['nullable', 'date'],
            'lugar_origen' => [$r, 'string', 'max:255'],
            'lugar_destino' => ['nullable', 'string', 'max:255'],
            'autoridad_solicitante' => ['nullable', 'string', 'max:255'],
            'agente_solicitante' => ['nullable', 'string', 'max:255'],
            'persona_solicitante' => ['nullable', 'string', 'max:255'],
            'operador_nombre' => [$r, 'string', 'max:255'],
            'unidad_grua' => [$r, 'string', 'max:120'],
            'kilometros_recorridos' => ['nullable', 'numeric', 'min:0'],
            'importe_total' => ['nullable', 'numeric', 'min:0'],
            'forma_pago' => ['nullable', 'string', 'max:40'],
            'realizo_maniobras' => ['nullable', 'boolean'],
            'maniobras_descripcion' => ['nullable', 'string', 'max:2000'],
            'observaciones_grua' => ['nullable', 'string', 'max:2000'],
            'tipo_general_vehiculo' => ['nullable', 'in:automovil,camioneta,camion,motocicleta,bicicleta,remolque,maquinaria,tren,semoviente'],
            'inventario_recepcion' => ['nullable', 'array'],
            'inventario_recepcion.llaves' => ['nullable', 'boolean'],
            'inventario_recepcion.tarjeta_circulacion' => ['nullable', 'boolean'],
            'inventario_recepcion.placas' => ['nullable', 'boolean'],
            'inventario_recepcion.estereo' => ['nullable', 'boolean'],
            'inventario_recepcion.bateria' => ['nullable', 'boolean'],
            'inventario_recepcion.llanta_refaccion' => ['nullable', 'boolean'],
            'inventario_recepcion.herramienta' => ['nullable', 'boolean'],
            'inventario_recepcion.danos_visibles' => ['nullable', 'boolean'],
            'memoria_descriptiva' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png,webp', 'max:20480'],
        ];
    }

    private function servicioPayload(array $validated, GruaUsuario $user, bool $includeNulls = true): array
    {
        $campos = [
            'modalidad_servicio', 'folio_sierse', 'fecha_solicitud', 'fecha_arribo',
            'fecha_inicio', 'fecha_fin', 'lugar_origen', 'lugar_destino',
            'autoridad_solicitante', 'agente_solicitante', 'persona_solicitante',
            'operador_nombre', 'unidad_grua', 'kilometros_recorridos', 'importe_total',
            'forma_pago', 'realizo_maniobras', 'maniobras_descripcion', 'observaciones_grua',
            'tipo_general_vehiculo', 'inventario_recepcion',
        ];
        $payload = [];
        foreach ($campos as $campo) {
            if (array_key_exists($campo, $validated)) {
                if ($campo === 'inventario_recepcion' && is_array($validated[$campo])) {
                    $payload[$campo] = collect($validated[$campo])
                        ->map(fn ($valor) => filter_var($valor, FILTER_VALIDATE_BOOLEAN))
                        ->all();
                } else {
                    $payload[$campo] = is_string($validated[$campo])
                        ? $this->nullableTrim($validated[$campo]) : $validated[$campo];
                }
            } elseif ($includeNulls) {
                $payload[$campo] = null;
            }
        }
        $payload['actualizado_por_grua_usuario_id'] = $user->id;
        $payload['actualizado_por_grua_at'] = now();
        return $payload;
    }

    private function guardarMemoria(Request $request, Servicio $servicio, GruaUsuario $user): void
    {
        if (!$request->hasFile('memoria_descriptiva')) {
            return;
        }
        $archivo = $request->file('memoria_descriptiva');
        $ruta = $archivo->store('grua_sierse/memorias', 'local');
        if ($servicio->memoria_descriptiva_path
            && Storage::disk('local')->exists($servicio->memoria_descriptiva_path)) {
            Storage::disk('local')->delete($servicio->memoria_descriptiva_path);
        }
        $servicio->update([
            'memoria_descriptiva_path' => $ruta,
            'memoria_descriptiva_nombre' => mb_substr($archivo->getClientOriginalName(), 0, 255),
            'memoria_descriptiva_mime' => $archivo->getMimeType(),
            'memoria_descriptiva_sha256' => hash_file('sha256', Storage::disk('local')->path($ruta)),
            'memoria_subida_por_grua_usuario_id' => $user->id,
            'memoria_subida_at' => now(),
        ]);
    }

    private function estadoExpediente(Vehiculo $vehiculo, ?Servicio $servicio): array
    {
        $faltantes = [];
        foreach (['marca' => 'Marca', 'linea' => 'Línea', 'tipo' => 'Tipo', 'color' => 'Color'] as $campo => $etiqueta) {
            if (trim((string) $vehiculo->{$campo}) === '') $faltantes[] = $etiqueta;
        }
        if (trim((string) $vehiculo->placas) === '' && trim((string) $vehiculo->serie) === '') {
            $faltantes[] = 'Placas o NIV';
        }
        if (!$servicio) {
            $faltantes[] = 'Datos del servicio';
        } else {
            foreach ([
                'modalidad_servicio' => 'Modalidad', 'fecha_solicitud' => 'Fecha de solicitud',
                'lugar_origen' => 'Lugar de origen', 'operador_nombre' => 'Operador',
                'unidad_grua' => 'Unidad de grúa', 'folio_sierse' => 'Folio SIERSE',
                'memoria_descriptiva_path' => 'Memoria descriptiva original',
            ] as $campo => $etiqueta) {
                if (trim((string) $servicio->{$campo}) === '') $faltantes[] = $etiqueta;
            }
        }
        return ['completo' => count($faltantes) === 0, 'faltantes' => $faltantes];
    }

    private function buscarDuplicadoActivo(int $gruaId, ?string $placas, ?string $serie): ?Vehiculo
    {
        $placas = mb_strtoupper(trim((string) $placas));
        $serie = mb_strtoupper(trim((string) $serie));
        if ($placas === '' && $serie === '') return null;

        return $this->vehiculosPendientesQuery($gruaId)
            ->where(function ($query) use ($placas, $serie) {
                if ($placas !== '') $query->orWhereRaw('UPPER(TRIM(placas)) = ?', [$placas]);
                if ($serie !== '') $query->orWhereRaw('UPPER(TRIM(serie)) = ?', [$serie]);
            })->first();
    }

    private function nullableTrim($valor): ?string
    {
        if ($valor === null) return null;
        $valor = trim((string) $valor);
        return $valor === '' ? null : $valor;
    }

    private function origenVehiculo(Vehiculo $vehiculo): array
    {
        $actividades = $vehiculo->relationLoaded('actividades')
            ? $vehiculo->actividades
            : collect();
        $actividadConduce = $actividades->first(function ($actividad) {
            return $actividad->relationLoaded('conduceLegalidadCaptura')
                && $actividad->conduceLegalidadCaptura;
        });

        if ($actividadConduce) {
            $captura = $actividadConduce->conduceLegalidadCaptura;
            $operativo = optional($captura)->operativo;

            return [
                'tipo' => 'CONDUCE_LEGALIDAD',
                'etiqueta' => 'Conduce con Legalidad',
                'id' => optional($captura)->id,
                'folio' => optional($captura)->folio_numero,
                'fecha' => optional($captura)->fecha ?: $actividadConduce->fecha,
                'lugar' => optional($captura)->lugar ?: $actividadConduce->lugar,
                'detalle' => optional($operativo)->nombre
                    ?: optional($operativo)->titulo
                    ?: 'Operativo Conduce con Legalidad',
            ];
        }

        $hecho = $vehiculo->relationLoaded('hechos') ? $vehiculo->hechos->first() : null;
        if ($hecho) {
            return [
                'tipo' => 'SINIESTRO',
                'etiqueta' => 'Siniestro',
                'id' => $hecho->id,
                'folio' => $hecho->folio_c5i,
                'fecha' => $hecho->fecha,
                'lugar' => collect([$hecho->calle, $hecho->colonia])->filter()->implode(', '),
                'detalle' => $hecho->tipo_hecho,
            ];
        }

        $actividad = $actividades->first();
        if ($actividad) {
            return [
                'tipo' => 'ACTIVIDAD',
                'etiqueta' => 'Actividad',
                'id' => $actividad->id,
                'folio' => $actividad->folio_c5i,
                'fecha' => $actividad->fecha,
                'lugar' => $actividad->lugar,
                'detalle' => optional($actividad->subcategoria)->nombre
                    ?: $actividad->motivo
                    ?: $actividad->nombre,
            ];
        }

        return [
            'tipo' => 'SIN_CLASIFICAR',
            'etiqueta' => 'Sin clasificar',
            'id' => null,
            'folio' => null,
            'fecha' => optional($vehiculo->servicio)->created_at,
            'lugar' => null,
            'detalle' => null,
        ];
    }

    private function galeriaVehiculo(
        Vehiculo $vehiculo,
        ?Servicio $servicio,
        ?LiberacionCorralon $liberacion
    ): array {
        $fotos = collect();

        if ($vehiculo->getRawOriginal('fotos')) {
            $fotos->push([
                'tipo' => 'vehiculo',
                'etiqueta' => 'Vehículo',
                'url' => '/grua/corralon/' . $vehiculo->id . '/foto-vehiculo',
            ]);
        }
        if ($vehiculo->foto_inventario_grua) {
            $fotos->push([
                'tipo' => 'inventario',
                'etiqueta' => 'Inventario de grúa',
                'url' => '/grua/corralon/' . $vehiculo->id . '/foto-inventario',
            ]);
        }
        if ($servicio && $servicio->foto_vehiculo) {
            $fotos->push([
                'tipo' => 'servicio',
                'etiqueta' => 'Servicio de grúa',
                'url' => '/grua/corralon/' . $vehiculo->id . '/foto-servicio',
            ]);
        }

        $actividades = $vehiculo->relationLoaded('actividades')
            ? $vehiculo->actividades
            : collect();
        foreach ($actividades as $actividad) {
            $captura = $actividad->relationLoaded('conduceLegalidadCaptura')
                ? $actividad->conduceLegalidadCaptura
                : null;
            if ($captura && $captura->relationLoaded('fotos')) {
                foreach ($captura->fotos as $foto) {
                    $fotos->push([
                        'tipo' => 'conduce_legalidad',
                        'etiqueta' => 'Conduce con Legalidad',
                        'url' => '/grua/corralon/' . $vehiculo->id
                            . '/foto-conduce/' . $foto->id,
                    ]);
                }
            }

            if ($actividad->relationLoaded('fotos')) {
                foreach ($actividad->fotos as $foto) {
                    $fotos->push([
                        'tipo' => 'actividad',
                        'etiqueta' => 'Actividad',
                        'url' => '/grua/corralon/' . $vehiculo->id
                            . '/foto-actividad/' . $foto->id,
                    ]);
                }
            }
            if ($actividad->foto_path || $actividad->foto_blob_path
                || $actividad->foto_thumbnail_path || $actividad->foto_thumbnail_blob_path) {
                $fotos->push([
                    'tipo' => 'actividad',
                    'etiqueta' => 'Actividad',
                    'url' => '/grua/corralon/' . $vehiculo->id
                        . '/foto-actividad-principal/' . $actividad->id,
                ]);
            }
        }

        if ($liberacion && $liberacion->foto_entrega) {
            $fotos->push([
                'tipo' => 'entrega',
                'etiqueta' => 'Entrega',
                'url' => '/grua/corralon/liberacion/' . $liberacion->id
                    . '/evidencia/foto_entrega',
            ]);
        }

        return $fotos->unique('url')->take(12)->values()->all();
    }

    private function servicioActual(Vehiculo $vehiculo): ?Servicio
    {
        if ($vehiculo->relationLoaded('servicio') && $vehiculo->servicio) {
            return $vehiculo->servicio;
        }

        return $vehiculo->servicios()
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->first();
    }

    private function vehiculoRelations(string $prefix = ''): array
    {
        return [
            $prefix . 'hechos',
            $prefix . 'servicio.grua',
            $prefix . 'liberacionCorralon',
            $prefix . 'actividades.subcategoria',
            $prefix . 'actividades.fotos',
            $prefix . 'actividades.conduceLegalidadCaptura.operativo',
            $prefix . 'actividades.conduceLegalidadCaptura.fotos',
        ];
    }

    private function resumen(int $gruaId): array
    {
        $hoy = now('America/Mexico_City');
        $liberaciones = LiberacionCorralon::query()
            ->where('grua_id', $gruaId)
            ->where('estado', 'ENTREGADO');

        $serie = collect(range(6, 0))->map(function (int $dias) use ($liberaciones, $hoy) {
            $fecha = $hoy->copy()->subDays($dias);

            return [
                'fecha' => $fecha->format('Y-m-d'),
                'etiqueta' => $fecha->locale('es')->isoFormat('dd'),
                'total' => (clone $liberaciones)->whereDate('fecha_entrega', $fecha)->count(),
            ];
        })->values();

        return [
            'pendientes' => $this->vehiculosPendientesQuery($gruaId)->count(),
            'entregados_hoy' => (clone $liberaciones)
                ->whereDate('fecha_entrega', $hoy)
                ->count(),
            'entregados_mes' => (clone $liberaciones)
                ->whereYear('fecha_entrega', $hoy->year)
                ->whereMonth('fecha_entrega', $hoy->month)
                ->count(),
            'total_entregados' => (clone $liberaciones)->count(),
            'con_observaciones_mes' => (clone $liberaciones)
                ->whereYear('fecha_entrega', $hoy->year)
                ->whereMonth('fecha_entrega', $hoy->month)
                ->where('condicion_entrega', 'CON_OBSERVACIONES')
                ->count(),
            'serie_7_dias' => $serie,
        ];
    }

    private function reporteItems(
        int $gruaId,
        string $estado,
        string $busqueda,
        string $origen,
        int $dias
    )
    {
        if ($estado === 'entregados') {
            return LiberacionCorralon::query()
                ->where('grua_id', $gruaId)
                ->where('estado', 'ENTREGADO')
                ->with($this->vehiculoRelations('vehiculo.'))
                ->when($busqueda !== '', function ($query) use ($busqueda) {
                    $query->whereHas('vehiculo', function ($vehiculo) use ($busqueda) {
                        $this->buscarVehiculo($vehiculo, $busqueda);
                    });
                })
                ->when($dias > 0, fn ($query) => $query->where(
                    'fecha_entrega', '>=', now('America/Mexico_City')->subDays($dias - 1)->startOfDay()
                ))
                ->when($origen !== 'TODOS', function ($query) use ($origen) {
                    $query->whereHas('vehiculo', fn ($vehiculo) => $this->filtrarOrigen($vehiculo, $origen));
                })
                ->orderByDesc('fecha_entrega')
                ->get()
                ->map(fn (LiberacionCorralon $liberacion) => $this->serializeVehiculo(
                    $liberacion->vehiculo,
                    $liberacion
                ));
        }

        return $this->vehiculosPendientesQuery($gruaId)
            ->with($this->vehiculoRelations())
            ->when($busqueda !== '', function ($query) use ($busqueda) {
                $query->where(function ($vehiculo) use ($busqueda) {
                    $this->buscarVehiculo($vehiculo, $busqueda);
                });
            })
            ->when($dias > 0, function ($query) use ($dias) {
                $desde = now('America/Mexico_City')->subDays($dias - 1)->startOfDay();
                $query->whereRaw(
                    'COALESCE((SELECT servicios_filtro.created_at FROM servicios AS servicios_filtro '
                    . 'WHERE servicios_filtro.vehiculo_id = vehiculos.id '
                    . 'ORDER BY servicios_filtro.created_at DESC, servicios_filtro.id DESC LIMIT 1), '
                    . 'vehiculos.fecha_inventario_grua, vehiculos.created_at) >= ?',
                    [$desde]
                );
            })
            ->when($origen !== 'TODOS', fn ($query) => $this->filtrarOrigen($query, $origen))
            ->orderByDesc('ultimo_servicio_at')
            ->get()
            ->map(fn (Vehiculo $vehiculo) => $this->serializeVehiculo($vehiculo));
    }

    private function csvSeguro($valor): string
    {
        $valor = (string) ($valor ?? '');

        return preg_match('/^[=+\-@]/', $valor) ? "'" . $valor : $valor;
    }

    private function normalizarTelefonoMx(?string $telefono): ?string
    {
        if ($telefono === null || trim($telefono) === '') {
            return null;
        }

        $telefono = preg_replace('/\D+/', '', $telefono);
        if ($telefono === '') {
            return null;
        }
        if (strlen($telefono) === 10) {
            return '521' . $telefono;
        }
        if (strlen($telefono) === 12 && str_starts_with($telefono, '52')) {
            return '521' . substr($telefono, 2);
        }

        return $telefono;
    }
}
