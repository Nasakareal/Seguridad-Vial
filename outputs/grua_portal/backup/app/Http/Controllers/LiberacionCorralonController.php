<?php

namespace App\Http\Controllers;

use App\Models\Grua;
use App\Models\LiberacionCorralon;
use App\Models\Vehiculo;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class LiberacionCorralonController extends Controller
{
    public function index(Request $request)
    {
        $portal = $this->esPortalGrua();
        $gruaUsuario = Auth::guard('grua')->user();
        $gruas = collect();

        $gruaId = null;

        if ($portal) {
            $gruaId = (int) $gruaUsuario->grua_id;
        } elseif ($request->filled('grua_id')) {
            $gruaId = (int) $request->input('grua_id');
            $gruas = Grua::orderBy('nombre')->get();
        } else {
            $gruas = Grua::orderBy('nombre')->get();
        }

        $vehiculosQuery = $this->vehiculosEnResguardoQuery($gruaId)
            ->with(['gruaAsignada', 'servicio.grua', 'hechos', 'liberacionCorralon']);

        $busqueda = trim((string) $request->input('q', ''));

        if ($busqueda !== '') {
            $vehiculosQuery->where(function ($q) use ($busqueda) {
                $q->where('placas', 'like', '%' . $busqueda . '%')
                    ->orWhere('serie', 'like', '%' . $busqueda . '%')
                    ->orWhere('marca', 'like', '%' . $busqueda . '%')
                    ->orWhere('linea', 'like', '%' . $busqueda . '%')
                    ->orWhere('numero_inventario_grua', 'like', '%' . $busqueda . '%');
            });
        }

        $vehiculos = $vehiculosQuery
            ->orderByDesc('ultimo_servicio_at')
            ->orderByDesc('fecha_inventario_grua')
            ->orderByDesc('updated_at')
            ->paginate(20)
            ->withQueryString();

        return view('liberaciones_corralon.index', compact(
            'portal',
            'gruaUsuario',
            'gruas',
            'gruaId',
            'busqueda',
            'vehiculos'
        ));
    }

    public function show(Vehiculo $vehiculo)
    {
        $this->autorizarVehiculo($vehiculo);

        $vehiculo->load(['gruaAsignada', 'servicio.grua', 'hechos', 'liberacionCorralon.gruaUsuario']);

        $portal = $this->esPortalGrua();
        $gruaUsuario = Auth::guard('grua')->user();
        $liberacion = $vehiculo->liberacionCorralon;

        return view('liberaciones_corralon.show', compact(
            'portal',
            'gruaUsuario',
            'vehiculo',
            'liberacion'
        ));
    }

    public function create(Vehiculo $vehiculo)
    {
        return $this->show($vehiculo);
    }

    public function store(Request $request, Vehiculo $vehiculo)
    {
        $this->autorizarVehiculo($vehiculo);

        $data = $this->validarEntrega($request, true);
        $gruaUsuario = Auth::guard('grua')->user();

        $gruaId = $gruaUsuario
            ? (int) $gruaUsuario->grua_id
            : $this->obtenerGruaIdVehiculo($vehiculo);

        DB::transaction(function () use ($vehiculo, $data, $gruaUsuario, $gruaId) {
            LiberacionCorralon::updateOrCreate(
                ['vehiculo_id' => $vehiculo->id],
                array_merge($data, [
                    'grua_id' => $gruaId,
                    'grua_usuario_id' => $gruaUsuario ? $gruaUsuario->id : null,
                    'estado' => 'ENTREGADO',
                    'fecha_entrega' => now(),
                ])
            );

            $vehiculo->update([
                'corralon' => null,
            ]);
        });

        return redirect()
            ->route($this->esPortalGrua() ? 'grua.corralon.index' : 'liberaciones_corralon.index')
            ->with('success', 'Vehiculo marcado como fuera de corralon.');
    }

    public function edit(LiberacionCorralon $liberacionCorralon)
    {
        $this->autorizarLiberacion($liberacionCorralon);

        return $this->show($liberacionCorralon->vehiculo);
    }

    public function update(Request $request, LiberacionCorralon $liberacionCorralon)
    {
        $this->autorizarLiberacion($liberacionCorralon);

        $data = $this->validarEntrega($request, false);

        DB::transaction(function () use ($liberacionCorralon, $data) {
            $liberacionCorralon->update(array_merge($data, [
                'estado' => 'ENTREGADO',
                'fecha_entrega' => $liberacionCorralon->fecha_entrega ?: now(),
            ]));

            $liberacionCorralon->vehiculo->update([
                'corralon' => null,
            ]);
        });

        return redirect()
            ->route($this->esPortalGrua() ? 'grua.corralon.index' : 'liberaciones_corralon.index')
            ->with('success', 'Entrega de corralon actualizada correctamente.');
    }

    private function vehiculosEnResguardoQuery(?int $gruaId = null)
    {
        return Vehiculo::query()
            ->select('vehiculos.*')
            ->selectSub(function ($query) {
                $query->from('servicios')
                    ->select('created_at')
                    ->whereColumn('servicios.vehiculo_id', 'vehiculos.id')
                    ->orderByDesc('created_at')
                    ->limit(1);
            }, 'ultimo_servicio_at')
            ->when($gruaId, function ($query) use ($gruaId) {
                $query->where(function ($query) use ($gruaId) {
                    $query->where('vehiculos.grua_id', $gruaId)
                        ->orWhereHas('servicios', function ($servicios) use ($gruaId) {
                            $servicios->where('grua_id', $gruaId);
                        });
                });
            })
            ->whereNotNull('vehiculos.corralon')
            ->whereRaw("TRIM(vehiculos.corralon) <> ''")
            ->whereRaw(
                "UPPER(TRIM(vehiculos.corralon)) NOT IN (" . implode(',', array_fill(0, count(Vehiculo::corralonValoresInvalidos()), '?')) . ")",
                Vehiculo::corralonValoresInvalidos()
            )
            ->whereDoesntHave('liberacionCorralon', function ($liberacion) {
                $liberacion->where('estado', 'ENTREGADO');
            });
    }

    private function validarEntrega(Request $request, bool $requiereConfirmacion): array
    {
        $rules = [
            'persona_recibe' => 'nullable|string|max:255',
            'identificacion_recibe' => 'nullable|string|max:255',
            'telefono_recibe' => 'nullable|string|max:30',
            'foto_identificacion' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
            'foto_entrega' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:5120',
            'documento_liberacion' => 'nullable|file|mimes:pdf,jpg,jpeg,png,webp|max:10240',
            'observaciones' => 'nullable|string|max:2000',
        ];

        if ($requiereConfirmacion) {
            $rules['confirmar_entrega'] = 'accepted';
        }

        $validated = $request->validate($rules);
        unset($validated['confirmar_entrega']);

        $validated['telefono_recibe'] = $this->normalizarTelefonoMx($validated['telefono_recibe'] ?? null);

        foreach (['foto_identificacion', 'foto_entrega', 'documento_liberacion'] as $campo) {
            if ($request->hasFile($campo)) {
                $validated[$campo] = $request->file($campo)->store('liberaciones_corralon', 'public');
            } else {
                unset($validated[$campo]);
            }
        }

        return $validated;
    }

    private function autorizarVehiculo(Vehiculo $vehiculo): void
    {
        if ($this->esPortalGrua()) {
            $gruaUsuario = Auth::guard('grua')->user();
            $gruaId = (int) $gruaUsuario->grua_id;
            $tieneServicio = $vehiculo->servicios()
                ->where('grua_id', $gruaId)
                ->exists();

            abort_unless((int) $vehiculo->grua_id === $gruaId || $tieneServicio, 403);
            return;
        }

        $usuario = Auth::guard('web')->user();
        abort_unless($usuario && $usuario->can('ver gruas'), 403);
    }

    private function autorizarLiberacion(LiberacionCorralon $liberacion): void
    {
        $liberacion->loadMissing('vehiculo');
        $this->autorizarVehiculo($liberacion->vehiculo);
    }

    private function esPortalGrua(): bool
    {
        return Auth::guard('grua')->check();
    }

    private function obtenerGruaIdVehiculo(Vehiculo $vehiculo): ?int
    {
        if (!empty($vehiculo->grua_id)) {
            return (int) $vehiculo->grua_id;
        }

        $servicio = $vehiculo->servicios()
            ->whereNotNull('grua_id')
            ->latest()
            ->first();

        return $servicio ? (int) $servicio->grua_id : null;
    }

    private function normalizarTelefonoMx(?string $telefono): ?string
    {
        if (is_null($telefono) || trim($telefono) === '') {
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
