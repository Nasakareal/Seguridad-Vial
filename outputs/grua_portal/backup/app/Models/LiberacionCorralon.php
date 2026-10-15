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
        'foto_identificacion',
        'foto_entrega',
        'documento_liberacion',
        'observaciones',
        'estado',
        'fecha_entrega',
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
