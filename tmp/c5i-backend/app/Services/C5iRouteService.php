<?php

namespace App\Services;

use App\Models\C5iServiceResponse;
use App\Models\User;
use App\Models\UserLocation;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class C5iRouteService
{
    public function record(User $user, array $point): ?UserLocation
    {
        if ((int) $user->unidad_id !== 1 || !Schema::hasTable('c5i_route_points')) {
            return null;
        }
        $user->loadMissing(['personal.patrulla', 'patrulla']);
        $patrol = optional($user->personal)->patrulla ?: $user->patrulla;
        // A buffered sample from a previous patrol must never be attributed to
        // the new patrol. Keep it unassigned if that association cannot be verified.
        $patrolId = $patrol && (int) $patrol->unidad_id === 1 ? $patrol->id : null;
        if (isset($point['patrulla_id']) && (int) $point['patrulla_id'] !== (int) $patrolId) {
            $patrolId = null;
        }
        $at = Carbon::parse($point['captured_at'])->timezone(config('app.timezone'));
        DB::table('c5i_route_points')->insertOrIgnore([
            'user_id' => $user->id, 'patrulla_id' => $patrolId,
            'lat' => $point['lat'], 'lng' => $point['lng'],
            'accuracy' => $point['accuracy'], 'captured_at' => $at,
            'received_at' => now(),
        ]);
        return $patrolId ? new UserLocation([
            'user_id' => $user->id, 'lat' => $point['lat'], 'lng' => $point['lng'],
            'accuracy' => $point['accuracy'], 'captured_at' => $at,
        ]) : null;
    }

    public function summary(C5iServiceResponse $response): array
    {
        $anchor = $response->arrival_reported_at ?: $response->gps_arrived_at ?: $response->reported_at;
        $start = $response->assigned_at ? $response->assigned_at->copy() : $anchor->copy()->subMinutes(30);
        $end = $response->arrival_reported_at ?: $response->gps_arrived_at ?: $start->copy()->addHours(4)->min(now());
        $next = C5iServiceResponse::query()->where('patrulla_id', $response->patrulla_id)
            ->where('id', '<>', $response->id)->where('assigned_at', '>', $start)
            ->min('assigned_at');
        if ($next) $end = $end->min(Carbon::parse($next));
        $points = collect();
        if ($response->patrulla_id && Schema::hasTable('c5i_route_points')) {
            $points = DB::table('c5i_route_points')->where('patrulla_id', $response->patrulla_id)
                ->whereBetween('captured_at', [$start, $end])->orderBy('captured_at')->orderBy('id')->get();
        }
        $radius = max(25, (int) config('services.whatsapp.c5i_response_time.arrival_radius_meters', 200));
        $maxAccuracy = max(1, (int) config('services.whatsapp.c5i_response_time.max_accuracy_meters', 100));
        $segments = []; $gaps = 0; $count = 0;
        foreach ($points->groupBy('user_id') as $userPoints) {
            $previous = null; $segment = [];
            foreach ($userPoints as $point) {
                if ($point->accuracy > $maxAccuracy) continue;
                $at = Carbon::parse($point->captured_at);
                if ($previous && $previous->diffInSeconds($at) > 120) {
                    if ($segment) $segments[] = $segment;
                    $segment = []; $gaps++;
                }
                $segment[] = ['lat' => (float) $point->lat, 'lng' => (float) $point->lng,
                    'at' => $at->toIso8601String(), 'accuracy' => (float) $point->accuracy,
                    'inside' => self::distance($response->incident_lat, $response->incident_lng, $point->lat, $point->lng) <= $radius];
                $previous = $at; $count++;
            }
            if ($segment) $segments[] = $segment;
        }
        return ['start' => $start->toIso8601String(), 'end' => $end->toIso8601String(),
            'fallback' => !$response->assigned_at, 'segments' => $segments,
            'point_count' => $count, 'gaps' => $gaps];
    }

    public static function distance($lat1, $lng1, $lat2, $lng2): float
    {
        $a = sin(deg2rad($lat2 - $lat1) / 2) ** 2 + cos(deg2rad($lat1))
            * cos(deg2rad($lat2)) * sin(deg2rad($lng2 - $lng1) / 2) ** 2;
        return 6371008.8 * 2 * atan2(sqrt($a), sqrt(max(0, 1 - $a)));
    }
}
