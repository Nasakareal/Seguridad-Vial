<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <style>
        @page { margin: 34px; }
        body { font-family: DejaVu Sans, sans-serif; color: #172033; font-size: 10px; }
        h1 { margin: 0; color: #0b3558; font-size: 20px; }
        h2 { margin: 18px 0 7px; color: #0b3558; font-size: 13px; border-bottom: 1px solid #aebbc5; padding-bottom: 4px; }
        .meta { color: #526071; margin: 4px 0 16px; }
        .badge { display: inline-block; background: #e1f1f3; color: #08636c; padding: 4px 8px; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; }
        td { border: 1px solid #d8e0e6; padding: 7px; vertical-align: top; }
        td.label { width: 22%; background: #eef3f7; font-weight: bold; }
        .notice { margin-top: 22px; padding: 10px; background: #fff8e6; border: 1px solid #efd79c; }
        .signatures { margin-top: 50px; }
        .signature { width: 45%; display: inline-block; text-align: center; border-top: 1px solid #222; padding-top: 5px; }
        .right { float: right; }
    </style>
</head>
<body>
    <h1>Memoria descriptiva del servicio de grúa</h1>
    <div class="meta">
        {{ optional($grua)->nombre ?: 'Grúa no especificada' }} ·
        Generado {{ $generado->format('d/m/Y H:i') }}
    </div>

    <span class="badge">{{ data_get($item, 'origen.etiqueta', 'Sin clasificar') }}</span>

    <h2>Origen del servicio</h2>
    <table>
        <tr><td class="label">Referencia</td><td>{{ data_get($item, 'origen.id', 'N/A') ?: 'N/A' }}</td></tr>
        <tr><td class="label">Folio</td><td>{{ data_get($item, 'origen.folio', 'N/A') ?: 'N/A' }}</td></tr>
        <tr><td class="label">Fecha</td><td>{{ data_get($item, 'origen.fecha', 'N/A') ?: 'N/A' }}</td></tr>
        <tr><td class="label">Lugar</td><td>{{ data_get($item, 'origen.lugar', 'N/A') ?: 'N/A' }}</td></tr>
        <tr><td class="label">Motivo / tipo</td><td>{{ data_get($item, 'origen.detalle', 'N/A') ?: 'N/A' }}</td></tr>
    </table>

    <h2>Vehículo e ingreso al corralón</h2>
    <table>
        <tr><td class="label">Vehículo</td><td>{{ trim(($item['marca'] ?? '') . ' ' . ($item['linea'] ?? '')) ?: 'N/A' }}</td></tr>
        <tr><td class="label">Placas</td><td>{{ $item['placas'] ?: 'Sin placas' }}</td></tr>
        <tr><td class="label">NIV</td><td>{{ $item['serie'] ?: 'N/A' }}</td></tr>
        <tr><td class="label">Modelo / color</td><td>{{ $item['modelo'] ?: 'N/A' }} / {{ $item['color'] ?: 'N/A' }}</td></tr>
        <tr><td class="label">Inventario</td><td>{{ $item['numero_inventario_grua'] ?: 'N/A' }}</td></tr>
        <tr><td class="label">Corralón</td><td>{{ $item['corralon'] ?: 'N/A' }}</td></tr>
        <tr><td class="label">Fecha del servicio</td><td>{{ $item['fecha_servicio'] ?: 'N/A' }}</td></tr>
    </table>

    <h2>Actuación de la grúa</h2>
    <table>
        <tr>
            <td class="label">Realizó maniobras</td>
            <td>{{ data_get($item, 'servicio.realizo_maniobras') === null ? 'Sin capturar' : (data_get($item, 'servicio.realizo_maniobras') ? 'Sí' : 'No') }}</td>
        </tr>
        <tr><td class="label">Descripción</td><td>{{ data_get($item, 'servicio.maniobras_descripcion', 'Sin capturar') ?: 'Sin capturar' }}</td></tr>
        <tr><td class="label">Observaciones</td><td>{{ data_get($item, 'servicio.observaciones_grua', 'Sin observaciones') ?: 'Sin observaciones' }}</td></tr>
    </table>

    <h2>Entrega / liberación</h2>
    <table>
        <tr><td class="label">Estado</td><td>{{ $item['estado'] === 'ENTREGADO' ? 'Entregado' : 'En corralón' }}</td></tr>
        <tr><td class="label">Folio SIERSE</td><td>{{ data_get($item, 'liberacion.sierse_folio', 'Pendiente') ?: 'Pendiente' }}</td></tr>
        <tr><td class="label">Persona que recibe</td><td>{{ data_get($item, 'liberacion.persona_recibe', 'Pendiente') ?: 'Pendiente' }}</td></tr>
        <tr><td class="label">Fecha de entrega</td><td>{{ data_get($item, 'liberacion.fecha_entrega', 'Pendiente') ?: 'Pendiente' }}</td></tr>
        <tr><td class="label">Condición</td><td>{{ data_get($item, 'liberacion.condicion_entrega', 'Pendiente') ?: 'Pendiente' }}</td></tr>
        <tr><td class="label">Observaciones</td><td>{{ data_get($item, 'liberacion.observaciones', 'Sin observaciones') ?: 'Sin observaciones' }}</td></tr>
    </table>

    <div class="notice">
        Documento de trazabilidad generado con la información capturada en el sistema.
        Los datos pendientes deben completarse antes del cierre definitivo del servicio.
    </div>

    <div class="signatures">
        <div class="signature">Responsable de la grúa</div>
        <div class="signature right">Persona que recibe</div>
    </div>
</body>
</html>
