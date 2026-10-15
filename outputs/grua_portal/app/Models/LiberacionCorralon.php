<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LiberacionCorralon extends Model
{
    use HasFactory;

    protected $table = 'liberaciones_corralon';

    protected $fillable = [
        'vehiculo_id',
        'grua_id',
        'grua_usuario_id',
        'persona_recibe',
        'identificacion_recibe',
        'telefono_recibe',
        'sierse_folio',
        'condicion_entrega',
        'foto_identificacion',
        'foto_entrega',
        'documento_liberacion',
        'memoria_descriptiva',
        'comprobante_pago',
        'firma_recibe',
        'conformidad_memoria',
        'fecha_conformidad',
        'ip_entrega',
        'user_agent_entrega',
        'observaciones',
        'estado',
        'fecha_entrega',
    ];

    protected $casts = [
        'conformidad_memoria' => 'boolean',
        'fecha_conformidad' => 'datetime',
        'fecha_entrega' => 'datetime',
    ];

    public function vehiculo()
    {
        return $this->belongsTo(Vehiculo::class, 'vehiculo_id');
    }

    public function grua()
    {
        return $this->belongsTo(Grua::class, 'grua_id');
    }

    public function gruaUsuario()
    {
        return $this->belongsTo(GruaUsuario::class, 'grua_usuario_id');
    }
}
