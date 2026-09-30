<?php

namespace Tests\Unit;

use App\Http\Controllers\Api\ConduceLegalidadController;
use App\Models\ConduceLegalidadCaptura;
use App\Models\ConduceLegalidadOperativo;
use Carbon\Carbon;
use Illuminate\Support\Collection;
use ReflectionMethod;
use Tests\TestCase;

class ConduceLegalidadIphMappingTest extends TestCase
{
    public function test_separa_el_nombre_escrito_del_agente_para_el_iph(): void
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'agenteCapturaData');
        $method->setAccessible(true);

        $agente = $method->invoke(
            new ConduceLegalidadController(),
            [
                'agente_nombres' => 'Ana María',
                'agente_apellido_paterno' => 'Pérez',
                'agente_apellido_materno' => 'López',
                'agente_numero_placa' => 'PLACA-7788',
            ],
            (object) ['name' => 'Usuario que captura']
        );

        $this->assertSame('Ana María Pérez López', $agente['nombre']);
        $this->assertSame('Ana María', $agente['nombres']);
        $this->assertSame('Pérez', $agente['apellido_paterno']);
        $this->assertSame('López', $agente['apellido_materno']);
        $this->assertSame('PLACA-7788', $agente['numero_placa']);
        $this->assertSame('Unidad de Protección en Vialidades Urbanas', $agente['adscripcion']);
    }

    public function test_mapeo_iph_usa_numero_y_codigo_postal_del_operativo(): void
    {
        $operativo = new ConduceLegalidadOperativo();
        $operativo->forceFill([
            'id' => 10,
            'fecha' => Carbon::parse('2026-07-02'),
            'hora_inicio' => '10:15:00',
            'municipio' => 'Morelia',
            'lugar' => 'Avenida Test',
            'numero' => '123',
            'colonia' => 'Centro',
            'codigo_postal' => '58000',
            'lat' => 19.7008,
            'lng' => -101.1844,
        ]);

        $captura = new ConduceLegalidadCaptura();
        $captura->forceFill([
            'id' => 25,
            'operativo_id' => 10,
            'fecha' => Carbon::parse('2026-07-02'),
            'hora' => '10:30:00',
            'municipio' => null,
            'lugar' => null,
            'lat' => null,
            'lng' => null,
            'observaciones' => null,
            'agente_nombre' => 'Ana María Pérez López',
            'agente_nombres' => 'Ana María',
            'agente_apellido_paterno' => 'Pérez',
            'agente_apellido_materno' => 'López',
            'agente_numero_placa' => 'PLACA-7788',
            'agente_adscripcion' => 'Unidad de Protección en Vialidades Urbanas',
        ]);
        $captura->setRelation('vehiculos', new Collection());
        $captura->setRelation('fundamentos', new Collection());
        $captura->setRelation('personas', new Collection());
        $captura->setRelation('fotos', new Collection());
        $captura->setRelation('unidad', null);
        $captura->setRelation('delegacion', null);
        $captura->setRelation('creador', null);

        $method = new ReflectionMethod(ConduceLegalidadController::class, 'mapearIphDesdeCaptura');
        $method->setAccessible(true);

        $mapeo = $method->invoke(new ConduceLegalidadController(), $operativo, $captura, (object) [
            'name' => 'Agente Test',
        ]);

        $this->assertSame('Avenida Test 123', $mapeo['hecho']['ubicacion']['calle']);
        $this->assertSame('58000', $mapeo['hecho']['ubicacion']['codigo_postal']);
        $this->assertStringContainsString('CP 58000', $mapeo['hecho']['ubicacion']['ubicacion_formateada']);
        $this->assertSame('Ana María Pérez López', $mapeo['puesta_disposicion']['nombre_policia']);
        $this->assertSame('Ana María', $mapeo['puesta_disposicion']['agente_nombres']);
        $this->assertSame('Pérez', $mapeo['puesta_disposicion']['agente_apellido_paterno']);
        $this->assertSame('López', $mapeo['puesta_disposicion']['agente_apellido_materno']);
        $this->assertSame('PLACA-7788', $mapeo['puesta_disposicion']['agente_numero_placa']);
        $this->assertSame(
            'Unidad de Protección en Vialidades Urbanas',
            $mapeo['puesta_disposicion']['area']
        );
    }
}
