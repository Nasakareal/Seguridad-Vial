from pathlib import Path
r = Path(__file__).parent/'c5i-backend'
p=r/'app/Services/C5iResponseTimeService.php'
s=p.read_text(encoding='utf-8')
s=s.replace("        // K8 acknowledgements used by dispatch are arrival confirmations.\n        if (preg_match('/\\bR\\s*10\\s+(?:COMANDO\\s+)?GRACIAS\\s+POR\\s+(?:EL\\s+)?K\\s*8\\b/u', $text)) {\n            return true;\n        }\n", '')
a=s.index('        $route = app(C5iRouteService::class)->summary($response);')
b=s.index('\n        return [',a)
s=s[:a]+"        $gpsDetail .= '; ruta registrada: ' . route('c5i.responses.show', ['response' => $response->id]);\n"+s[b:]
s=s.replace("        $this->reconcileHistory($response);\n        $response->refresh();\n",'')
needle="        $this->notifyIfComplete($response->fresh(['patrulla']));"
s=s.replace(needle,"        $this->reconcileHistory($response->fresh());\n"+needle,1)
# PM256 is another agency's unit, not the reporting patrol. Prefer the
# operational author's verified patrol for arrivals without an explicit own-unit cue.
s=s.replace("        $patrulla = $this->resolvePatrulla($body, $author);", """        $patrulla = $this->resolvePatrulla($body, $author);
        if ($this->hasArrivalCue($normalized) && !$this->hasUnitReportCue($normalized)) {
            $authorPatrol = $this->patrullaFromAuthor($author);
            $patrulla = $authorPatrol ?: $this->patrullaFromText($body);
        }""")
s=s.replace("        $unitSlug = trim((string) config(", "        // Ignore external police units and phone/coordinate numbers embedded in reports.\n        $body = preg_replace('/\\bPM\\s*[-:]?\\s*\\d+\\b/iu', ' ', $body) ?? $body;\n        $unitSlug = trim((string) config(",1)
# Resolve users linked via personal as well as directly assigned patrols.
s=s.replace("            ->whereNotNull('patrulla_id')\n            ->with(['unidad', 'patrulla'])", "            ->where(function ($query) {\n                $query->whereNotNull('patrulla_id')->orWhereHas('personal', function ($personal) {\n                    $personal->whereNotNull('patrulla_id');\n                });\n            })\n            ->with(['unidad', 'patrulla', 'personal.patrulla'])")
s=s.replace('                return $user->patrulla;', '                return optional($user->personal)->patrulla ?: $user->patrulla;')
# Ambiguous unmatched services stay unresolved instead of inventing an assignment.
needle="        // Do not attach an arrival to an arbitrary service if several are open."
s=s.replace(needle,"""        if (!$forAssignment && $matches->isEmpty()) {
            $matches = C5iServiceResponse::query()
                ->where('whatsapp_web_group_id', $message->whatsapp_web_group_id)
                ->whereNull('patrulla_id')->whereNull('arrival_message_id')
                ->whereBetween('reported_at', [
                    ($message->sent_at ?: now())->copy()->subMinutes($lookbackMinutes),
                    $message->sent_at ?: now(),
                ])->latest('reported_at')->limit(2)->get();
        }
"""+needle)
p.write_text(s,encoding='utf-8')
p=r/'app/Services/C5iRouteService.php'
s=p.read_text(encoding='utf-8')
s=s.replace("        $end = $anchor->copy()->addHours(4)->min(now());", "        $end = $response->arrival_reported_at ?: $response->gps_arrived_at ?: now();")
a=s.index('        $maxAccuracy = ')
b=s.index('\n    public static function distance',a)
s=s[:a]+'''        $maxAccuracy = max(1, (int) config('services.whatsapp.c5i_response_time.max_accuracy_meters', 100));
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
''' + s[b:]
p.write_text(s,encoding='utf-8')
p=r/'resources/views/c5i/response-report.blade.php'
s=p.read_text(encoding='utf-8')
s='\n'.join(line for line in s.splitlines() if not any(x in line for x in ['Permanencia observada','Primera salida observada','Última muestra en el lugar','La permanencia es']))
s=s.replace("{{ $date($response->arrival_reported_at) }}</b><br>","{{ $date($response->arrival_reported_at) }}</b></p>")
s=s.replace('Se muestran hasta 4 horas después de la llegada o hasta la siguiente asignación.', 'Se muestra el recorrido hasta el aviso de llegada, la llegada GPS o el momento actual si el servicio sigue abierto.')
p.write_text(s,encoding='utf-8')
