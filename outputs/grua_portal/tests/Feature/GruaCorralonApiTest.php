<?php

namespace Tests\Feature;

use App\Models\Grua;
use App\Models\GruaUsuario;
use App\Models\Servicio;
use App\Models\Vehiculo;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class GruaCorralonApiTest extends TestCase
{
    use DatabaseTransactions;

    public function test_grua_can_list_and_deliver_only_its_current_vehicle(): void
    {
        Storage::fake('local');
        Storage::fake('public');

        $grua = Grua::create(['nombre' => 'GRUA API CORRALON ' . uniqid()]);
        $otraGrua = Grua::create(['nombre' => 'OTRA GRUA API ' . uniqid()]);
        $password = 'PruebaGrua_2026';
        $user = GruaUsuario::create([
            'grua_id' => $grua->id,
            'nombre' => 'Operador Corralon',
            'email' => 'operador-corralon-' . uniqid() . '@example.test',
            'password' => Hash::make($password),
            'activo' => true,
        ]);

        $vehiculo = $this->crearVehiculo($grua->id, 'API' . random_int(1000, 9999));
        $inventoryPhoto = UploadedFile::fake()->image('inventario.jpg');
        Storage::disk('public')->putFileAs(
            'hechos/pruebas',
            $inventoryPhoto,
            'inventario.jpg'
        );
        $vehiculo->update([
            'foto_inventario_grua' => 'hechos/pruebas/inventario.jpg',
        ]);
        Storage::disk('public')->putFileAs(
            'hechos/pruebas',
            UploadedFile::fake()->image('vehiculo.jpg'),
            'vehiculo.jpg'
        );
        $vehiculo->update(['fotos' => 'hechos/pruebas/vehiculo.jpg']);
        Servicio::create([
            'grua_id' => $grua->id,
            'vehiculo_id' => $vehiculo->id,
            'tipo_vehiculo' => 'AUTOMOVIL',
            'descripcion' => 'Servicio de prueba',
        ]);

        $ajeno = $this->crearVehiculo($otraGrua->id, 'OTR' . random_int(1000, 9999));
        Servicio::create([
            'grua_id' => $otraGrua->id,
            'vehiculo_id' => $ajeno->id,
            'tipo_vehiculo' => 'AUTOMOVIL',
        ]);

        $token = (string) $this->postJson('http://localhost/api/login', [
            'email' => $user->email,
            'password' => $password,
        ])->json('token');

        $list = $this->withToken($token)
            ->getJson('http://localhost/api/grua/corralon')
            ->assertOk();
        $ids = collect($list->json('items'))->pluck('id');
        $this->assertTrue($ids->contains($vehiculo->id));
        $this->assertFalse($ids->contains($ajeno->id));
        $list->assertJsonPath('summary.pendientes', 1)
            ->assertJsonPath('items.0.origen.tipo', 'SIN_CLASIFICAR')
            ->assertJsonPath('items.0.galeria.0.tipo', 'vehiculo')
            ->assertJsonStructure([
                'summary' => [
                    'pendientes',
                    'entregados_hoy',
                    'entregados_mes',
                    'total_entregados',
                    'con_observaciones_mes',
                    'serie_7_dias',
                ],
            ]);

        $this->withToken($token)
            ->get('http://localhost/api/grua/corralon/exportar/csv')
            ->assertOk()
            ->assertHeader('content-type', 'text/csv; charset=UTF-8');

        $this->withToken($token)
            ->get('http://localhost/api/grua/corralon/' . $vehiculo->id . '/foto-inventario')
            ->assertOk();

        $this->withToken($token)
            ->get('http://localhost/api/grua/corralon/' . $vehiculo->id . '/foto-vehiculo')
            ->assertOk();

        $this->withToken($token)
            ->patchJson('http://localhost/api/grua/corralon/' . $vehiculo->id . '/servicio', [
                'realizo_maniobras' => true,
                'maniobras_descripcion' => 'Izaje y acomodo del vehículo.',
                'observaciones_grua' => 'Sin daños adicionales.',
            ])
            ->assertOk()
            ->assertJsonPath('item.servicio.realizo_maniobras', true)
            ->assertJsonPath('item.servicio.maniobras_descripcion', 'Izaje y acomodo del vehículo.');

        $this->assertDatabaseHas('servicios', [
            'vehiculo_id' => $vehiculo->id,
            'realizo_maniobras' => true,
            'maniobras_descripcion' => 'Izaje y acomodo del vehículo.',
            'observaciones_grua' => 'Sin daños adicionales.',
            'actualizado_por_grua_usuario_id' => $user->id,
        ]);

        $this->withToken($token)
            ->get('http://localhost/api/grua/corralon/' . $vehiculo->id . '/memoria-descriptiva')
            ->assertOk()
            ->assertHeader('content-type', 'application/pdf');

        $this->withToken($token)
            ->post('http://localhost/api/grua/corralon/' . $ajeno->id . '/entregar', [
                'persona_recibe' => 'Persona Ajena',
                'identificacion_recibe' => 'INE 000',
                'sierse_folio' => 'SIERSE-AJENO',
                'condicion_entrega' => 'CONFORME_INVENTARIO',
                'foto_entrega' => UploadedFile::fake()->image('ajeno.jpg'),
                'conformidad_memoria' => '1',
                'confirmar_entrega' => '1',
            ], ['Accept' => 'application/json'])
            ->assertForbidden();

        $delivery = $this->withToken($token)
            ->post('http://localhost/api/grua/corralon/' . $vehiculo->id . '/entregar', [
                'persona_recibe' => 'María Receptora',
                'identificacion_recibe' => 'INE 123456',
                'telefono_recibe' => '4431234567',
                'sierse_folio' => 'SIERSE-PRUEBA-1',
                'condicion_entrega' => 'CONFORME_INVENTARIO',
                'foto_entrega' => UploadedFile::fake()->image('entrega.jpg'),
                'conformidad_memoria' => '1',
                'confirmar_entrega' => '1',
            ], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonPath('item.estado', 'ENTREGADO');

        $photoUrl = $delivery->json('item.fotos.entrega');
        $this->assertNotEmpty($photoUrl);
        $this->withToken($token)
            ->get('http://localhost/api' . $photoUrl)
            ->assertOk();

        $this->assertDatabaseHas('liberaciones_corralon', [
            'vehiculo_id' => $vehiculo->id,
            'grua_id' => $grua->id,
            'grua_usuario_id' => $user->id,
            'estado' => 'ENTREGADO',
            'sierse_folio' => 'SIERSE-PRUEBA-1',
        ]);
        $this->assertNull($vehiculo->fresh()->corralon);
    }

    public function test_grua_can_create_manual_service_complete_record_and_upload_memory(): void
    {
        Storage::fake('local');
        $grua = Grua::create(['nombre' => 'GRUA SIERSE ' . uniqid()]);
        $password = 'PruebaGrua_2026';
        $user = GruaUsuario::create([
            'grua_id' => $grua->id,
            'nombre' => 'Operador SIERSE',
            'email' => 'sierse-' . uniqid() . '@example.test',
            'password' => Hash::make($password),
            'activo' => true,
        ]);
        $token = (string) $this->postJson('http://localhost/api/login', [
            'email' => $user->email,
            'password' => $password,
        ])->json('token');

        $created = $this->withToken($token)->post('http://localhost/api/grua/corralon/servicios', [
            'marca' => 'FORD', 'linea' => 'FIESTA', 'modelo' => '2018',
            'tipo' => 'SEDAN', 'color' => 'AZUL', 'placas' => 'MAN' . random_int(1000, 9999),
            'serie' => '3FA6P0H70JR123456', 'corralon' => $grua->nombre,
            'modalidad_servicio' => 'ARRASTRE_SALVAMENTO',
            'tipo_general_vehiculo' => 'automovil',
            'fecha_solicitud' => now()->subHour()->toDateTimeString(),
            'lugar_origen' => 'Avenida de prueba',
            'operador_nombre' => 'Operador de prueba',
            'unidad_grua' => 'ECO-12',
            'inventario_recepcion' => [
                'llaves' => '1',
                'tarjeta_circulacion' => '0',
                'placas' => '1',
                'bateria' => '1',
            ],
        ], ['Accept' => 'application/json'])->assertCreated()
            ->assertJsonPath('item.origen.tipo', 'SIN_CLASIFICAR')
            ->assertJsonPath('item.servicio.inventario_recepcion.llaves', true);

        $vehiculoId = (int) $created->json('item.id');
        $updated = $this->withToken($token)->post(
            'http://localhost/api/grua/corralon/' . $vehiculoId . '/expediente',
            [
                'folio_sierse' => 'SIERSE-MANUAL-001',
                'fecha_arribo' => now()->subMinutes(50)->toDateTimeString(),
                'fecha_inicio' => now()->subMinutes(45)->toDateTimeString(),
                'fecha_fin' => now()->subMinutes(20)->toDateTimeString(),
                'lugar_destino' => $grua->nombre,
                'autoridad_solicitante' => 'Guardia Civil',
                'agente_solicitante' => 'Agente de prueba',
                'realizo_maniobras' => '1',
                'maniobras_descripcion' => 'Izaje y arrastre.',
                'memoria_descriptiva' => UploadedFile::fake()->create('memoria.pdf', 120, 'application/pdf'),
            ],
            ['Accept' => 'application/json']
        )->assertOk()
            ->assertJsonPath('item.servicio.folio_sierse', 'SIERSE-MANUAL-001')
            ->assertJsonPath('item.servicio.memoria.nombre', 'memoria.pdf');

        $this->assertNotEmpty($updated->json('item.servicio.memoria.sha256'));
        $this->withToken($token)
            ->get('http://localhost/api/grua/corralon/' . $vehiculoId . '/memoria-descriptiva/archivo')
            ->assertOk()
            ->assertHeader('content-type', 'application/pdf');

        $this->withToken($token)
            ->getJson('http://localhost/api/grua/corralon?origen=MANUAL&dias=1&per_page=20')
            ->assertOk()
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('items.0.id', $vehiculoId);

        foreach (range(1, 21) as $index) {
            $extra = $this->crearVehiculo($grua->id, 'PG' . str_pad((string) $index, 4, '0', STR_PAD_LEFT));
            Servicio::create([
                'grua_id' => $grua->id,
                'vehiculo_id' => $extra->id,
                'tipo_vehiculo' => 'SEDAN',
                'created_at' => now()->subMinutes($index),
            ]);
        }

        $pageOne = $this->withToken($token)
            ->getJson('http://localhost/api/grua/corralon?origen=MANUAL&per_page=20&page=1')
            ->assertOk()
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.last_page', 2)
            ->assertJsonPath('meta.total', 22);
        $this->assertCount(20, $pageOne->json('items'));

        $pageTwo = $this->withToken($token)
            ->getJson('http://localhost/api/grua/corralon?origen=MANUAL&per_page=20&page=2')
            ->assertOk()
            ->assertJsonPath('meta.current_page', 2);
        $this->assertCount(2, $pageTwo->json('items'));
    }

    private function crearVehiculo(int $gruaId, string $placas): Vehiculo
    {
        return Vehiculo::create([
            'marca' => 'NISSAN',
            'modelo' => '2020',
            'tipo' => 'SEDAN',
            'linea' => 'VERSA',
            'color' => 'BLANCO',
            'placas' => $placas,
            'estado_placas' => 'MICHOACAN',
            'serie' => strtoupper(substr(uniqid('VIN'), 0, 17)),
            'capacidad_personas' => 5,
            'tipo_servicio' => 'PARTICULAR',
            'tarjeta_circulacion_nombre' => 'PRUEBA',
            'grua_id' => $gruaId,
            'grua' => 'PRUEBA',
            'corralon' => 'CORRALON PRUEBA',
        ]);
    }
}
