<?php

namespace App\Http\Controllers;

use App\Models\Comunicacion;
use App\Models\ComunicacionAdjunto;
use App\Models\ComunicacionDestinatario;
use App\Models\Role;
use App\Models\Turno;
use App\Models\Unidad;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Throwable;

class ComunicacionController extends Controller
{
    public function index(Request $request)
    {
        $actor = Auth::user();

        if ($request->filled('con_usuario') && $this->quiereJson($request)) {
            return $this->conversacionDirecta(
                $actor,
                (int) $request->query('con_usuario')
            );
        }

        $recibidas = ComunicacionDestinatario::query()
            ->where('user_id', $actor->id)
            ->with([
                'comunicacion.remitente:id,name,nombres,apellido_paterno,apellido_materno',
                'comunicacion.unidad:id,nombre',
                'comunicacion.turno:id,nombre',
                'comunicacion.role:id,name',
                'comunicacion.adjuntos',
            ])
            ->orderByDesc('id')
            ->paginate(20, ['*'], 'recibidas_page');

        $enviadas = Comunicacion::query()
            ->where('remitente_user_id', $actor->id)
            ->with([
                'unidad:id,nombre',
                'turno:id,nombre',
                'role:id,name',
                'destinatario:id,name,nombres,apellido_paterno,apellido_materno',
                'adjuntos',
            ])
            ->withCount('destinatarios')
            ->withCount([
                'destinatarios as leidos_count' => function ($query) {
                    $query->whereNotNull('leido_at');
                },
            ])
            ->withCount([
                'destinatarios as enterados_count' => function ($query) {
                    $query->whereNotNull('enterado_at');
                },
            ])
            ->orderByDesc('id')
            ->paginate(20, ['*'], 'enviadas_page');

        if ($this->quiereJson($request)) {
            return response()->json([
                'recibidas' => $recibidas,
                'enviadas' => $enviadas,
                'no_leidas' => $this->numeroNoLeidas($actor),
            ]);
        }

        $capacidades = $this->capacidadesActor($actor);

        return view('comunicaciones.index', compact(
            'recibidas',
            'enviadas',
            'capacidades'
        ));
    }

    public function create()
    {
        $actor = Auth::user();
        $capacidades = $this->capacidadesActor($actor);

        if ($this->actorTieneAlcanceGlobal($actor)) {
            $unidades = Unidad::query()
                ->orderBy('nombre')
                ->get();
        } elseif ($actor->unidad_id) {
            $unidades = Unidad::query()
                ->whereKey($actor->unidad_id)
                ->get();
        } else {
            $unidades = collect();
        }

        $turnos = Turno::query()
            ->orderBy('nombre')
            ->get();

        if ($this->actorTieneAlcanceGlobal($actor)) {
            $roles = Role::query()
                ->with('unidad')
                ->when(!$actor->isSuperadmin(), function ($query) {
                    $query->where('name', '!=', 'Superadmin');
                })
                ->orderBy('name')
                ->get();
        } else {
            $roles = collect();
        }

        return view('comunicaciones.create', compact(
            'capacidades',
            'unidades',
            'turnos',
            'roles'
        ));
    }

