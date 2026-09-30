<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('conduce_legalidad_capturas', function (Blueprint $table) {
            $table->string('agente_nombre')->nullable()->after('created_by');
            $table->string('agente_nombres', 120)->nullable()->after('agente_nombre');
            $table->string('agente_apellido_paterno', 100)->nullable()->after('agente_nombres');
            $table->string('agente_apellido_materno', 100)->nullable()->after('agente_apellido_paterno');
            $table->string('agente_numero_placa', 80)->nullable()->after('agente_apellido_materno');
            $table->string('agente_adscripcion', 180)
                ->default('Unidad de Protección en Vialidades Urbanas')
                ->after('agente_numero_placa');
        });
    }

    public function down(): void
    {
        Schema::table('conduce_legalidad_capturas', function (Blueprint $table) {
            $table->dropColumn([
                'agente_nombre',
                'agente_nombres',
                'agente_apellido_paterno',
                'agente_apellido_materno',
                'agente_numero_placa',
                'agente_adscripcion',
            ]);
        });
    }
};
