<?php

namespace Tests\Unit;

use App\Http\Controllers\Api\ConduceLegalidadController;
use App\Models\ConduceLegalidadCaptura;
use App\Models\ConduceLegalidadOperativo;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use ReflectionMethod;
use Tests\TestCase;

class ConduceLegalidadFolioReservationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config()->set('database.default', 'sqlite');
        config()->set('database.connections.sqlite.database', ':memory:');
        DB::purge('sqlite');

        Schema::create('conduce_legalidad_folio_reservas', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('operativo_id');
            $table->uuid('client_uuid');
            $table->unsignedBigInteger('created_by')->nullable();
            $table->timestamps();
            $table->unique(['operativo_id', 'client_uuid']);
        });
    }

    public function test_same_capture_keeps_its_reserved_folio_and_concurrent_captures_get_different_numbers(): void
    {
        $controller = new ConduceLegalidadController();
        $operativo = new ConduceLegalidadOperativo([
            'nombre' => 'Operativo conduce con legalidad',
            'tipo_operativo' => 'conduce_legalidad',
            'estado' => 'activo',
        ]);
        $operativo->id = 17;

        $reserve = new ReflectionMethod($controller, 'reservarNumeroFolio');
        $reserve->setAccessible(true);
        $folioA = $reserve->invoke($controller, $operativo, '11111111-1111-4111-8111-111111111111', 9);
        $folioARepeat = $reserve->invoke($controller, $operativo, '11111111-1111-4111-8111-111111111111', 9);
        $folioB = $reserve->invoke($controller, $operativo, '22222222-2222-4222-8222-222222222222', 10);

        $this->assertSame($folioA, $folioARepeat);
        $this->assertNotSame($folioA, $folioB);
        $this->assertSame(2, DB::table('conduce_legalidad_folio_reservas')->count());

        $captura = new ConduceLegalidadCaptura(['folio_numero' => $folioA]);
        $captura->id = 900;
        $folioCaptura = new ReflectionMethod($controller, 'folioCaptura');
        $folioCaptura->setAccessible(true);

        $this->assertSame(
            'CL-17-' . $folioA,
            $folioCaptura->invoke($controller, $operativo, $captura)
        );
    }
}
