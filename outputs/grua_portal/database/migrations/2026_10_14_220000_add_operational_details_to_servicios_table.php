<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class AddOperationalDetailsToServiciosTable extends Migration
{
    public function up()
    {
        Schema::table('servicios', function (Blueprint $table) {
            $table->boolean('realizo_maniobras')->nullable()->after('foto_vehiculo');
            $table->text('maniobras_descripcion')->nullable()->after('realizo_maniobras');
            $table->text('observaciones_grua')->nullable()->after('maniobras_descripcion');
            $table->unsignedBigInteger('actualizado_por_grua_usuario_id')
                ->nullable()
                ->after('observaciones_grua')
                ->index('servicios_grua_usuario_actualiza_idx');
            $table->timestamp('actualizado_por_grua_at')
                ->nullable()
                ->after('actualizado_por_grua_usuario_id');
        });
    }

    public function down()
    {
        Schema::table('servicios', function (Blueprint $table) {
            $table->dropIndex('servicios_grua_usuario_actualiza_idx');
            $table->dropColumn([
                'realizo_maniobras',
                'maniobras_descripcion',
                'observaciones_grua',
                'actualizado_por_grua_usuario_id',
                'actualizado_por_grua_at',
            ]);
        });
    }
}
