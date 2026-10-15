<?php

namespace Tests\Unit;

use App\Models\ConduceLegalidadOperativo;
use App\Services\ConduceLegalidadDuplicateGuard;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class ConduceLegalidadDuplicateGuardTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config()->set('database.default', 'sqlite');
        config()->set('database.connections.sqlite.database', ':memory:');
        DB::purge('sqlite');

        Schema::create('conduce_legalidad_operativos', function (Blueprint $table) {
            $table->id();
            $table->string('nombre')->nullable();
            $table->timestamps();
        });
        Schema::create('conduce_legalidad_capturas', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('operativo_id');
            $table->timestamps();
        });
        Schema::create('conduce_legalidad_vehiculos', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('captura_id');
            $table->string('placas')->nullable();
            $table->string('serie')->nullable();
            $table->timestamps();
        });
        Schema::create('conduce_legalidad_fotos', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('captura_id');
            $table->string('foto_hash', 64)->nullable();
            $table->timestamps();
        });
    }

    public function test_blocks_same_plate_and_vin_only_inside_the_same_operativo(): void
    {
        $operativo = $this->operativo(1);
        $otherOperativo = $this->operativo(2);
        $this->captureWithVehicle(1, 1, 'ABC-123-A', '1HGCM82633A004352');

        $guard = new ConduceLegalidadDuplicateGuard();

        try {
            $guard->assertUnique($operativo, [[
                'placas' => 'abc 123-a',
                'serie' => 'OTRONIV123456789',
            ]], []);
            $this->fail('La placa repetida debió bloquearse.');
        } catch (ValidationException $e) {
            $this->assertStringContainsString('placas ya están registradas', $e->errors()['vehiculos.0.placas'][0]);
        }

        try {
            $guard->assertUnique($operativo, [[
                'placas' => 'XYZ987',
                'serie' => '1hgcm82633a004352',
            ]], []);
            $this->fail('El NIV repetido debió bloquearse.');
        } catch (ValidationException $e) {
            $this->assertStringContainsString('NIV/serie ya está registrado', $e->errors()['vehiculos.0.serie'][0]);
        }

        $guard->assertUnique($otherOperativo, [[
            'placas' => 'ABC123A',
            'serie' => '1HGCM82633A004352',
        ]], []);
        $this->assertTrue(true);
    }

    public function test_blocks_repeated_photos_in_the_request_or_operativo(): void
    {
        $operativo = $this->operativo(1);
        $this->captureWithVehicle(1, 1, null, null);
        DB::table('conduce_legalidad_fotos')->insert([
            'captura_id' => 1,
            'foto_hash' => 'hash-existente',
        ]);

        $guard = new ConduceLegalidadDuplicateGuard();

        foreach ([
            ['hash-nuevo', 'hash-nuevo'],
            ['hash-existente'],
        ] as $hashes) {
            try {
                $guard->assertUnique($operativo, [], $hashes);
                $this->fail('La foto repetida debió bloquearse.');
            } catch (ValidationException $e) {
                $this->assertArrayHasKey('fotos', $e->errors());
            }
        }
    }

    public function test_update_ignores_its_own_vehicle_but_not_an_existing_photo(): void
    {
        $operativo = $this->operativo(1);
        $this->captureWithVehicle(1, 1, 'ABC123A', '1HGCM82633A004352');
        DB::table('conduce_legalidad_fotos')->insert([
            'captura_id' => 1,
            'foto_hash' => 'foto-propia',
        ]);

        $guard = new ConduceLegalidadDuplicateGuard();
        $guard->assertUnique($operativo, [[
            'placas' => 'ABC-123-A',
            'serie' => '1HGCM82633A004352',
        ]], [], 1);

        $this->expectException(ValidationException::class);
        $guard->assertUnique($operativo, [], ['foto-propia'], 1);
    }

    private function operativo(int $id): ConduceLegalidadOperativo
    {
        DB::table('conduce_legalidad_operativos')->insert([
            'id' => $id,
            'nombre' => 'Operativo ' . $id,
        ]);

        return ConduceLegalidadOperativo::query()->findOrFail($id);
    }

    private function captureWithVehicle(
        int $capturaId,
        int $operativoId,
        ?string $placas,
        ?string $serie
    ): void {
        DB::table('conduce_legalidad_capturas')->insert([
            'id' => $capturaId,
            'operativo_id' => $operativoId,
        ]);
        DB::table('conduce_legalidad_vehiculos')->insert([
            'captura_id' => $capturaId,
            'placas' => $placas,
            'serie' => $serie,
        ]);
    }
}
