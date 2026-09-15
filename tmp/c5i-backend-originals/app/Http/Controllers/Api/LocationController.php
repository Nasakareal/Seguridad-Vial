<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserLocation;
use App\Services\LocationTrackingEligibilityService;
use App\Services\C5iResponseTimeService;
use App\Services\SuspiciousPlaceDwellService;
use App\Support\MapaPatrullasAccess;
use Carbon\Carbon;
use Illuminate\Http\Request;

class LocationController extends Controller
{
    public function storeSuspiciousPlaceEvent(
        Request $request,
        SuspiciousPlaceDwellService $suspiciousPlaceDwell
    ) {
        $validated = $request->validate([
            'visit_id' => 'required|uuid',
            'event_type' => 'required|in:dwell,exit',
            'place_key' => 'required|string|max:80',
            'entered_at' => 'required|date',
            'occurred_at' => 'required|date',
            'duration_seconds' => 'required|integer|min:0|max:86400',
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
            'accuracy' => 'required|numeric|min:0|max:1000',
        ]);

        $result = $suspiciousPlaceDwell->processClientEvent(
            $request->user(),
            $validated
        );

        $statusCode = in_array(
            $result['status'] ?? null,
            ['failed', 'notification_failed'],
            true
        ) ? 503 : 200;

        return response()->json([
            'message' => 'Evento local procesado',
            'data' => $result,
        ], $statusCode);
    }

    public function store(
        Request $request,
        LocationTrackingEligibilityService $trackingEligibility,
        C5iResponseTimeService $responseTime,
        SuspiciousPlaceDwellService $suspiciousPlaceDwell
    )
    {
        $user = $request->user();

        $trackingStatus = $trackingEligibility->statusForUser($user);

        // Si está apagado por administración/jefe, no tiene turno o su turno descansa, no se guarda.
        if (!$trackingStatus['allowed']) {
            return response()->json([
                'message' => $this->trackingBlockedMessage($trackingStatus['reason'] ?? null),
                'user_id' => $user->id,
                'compartir_ubicacion' => (int)($user->compartir_ubicacion ?? 0),
                'location_tracking' => $trackingStatus,
            ], 403);
        }

        $validated = $request->validate([
            'lat'         => 'required|numeric|between:-90,90',
            'lng'         => 'required|numeric|between:-180,180',
            'accuracy'    => 'nullable|numeric|min:0',
            'speed'       => 'nullable|numeric|min:0',
            'heading'     => 'nullable|numeric|between:0,360',
            'captured_at' => 'nullable|date',
        ]);

        $capturedAt = isset($validated['captured_at'])
            ? Carbon::parse($validated['captured_at'])
            : now();

        $currentLocation = UserLocation::query()
            ->where('user_id', $user->id)
            ->first();

        // Las ubicaciones pueden llegar tarde desde la cola offline. No se permite
        // que una muestra vieja reemplace la posición más reciente ni dispare eventos.
        if ($currentLocation
            && $currentLocation->captured_at
            && $capturedAt->lte($currentLocation->captured_at)) {
            return response()->json([
                'message' => 'Ubicación anterior ignorada',
                'data' => $currentLocation,
                'location_tracking' => $trackingStatus,
            ], 200);
        }

        $location = UserLocation::updateOrCreate(
            ['user_id' => $user->id],
            [
                'lat'         => $validated['lat'],
                'lng'         => $validated['lng'],
                'accuracy'    => $validated['accuracy'] ?? null,
                'speed'       => $validated['speed'] ?? null,
                'heading'     => $validated['heading'] ?? null,
                'captured_at' => $capturedAt,
            ]
        );

        $user->last_seen_at = $capturedAt;
        $user->connection_status = 'connected';
        $user->disconnected_alert_sent_at = null;
        $user->save();

        $responseTime->processLocation($user, $location);
        $suspiciousPlaceDwell->processLocation($user, $location);

        return response()->json([
            'message' => 'Ubicación guardada',
            'data'    => $location,
            'location_tracking' => $trackingStatus,
        ], 200);
    }

    public function last(Request $request)
    {
        $user = $request->user();

        $location = UserLocation::where('user_id', $user->id)
            ->latest('captured_at')
            ->first();

        return response()->json([
            'data' => $location,
        ], 200);
    }

