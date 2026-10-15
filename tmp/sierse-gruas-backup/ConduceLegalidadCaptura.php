<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ConduceLegalidadCaptura extends Model
{
    use HasFactory;

    protected $table = 'conduce_legalidad_capturas';

    protected $fillable = [
        'operativo_id',
        'actividad_id',
        'licencia_punto_infraccion_id',
        'infraccion_codigo',
        'fundamento_legal',
        'client_uuid',
        'created_by',
        'agente_nombre',
        'agente_nombres',
        'agente_apellido_paterno',
        'agente_apellido_materno',
        'agente_numero_placa',
        'agente_adscripcion',
        'unidad_id',
        'delegacion_id',
        'fecha',
        'hora',
        'municipio',
        'lugar',
        'lat',
        'lng',
        'coordenadas_texto',
        'narrativa',
        'observaciones',
        'rnd_data',
    ];

    protected $casts = [
        'fecha' => 'date',
        'lat' => 'decimal:7',
        'lng' => 'decimal:7',
        'rnd_data' => 'array',
    ];

    public function operativo()
    {
        return $this->belongsTo(ConduceLegalidadOperativo::class, 'operativo_id');
    }

    public function actividad()
    {
        return $this->belongsTo(Actividad::class, 'actividad_id');
    }

    public function infraccion()
    {
        return $this->belongsTo(LicenciaPuntoInfraccion::class, 'licencia_punto_infraccion_id');
    }

    public function fundamentos()
    {
        return $this->hasMany(ConduceLegalidadCapturaFundamento::class, 'captura_id')
            ->orderBy('orden')
            ->orderBy('id');
    }

    public function creador()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function unidad()
    {
        return $this->belongsTo(Unidad::class, 'unidad_id');
    }

    public function delegacion()
    {
        return $this->belongsTo(Delegacion::class, 'delegacion_id');
    }

    public function vehiculos()
    {
        return $this->hasMany(ConduceLegalidadVehiculo::class, 'captura_id');
    }

    public function personas()
    {
        return $this->hasMany(ConduceLegalidadPersona::class, 'captura_id');
    }

    public function fotos()
    {
        return $this->hasMany(ConduceLegalidadFoto::class, 'captura_id')
            ->orderBy('orden')
            ->orderBy('id');
    }
}
