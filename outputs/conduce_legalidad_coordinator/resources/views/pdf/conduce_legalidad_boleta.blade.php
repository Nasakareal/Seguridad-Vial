<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <title>Boleta {{ $boleta['folio'] }}</title>
    <style>
        @page { margin: 16px 28px; }
        body { font-family: DejaVu Sans, sans-serif; color: #111827; font-size: 9px; line-height: 1.22; }
        h1, h2, p { margin: 0; }
        .header { text-align: center; margin-bottom: 7px; }
        .header h1 { font-size: 13px; }
        .header h2 { font-size: 10px; margin-top: 2px; }
        .title { font-size: 15px; font-weight: 700; margin-top: 6px; }
        .subtitle { font-size: 11px; font-weight: 700; margin-top: 2px; }
        .section { border-top: 1px solid #4b5563; margin-top: 6px; padding-top: 4px; }
        .section-title { font-size: 10px; font-weight: 700; margin-bottom: 3px; }
        table { width: 100%; border-collapse: collapse; }
        td { vertical-align: top; padding: 2px 5px 2px 0; }
        .label { color: #4b5563; font-size: 7px; text-transform: uppercase; }
        .value { font-weight: 600; }
        .block { margin: 3px 0; }
        .signature { margin-top: 18px; border-top: 1px solid #111827; width: 48%; text-align: center; padding-top: 2px; }
        .leadership { margin-top: 3px; padding: 5px 7px; border-left: 3px solid #111827; background: #f3f4f6; }
        .leadership-item + .leadership-item { margin-top: 5px; }
        .leadership-label { color: #4b5563; font-size: 7px; text-transform: uppercase; letter-spacing: .03em; }
        .leadership-name { margin-top: 1px; font-size: 9px; font-weight: 700; }
        .notice { margin-top: 7px; padding: 5px; background: #f3f4f6; font-size: 7px; }
        .sample { margin: 0 0 7px; padding: 5px; border: 1px solid #b91c1c; color: #b91c1c; text-align: center; font-weight: 700; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SECRETARÍA DE SEGURIDAD PÚBLICA</h1>
        <h2>COORDINACIÓN DEL AGRUPAMIENTO DE SEGURIDAD VIAL</h2>
        <div class="title">BOLETA DE NOTIFICACIÓN</div>
        <div class="subtitle">OPERATIVO CONDUCE CON LEGALIDAD</div>
    </div>
    @if (!empty($boleta['es_muestra']))
        <div class="sample">SAMPLE DOCUMENT FOR META REVIEW - NO REAL PERSONAL DATA</div>
    @endif

    <table>
        <tr>
            <td><div class="label">Folio</div><div class="value">{{ $boleta['folio'] }}</div></td>
            <td><div class="label">Municipio</div><div class="value">{{ $boleta['municipio'] }}</div></td>
            <td><div class="label">Fecha</div><div class="value">{{ $boleta['fecha'] }}</div></td>
            <td><div class="label">Hora</div><div class="value">{{ $boleta['hora'] }}</div></td>
        </tr>
    </table>
    <div class="block"><div class="label">Lugar</div><div class="value">{{ $boleta['lugar'] }}</div></div>

    <div class="section">
        <div class="section-title">I. FUNDAMENTO JURÍDICO</div>
        <div class="block"><div class="label">Artículo(s) infringido(s)</div><div>{{ $boleta['fundamento'] }}</div></div>
        <div class="block"><div class="label">Los cuales ameritan</div><div>{{ $boleta['sancion'] }}</div></div>
    </div>

    <div class="section">
        <div class="section-title">II. MOTIVACIÓN</div>
        <div class="block"><div class="label">Descripción breve de la conducta</div><div>{{ $boleta['conducta'] }}</div></div>
    </div>

    <div class="section">
        <div class="section-title">PERSONA INFRACTORA</div>
        <table>
            <tr>
                <td><div class="label">Nombre</div><div class="value">{{ $boleta['persona_nombre'] }}</div></td>
                <td><div class="label">Domicilio</div><div class="value">{{ $boleta['persona_domicilio'] }}</div></td>
            </tr>
        </table>
    </div>

    <div class="section">
        <div class="section-title">VEHÍCULO</div>
        <div class="block"><div class="label">Descripción</div><div>{{ $boleta['vehiculo_resumen'] }}</div></div>
        <table>
            <tr>
                <td><div class="label">Placas/permiso</div><div class="value">{{ $boleta['placas'] }}</div></td>
                <td><div class="label">Estado placas</div><div class="value">{{ $boleta['estado_placas'] }}</div></td>
                <td><div class="label">Número de inventario</div><div class="value">{{ $boleta['numero_inventario'] }}</div></td>
            </tr>
            <tr>
                <td colspan="2"><div class="label">Corralón de destino</div><div class="value">{{ $boleta['corralon'] }}</div></td>
                <td><div class="label">Grúa</div><div class="value">{{ $boleta['grua'] }}</div></td>
            </tr>
        </table>
    </div>

    @if ($boleta['requiere_liberacion'])
        <div class="section">
            <div class="section-title">LIBERACIÓN DEL VEHÍCULO</div>
            <div>{{ $boleta['liberacion'] }}</div>
        </div>
    @endif

    <div class="section">
        <div class="section-title">LICENCIA O PERMISO</div>
        <div>{{ $boleta['licencia'] }}</div>
    </div>

    <div class="section">
        <div class="section-title">FIRMA Y MANIFESTACIÓN</div>
        <div class="signature">Firma de la persona infractora</div>
        <div class="block" style="margin-top: 8px;"><div class="label">Manifestación de inconformidad (opcional)</div><br></div>
    </div>

    <div class="section">
        <div class="section-title">RESPONSABLES DEL OPERATIVO</div>
        <div class="leadership">
            <div class="leadership-item">
                <div class="leadership-label">{{ $boleta['coordinador_cargo'] }}</div>
                <div class="leadership-name">{{ $boleta['coordinador_nombre'] }}</div>
            </div>
            <div class="leadership-item">
                <div class="leadership-label">Supervisión operativa</div>
                <div class="leadership-name">{{ $boleta['supervisor_nombre'] }}</div>
                <div>{{ $boleta['supervisor_cargo'] }}</div>
            </div>
        </div>
    </div>

    <div class="section">
        <div class="section-title">AGENTE</div>
        <table>
            <tr>
                <td><div class="label">Nombre</div><div class="value">{{ $boleta['agente_nombre'] }}</div></td>
                <td><div class="label">No. placa</div><div class="value">{{ $boleta['agente_placa'] }}</div></td>
            </tr>
        </table>
        <div class="block"><div class="label">Adscripción</div><div class="value">{{ $boleta['adscripcion'] }}</div></div>
        <div class="signature">Firma autógrafa/electrónica</div>
    </div>

    <div class="notice">
        Documento generado por el sistema institucional. La copia enviada por WhatsApp contiene la información registrada en la boleta al momento del envío.
    </div>
</body>
</html>