    public function store(Request $request)
    {
        $actor = Auth::user();

        $request->merge([
            'tipo' => Str::lower(trim((string) $request->input('tipo'))),
            'alcance' => Str::lower(trim((string) $request->input('alcance'))),
        ]);

        $validated = $request->validate([
            'tipo' => 'required|in:orden,aviso,mensaje',
            'asunto' => 'nullable|string|max:180',
            'contenido' => 'nullable|string|max:10000',
            'alcance' => 'required|in:todos,unidad,unidad_turno,subdirectores,rol,usuario',
            'unidad_id' => 'nullable|integer|exists:unidades,id',
            'turno_id' => 'nullable|integer|exists:turnos,id',
            'role_id' => 'nullable|integer|exists:roles,id',
            'destinatario_user_id' => 'nullable|integer|exists:users,id',
            'requiere_enterado' => 'nullable|boolean',
            'imagenes' => 'nullable|array|max:10',
            'imagenes.*' => 'file|image|mimes:jpg,jpeg,png,webp|max:10240',
        ]);

        $contenido = trim((string) ($validated['contenido'] ?? ''));

        $imagenes = $request->file('imagenes', []);

        if (!is_array($imagenes)) {
            $imagenes = [$imagenes];
        }

        $imagenes = array_values(array_filter($imagenes));

        $tieneImagenes = count($imagenes) > 0;

        if (
            in_array($validated['tipo'], ['orden', 'aviso'], true)
            && trim((string) ($validated['asunto'] ?? '')) === ''
        ) {
            throw ValidationException::withMessages([
                'asunto' => 'El asunto es obligatorio para órdenes y avisos.',
            ]);
        }

        if (
            in_array($validated['tipo'], ['orden', 'aviso'], true)
            && $contenido === ''
        ) {
            throw ValidationException::withMessages([
                'contenido' => 'Las órdenes y avisos deben contener texto.',
            ]);
        }

        if (
            $validated['tipo'] === 'mensaje'
            && $validated['alcance'] !== 'usuario'
        ) {
            throw ValidationException::withMessages([
                'alcance' => 'Los mensajes directos deben enviarse a un usuario.',
            ]);
        }

        if (
            $validated['tipo'] === 'mensaje'
            && $contenido === ''
            && !$tieneImagenes
        ) {
            throw ValidationException::withMessages([
                'contenido' => 'Debes escribir un mensaje o adjuntar al menos una imagen.',
            ]);
        }

        $this->validarCamposRequeridosPorAlcance($validated);
        $this->validarPermisosEnvio($actor, $validated);

        $validated = $this->normalizarCamposAlcance($validated);

        $destinatarios = $this->resolverDestinatarios(
            $actor,
            $validated
        );

        if ($destinatarios->isEmpty()) {
            throw ValidationException::withMessages([
                'destinatarios' => 'No se encontraron destinatarios válidos para esta comunicación.',
            ]);
        }

        $archivosGuardados = [];

        try {
            $comunicacion = DB::transaction(function () use (
                $actor,
                $validated,
                $destinatarios,
                $request,
                $contenido,
                $imagenes,
                &$archivosGuardados
            ) {
                $requiereEnterado = false;

                if ($validated['tipo'] === 'orden') {
                    $requiereEnterado = true;
                } elseif ($validated['tipo'] === 'aviso') {
                    $requiereEnterado = $request->boolean('requiere_enterado');
                }

                $comunicacion = Comunicacion::create([
                    'remitente_user_id' => $actor->id,
                    'tipo' => $validated['tipo'],
                    'asunto' => ($validated['asunto'] ?? null)
                        ?: ($validated['tipo'] === 'mensaje'
                            ? 'Mensaje directo'
                            : 'Comunicación'),
                    'contenido' => $contenido,
                    'alcance' => $validated['alcance'],
                    'unidad_id' => $validated['unidad_id'],
                    'turno_id' => $validated['turno_id'],
                    'role_id' => $validated['role_id'],
                    'destinatario_user_id' => $validated['destinatario_user_id'],
                    'requiere_enterado' => $requiereEnterado,
                    'enviado_at' => now(),
                ]);

                $ahora = now();

                $filas = $destinatarios
                    ->map(function ($userId) use ($comunicacion, $ahora) {
                        return [
                            'comunicacion_id' => $comunicacion->id,
                            'user_id' => $userId,
                            'leido_at' => null,
                            'enterado_at' => null,
                            'created_at' => $ahora,
                            'updated_at' => $ahora,
                        ];
                    })
                    ->values()
                    ->all();

                foreach (array_chunk($filas, 500) as $chunk) {
                    ComunicacionDestinatario::insert($chunk);
                }

                $this->guardarImagenes(
                    $comunicacion,
                    $imagenes,
                    $archivosGuardados
                );

                return $comunicacion;
            });
        } catch (Throwable $e) {
            foreach ($archivosGuardados as $archivo) {
                Storage::disk($archivo['disk'])
                    ->delete($archivo['ruta']);
            }

            throw $e;
        }

        app(\App\Services\ComunicacionPushService::class)->schedule($comunicacion->id);

        $comunicacion->load([
            'remitente:id,name,nombres,apellido_paterno,apellido_materno',
            'destinatario:id,name,nombres,apellido_paterno,apellido_materno',
            'unidad:id,nombre',
            'turno:id,nombre',
            'role:id,name',
            'adjuntos',
        ]);

        if ($this->quiereJson($request)) {
            return response()->json([
                'ok' => true,
                'mensaje' => 'Comunicación enviada correctamente.',
                'comunicacion' => $this->formatearComunicacionParaJson(
                    $comunicacion,
                    $actor
                ),
                'destinatarios' => $destinatarios->count(),
            ], 201);
        }

        return redirect()
            ->route('comunicaciones.show', $comunicacion)
            ->with('success', 'Comunicación enviada correctamente.');
    }

