<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Servicio extends Model
{
    use HasFactory;

    protected $fillable = [
        'client_uuid',
        'grua_id',
        'vehiculo_id',
        'unidad_id',
        'delegacion_id',
        'tipo_vehiculo',
        'tipo_general_vehiculo',
        'aseguradora',
        'descripcion',
        'modalidad_servicio',
        'folio_sierse',
        'fecha_solicitud',
        'fecha_arribo',
        'fecha_inicio',
        'fecha_fin',
        'lugar_origen',
        'lugar_destino',
        'autoridad_solicitante',
        'agente_solicitante',
        'persona_solicitante',
        'operador_nombre',
        'unidad_grua',
        'kilometros_recorridos',
        'importe_total',
        'forma_pago',
        'memoria_descriptiva_path',
        'memoria_descriptiva_nombre',
        'memoria_descriptiva_mime',
        'memoria_descriptiva_sha256',
        'memoria_subida_por_grua_usuario_id',
        'memoria_subida_at',
        'foto_vehiculo',
        'realizo_maniobras',
        'maniobras_descripcion',
        'observaciones_grua',
        'inventario_recepcion',
        'actualizado_por_grua_usuario_id',
        'actualizado_por_grua_at',
        'created_at',
    ];

    protected $casts = [
        'realizo_maniobras' => 'boolean',
        'actualizado_por_grua_at' => 'datetime',
        'fecha_solicitud' => 'datetime',
        'fecha_arribo' => 'datetime',
        'fecha_inicio' => 'datetime',
        'fecha_fin' => 'datetime',
        'memoria_subida_at' => 'datetime',
        'kilometros_recorridos' => 'decimal:2',
        'importe_total' => 'decimal:2',
        'inventario_recepcion' => 'array',
    ];

    public function grua()
    {
        return $this->belongsTo(Grua::class, 'grua_id');
    }

    public function vehiculo()
    {
        return $this->belongsTo(Vehiculo::class, 'vehiculo_id');
    }

    public function actualizadoPorGruaUsuario()
    {
        return $this->belongsTo(GruaUsuario::class, 'actualizado_por_grua_usuario_id');
    }

    public function scopeConOrigenVinculado($query)
    {
        return $query->whereHas('vehiculo', function ($vehiculo) {
            $vehiculo->where(function ($origen) {
                $origen->whereHas('hechos')
                    ->orWhereHas('actividades')
                    ->orWhereHas('operativoDispositivos')
                    ->orWhereHas('puestasDisposicionVehiculos');
            });
        });
    }
}
