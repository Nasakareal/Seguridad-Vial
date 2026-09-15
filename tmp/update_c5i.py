from pathlib import Path
root = Path(__file__).parent / 'c5i-backend'
p = root / 'app/Services/C5iResponseTimeService.php'
s = p.read_text(encoding='utf-8')
def replace(old, new):
    global s
    assert old in s, old[:120]
    s = s.replace(old, new)
replace("use Illuminate\\Support\\Facades\\Log;", "use Illuminate\\Support\\Facades\\Log;\nuse Illuminate\\Support\\Facades\\DB;\nuse Illuminate\\Support\\Facades\\Schema;")
replace("        $response = C5iServiceResponse::query()->updateOrCreate(", "        // Replaying an incident must preserve its assignment and arrival.\n        $response = C5iServiceResponse::query()->firstOrCreate(")
replace("        $response->forceFill([\n            'assignment_message_id'", "        if ($response->assignment_message_id || $response->arrival_message_id) {\n            return ['status' => 'ignored', 'reason' => 'already_assigned_or_complete'];\n        }\n\n        $response->forceFill([\n            'assignment_message_id'")
replace("        return [\n            'status' => 'assigned',", "        $this->reconcileHistory($response->fresh());\n\n        return [\n            'status' => 'assigned',")
replace("        $arrivalAt = ($message->sent_at", "        if ($response->arrival_message_id) {\n            return ['status' => 'ignored', 'reason' => 'arrival_already_recorded'];\n        }\n        // A quoted incident can establish the patrol even without an assignment.\n        $response->forceFill(['patrulla_id' => $patrulla->id])->save();\n        $this->reconcileHistory($response);\n        $response->refresh();\n\n        $arrivalAt = ($message->sent_at")
replace("            ->whereNull('gps_arrived_at')\n            ->whereNotNull('assigned_at')", "            ->where(function ($query) use ($capturedAt) {\n                $query->whereNull('gps_arrived_at')->orWhere('gps_arrived_at', '>', $capturedAt);\n            })\n            ->where(function ($query) use ($capturedAt) {\n                $query->whereNull('assigned_at')->orWhere('assigned_at', '<=', $capturedAt);\n            })")
replace("        foreach ($responses as $response) {\n            $distance", "        foreach ($responses as $response) {\n            // A later pass by the scene is not evidence of the original arrival.\n            if ($response->arrival_reported_at && $capturedAt->gt($response->arrival_reported_at)) continue;\n            $distance")
replace("                if ($quotedResponse\n                    &&", "                if ($quotedResponse\n                    && (int) $quotedResponse->whatsapp_web_group_id === (int) $message->whatsapp_web_group_id\n                    && $quotedResponse->reported_at->lte($message->sent_at ?: now())\n                    &&")
replace("            $query->whereNull('assignment_message_id');", "            $query->whereNull('assignment_message_id')->whereNull('arrival_message_id');")
replace("            $query->where('patrulla_id', $patrulla->id)\n                ->whereNotNull('assignment_message_id')", "            $query->where('patrulla_id', $patrulla->id)")
replace("        return $query->latest('reported_at')->first();", "        $matches = $query->latest('reported_at')->limit(2)->get();\n        // Do not attach an arrival to an arbitrary service if several are open.\n        if (!$forAssignment && $matches->count() > 1) return null;\n        return $matches->first();")
replace("            ->where('activa', 1)\n            ->whereHas", "            ->where('activa', 1)\n            ->where('unidad_id', 1)\n            ->whereHas")
replace("            if (mb_strtolower((string) optional($personal->unidad)->slug, 'UTF-8') !== 'siniestros')", "            if ((int) $personal->unidad_id !== 1)")
replace("        return (int) $user->unidad_id === 1\n            || mb_strtolower((string) optional($user->unidad)->slug, 'UTF-8') === 'siniestros';", "        return (int) $user->unidad_id === 1;")
replace("                . '; C5i → audio: ' . $this->humanDuration($reactionSeconds)\n                . '; asignación → audio: '", "                . '; C5i → ' . ($response->arrival_source === 'audio_transcription' ? 'audio' : 'mensaje') . ': ' . $this->humanDuration($reactionSeconds)\n                . '; asignación → ' . ($response->arrival_source === 'audio_transcription' ? 'audio' : 'mensaje') . ': '")
replace("        return [\n            $response->incident_reference", "        $route = app(C5iRouteService::class)->summary($response);\n        $gpsDetail .= '; permanencia observada: ' . $this->humanDuration($route['observed_dwell_seconds'])\n            . ($route['point_count'] ? ' (estimada entre muestras; los huecos no se cuentan)' : ' (sin muestras)')\n            . '; ruta y detalle: ' . route('c5i.responses.show', ['response' => $response->id]);\n\n        return [\n            $response->incident_reference")
replace("        return (bool) preg_match(\n            '/(?:^|\\s)86", "        // K8 acknowledgements used by dispatch are arrival confirmations.\n        if (preg_match('/\\bR\\s*10\\s+(?:COMANDO\\s+)?GRACIAS\\s+POR\\s+(?:EL\\s+)?K\\s*8\\b/u', $text)) {\n            return true;\n        }\n        return (bool) preg_match(\n            '/(?:^|\\s)86")
anchor = '    private function responseForMessage('
method = '''    private function reconcileHistory(C5iServiceResponse $response): void
    {
        if (!$response->patrulla_id || !Schema::hasTable('c5i_route_points')) return;
        $start = $response->assigned_at ?: $response->reported_at;
        $end = $response->arrival_reported_at ?: $start->copy()->addMinutes(240)->min(now());
        $patrol = $response->patrulla;
        if (!$patrol) return;
        $points = DB::table('c5i_route_points')->where('patrulla_id', $patrol->id)
            ->whereBetween('captured_at', [$start, $end])->orderBy('captured_at')->get();
        foreach ($points as $point) {
            $this->registerGpsArrival($patrol, new UserLocation([
                'user_id' => $point->user_id, 'lat' => $point->lat, 'lng' => $point->lng,
                'accuracy' => $point->accuracy, 'captured_at' => $point->captured_at,
            ]));
        }
    }

'''
replace(anchor, method + anchor)
p.write_text(s, encoding='utf-8')
p = root / 'routes/api.php'
s = p.read_text(encoding='utf-8').replace("    Route::post('/location',", "    Route::post('/location/response-route', [\\App\\Http\\Controllers\\Api\\C5iRouteController::class, 'store']);\n    Route::post('/location',")
p.write_text(s, encoding='utf-8')
p = root / 'routes/web.php'
s = p.read_text(encoding='utf-8') + "\nRoute::get('/c5i/tiempos/{response}', [\\App\\Http\\Controllers\\C5iResponseReportController::class, 'show'])->middleware('auth')->name('c5i.responses.show');\n"
p.write_text(s, encoding='utf-8')
# Preserve old clients' samples before the stale-position check, without moving
# the current marker backwards. Batch uploads are entirely separate from it.
p = root / 'app/Http/Controllers/Api/LocationController.php'
s = p.read_text(encoding='utf-8')
needle = '        $currentLocation = UserLocation::query()'
assert needle in s
s = s.replace(needle, '''        if ((int) $user->unidad_id === 1 && isset($validated['accuracy'])
            && $validated['accuracy'] <= 100 && $capturedAt->lte(now())
            && $trackingEligibility->statusForUser($user, $capturedAt)['allowed']) {
            $history = app(\\App\\Services\\C5iRouteService::class)->record($user, [
                'lat' => $validated['lat'], 'lng' => $validated['lng'],
                'accuracy' => $validated['accuracy'], 'captured_at' => $capturedAt->toIso8601String(),
            ]);
            if ($history) $responseTime->processLocation($user, $history);
        }

''' + needle)
p.write_text(s, encoding='utf-8')