    public function show(Request $request, Comunicacion $comunicacion)
    {
        $actor = Auth::user();

        $registroDestinatario = ComunicacionDestinatario::query()
            ->where('comunicacion_id', $comunicacion->id)
            ->where('user_id', $actor->id)
            ->first();

        $esRemitente =
            (int) $comunicacion->remitente_user_id === (int) $actor->id;

        if (!$esRemitente && !$registroDestinatario) {
            abort(403);
        }

        if (
            $registroDestinatario
            && is_null($registroDestinatario->leido_at)
        ) {
            $registroDestinatario->update([
                'leido_at' => now(),
            ]);
        }

        $comunicacion->load([
            'remitente:id,name,nombres,apellido_paterno,apellido_materno',
            'destinatario:id,name,nombres,apellido_paterno,apellido_materno',
            'unidad:id,nombre',
            'turno:id,nombre',
            'role:id,name',
            'adjuntos',
        ]);

        if ($esRemitente) {

        $comunicacion->load([
                'destinatarios.usuario:id,name,nombres,apellido_paterno,apellido_materno,unidad_id,turno_id',
                'destinatarios.usuario.unidad:id,nombre',
                'destinatarios.usuario.turno:id,nombre',
            ]);
        }

        if ($this->quiereJson($request)) {
            return response()->json([
                'comunicacion' => $this->formatearComunicacionParaJson(
                    $comunicacion,
                    $actor
                ),
                'es_remitente' => $esRemitente,
                'registro_destinatario' => $registroDestinatario,
            ]);
        }

        return view('comunicaciones.show', compact(
            'comunicacion',
            'registroDestinatario',
            'esRemitente'
        ));
    }

    public function verAdjunto(ComunicacionAdjunto $adjunto)
    {
        $actor = Auth::user();

        $adjunto->load('comunicacion');

        if (!$adjunto->comunicacion) {
            abort(404);
        }

        if (!$this->puedeVerComunicacion(
            $actor,
            $adjunto->comunicacion
        )) {
            abort(403);
        }

        $disk = $adjunto->disk ?: 'local';

        if (!Storage::disk($disk)->exists($adjunto->ruta)) {
            abort(404);
        }

        $nombre = $adjunto->nombre_original
            ?: basename($adjunto->ruta);

        return Storage::disk($disk)->response(
            $adjunto->ruta,
            $nombre,
            [
                'Content-Type' => $adjunto->mime_type ?: 'application/octet-stream',
                'Cache-Control' => 'private, max-age=3600',
            ],
            'inline'
        );
    }

    public function destinatarios(Request $request)
    {
        $actor = Auth::user();

        $query = $this->queryUsuariosParaMensajeIndividual($actor)
            ->with([
                'unidad:id,nombre',
                'turno:id,nombre',
                'roles:id,name',
            ]);

        $busqueda = trim((string) $request->query('q', ''));

        if ($busqueda !== '') {
            $query->where(function ($subQuery) use ($busqueda) {
                $subQuery
                    ->where('name', 'like', '%' . $busqueda . '%')
                    ->orWhere('nombres', 'like', '%' . $busqueda . '%')
                    ->orWhere('apellido_paterno', 'like', '%' . $busqueda . '%')
                    ->orWhere('apellido_materno', 'like', '%' . $busqueda . '%')
                    ->orWhere('email', 'like', '%' . $busqueda . '%');
            });
        }

        if (
            $this->actorTieneAlcanceGlobal($actor)
            && $request->filled('unidad_id')
        ) {
            $query->where(
                'unidad_id',
                (int) $request->query('unidad_id')
            );
        }

        if ($request->filled('turno_id')) {
            $query->where(
                'turno_id',
                (int) $request->query('turno_id')
            );
        }

        $usuarios = $query
            ->orderBy('name')
            ->limit(100)
            ->get()
            ->map(function (User $user) {
                return [
                    'id' => $user->id,
                    'nombre' => $user->nombre_completo,
                    'email' => $user->email,
                    'unidad_id' => $user->unidad_id,
                    'unidad' => optional($user->unidad)->nombre,
                    'turno_id' => $user->turno_id,
                    'turno' => optional($user->turno)->nombre,
                    'roles' => $user->roles->pluck('name')->values(),
                ];
            })
            ->values();

        return response()->json([
            'usuarios' => $usuarios,
        ]);
    }