    public function lastByUser(Request $request, User $user)
    {
        $actor = $request->user();

        if (!$this->canManageUser($actor, $user)) {
            abort(403, 'No autorizado.');
        }

        if ((int)($user->compartir_ubicacion ?? 0) !== 1) {
            return response()->json([
                'message' => 'La ubicación de este usuario está desactivada (compartir_ubicacion=0).',
                'data' => null,
                'user_id' => $user->id,
                'compartir_ubicacion' => (int)($user->compartir_ubicacion ?? 0),
            ], 403);
        }

        $location = UserLocation::where('user_id', $user->id)
            ->latest('captured_at')
            ->first();

        return response()->json([
            'data' => $location,
        ], 200);
    }

    public function index(Request $request)
    {
        $actor = $request->user();

        $usersQuery = User::query()->where('compartir_ubicacion', 1);

        if ($actor->hasRole('Subdirector')) {
            if ($actor->unidad_id) {
                $usersQuery->where('unidad_id', $actor->unidad_id);
            } else {
                $usersQuery->whereRaw('1=0');
            }
        } else {
            if ($actor->unidad_id) {
                $usersQuery->where('unidad_id', $actor->unidad_id);
            }
            if ($actor->turno_id) {
                $usersQuery->where('turno_id', $actor->turno_id);
            }
        }

        MapaPatrullasAccess::applySiniestrosGroupLeadScope($usersQuery, $actor);

        $userIds = $usersQuery->pluck('id');

        $latest = UserLocation::query()
            ->selectRaw('user_id, MAX(captured_at) AS max_captured_at')
            ->whereIn('user_id', $userIds)
            ->groupBy('user_id');

        $data = UserLocation::query()
            ->joinSub($latest, 'ul', function ($join) {
                $join->on('user_locations.user_id', '=', 'ul.user_id')
                    ->on('user_locations.captured_at', '=', 'ul.max_captured_at');
            })
            ->join('users', 'users.id', '=', 'user_locations.user_id')
            ->leftJoin('patrullas', 'patrullas.id', '=', 'users.patrulla_id')
            ->leftJoin('unidades', 'unidades.id', '=', 'users.unidad_id')
            ->leftJoin('turnos', 'turnos.id', '=', 'users.turno_id')
            ->orderByDesc('user_locations.captured_at')
            ->get([
                'user_locations.id',
                'user_locations.user_id',

                'users.name',
                'users.email',
                'users.patrulla_id',
                'users.unidad_id',
                'users.turno_id',
                'users.connection_status',
                'users.last_seen_at',

                'patrullas.numero_economico as patrulla_numero',
                'unidades.nombre as unidad_nombre',
                'turnos.nombre as turno_nombre',

                'user_locations.lat',
                'user_locations.lng',
                'user_locations.accuracy',
                'user_locations.speed',
                'user_locations.heading',
                'user_locations.captured_at',
            ]);

        $isSubdirector = $actor->hasRole('Subdirector');
        $isJefeGrupo = MapaPatrullasAccess::isSiniestrosGroupLead($actor);

        return response()->json([
            'data' => $data,
            'meta' => [
                'flags' => [
                    'is_subdirector' => $isSubdirector,
                    'is_jefe_grupo' => $isJefeGrupo,
                    'can_receive_disconnected_alerts' => false,
                ],
            ],
        ], 200);
    }

    private function canManageUser(User $actor, User $target): bool
    {
        if ($actor->unidad_id && (int)$target->unidad_id !== (int)$actor->unidad_id) {
            return false;
        }

        if (!MapaPatrullasAccess::canManageScopedUser($actor, $target)) {
            return false;
        }

        if ($actor->hasRole('Subdirector')) {
            return true;
        }

        if ($actor->turno_id && (int)$target->turno_id !== (int)$actor->turno_id) {
            return false;
        }

        return true;
    }

    private function trackingBlockedMessage(?string $reason): string
    {
        $messages = [
            'turno_descanso' => 'Ubicación desactivada: tu turno está en descanso.',
            'turno_sin_asignar' => 'Ubicación desactivada: no tienes un turno asignado.',
            'rol_no_autorizado_vialidades' => 'Ubicación desactivada: rol no autorizado para Vialidades Urbanas.',
        ];

        return $messages[$reason]
            ?? 'Ubicación desactivada (compartir_ubicacion=0). No se guardó.';
    }
}
