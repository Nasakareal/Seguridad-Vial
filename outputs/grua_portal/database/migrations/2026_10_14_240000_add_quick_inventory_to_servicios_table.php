<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class AddQuickInventoryToServiciosTable extends Migration
{
    public function up()
    {
        Schema::table('servicios', function (Blueprint $table) {
            $table->string('tipo_general_vehiculo', 40)->nullable()->after('tipo_vehiculo');
            $table->json('inventario_recepcion')->nullable()->after('observaciones_grua');
        });
    }

    public function down()
    {
        Schema::table('servicios', function (Blueprint $table) {
            $table->dropColumn(['tipo_general_vehiculo', 'inventario_recepcion']);
        });
    }
}