    public function countNoLeidas()
    {
        $actor = Auth::user();

        $ultimo = ComunicacionDestinatario::query()
            ->where('user_id', $actor->id)
            ->whereNull('leido_at')
            ->with([
                'comunicacion.remitente:id,name,nombres,apellido_paterno,apellido_materno',
            ])
            ->orderByDesc('id')
            ->first();

        return response()->json([
            'count' => $this->numeroNoLeidas($actor),
            'ultimo_destinatario_id' => $ultimo?->id,
            'ultimo_comunicacion_id' => $ultimo?->comunicacion_id,
            'ultimo_tipo' => $ultimo?->comunicacion?->tipo,
            'ultimo_asunto' => $ultimo?->comunicacion?->asunto,
            'ultimo_remitente' => $ultimo?->comunicacion?->remitente?->nombre_completo,
            'ultimo_enviado_at' => $ultimo?->comunicacion?->enviado_at,
        ]);
    }

    public function marcarLeido(
        Request $request,
        Comunicacion $comunicacion
    ) {
        $actor = Auth::user();

        $registro = ComunicacionDestinatario::query()
            ->where('comunicacion_id', $comunicacion->id)
            ->where('user_id', $actor->id)
            ->firstOrFail();

        if (is_null($registro->leido_at)) {
            $registro->update([
                'leido_at' => now(),
            ]);
        }

        if ($this->quiereJson($request)) {
            return response()->json([
                'ok' => true,
                'leido_at' => $registro->fresh()->leido_at,
                'no_leidas' => $this->numeroNoLeidas($actor),
            ]);
        }

        return back();
    }

    public function marcarEnterado(
        Request $request,
        Comunicacion $comunicacion
    ) {
        $actor = Auth::user();

        if (!$comunicacion->requiere_enterado) {
            throw ValidationException::withMessages([
                'comunicacion' => 'Esta comunicación no requiere confirmación de enterado.',
            ]);
        }

        $registro = ComunicacionDestinatario::query()
            ->where('comunicacion_id', $comunicacion->id)
            ->where('user_id', $actor->id)
            ->firstOrFail();

        $cambios = [];

        if (is_null($registro->leido_at)) {
            $cambios['leido_at'] = now();
        }

        if (is_null($registro->enterado_at)) {
            $cambios['enterado_at'] = now();
        }

        if (!empty($cambios)) {
            $registro->update($cambios);
        }

        $registro->refresh();

        if ($this->quiereJson($request)) {
            return response()->json([
                'ok' => true,
                'leido_at' => $registro->leido_at,
                'enterado_at' => $registro->enterado_at,
                'no_leidas' => $this->numeroNoLeidas($actor),
            ]);
        }

        return back()->with(
            'success',
            'Se registró tu confirmación de enterado.'
        );
    }

