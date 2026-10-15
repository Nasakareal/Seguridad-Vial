<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class GruaUsuario extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $table = 'grua_usuarios';

    protected $fillable = [
        'grua_id',
        'nombre',
        'telefono',
        'email',
        'password',
        'activo',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'activo' => 'boolean',
    ];

    public function grua()
    {
        return $this->belongsTo(Grua::class, 'grua_id');
    }

    public function liberacionesCorralon()
    {
        return $this->hasMany(LiberacionCorralon::class, 'grua_usuario_id');
    }
}
