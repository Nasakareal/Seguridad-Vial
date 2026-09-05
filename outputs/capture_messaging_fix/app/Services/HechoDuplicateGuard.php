<?php

namespace App\Services;

use Illuminate\Support\Str;

class HechoDuplicateGuard
{
    public function legacyMatches(array $submitted, array $saved): bool
    {
        foreach (['fecha', 'calle', 'colonia', 'municipio', 'tipo_hecho', 'folio_c5i'] as $field) {
            if (!array_key_exists($field, $submitted)) continue;
            $incoming = trim((string) $submitted[$field]);
            $original = trim((string) ($saved[$field] ?? ''));
            if ($field === 'fecha') {
                $incoming = substr($incoming, 0, 10);
                $original = substr($original, 0, 10);
            }
            $normalize = fn ($value) => Str::upper(preg_replace('/\s+/u', ' ', $value));
            if ($normalize($incoming) !== $normalize($original)) return false;
        }
        return true;
    }

    public function fingerprint(int $userId, array $payload, array $photoHashes): string
    {
        // Do not include the UUID or values recalculated on each upload.
        // The event date, location and capture details separate real events.
        $fields = [
            'fecha', 'folio_c5i', 'perito', 'unidad', 'calle', 'colonia',
            'entre_calles', 'municipio', 'tipo_hecho', 'superficie_via',
            'tiempo', 'clima', 'condiciones', 'control_transito', 'causas',
            'responsable', 'colision_camino', 'situacion', 'vehiculos_mp',
            'personas_mp', 'vehiculos_esperados', 'conductores_esperados',
            'lesionados_esperados', 'danos_patrimoniales',
            'propiedades_afectadas', 'monto_danos_patrimoniales',
        ];
        $values = [];
        foreach ($fields as $field) {
            $values[$field] = Str::upper(preg_replace('/\s+/u', ' ', trim((string) ($payload[$field] ?? ''))));
        }
        foreach (['lat', 'lng'] as $field) {
            $value = $payload[$field] ?? null;
            $values[$field] = is_numeric($value) ? round((float) $value, 5) : null;
        }
        // Without photos, two similar accidents at the same place on the same
        // day can be distinct events. Keep their capture time in the identity.
        if (!$photoHashes) {
            $values['hora'] = substr(trim((string) ($payload['hora'] ?? '')), 0, 5);
        }
        sort($photoHashes, SORT_STRING);
        return hash('sha256', json_encode([$userId, $values, $photoHashes], JSON_UNESCAPED_UNICODE));
    }
}
