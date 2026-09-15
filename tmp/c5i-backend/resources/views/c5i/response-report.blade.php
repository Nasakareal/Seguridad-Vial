<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Tiempo de reacción · {{ $response->patrulla->numero_economico }}</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <style>
        *{box-sizing:border-box}body{margin:0;background:#f3f6fa;color:#142a40;font:16px system-ui,sans-serif}
        main{max-width:1100px;margin:auto;padding:24px}h1{font-size:28px;margin:8px 0}h2{font-size:19px}
        .muted{color:#516579}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px;margin:24px 0}
        .card,section{background:white;border:1px solid #dae3eb;border-radius:12px;padding:18px}.card strong{display:block;font-size:21px;margin-top:8px}
        #map{height:460px;border-radius:10px;background:#e3ebf2}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:10px;border-bottom:1px solid #e3ebf2}
        .table-wrap{overflow:auto;max-height:360px}a{color:#065fb7}.notice{background:#fff3d6;padding:14px;border-radius:8px}section{margin-bottom:18px}
    </style>
</head>
<body><main>
    <p class="muted">ESINIESTROS · UNIDAD 1</p>
    <h1>Tiempo de reacción · {{ $response->patrulla->numero_economico }}</h1>
    <p>{{ $response->incident_reference }} · {{ $response->incident_location }}</p>
    @php
        $zone = 'America/Mexico_City';
        $incidentPoint = [(float) $response->incident_lat, (float) $response->incident_lng];
        $radius = max(25, (int) config('services.whatsapp.c5i_response_time.arrival_radius_meters', 200));
        $date = function ($value) use ($zone) { return $value ? \Carbon\Carbon::parse($value)->timezone($zone)->format('d/m/Y H:i:s') : 'Sin registro'; };
        $duration = function ($seconds) { return $seconds === null ? 'Sin registro' : intdiv($seconds, 60).' min '.($seconds % 60).' s'; };
    @endphp
    <div class="cards">
        <div class="card">C5i → primera muestra en el lugar<strong>{{ $duration($response->report_to_gps_seconds) }}</strong></div>
        <div class="card">Asignación → primera muestra en el lugar<strong>{{ $duration($response->assignment_to_gps_seconds) }}</strong></div>
    </div>
    <section><h2>Registro del servicio</h2>
        <p>Reporte C5i: <b>{{ $date($response->reported_at) }}</b><br>
        Asignación: <b>{{ $date($response->assigned_at) }}</b><br>
        Llegada GPS: <b>{{ $date($response->gps_arrived_at) }}</b><br>
        Llegada por {{ $response->arrival_source === 'audio_transcription' ? 'audio transcrito' : 'mensaje' }}: <b>{{ $date($response->arrival_reported_at) }}</b></p>
    </section>
    <section><h2>Recorrido registrado</h2>
        <p>{{ $date($routeData['start']) }} — {{ $date($routeData['end']) }}</p>
        @if($routeData['fallback'])<p class="notice">Sin hora de asignación: se muestran los 30 minutos anteriores al aviso de llegada; si falta ese aviso, se usa la llegada GPS o el reporte C5i como referencia.</p>@endif
        <p>{{ $routeData['point_count'] }} muestras · {{ $routeData['gaps'] }} interrupciones. Se muestra el recorrido hasta el aviso de llegada, la llegada GPS o el momento actual si el servicio sigue abierto.</p>
        @if(!$routeData['point_count'])<p class="notice">No hay recorrido GPS guardado para este periodo. Los mensajes de WhatsApp no permiten reconstruirlo.</p>@endif
        <div id="map" aria-label="Mapa del recorrido registrado"></div>
        <p class="muted">Azul: muestras consecutivas. Los tramos con más de 2 minutos sin datos se separan. El círculo marca el radio del lugar; las líneas unen muestras y no representan una ruta calculada por calles.</p>
        <a href="{{ route('c5i.responses.show', ['response' => $response->id]) }}">Actualizar con las ubicaciones sincronizadas</a>
    </section>
    <section><h2>Muestras GPS</h2><div class="table-wrap"><table><thead><tr><th>Hora</th><th>Coordenadas</th><th>Precisión</th><th>En el radio</th></tr></thead><tbody>
        @foreach($routeData['segments'] as $segment)@foreach($segment as $point)
            <tr><td>{{ $date($point['at']) }}</td><td>{{ $point['lat'] }}, {{ $point['lng'] }}</td><td>{{ $point['accuracy'] }} m</td><td>{{ $point['inside'] ? 'Sí' : 'No' }}</td></tr>
        @endforeach @endforeach
    </tbody></table></div></section>
</main>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
const data = @json($routeData);
const incident = @json($incidentPoint);
const map = L.map('map').setView(incident, 15);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {maxZoom:19, attribution:'© OpenStreetMap contributors'}).addTo(map);
L.circle(incident, {radius: @json($radius), color:'#b64c21'}).addTo(map).bindPopup('Lugar del servicio');
const bounds = [incident];
for (const segment of data.segments) {
    L.polyline(segment.map(p => [p.lat,p.lng]), {color:'#146ac1',weight:4}).addTo(map);
    for (const point of segment) {
        bounds.push([point.lat,point.lng]);
        const label = document.createElement('span');
        label.textContent = new Date(point.at).toLocaleString('es-MX',{timeZone:'America/Mexico_City'}) + ' · precisión '+point.accuracy+' m';
        L.circleMarker([point.lat,point.lng], {radius:3,color:point.inside?'#14774a':'#146ac1'}).addTo(map).bindPopup(label);
    }
}
if (bounds.length > 1) map.fitBounds(bounds, {padding:[25,25],maxZoom:17});
</script></body></html>
