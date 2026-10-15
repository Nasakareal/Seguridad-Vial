<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 22px; }
        body { font-family: DejaVu Sans, sans-serif; color: #172033; font-size: 9px; }
        h1 { margin: 0 0 4px; font-size: 18px; color: #0b3558; }
        .meta { color: #526071; margin-bottom: 14px; }
        .summary { width: 100%; margin-bottom: 14px; border-spacing: 6px; }
        .summary td { background: #eef4f8; border-radius: 5px; padding: 8px; text-align: center; }
        .summary strong { display: block; color: #0b6b73; font-size: 16px; }
        table.data { width: 100%; border-collapse: collapse; }
        table.data th { background: #0b3558; color: white; padding: 6px 4px; }
        table.data td { border-bottom: 1px solid #dce3e8; padding: 5px 4px; vertical-align: top; }
        table.data tr:nth-child(even) { background: #f7f9fb; }
        .status { font-weight: bold; color: #0b6b73; }
    </style>
</head>
<body>
    <h1>Servicios de corralón · {{ optional($grua)->nombre ?: 'Grúa' }}</h1>
    <div class="meta">
        Estado: {{ $estado === 'entregados' ? 'Entregados' : 'En corralón' }} ·
        Generado: {{ $generado->format('d/m/Y H:i') }} ·
        Registros: {{ $items->count() }}
    </div>

    <table class="summary">
        <tr>
            <td><strong>{{ $summary['pendientes'] }}</strong>En corralón</td>
            <td><strong>{{ $summary['entregados_hoy'] }}</strong>Entregados hoy</td>
            <td><strong>{{ $summary['entregados_mes'] }}</strong>Entregados este mes</td>
            <td><strong>{{ $summary['total_entregados'] }}</strong>Total entregados</td>
        </tr>
    </table>

    <table class="data">
        <thead>
            <tr>
                <th>Estado</th><th>Origen</th><th>Placas</th><th>NIV</th><th>Vehículo</th>
                <th>Inventario</th><th>Fecha servicio</th><th>Maniobras</th><th>Entrega</th>
                <th>Recibió</th><th>SIERSE</th><th>Observaciones</th>
            </tr>
        </thead>
        <tbody>
            @forelse($items as $item)
                <tr>
                    <td class="status">{{ $item['estado'] }}</td>
                    <td>{{ data_get($item, 'origen.etiqueta', 'Sin clasificar') }}</td>
                    <td>{{ $item['placas'] ?: 'S/P' }}</td>
                    <td>{{ $item['serie'] ?: 'N/A' }}</td>
                    <td>{{ trim(($item['marca'] ?? '') . ' ' . ($item['linea'] ?? '')) }}<br>{{ $item['modelo'] }} · {{ $item['color'] }}</td>
                    <td>{{ $item['numero_inventario_grua'] ?: 'N/A' }}</td>
                    <td>{{ $item['fecha_servicio'] ?: 'N/A' }}</td>
                    <td>
                        {{ data_get($item, 'servicio.realizo_maniobras') === null ? 'Sin capturar' : (data_get($item, 'servicio.realizo_maniobras') ? 'Sí' : 'No') }}
                        @if(data_get($item, 'servicio.maniobras_descripcion'))<br>{{ data_get($item, 'servicio.maniobras_descripcion') }}@endif
                    </td>
                    <td>{{ data_get($item, 'liberacion.fecha_entrega', 'N/A') ?: 'N/A' }}</td>
                    <td>{{ data_get($item, 'liberacion.persona_recibe', 'N/A') ?: 'N/A' }}</td>
                    <td>{{ data_get($item, 'liberacion.sierse_folio', 'N/A') ?: 'N/A' }}</td>
                    <td>{{ data_get($item, 'liberacion.observaciones', '') ?: 'Sin observaciones' }}</td>
                </tr>
            @empty
                <tr><td colspan="12" style="text-align:center;padding:18px;">Sin registros</td></tr>
            @endforelse
        </tbody>
    </table>
</body>
</html>
