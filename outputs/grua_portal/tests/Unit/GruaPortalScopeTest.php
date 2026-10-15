<?php

namespace Tests\Unit;

use App\Http\Controllers\LiberacionCorralonController;
use App\Models\LiberacionCorralon;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use ReflectionMethod;
use Tests\TestCase;

class GruaPortalScopeTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config()->set('database.default', 'sqlite');
        config()->set('database.connections.sqlite.database', ':memory:');
        DB::purge('sqlite');

        Schema::create('vehiculos', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('grua_id')->nullable();
            $table->string('corralon')->nullable();
            $table->dateTime('fecha_inventario_grua')->nullable();
            $table->timestamps();
        });
        Schema::create('servicios', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('vehiculo_id');
            $table->unsignedBigInteger('grua_id')->nullable();
            $table->timestamps();
        });
        Schema::create('liberaciones_corralon', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('vehiculo_id');
            $table->string('estado')->default('PENDIENTE');
            $table->timestamps();
        });
    }

    public function test_portal_uses_the_latest_service_instead_of_any_historical_service(): void
    {
        foreach ([1, 2, 3] as $vehiculoId) {
            DB::table('vehiculos')->insert([
                'id' => $vehiculoId,
                'grua_id' => $vehiculoId === 3 ? 1 : 2,
                'corralon' => 'CORRALON CENTRAL',
                'updated_at' => '2026-10-14 12:00:00',
            ]);
        }

        DB::table('servicios')->insert([
            ['id' => 1, 'vehiculo_id' => 1, 'grua_id' => 1, 'created_at' => '2026-10-14 10:00:00'],
            ['id' => 2, 'vehiculo_id' => 1, 'grua_id' => 2, 'created_at' => '2026-10-14 11:00:00'],
            ['id' => 3, 'vehiculo_id' => 2, 'grua_id' => 2, 'created_at' => '2026-10-14 10:00:00'],
            ['id' => 4, 'vehiculo_id' => 2, 'grua_id' => 1, 'created_at' => '2026-10-14 11:00:00'],
        ]);

        $method = new ReflectionMethod(LiberacionCorralonController::class, 'vehiculosEnResguardoQuery');
        $method->setAccessible(true);
        $query = $method->invoke(new LiberacionCorralonController(), 1);

        $this->assertSame([2, 3], $query->orderBy('vehiculos.id')->pluck('vehiculos.id')->all());
    }

    public function test_release_model_keeps_sierse_closure_and_audit_fields(): void
    {
        $model = new LiberacionCorralon();
        $fillable = $model->getFillable();

        foreach ([
            'sierse_folio',
            'memoria_descriptiva',
            'comprobante_pago',
            'condicion_entrega',
            'conformidad_memoria',
            'fecha_conformidad',
            'ip_entrega',
        ] as $field) {
            $this->assertContains($field, $fillable);
        }
    }
}
