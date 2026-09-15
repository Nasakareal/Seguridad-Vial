<?php

namespace App\Http\Controllers;

use App\Models\C5iServiceResponse;
use App\Models\User;
use App\Services\C5iRouteService;
use App\Support\MapaPatrullasAccess;
use Illuminate\Http\Request;

class C5iResponseReportController extends Controller
{
    public function show(Request $request, C5iServiceResponse $response, C5iRouteService $routes)
    {
        $actor = $request->user();
        abort_unless((int) $actor->unidad_id === 1, 403);
        $response->loadMissing('patrulla');
        abort_unless($response->patrulla && (int) $response->patrulla->unidad_id === 1, 404);
        $actor->loadMissing('personal');
        $ownPatrol = optional($actor->personal)->patrulla_id ?: $actor->patrulla_id;
        $allowed = (int) $ownPatrol === (int) $response->patrulla_id;
        if (!$allowed && $actor->can('ver mapa')) {
            $targets = User::query()->where('unidad_id', 1)
                ->where(function ($query) use ($response) {
                    $query->where('patrulla_id', $response->patrulla_id)
                        ->orWhereHas('personal', function ($personal) use ($response) {
                            $personal->where('patrulla_id', $response->patrulla_id);
                        });
                });
            MapaPatrullasAccess::applySiniestrosGroupLeadScope($targets, $actor);
            $allowed = $targets->exists();
        }
        abort_unless($allowed, 403);
        return response()->view('c5i.response-report', [
            'response' => $response, 'routeData' => $routes->summary($response),
        ])->header('Cache-Control', 'private, no-store');
    }
}
