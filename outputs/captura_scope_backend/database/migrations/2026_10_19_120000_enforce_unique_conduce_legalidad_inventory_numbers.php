<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const INDEX_NAME = 'cl_vehiculos_numero_inventario_unique';

    public function up(): void
    {
        if (
            !Schema::hasTable('conduce_legalidad_vehiculos')
            || !Schema::hasColumn('conduce_legalidad_vehiculos', 'numero_inventario')
        ) {
            return;
        }

        // Los folios anteriores a la serie digital pueden contener duplicados.
        // No se alteran ni se eliminan: la tabla de reservas protege la nueva
        // serie y el controlador evita asignar un número histórico ocupado.
        $hayDuplicadosHistoricos = DB::table('conduce_legalidad_vehiculos')
            ->select('numero_inventario')
            ->whereNotNull('numero_inventario')
            ->where('numero_inventario', '<>', '')
            ->groupBy('numero_inventario')
            ->havingRaw('COUNT(*) > 1')
            ->exists();

        if ($hayDuplicadosHistoricos) {
            return;
        }

        Schema::table('conduce_legalidad_vehiculos', function (Blueprint $table) {
            $table->unique('numero_inventario', self::INDEX_NAME);
        });
    }

    public function down(): void
    {
        if (
            Schema::hasTable('conduce_legalidad_vehiculos')
            && Schema::hasColumn('conduce_legalidad_vehiculos', 'numero_inventario')
        ) {
            Schema::table('conduce_legalidad_vehiculos', function (Blueprint $table) {
                $table->dropUnique(self::INDEX_NAME);
            });
        }
    }
};
