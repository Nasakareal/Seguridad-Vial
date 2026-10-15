<?php

namespace App\Services;

use App\Models\ConduceLegalidadFoto;
use App\Models\ConduceLegalidadOperativo;
use App\Models\ConduceLegalidadVehiculo;
use Illuminate\Validation\ValidationException;

class ConduceLegalidadDuplicateGuard
{
    /**
     * @return string[]
     */
    public function hashUploadedFiles(iterable $files): array
    {
        $hashes = [];

        foreach ($files as $file) {
            if (!$file || !method_exists($file, 'getRealPath')) {
                continue;
            }

            $path = $file->getRealPath();
            if (!$path) {
                continue;
            }

            $hash = @hash_file('sha256', $path);
            if ($hash) {
                $hashes[] = $hash;
            }
        }

        return $hashes;
    }

    public function assertUnique(
        ConduceLegalidadOperativo $operativo,
        array $vehiculos,
        array $fotoHashes,
        ?int $exceptCapturaId = null
    ): void {
        $placas = [];
        $series = [];

        foreach ($vehiculos as $index => $vehiculo) {
            $placa = self::normalizePlate($vehiculo['placas'] ?? null);
            $serie = self::normalizeVin($vehiculo['serie'] ?? null);

            if ($placa !== null) {
                if (isset($placas[$placa])) {
                    throw ValidationException::withMessages([
                        "vehiculos.$index.placas" => 'Estas placas están repetidas en la misma captura.',
                    ]);
                }
                $placas[$placa] = true;
            }

            if ($serie !== null) {
                if (isset($series[$serie])) {
                    throw ValidationException::withMessages([
                        "vehiculos.$index.serie" => 'Este NIV/serie está repetido en la misma captura.',
                    ]);
                }
                $series[$serie] = true;
            }
        }

        foreach (array_keys($placas) as $placa) {
            if ($this->vehicleValueExists($operativo->id, 'placas', $placa, $exceptCapturaId)) {
                throw ValidationException::withMessages([
                    'vehiculos.0.placas' => 'Estas placas ya están registradas en otra captura de este operativo.',
                ]);
            }
        }

        foreach (array_keys($series) as $serie) {
            if ($this->vehicleValueExists($operativo->id, 'serie', $serie, $exceptCapturaId)) {
                throw ValidationException::withMessages([
                    'vehiculos.0.serie' => 'Este NIV/serie ya está registrado en otra captura de este operativo.',
                ]);
            }
        }

        $fotoHashes = array_values(array_filter(array_map('strval', $fotoHashes)));
        if (count($fotoHashes) !== count(array_unique($fotoHashes))) {
            throw ValidationException::withMessages([
                'fotos' => 'Estás intentando subir la misma foto más de una vez.',
            ]);
        }

        if ($fotoHashes && ConduceLegalidadFoto::query()
            ->whereIn('foto_hash', $fotoHashes)
            ->whereHas('captura', function ($query) use ($operativo) {
                $query->where('operativo_id', $operativo->id);
            })
            ->exists()) {
            throw ValidationException::withMessages([
                'fotos' => 'Esta foto ya está registrada en otra captura de este operativo.',
            ]);
        }
    }

    public static function normalizePlate($value): ?string
    {
        $normalized = self::normalizeToken($value);
        if ($normalized === null || in_array($normalized, [
            'SINPLACA',
            'SINPLACAS',
            'SPLACA',
            'SPLACAS',
            'PERMISO',
            'SD',
            'SN',
            'NA',
        ], true)) {
            return null;
        }

        return $normalized;
    }

    public static function normalizeVin($value): ?string
    {
        return self::normalizeToken($value);
    }

    private function vehicleValueExists(
        int $operativoId,
        string $column,
        string $normalized,
        ?int $exceptCapturaId
    ): bool {
        return ConduceLegalidadVehiculo::query()
            ->whereHas('captura', function ($query) use ($operativoId, $exceptCapturaId) {
                $query->where('operativo_id', $operativoId)
                    ->when($exceptCapturaId, function ($captureQuery) use ($exceptCapturaId) {
                        $captureQuery->where('id', '!=', $exceptCapturaId);
                    });
            })
            ->get([$column])
            ->contains(function (ConduceLegalidadVehiculo $vehiculo) use ($column, $normalized) {
                $current = $column === 'placas'
                    ? self::normalizePlate($vehiculo->{$column})
                    : self::normalizeVin($vehiculo->{$column});

                return $current === $normalized;
            });
    }

    private static function normalizeToken($value): ?string
    {
        $normalized = strtoupper(trim((string) $value));
        $normalized = preg_replace('/[^A-Z0-9]+/', '', $normalized) ?: '';

        return $normalized === '' ? null : $normalized;
    }
}
