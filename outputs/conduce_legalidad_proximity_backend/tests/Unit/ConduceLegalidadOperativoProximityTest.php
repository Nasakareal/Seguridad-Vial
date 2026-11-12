<?php

namespace Tests\Unit;

use App\Http\Controllers\Api\ConduceLegalidadController;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;
use ReflectionMethod;
use Tests\TestCase;

class ConduceLegalidadOperativoProximityTest extends TestCase
{
    private string $originalConnection;

    protected function setUp(): void
    {
        parent::setUp();

        $this->originalConnection = (string) config('database.default');
        config([
            'database.default' => 'proximity_test',
            'database.connections.proximity_test' => [
                'driver' => 'sqlite',
                'database' => ':memory:',
                'prefix' => '',
                'foreign_key_constraints' => false,
            ],
        ]);
        DB::purge('proximity_test');
        Schema::connection('proximity_test')->create('conduce_legalidad_operativos', function (Blueprint $table) {
            $table->id();
            $table->string('estado', 30);
            $table->decimal('lat', 10, 7)->nullable();
            $table->decimal('lng', 10, 7)->nullable();
            $table->string('municipio')->nullable();
            $table->string('lugar')->nullable();
            $table->string('numero')->nullable();
            $table->string('colonia')->nullable();
            $table->softDeletes();
            $table->timestamps();
        });
    }

    protected function tearDown(): void
    {
        DB::purge('proximity_test');
        config(['database.default' => $this->originalConnection]);
        parent::tearDown();
    }

    public function test_distance_detects_an_operativo_inside_thirty_meters(): void
    {
        $distance = $this->distanceMeters(19.7023456, -101.1923456, 19.7026056, -101.1923456);

        $this->assertGreaterThan(28.0, $distance);
        $this->assertLessThan(30.0, $distance);
    }

    public function test_distance_allows_an_operativo_beyond_thirty_meters(): void
    {
        $distance = $this->distanceMeters(19.7023456, -101.1923456, 19.7026456, -101.1923456);

        $this->assertGreaterThan(30.0, $distance);
    }

    public function test_identical_coordinates_have_zero_distance(): void
    {
        $distance = $this->distanceMeters(19.7023456, -101.1923456, 19.7023456, -101.1923456);

        $this->assertEqualsWithDelta(0.0, $distance, 0.001);
    }

    public function test_active_operativo_inside_radius_is_rejected_with_clear_message(): void
    {
        $id = $this->insertOperativo('activo', 19.7026056, -101.1923456);

        try {
            $this->assertLocationAvailable(19.7023456, -101.1923456);
            $this->fail('The nearby active operativo should have been rejected.');
        } catch (ValidationException $exception) {
            $message = $exception->errors()['coordenadas_texto'][0] ?? '';
            $this->assertStringContainsString("operativo activo #{$id}", $message);
            $this->assertStringContainsString('CALZADA LA HUERTA', $message);
            $this->assertStringContainsString('ciérralo', $message);
        }
    }

    public function test_closed_operativo_inside_radius_does_not_block_creation(): void
    {
        $this->insertOperativo('cerrado', 19.7026056, -101.1923456);

        $this->assertLocationAvailable(19.7023456, -101.1923456);
        $this->addToAssertionCount(1);
    }

    public function test_active_operativo_outside_radius_does_not_block_creation(): void
    {
        $this->insertOperativo('activo', 19.7026456, -101.1923456);

        $this->assertLocationAvailable(19.7023456, -101.1923456);
        $this->addToAssertionCount(1);
    }

    public function test_editing_ignores_the_same_operativo(): void
    {
        $id = $this->insertOperativo('activo', 19.7023456, -101.1923456);

        $this->assertLocationAvailable(19.7023456, -101.1923456, $id);
        $this->addToAssertionCount(1);
    }

    private function distanceMeters(float $latA, float $lngA, float $latB, float $lngB): float
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'distanceMeters');
        $method->setAccessible(true);

        return $method->invoke(new ConduceLegalidadController(), $latA, $lngA, $latB, $lngB);
    }

    private function assertLocationAvailable(float $lat, float $lng, ?int $ignoreId = null): void
    {
        $method = new ReflectionMethod(ConduceLegalidadController::class, 'assertNoActiveOperativoNearby');
        $method->setAccessible(true);
        $method->invoke(new ConduceLegalidadController(), $lat, $lng, $ignoreId);
    }

    private function insertOperativo(string $estado, float $lat, float $lng): int
    {
        return (int) DB::table('conduce_legalidad_operativos')->insertGetId([
            'estado' => $estado,
            'lat' => $lat,
            'lng' => $lng,
            'municipio' => 'MORELIA',
            'lugar' => 'CALZADA LA HUERTA',
            'numero' => '100',
            'colonia' => 'NUEVA VALLADOLID',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