    private function conversacionDirecta(
        User $actor,
        int $otroUsuarioId
    ) {
        if (
            $otroUsuarioId <= 0
            || $otroUsuarioId === (int) $actor->id
        ) {
            abort(404);
        }

        $otroUsuario = User::query()
            ->with([
                'unidad:id,nombre',
                'turno:id,nombre',
                'roles:id,name',
            ])
            ->findOrFail($otroUsuarioId);

        $puedeEnviarActualmente = $this
            ->queryUsuariosParaMensajeIndividual($actor)
            ->whereKey($otroUsuarioId)
            ->exists();

        $existeConversacion = Comunicacion::query()
            ->where('tipo', 'mensaje')
            ->where('alcance', 'usuario')
            ->where(function ($query) use ($actor, $otroUsuarioId) {
                $query
                    ->where(function ($subQuery) use ($actor, $otroUsuarioId) {
                        $subQuery
                            ->where('remitente_user_id', $actor->id)
                            ->where('destinatario_user_id', $otroUsuarioId);
                    })
                    ->orWhere(function ($subQuery) use ($actor, $otroUsuarioId) {
                        $subQuery
                            ->where('remitente_user_id', $otroUsuarioId)
                            ->where('destinatario_user_id', $actor->id);
                    });
            })
            ->exists();

        if (!$puedeEnviarActualmente && !$existeConversacion) {
            abort(403);
        }

        $entrantesIds = Comunicacion::query()
            ->where('tipo', 'mensaje')
            ->where('alcance', 'usuario')
            ->where('remitente_user_id', $otroUsuarioId)
            ->where('destinatario_user_id', $actor->id)
            ->pluck('id');

        if ($entrantesIds->isNotEmpty()) {
            ComunicacionDestinatario::query()
                ->where('user_id', $actor->id)
                ->whereIn('comunicacion_id', $entrantesIds)
                ->whereNull('leido_at')
                ->update([
                    'leido_at' => now(),
                    'updated_at' => now(),
                ]);
        }

        $mensajes = Comunicacion::query()
            ->where('tipo', 'mensaje')
            ->where('alcance', 'usuario')
            ->where(function ($query) use ($actor, $otroUsuarioId) {
                $query
                    ->where(function ($subQuery) use ($actor, $otroUsuarioId) {
                        $subQuery
                            ->where('remitente_user_id', $actor->id)
                            ->where('destinatario_user_id', $otroUsuarioId);
                    })
                    ->orWhere(function ($subQuery) use ($actor, $otroUsuarioId) {
                        $subQuery
                            ->where('remitente_user_id', $otroUsuarioId)
                            ->where('destinatario_user_id', $actor->id);
                    });
            })
            ->with([
                'remitente:id,name,nombres,apellido_paterno,apellido_materno',
                'adjuntos',
                'destinatarios' => function ($query) use (
                    $actor,
                    $otroUsuarioId
                ) {
                    $query->whereIn('user_id', [
                        $actor->id,
                        $otroUsuarioId,
                    ]);
                },
            ])
            ->orderByDesc('id')
            ->limit(50)
            ->get()
            ->reverse()
            ->values()
            ->map(function (Comunicacion $mensaje) use ($actor) {
                $registroDestinatario = $mensaje
                    ->destinatarios
                    ->firstWhere(
                        'user_id',
                        (int) $mensaje->destinatario_user_id
                    );

                return [
                    'id' => $mensaje->id,
                    'remitente_user_id' => $mensaje->remitente_user_id,
                    'destinatario_user_id' => $mensaje->destinatario_user_id,
                    'contenido' => $mensaje->contenido,
                    'enviado_at' => $mensaje->enviado_at,
                    'es_mio' =>
                        (int) $mensaje->remitente_user_id ===
                        (int) $actor->id,
                    'leido_at' => $registroDestinatario?->leido_at,
                    'remitente' => $mensaje->remitente?->nombre_completo,
                    'adjuntos' => $mensaje->adjuntos
                        ->map(function (ComunicacionAdjunto $adjunto) {
                            return $this->formatearAdjunto($adjunto);
                        })
                        ->values(),
                ];
            });

        return response()->json([
            'usuario' => [
                'id' => $otroUsuario->id,
                'nombre' => $otroUsuario->nombre_completo,
                'unidad' => optional($otroUsuario->unidad)->nombre,
                'turno' => optional($otroUsuario->turno)->nombre,
                'roles' => $otroUsuario->roles->pluck('name')->values(),
                'puede_enviar' => $puedeEnviarActualmente,
            ],
            'mensajes' => $mensajes,
            'no_leidas' => $this->numeroNoLeidas($actor),
        ]);
    }

