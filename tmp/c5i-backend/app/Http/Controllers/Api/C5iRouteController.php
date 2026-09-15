<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\C5iRouteService;
use App\Services\C5iResponseTimeService;
use App\Services\LocationTrackingEligibilityService;
use Carbon\Carbon;
use Illuminate\Http\Request;

class C5iRouteController extends Controller
{
    public function store(Request $request, C5iRouteService $routes,
        C5iResponseTimeService $responses, LocationTrackingEligibilityService $eligibility)
    {
        $user = $request->user();
        abort_unless((int) $user->unidad_id === 1, 403);
        abort_unless(\Illuminate\Support\Facades\Schema::hasTable('c5i_route_points'), 503);
        $data = $request->validate([
            'points' => 'required|array|min:1|max:200',
            'points.*.lat' => 'required|numeric|between:-90,90',
            'points.*.lng' => 'required|numeric|between:-180,180',
            'points.*.accuracy' => 'required|numeric|between:0,100',
            'points.*.captured_at' => 'required|date|before_or_equal:now',
            'points.*.patrulla_id' => 'nullable|integer|min:1',
        ]);
        $points = $data['points'];
        usort($points, function ($a, $b) {
            return Carbon::parse($a['captured_at'])->getTimestamp() <=> Carbon::parse($b['captured_at'])->getTimestamp();
        });
        $stored = 0;
        foreach ($points as $point) {
            // Evaluate the shift at capture time, not at upload time.
            $status = $eligibility->statusForUser($user, Carbon::parse($point['captured_at']));
            if (!$status['allowed']) continue;
            $location = $routes->record($user, $point);
            if ($location) $responses->processLocation($user, $location);
            $stored++;
        }
        return response()->json(['acknowledged' => count($points), 'stored' => $stored,
            'discarded_ineligible' => count($points) - $stored]);
    }
}
