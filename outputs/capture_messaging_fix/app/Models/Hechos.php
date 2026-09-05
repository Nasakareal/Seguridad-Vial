<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class Hechos extends Model
{
    use HasFactory;

    private const NEXT_ID_LOCK_NAME = 'sistema_estadistico_hechos_next_id';

    private static bool $nextIdLockHeld = false;

    protected $table = 'hechos';

    protected $fillable = [
        'client_uuid',
        'submission_fingerprint',
        'folio_c5i',
        'perito',
        'autorizacion_practico',
        'unidad',
        'unidad_org_id',
        'hora',
        'fecha',
        'sector',
        'calle',
        'calle_norm',
        'colonia',
        'entre_calles',
        'municipio',
        'codigo_postal',
        'tipo_hecho',
        'superficie_via',
        'tiempo',
        'clima',
        'condiciones',
        'control_transito',
        'checaron_antecedentes',
        'causas',
        'responsable',
        'colision_camino',
        'situacion',
        'oficio_mp',
        'vehiculos_mp',
        'personas_mp',
        'danos_patrimoniales',
        'propiedades_afectadas',
        'monto_danos_patrimoniales',
        'foto_lugar',
        'foto_lugar_2',
        'foto_situacion',
        'iph_delegaciones_path',
        'delegacion_id',
        'lat',
        'lng',
        'km_recorridos', // 👈 NUEVO
        'calidad_geo',
        'nota_geo',
        'fuente_ubicacion',
        'ubicacion_formateada',
        'place_id',
        'created_by',
        'updated_by',
        'es_relevante',
        'marcado_relevante_por',
        'marcado_relevante_at',
        'estado_revision',
        'revisado_por',
        'revisado_at',
        'observacion_revision',
        'vehiculos_esperados',
        'conductores_esperados',
        'lesionados_esperados',
        'vehiculos_capturados',
        'conductores_capturados',
        'lesionados_capturados',
        'captura_completa',
        'captura_completa_at',
    ];

    protected $casts = [
        'checaron_antecedentes' => 'boolean',
        'lat' => 'decimal:7',
        'lng' => 'decimal:7',
        'km_recorridos' => 'decimal:2', // 👈 NUEVO
        'es_relevante' => 'boolean',
        'marcado_relevante_at' => 'datetime',
        'revisado_at' => 'datetime',
        'fecha' => 'date',
        'vehiculos_esperados' => 'integer',
        'conductores_esperados' => 'integer',
        'lesionados_esperados' => 'integer',
        'vehiculos_capturados' => 'integer',
        'conductores_capturados' => 'integer',
        'lesionados_capturados' => 'integer',
        'captura_completa' => 'boolean',
        'captura_completa_at' => 'datetime',
    ];

    public static function normalizarLongitud($valor)
    {
        if ($valor === null || $valor === '' || !is_numeric($valor)) {
            return $valor;
        }

        return -abs((float) $valor);
    }

    public function setLngAttribute($valor): void
    {
        $this->attributes['lng'] = self::normalizarLongitud($valor);
    }

    protected static function booted(): void
    {
        static::creating(function (Hechos $hecho): void {
            if (!empty($hecho->id) || DB::connection()->getDriverName() !== 'mysql') {
                return;
            }

            $lock = DB::selectOne('SELECT GET_LOCK(?, 10) AS locked', [self::NEXT_ID_LOCK_NAME]);

            if ((int) ($lock->locked ?? 0) !== 1) {
                throw new RuntimeException('No se pudo reservar el siguiente ID de hechos.');
            }

            self::$nextIdLockHeld = true;
            $hecho->id = ((int) DB::table($hecho->getTable())->max('id')) + 1;
        });

        static::created(function (): void {
            self::releaseNextIdLock();
        });
    }

    private static function releaseNextIdLock(): void
    {
        if (!self::$nextIdLockHeld || DB::connection()->getDriverName() !== 'mysql') {
            return;
        }

        DB::selectOne('SELECT RELEASE_LOCK(?) AS released', [self::NEXT_ID_LOCK_NAME]);
        self::$nextIdLockHeld = false;
    }

    public function vehiculos(): BelongsToMany
    {
        return $this->belongsToMany(Vehiculo::class, 'hecho_vehiculo', 'hecho_id', 'vehiculo_id')
            ->withTimestamps();
    }

    public function vehiculosEnCorralon(): BelongsToMany
    {
        return $this->vehiculos()
            ->whereNotNull('vehiculos.corralon')
            ->whereRaw("TRIM(vehiculos.corralon) <> ''")
            ->whereRaw(
                "UPPER(TRIM(vehiculos.corralon)) NOT IN (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                ['N/A', 'NA', 'NO', 'NO APLICA', 'NO SE UTILIZA', 'NO SE UTILIZO', 'NINGUNO', 'NULL', 'O', 'SIN CORRALON']
            );
    }

    public function lesionados(): HasMany
    {
        return $this->hasMany(Lesionado::class, 'hecho_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function updater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by');
    }

    public function unidadOrganizacional(): BelongsTo
    {
        return $this->belongsTo(Unidad::class, 'unidad_org_id');
    }

    public function delegacion(): BelongsTo
    {
        return $this->belongsTo(Delegacion::class, 'delegacion_id');
    }

    public function dictamen(): HasOne
    {
        return $this->hasOne(Dictamen::class, 'hecho_id');
    }

    public function puestaDisposicion(): HasOne
    {
        return $this->hasOne(PuestaDisposicion::class, 'hecho_id')->latestOfMany();
    }

    public function marcadoRelevantePor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'marcado_relevante_por');
    }

    public function revisadoPor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'revisado_por');
    }

    public function croquis(): HasOne
    {
        return $this->hasOne(Croquis::class, 'hecho_id')->latestOfMany();
    }

    public function getEsPendienteRevisionAttribute(): bool
    {
        return $this->estado_revision === 'pendiente';
    }

    public function getEsAprobadoAttribute(): bool
    {
        return $this->estado_revision === 'aprobado';
    }

    public function getEsRechazadoAttribute(): bool
    {
        return $this->estado_revision === 'rechazado';
    }

    public function getPuedeSalirEnResumenAttribute(): bool
    {
        return $this->es_relevante;
    }

    public function getPuedeSalirEnResumenFormalAttribute(): bool
    {
        return $this->es_relevante && $this->estado_revision === 'aprobado';
    }

    public function capturaCompletaCalculada(): bool
    {
        return $this->capturadosCubrenEsperados('vehiculos')
            && $this->capturadosCubrenEsperados('conductores')
            && $this->capturadosCubrenEsperados('lesionados');
    }

    public function faltantesCaptura(): array
    {
        $campos = [
            'vehiculos' => ['singular' => 'vehículo', 'plural' => 'vehículos'],
            'conductores' => ['singular' => 'conductor', 'plural' => 'conductores'],
            'lesionados' => ['singular' => 'lesionado', 'plural' => 'lesionados'],
        ];

        $faltantes = [];

        foreach ($campos as $campo => $labels) {
            $esperados = (int) ($this->{$campo . '_esperados'} ?? 0);
            $capturados = (int) ($this->{$campo . '_capturados'} ?? 0);
            $faltan = max(0, $esperados - $capturados);

            if ($faltan <= 0) {
                continue;
            }

            $faltantes[$campo] = [
                'label' => $faltan === 1 ? $labels['singular'] : $labels['plural'],
                'faltan' => $faltan,
                'esperados' => $esperados,
                'capturados' => $capturados,
            ];
        }

        return $faltantes;
    }

    public function faltantesCapturaTexto(): array
    {
        return array_map(function (array $faltante): string {
            return "{$faltante['faltan']} {$faltante['label']} ({$faltante['capturados']}/{$faltante['esperados']})";
        }, $this->faltantesCaptura());
    }

    public function actualizarEstadoCaptura(): void
    {
        $vehiculosCapturados = $this->vehiculos()->count();
        $conductoresCapturados = \App\Models\Conductor::whereHas('vehiculos', function ($query) {
            $query->whereHas('hechos', function ($subQuery) {
                $subQuery->where('hechos.id', $this->id);
            });
        })->distinct('conductores.id')->count('conductores.id');

        $lesionadosCapturados = $this->lesionados()->count();

        $capturaCompleta =
            $vehiculosCapturados >= (int) $this->vehiculos_esperados &&
            $conductoresCapturados >= (int) $this->conductores_esperados &&
            $lesionadosCapturados >= (int) $this->lesionados_esperados;

        $capturaCompletaAt = null;

        if ($capturaCompleta) {
            $capturaCompletaAt = $this->captura_completa_at ?: now();
        }

        $this->update([
            'vehiculos_capturados' => $vehiculosCapturados,
            'conductores_capturados' => $conductoresCapturados,
            'lesionados_capturados' => $lesionadosCapturados,
            'captura_completa' => $capturaCompleta,
            'captura_completa_at' => $capturaCompletaAt,
        ]);
    }

    private function capturadosCubrenEsperados(string $campo): bool
    {
        return (int) ($this->{$campo . '_capturados'} ?? 0) >= (int) ($this->{$campo . '_esperados'} ?? 0);
    }
}