    private function guardarImagenes(
        Comunicacion $comunicacion,
        array $imagenes,
        array &$archivosGuardados
    ): void {
        if (empty($imagenes)) {
            return;
        }

        $disk = 'local';

        foreach ($imagenes as $orden => $imagen) {
            if (!$imagen || !$imagen->isValid()) {
                continue;
            }

            $extension = strtolower(
                $imagen->extension()
                ?: $imagen->getClientOriginalExtension()
            );

            $nombreArchivo =
                Str::uuid()->toString()
                . ($extension ? '.' . $extension : '');

            $directorio =
                'comunicaciones/'
                . $comunicacion->id;

            $dimensiones = @getimagesize(
                $imagen->getRealPath()
            );

            $ancho = is_array($dimensiones)
                ? ($dimensiones[0] ?? null)
                : null;

            $alto = is_array($dimensiones)
                ? ($dimensiones[1] ?? null)
                : null;

            $ruta = $imagen->storeAs(
                $directorio,
                $nombreArchivo,
                $disk
            );

            if (!$ruta) {
                throw new \RuntimeException(
                    'No fue posible guardar una de las imágenes.'
                );
            }

            $archivosGuardados[] = [
                'disk' => $disk,
                'ruta' => $ruta,
            ];

            ComunicacionAdjunto::create([
                'comunicacion_id' => $comunicacion->id,
                'tipo' => 'imagen',
                'disk' => $disk,
                'ruta' => $ruta,
                'nombre_original' => $imagen->getClientOriginalName(),
                'mime_type' => $imagen->getMimeType(),
                'tamano_bytes' => $imagen->getSize(),
                'ancho' => $ancho,
                'alto' => $alto,
                'orden' => $orden,
            ]);
        }
    }

    private function formatearAdjunto(
        ComunicacionAdjunto $adjunto
    ): array {
        return [
            'id' => $adjunto->id,
            'tipo' => $adjunto->tipo,
            'nombre_original' => $adjunto->nombre_original,
            'mime_type' => $adjunto->mime_type,
            'tamano_bytes' => $adjunto->tamano_bytes,
            'ancho' => $adjunto->ancho,
            'alto' => $adjunto->alto,
            'url' => route(
                'comunicaciones.adjuntos.show',
                $adjunto
            ),
        ];
    }

    private function formatearComunicacionParaJson(
        Comunicacion $comunicacion,
        User $actor
    ): array {
        return [
            'id' => $comunicacion->id,
            'tipo' => $comunicacion->tipo,
            'asunto' => $comunicacion->asunto,
            'contenido' => $comunicacion->contenido,
            'alcance' => $comunicacion->alcance,
            'remitente_user_id' => $comunicacion->remitente_user_id,
            'destinatario_user_id' => $comunicacion->destinatario_user_id,
            'requiere_enterado' => $comunicacion->requiere_enterado,
            'enviado_at' => $comunicacion->enviado_at,
            'es_mio' =>
                (int) $comunicacion->remitente_user_id ===
                (int) $actor->id,
            'adjuntos' => $comunicacion->adjuntos
                ->map(function (ComunicacionAdjunto $adjunto) {
                    return $this->formatearAdjunto($adjunto);
                })
                ->values(),
        ];
    }

    private function puedeVerComunicacion(
        User $actor,
        Comunicacion $comunicacion
    ): bool {
        if (
            (int) $comunicacion->remitente_user_id ===
            (int) $actor->id
        ) {
            return true;
        }

        return ComunicacionDestinatario::query()
            ->where(
                'comunicacion_id',
                $comunicacion->id
            )
            ->where(
                'user_id',
                $actor->id
            )
            ->exists();
    }

    private function validarCamposRequeridosPorAlcance(
        array $data
    ): void {
        if (
            $data['alcance'] === 'unidad'
            && empty($data['unidad_id'])
        ) {
            throw ValidationException::withMessages([
                'unidad_id' => 'Debes seleccionar una unidad.',
            ]);
        }

        if ($data['alcance'] === 'unidad_turno') {
            if (empty($data['unidad_id'])) {
                throw ValidationException::withMessages([
                    'unidad_id' => 'Debes seleccionar una unidad.',
                ]);
            }

            if (empty($data['turno_id'])) {
                throw ValidationException::withMessages([
                    'turno_id' => 'Debes seleccionar un turno.',
                ]);
            }
        }

        if (
            $data['alcance'] === 'rol'
            && empty($data['role_id'])
        ) {
            throw ValidationException::withMessages([
                'role_id' => 'Debes seleccionar un rol.',
            ]);
        }

        if (
            $data['alcance'] === 'usuario'
            && empty($data['destinatario_user_id'])
        ) {
            throw ValidationException::withMessages([
                'destinatario_user_id' => 'Debes seleccionar un usuario.',
            ]);
        }
    }

    private function validarPermisosEnvio(
        User $actor,
        array $data
    ): void {
        if ($this->actorTieneAlcanceGlobal($actor)) {
            if (
                $data['alcance'] === 'usuario'
                && !$this->usuarioPermitidoParaMensaje(
                    $actor,
                    (int) $data['destinatario_user_id']
                )
            ) {
                throw ValidationException::withMessages([
                    'destinatario_user_id' => 'No puedes enviar una comunicación a ese usuario.',
                ]);
            }

            return;
        }

        if ($this->actorEsSubdirector($actor)) {
            if (!$actor->unidad_id) {
                throw ValidationException::withMessages([
                    'unidad_id' => 'Tu usuario no tiene una unidad asignada.',
                ]);
            }

            $alcancesPermitidos = [
                'unidad',
                'unidad_turno',
                'usuario',
            ];

            if (!in_array(
                $data['alcance'],
                $alcancesPermitidos,
                true
            )) {
                throw ValidationException::withMessages([
                    'alcance' => 'Como Subdirector solamente puedes enviar a tu unidad, a un turno de tu unidad o a una persona de tu unidad.',
                ]);
            }

            if (
                in_array(
                    $data['alcance'],
                    ['unidad', 'unidad_turno'],
                    true
                )
                && (int) $data['unidad_id'] !==
                    (int) $actor->unidad_id
            ) {
                throw ValidationException::withMessages([
                    'unidad_id' => 'Solamente puedes enviar comunicaciones a tu propia unidad.',
                ]);
            }

            if (
                $data['alcance'] === 'usuario'
                && !$this->usuarioPermitidoParaMensaje(
                    $actor,
                    (int) $data['destinatario_user_id']
                )
            ) {
                throw ValidationException::withMessages([
                    'destinatario_user_id' => 'Solamente puedes enviar comunicaciones a personal de tu unidad.',
                ]);
            }

            return;
        }

        if (
            $data['tipo'] !== 'mensaje'
            || $data['alcance'] !== 'usuario'
        ) {
            throw ValidationException::withMessages([
                'alcance' => 'Tu usuario solamente puede enviar mensajes directos a personal de su misma unidad.',
            ]);
        }

        if (!$actor->unidad_id) {
            throw ValidationException::withMessages([
                'unidad_id' => 'Tu usuario no tiene una unidad asignada.',
            ]);
        }

        if (
            !$this->usuarioPermitidoParaMensaje(
                $actor,
                (int) $data['destinatario_user_id']
            )
        ) {
            throw ValidationException::withMessages([
                'destinatario_user_id' => 'Solamente puedes enviar mensajes a personal de tu misma unidad.',
            ]);
        }
    }

    private function normalizarCamposAlcance(
        array $data
    ): array {
        $unidadId = null;
        $turnoId = null;
        $roleId = null;
        $destinatarioUserId = null;

        if ($data['alcance'] === 'unidad') {
            $unidadId = (int) $data['unidad_id'];
        }

        if ($data['alcance'] === 'unidad_turno') {
            $unidadId = (int) $data['unidad_id'];
            $turnoId = (int) $data['turno_id'];
        }

        if ($data['alcance'] === 'rol') {
            $roleId = (int) $data['role_id'];

            if (!empty($data['unidad_id'])) {
                $unidadId = (int) $data['unidad_id'];
            }
        }

        if ($data['alcance'] === 'usuario') {
            $destinatarioUserId =
                (int) $data['destinatario_user_id'];
        }

        $data['unidad_id'] = $unidadId;
        $data['turno_id'] = $turnoId;
        $data['role_id'] = $roleId;
        $data['destinatario_user_id'] =
            $destinatarioUserId;

        return $data;
    }

    private function resolverDestinatarios(
        User $actor,
        array $data
    ) {
        $query = User::query()
            ->visibleFor($actor)
            ->where('estado', 'Activo')
            ->where('id', '!=', $actor->id);

        if ($data['alcance'] === 'todos') {
            return $query
                ->pluck('id')
                ->unique()
                ->values();
        }

        if ($data['alcance'] === 'unidad') {
            return $query
                ->where(
                    'unidad_id',
                    $data['unidad_id']
                )
                ->pluck('id')
                ->unique()
                ->values();
        }

        if ($data['alcance'] === 'unidad_turno') {
            return $query
                ->where(
                    'unidad_id',
                    $data['unidad_id']
                )
                ->where(
                    'turno_id',
                    $data['turno_id']
                )
                ->pluck('id')
                ->unique()
                ->values();
        }

        if ($data['alcance'] === 'subdirectores') {
            return $query
                ->whereHas(
                    'roles',
                    function ($roleQuery) {
                        $roleQuery->whereRaw(
                            'LOWER(name) LIKE ?',
                            ['%subdirector%']
                        );
                    }
                )
                ->pluck('id')
                ->unique()
                ->values();
        }

        if ($data['alcance'] === 'rol') {
            $role = Role::findOrFail(
                $data['role_id']
            );

            $query->role($role->name);

            if (!empty($data['unidad_id'])) {
                $query->where(
                    'unidad_id',
                    $data['unidad_id']
                );
            }

            return $query
                ->pluck('id')
                ->unique()
                ->values();
        }

        if ($data['alcance'] === 'usuario') {
            return $this->queryUsuariosParaMensajeIndividual($actor)
                ->whereKey(
                    $data['destinatario_user_id']
                )
                ->pluck('id')
                ->unique()
                ->values();
        }

        return collect();
    }

    private function queryUsuariosParaMensajeIndividual(User $actor)
    {
        return \App\Services\ComunicacionConversationAccess::recipients($actor, $this->actorTieneAlcanceGlobal($actor));
    }

    private function usuarioPermitidoParaMensaje(
        User $actor,
        int $userId
    ): bool {
        if (
            $userId <= 0
            || $userId === (int) $actor->id
        ) {
            return false;
        }

        return $this
            ->queryUsuariosParaMensajeIndividual($actor)
            ->whereKey($userId)
            ->exists();
    }

    private function numeroNoLeidas(
        User $actor
    ): int {
        return ComunicacionDestinatario::query()
            ->where('user_id', $actor->id)
            ->whereNull('leido_at')
            ->count();
    }

    private function capacidadesActor(
        User $actor
    ): array {
        if ($this->actorTieneAlcanceGlobal($actor)) {
            return [
                'todos' => true,
                'unidad' => true,
                'unidad_turno' => true,
                'subdirectores' => true,
                'rol' => true,
                'usuario' => true,
                'orden' => true,
                'aviso' => true,
                'mensaje' => true,
            ];
        }

        if ($this->actorEsSubdirector($actor)) {
            return [
                'todos' => false,
                'unidad' => true,
                'unidad_turno' => true,
                'subdirectores' => false,
                'rol' => false,
                'usuario' => true,
                'orden' => true,
                'aviso' => true,
                'mensaje' => true,
            ];
        }

        return [
            'todos' => false,
            'unidad' => false,
            'unidad_turno' => false,
            'subdirectores' => false,
            'rol' => false,
            'usuario' => true,
            'orden' => false,
            'aviso' => false,
            'mensaje' => true,
        ];
    }

    private function actorTieneAlcanceGlobal(
        User $actor
    ): bool {
        return $actor->isSuperadmin()
            || $this->actorEsCoordinador($actor);
    }

    private function actorEsCoordinador(
        User $actor
    ): bool {
        $actor->loadMissing('roles');

        return $actor->roles->contains(
            function ($role) {
                return Str::contains(
                    Str::lower(
                        (string) $role->name
                    ),
                    'coordinador'
                );
            }
        );
    }

    private function actorEsSubdirector(
        User $actor
    ): bool {
        $actor->loadMissing('roles');

        return $actor->roles->contains(
            function ($role) {
                return Str::contains(
                    Str::lower(
                        (string) $role->name
                    ),
                    'subdirector'
                );
            }
        );
    }

    private function quiereJson(
        Request $request
    ): bool {
        return $request->expectsJson()
            || $request->ajax()
            || $request->boolean('json');
    }
}
